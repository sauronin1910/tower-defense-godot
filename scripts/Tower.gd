extends Area2D

# Exported variables for tower configuration
@export var attack_range: float = 150.0
@export var projectile_texture: String = "res://assets/sprites/Spear.png"
@export var fire_rate: float = 1.0 # Shots per second

# Tower state tracking
var enemies_in_range = []

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
	
	# Setup timer for shooting
	var timer = Timer.new()
	add_child(timer)
	timer.connect("timeout",Callable(self,"_on_shoot_timer"))
	timer.wait_time = 1.0 / fire_rate
	timer.start()

func _process(delta):
	# Manually check distance to all enemies in the scene
	enemies_in_range.clear()
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= attack_range:
			enemies_in_range.append(enemy)

func _on_shoot_timer():
	if not enemies_in_range.is_empty():
		var target = enemies_in_range[0]  # Get the first enemy (closest logic can come later)
		shoot(target)

func shoot(target):
	# Load and instantiate projectile
	var projectile_scene = preload("res://scenes/Projectile.tscn")
	var projectile = projectile_scene.instantiate()
	
	# Set projectile position to tower's position
	projectile.global_position = global_position
	
	# Give projectile reference to target enemy
	projectile.target = target
	
	# Add projectile as child of the scene
	get_tree().root.add_child(projectile)