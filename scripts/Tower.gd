extends Area2D

signal tower_clicked(tower)

# Tower type selection
@export var tower_type: String = "spear"

# Upgrade system
var level: int = 1
const MAX_LEVEL: int = 3
var total_gold_invested: int = 0

# Tower stats (set in _ready() based on tower_type, then scaled by level)
var base_attack_range: float = 150.0
var base_fire_rate: float = 1.0
var base_tower_damage: int = 10
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
	add_to_group("towers")
	# Set stats and textures based on tower type
	if tower_type == "arrow":
		base_attack_range = 200.0
		base_fire_rate = 1.5
		tower_cost = 75
		base_tower_damage = 8
		tower_texture_path = "res://assets/sprites/Tower_basic_arrow.png"
		projectile_texture_path = "res://assets/sprites/arrow.png"
	elif tower_type == "shells":
		base_attack_range = 130.0
		base_fire_rate = 0.5
		tower_cost = 120
		base_tower_damage = 30
		tower_texture_path = "res://assets/sprites/Tower_basic_shells.png"
		projectile_texture_path = "res://assets/sprites/Shell.png"
	else: # spear (default)
		base_attack_range = 150.0
		base_fire_rate = 1.0
		tower_cost = 50
		base_tower_damage = 10
		tower_texture_path = "res://assets/sprites/Tower_basic_spear.png"
		projectile_texture_path = "res://assets/sprites/Spear.png"
	
	total_gold_invested = tower_cost
	_apply_level_stats()	

	# Create and set the collision shape radius to match attack range
	var collision_shape = get_node("CollisionShape2D")
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 32.0
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
	
	# Enable input for click detection (deferred to avoid catching the placement click)
	input_pickable = false
	input_event.connect(_on_input_event)
	call_deferred("_enable_input_after_frame")


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tower_clicked.emit(self)
		get_viewport().set_input_as_handled()


func _process(_delta):
	# Manually check distance to all enemies in the scene
	enemies_in_range.clear()
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= attack_range:
			enemies_in_range.append(enemy)


func _on_shoot_timer():
	if enemies_in_range.is_empty():
		return

	var best_target: Object = null
	var best_progress: float = -1.0

	for enemy in enemies_in_range:
		if not is_instance_valid(enemy):
			continue
		if enemy.progress_ratio > best_progress:
			best_progress = enemy.progress_ratio
			best_target = enemy

	if best_target != null:
		shoot(best_target)



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


# ════════════════════════════════════════════
#  UPGRADE SYSTEM
# ════════════════════════════════════════════

func _apply_level_stats() -> void:
	# Each level: +15% damage, +15% fire rate, +15% range
	var multiplier: float = pow(1.15, level - 1)
	attack_range = base_attack_range * multiplier
	fire_rate = base_fire_rate * multiplier
	tower_damage = int(base_tower_damage * multiplier)
	
	
	# Visual: darken by 25% per level (level 1 = 1.0, level 2 = 0.75, level 3 = 0.5)
	var sprite = get_node("Sprite2D")
	var darkness: float = 1.0 - (level - 1) * 0.25
	sprite.modulate = Color(darkness, darkness, darkness, 1.0)


func get_upgrade_cost() -> int:
	if level >= MAX_LEVEL:
		return 0
	return int(tower_cost * 0.75)


func get_sell_value() -> int:
	return int(total_gold_invested * 0.7)


func upgrade() -> bool:
	if level >= MAX_LEVEL:
		return false
	var cost: int = get_upgrade_cost()
	total_gold_invested += cost
	level += 1
	_apply_level_stats()
	return true
func _enable_input_after_frame() -> void:
	await get_tree().process_frame
	input_pickable = true
