extends Node

# One-shot mask generator (v3 — geometry-accurate, shape-query).
# Attach to a temporary Node in the scene, run the scene once.
#
# Samples the ROAD COLLISION geometry at sub-tile resolution using the SAME
# physics query style that the working tower-placement check uses:
# intersect_shape with a small circle on get_world_2d(). A point query
# (intersect_point) missed the road because the per-tile road colliders have
# tiny seams between tiles that a bare point slips through; a small circle
# bridges those seams, exactly like the tower footprint check does.
#
# White (255) = grass allowed, Black (0) = road (no grass).

const OUTPUT_PATH: String = "res://assets/grass_mask.png"
const ROAD_COLLISION_MASK: int = 1 << 4     # road physics layer 5 (value 16)
const SUBDIV: int = 8                        # samples per tile per axis
const PROBE_RADIUS: float = 8.0              # small circle to bridge tile seams

@export var tilemap_path: NodePath = ^"../TileMapLayer"

var _done: bool = false


var _frames_waited: int = 0

func _physics_process(_delta: float) -> void:
	if _done:
		return
	# Wait several physics frames so TileMapLayer colliders are registered.
	_frames_waited += 1
	if _frames_waited < 30:
		return
	_done = true
	_generate()
	queue_free()


func _generate() -> void:
	var tilemap := get_node_or_null(tilemap_path) as TileMapLayer
	if tilemap == null:
		tilemap = _find_tilemap_named(get_tree().root, "TileMapLayer")
	if tilemap == null:
		tilemap = _find_any_tilemap(get_tree().root)
	if tilemap == null:
		push_error("MaskGen: no TileMapLayer found anywhere in the scene")
		return
	print("MaskGen: using TileMapLayer at ", tilemap.get_path())

	var used: Rect2i = tilemap.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		push_error("MaskGen: tilemap has no used cells")
		return

	var tile_size: Vector2 = Vector2(tilemap.tile_set.tile_size)
	var world_origin: Vector2 = Vector2(used.position) * tile_size

	var out_w: int = used.size.x * SUBDIV
	var out_h: int = used.size.y * SUBDIV
	var img := Image.create(out_w, out_h, false, Image.FORMAT_L8)
	img.fill(Color(1, 1, 1, 1))  # default: grass everywhere

	# World2D via the tilemap (a CanvasItem) — Node itself has no get_world_2d().
	var space: PhysicsDirectSpaceState2D = tilemap.get_world_2d().direct_space_state
	var step: Vector2 = tile_size / float(SUBDIV)

	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = PROBE_RADIUS
	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.collision_mask = ROAD_COLLISION_MASK
	params.collide_with_bodies = true
	params.collide_with_areas = false

	var road_hits: int = 0
	for py in range(out_h):
		for px in range(out_w):
			var wp: Vector2 = world_origin + Vector2(
				(float(px) + 0.5) * step.x,
				(float(py) + 0.5) * step.y
			)
			params.transform = Transform2D(0.0, wp)
			if space.intersect_shape(params, 1).size() > 0:
				img.set_pixel(px, py, Color(0, 0, 0, 1))  # road = black
				road_hits += 1

	var err := img.save_png(OUTPUT_PATH)
	if err == OK:
		print("MaskGen: saved ", OUTPUT_PATH,
			"  img_size=", Vector2i(out_w, out_h),
			"  road_pixels=", road_hits, " / ", out_w * out_h)
		print("MaskGen: mask world origin (px) = ", world_origin)
		print("MaskGen: mask world size  (px) = ", Vector2(used.size) * tile_size)
		if road_hits == 0:
			push_warning("MaskGen: found NO road pixels — check ROAD_COLLISION_MASK / that road colliders exist")
	else:
		push_error("MaskGen: save failed, error %d" % err)


func _find_tilemap_named(node: Node, wanted_name: String) -> TileMapLayer:
	if node is TileMapLayer and node.name == wanted_name:
		return node as TileMapLayer
	for child in node.get_children():
		var found := _find_tilemap_named(child, wanted_name)
		if found != null:
			return found
	return null


func _find_any_tilemap(node: Node) -> TileMapLayer:
	if node is TileMapLayer:
		return node as TileMapLayer
	for child in node.get_children():
		var found := _find_any_tilemap(child)
		if found != null:
			return found
	return null
