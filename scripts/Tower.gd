extends Area2D

# Tower type selection
@export var tower_type: String = "spear"

# Tower stats (set in _ready() based on tower_type)
var attack_range: float = 150.0
var fire_rate: float = 1.0
var tower_cost: int = 50
var tower_damage: int = 10

# Tower's own visual sprite path (used for the tower placed on the map)
var tower_texture_path: String = ""

# Projectile texture path (what this tower shoots at enemies)
var projectile_texture_path: String = ""

# Tower state tracking
var enemies_in_range = []


func _ready():
	# Set stats and textures based on tower type
	if tower_type == "arrow":
		attack_range = 200.0
		fire_rate = 1.5
		tower_cost = 75
		tower_damage = 8
		tower_texture_path = "res://assets/sprites/Tower_basic_arrow.png"
		projectile_texture_path = "res://assets/sprites/arrow.png"
	elif tower_type == "shells":
		attack_range = 130.0
		fire_rate = 0.5
		tower_cost = 120
		tower_damage = 30
		tower_texture_path = "res://assets/sprites/Tower_basic_shells.png"
		projectile_texture_path = "res://assets/sprites/Shell.png"
	else: # spear (default)
		attack_range = 150.0
		fire_rate = 1.0
		tower_cost = 50
		tower_damage = 10
		tower_texture_path = "res://assets/sprites/Tower_basic_spear.png"
		projectile_texture_path = "res://assets/sprites/Spear.png"

	# Create and set the collision shape radius to match attack range
	var collision_shape = get_node("CollisionShape2D")
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = attack_range
	collision_shape.shape = circle_shape

	# Load and set tower's own sprite texture (its visual on the map)
	var sprite = get_node("Sprite2D")
	sprite.texture = load(tower_texture_path)

	# Scale the sprite appropriately for 720x1280 screen (roughly 64x64 pixels)
	sprite.scale = Vector2(0.5, 0.5)

	# Setup timer for shooting
	var timer = Timer.new()
	add_child(timer)
	timer.connect("timeout",Callable(self,"_on_shoot_timer"))
	timer.wait_time = 1.0 / fire_rate
	timer.start()


func _process(_delta):
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

	# Pass damage value to the projectile
	projectile.damage = tower_damage

	# Pass texture path so projectile loads its own visual
	projectile.texture_path = projectile_texture_path

	# Add projectile as child of the scene
	get_tree().root.add_child(projectile)