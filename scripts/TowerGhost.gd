extends Node2D

# Ghost preview of a tower while player is dragging to place it.
# Shows the tower sprite semi-transparently, a range circle, and a small grid
# of tiles around the cursor tinted green (buildable) or red (blocked road).
# All visuals come from TowerVisuals so this always matches the real tower.

var tower_type: String = "spear"
var attack_range: float = 150.0
var is_valid: bool = true
var footprint_radius: float = 48.0
var range_reveal: float = 0.0
var sprite: Sprite2D = null

# Placement-grid overlay
const CELL_SIZE: float = 12.0        # fine cells, ~1/8 of a 96px map tile
const GRID_EXTENT: float = 96.0      # half-width of the overlay area, in pixels
const ROAD_MASK: int = 1 << 4        # must match Main.gd ROAD_COLLISION_MASK


func _ready() -> void:
	z_index = 20
	sprite = Sprite2D.new()
	add_child(sprite)
	_apply_type()


func set_tower_type(new_type: String) -> void:
	tower_type = new_type
	if sprite != null:
		_apply_type()


func _apply_type() -> void:
	attack_range = TowerVisuals.attack_range(tower_type)
	footprint_radius = TowerVisuals.footprint_radius(tower_type)

	# Preview uses the first frame; the ghost doesn't animate
	var frames: Array = TowerVisuals.load_frames(tower_type)
	if frames.is_empty():
		sprite.texture = null
	else:
		sprite.texture = frames[0]
		sprite.scale = TowerVisuals.scale_for(sprite.texture)
		sprite.offset = TowerVisuals.base_offset(sprite.texture)

	set_valid(is_valid)
	queue_redraw()


func set_valid(valid: bool) -> void:
	is_valid = valid
	queue_redraw()
	if sprite != null:
		if valid:
			sprite.modulate = Color(0.5, 1.0, 0.5, 0.7)
		else:
			sprite.modulate = Color(1.0, 0.4, 0.4, 0.7)


func _process(delta: float) -> void:
	# Grow the range ring open, then hold it; grid needs a redraw each frame anyway
	if range_reveal < 1.0:
		range_reveal = min(range_reveal + delta * 6.0, 1.0)
	# The grid follows the cursor, so it must redraw as the ghost moves
	queue_redraw()


# True if the given world point sits on a blocked road tile
func _is_road_at(world_point: Vector2) -> bool:
	var world := get_world_2d()
	if world == null:
		return false
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_point
	params.collision_mask = ROAD_MASK
	params.collide_with_bodies = true
	params.collide_with_areas = false
	return world.direct_space_state.intersect_point(params, 1).size() > 0


func _draw() -> void:
	_draw_placement_grid()

	# Range ring: plain black arc that animates open, matching placed towers
	var ring_r: float = attack_range * range_reveal
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64, Color(0.0, 0.0, 0.0, 1.0), 2.0)


func _draw_placement_grid() -> void:
	var green := Color(0.3, 1.0, 0.3, 0.16)
	var red := Color(1.0, 0.3, 0.3, 0.22)
	# Snap the cursor to the fine grid so cells sit still as the mouse moves
	var origin: Vector2 = global_position
	var count: int = int(GRID_EXTENT / CELL_SIZE)
	var base_x: float = floor(origin.x / CELL_SIZE)
	var base_y: float = floor(origin.y / CELL_SIZE)
	var cell_vec := Vector2(CELL_SIZE, CELL_SIZE)
	for dy in range(-count, count + 1):
		for dx in range(-count, count + 1):
			var top_left_world := Vector2((base_x + dx) * CELL_SIZE, (base_y + dy) * CELL_SIZE)
			var center_world := top_left_world + cell_vec * 0.5
			var color := red if _is_road_at(center_world) else green
			# _draw is in local space, so convert the world rect back to local
			draw_rect(Rect2(top_left_world - global_position, cell_vec), color, true)
