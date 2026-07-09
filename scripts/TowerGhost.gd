extends Node2D

# Ghost preview of a tower while player is dragging to place it.
# Shows the tower sprite semi-transparently plus a range circle.
# Modulates green/red based on whether placement is currently valid.

var tower_type: String = "spear"
var attack_range: float = 150.0
var is_valid: bool = true

var sprite: Sprite2D = null


func _ready() -> void:
	z_index = 20
	# Create sprite
	sprite = Sprite2D.new()
	sprite.scale = Vector2(0.5, 0.5)
	add_child(sprite)
	_apply_type()


func set_tower_type(new_type: String) -> void:
	tower_type = new_type
	if sprite != null:
		_apply_type()


func _apply_type() -> void:
	var tex_path: String = "res://assets/sprites/Tower_basic_spear.png"
	if tower_type == "arrow":
		tex_path = "res://assets/sprites/Tower_basic_arrow.png"
		attack_range = 200.0
	elif tower_type == "shells":
		tex_path = "res://assets/sprites/Tower_basic_shells.png"
		attack_range = 130.0
	else:
		attack_range = 150.0
	
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)


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
