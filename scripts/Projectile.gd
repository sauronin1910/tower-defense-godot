extends Area2D

# Exported variables for projectile configuration
@export var speed: float = 400.0
@export var damage: int = 10

# On-map length of a projectile sprite, in map pixels (tile = 96).
# Source art can be any resolution; this keeps every projectile the same size.
const TARGET_LENGTH: float = 25.9

# Sprite art points up (-Y), while angle 0 in Godot is +X, so rotate a quarter
# turn on top of the travel direction to put the tip forward.
const SPRITE_ANGLE_OFFSET: float = PI * 0.5

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

	# Scale to TARGET_LENGTH regardless of the source resolution
	if sprite.texture != null and sprite.texture.get_size().y > 0.0:
		var s: float = TARGET_LENGTH / sprite.texture.get_size().y
		sprite.scale = Vector2(s, s)
	else:
		sprite.scale = Vector2(1.0, 1.0)


func _process(delta):
	# Freed enemies leave a stale reference that is not null, so check validity
	if not is_instance_valid(target):
		queue_free()
		return

	# Move towards the target
	var direction = target.global_position - global_position
	var distance = direction.length()

	# Point the tip along the direction of travel
	if distance > 0.0:
		rotation = direction.angle() + SPRITE_ANGLE_OFFSET

	# If we're close enough to the target, hit it
	if distance < speed * delta:
		hit_target()
	else:
		# Move toward target at constant speed
		direction = direction.normalized() * speed * delta
		global_position += direction


func hit_target():
	if is_instance_valid(target):
		# Apply damage to the enemy
		target.take_damage(damage)
	queue_free()
