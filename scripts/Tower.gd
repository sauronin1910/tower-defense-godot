extends Area2D

# Exported variables for tower configuration
@export var attack_range: float = 150.0
@export var projectile_texture: String = "res://assets/sprites/Spear.png"

func _ready():
	# Create and set the collision shape radius to match attack range
	var collision_shape = get_node("CollisionShape2D")
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = attack_range
	collision_shape.shape = circle_shape
	
	# Load and set tower sprite texture
	var sprite = get_node("Sprite2D")
	sprite.texture = preload("res://assets/sprites/Tower_basic_spear.png")
	
	# Scale the sprite appropriately for 720x1280 screen (roughly 64x64 pixels)
	sprite.scale = Vector2(0.5, 0.5)
