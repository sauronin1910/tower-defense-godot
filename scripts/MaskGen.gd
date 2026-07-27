extends Node

# One-shot mask generator (v3 — geometry-accurate, shape-query).
#
# EDITOR-ONLY TOOL. Never put this node in Main.tscn: the sampling loop below is
# ~1.3M blocking physics queries and save_png() cannot write to res:// in an
# exported build. Run `scenes/MaskGenTool.tscn` (F6) instead — it instances Main
# and adds this node next to it. See CLAUDE.md → Regenerating the grass mask.
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
const SUBDIV: int = 32
# Decor footprints are carved as ellipses — flatter than circles, since the
# ground is seen at an angle.
const PROBE_RADIUS: float = 1
# Decor is carved by its own silhouette: the bottom slice of its opaque pixels is
# what touches the ground, so any shape works without per-object tuning.
const CARVE_SLICE_RATIO: float = 0.18   # bottom fraction of the art counted as ground contact
const CARVE_DILATE: int = 2             # grow the stamp a little so it isn't a hairline      # small circle to bridge tile seams

@export var tilemap_path: NodePath = ^"../TileMapLayer"

var _done: bool = false


var _frames_waited: int = 0


func _ready() -> void:
	# Hard stop in an exported build: res:// is read-only there, and the sampling
	# pass would freeze the game for many seconds before failing to save.
	if not OS.has_feature("editor"):
		push_error("MaskGen: editor-only tool, refusing to run in an exported build")
		_done = true
		queue_free()


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
# ── Carve decor into the mask ──
	# Stamp the bottom slice of each decor sprite's silhouette, so grass streaks
	# stop at trees and rocks and the trembling rim forms around them for free.
	# Walking texture pixels (rather than mask pixels) lets to_global() handle
	# scale, rotation and flips for us.
	var carved: int = 0
	for d in get_tree().get_nodes_in_group("decor"):
		if not is_instance_valid(d) or not ("carves_grass" in d):
			continue
		if not d.carves_grass or d.texture == null:
			continue
		var img2: Image = d.texture.get_image()
		if img2 == null:
			continue
		if img2.is_compressed():
			img2.decompress()
		var ob: Rect2i = img2.get_used_rect()
		if ob.size.x <= 0 or ob.size.y <= 0:
			continue
		var tex_size: Vector2 = d.texture.get_size()
		var slice_h: int = max(1, int(round(float(ob.size.y) * CARVE_SLICE_RATIO)))
		var slice_top: int = ob.position.y + ob.size.y - slice_h
		for ty in range(slice_top, ob.position.y + ob.size.y):
			for tx in range(ob.position.x, ob.position.x + ob.size.x):
				if img2.get_pixel(tx, ty).a <= 0.3:
					continue
				# Sprite2D draws centred, so local coords are texture pixels
				# measured from the middle.
				var local: Vector2 = Vector2(float(tx) + 0.5, float(ty) + 0.5) - tex_size * 0.5
				local += d.offset
				if d.flip_h:
					local.x = -local.x
				if d.flip_v:
					local.y = -local.y
				var wp2: Vector2 = d.to_global(local)
				var mx: int = int((wp2.x - world_origin.x) / step.x)
				var my: int = int((wp2.y - world_origin.y) / step.y)
				for oy in range(-CARVE_DILATE, CARVE_DILATE + 1):
					for ox in range(-CARVE_DILATE, CARVE_DILATE + 1):
						var px2: int = mx + ox
						var py2: int = my + oy
						if px2 < 0 or py2 < 0 or px2 >= out_w or py2 >= out_h:
							continue
						img.set_pixel(px2, py2, Color(0, 0, 0, 1))
						carved += 1
	print("MaskGen: carved ", carved, " decor pixels")
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
