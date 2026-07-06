extends PathFollow2D

# Exported variable for enemy type selection
@export var enemy_type: String = "peasant"

# Health system
var health: int = 0
@export var speed: float = 100.0

func _ready():
	print("Enemy created with type: ", enemy_type)
	
	# Set stats based on enemy type directly
	if enemy_type == "knight":
		health = 80
		speed = 70
	else:
		health = 30
		speed = 100
	
	print("Enemy type: ", enemy_type, " - Health: ", health, " - Speed: ", speed)
	
	# Apply texture to sprite
	var sprite_node = get_node("Sprite2D")
	if enemy_type == "knight":
		sprite_node.texture = preload("res://assets/sprites/Knight.png")
	else:
		sprite_node.texture = preload("res://assets/sprites/Peasant .png")
	
	# Scale the sprite for better visibility on 720x1280 screen
	sprite_node.scale = Vector2(0.5, 0.5)
	
	# Start at the beginning of the path
	progress_ratio = 0.0

func _process(delta):
	# Move forward along the path based on speed and delta time
	progress_ratio += delta * speed / get_parent().curve.get_baked_length()
	
	# Check if enemy has reached the end of the path
	if progress_ratio >= 1.0:
		print("Enemy reached the end")
		queue_free() # Remove this enemy from the scene

func take_damage(damage: int):
	health -= damage
	if health <= 0:
		print("Enemy defeated!")
		queue_free()
