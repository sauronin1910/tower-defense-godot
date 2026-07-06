extends Area2D

# Exported variables for projectile configuration
@export var speed: float = 400.0
@export var damage: int = 10

# Target enemy reference
var target = null

# Dynamic texture path (set by the tower that fires this projectile)
var texture_path: String = ""


func _ready():
	# Create and set collision shape programmatically
	var collision_shape = get_node("CollisionShape2D")
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 10.0
	collision_shape.shape = circle_shape

	# Set sprite texture from the path provided by the tower
	var sprite = get_node("Sprite2D")
	if texture_path != "":
		sprite.texture = load(texture_path)

	# Scale the sprite appropriately for 720x1280 screen (roughly 32x32 pixels)
	sprite.scale = Vector2(0.5, 0.5)


func _process(delta):
	if target != null:
		# Move towards the target
		var direction = target.global_position - global_position
		var distance = direction.length()

		# If we're close enough to the target, hit it
		if distance < speed * delta:
			hit_target()
		else:
			# Move toward target at constant speed
			direction = direction.normalized() * speed * delta
			global_position += direction
	else:
		# Target was destroyed or invalid
		queue_free()


func hit_target():
	if target != null and is_instance_valid(target):
		# Apply damage to the enemy
		target.take_damage(damage)
	queue_free()