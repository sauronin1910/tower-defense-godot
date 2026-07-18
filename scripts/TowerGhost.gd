extends Node2D

# Ghost preview of a tower while player is dragging to place it.
# Shows the tower sprite semi-transparently plus a range circle.
# Modulates green/red based on whether placement is currently valid.
# All visuals come from TowerVisuals so this always matches the real tower.

var tower_type: String = "spear"
var attack_range: float = 150.0
var is_valid: bool = true
var sprite: Sprite2D = null


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


func _draw() -> void:
	# Draw range circle around ghost
	var fill_color: Color = Color(0.2, 0.9, 0.2, 0.15) if is_valid else Color(0.9, 0.2, 0.2, 0.15)
	var border_color: Color = Color(0.2, 0.9, 0.2, 0.8) if is_valid else Color(0.9, 0.2, 0.2, 0.8)
	draw_circle(Vector2.ZERO, attack_range, fill_color)
	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, border_color, 2.0)
