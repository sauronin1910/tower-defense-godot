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

# Projectile texture path (what this tower shoots at enemies)
var projectile_texture_path: String = ""

# Tower state tracking
var enemies_in_range = []
var range_visible: bool = false

# Ground footprint, used to stop towers overlapping each other
var footprint_radius: float = 48.0

# Idle animation state (flag waving)
var frame_textures: Array = []
var frame_index: int = 0
var frame_timer: float = 0.0
const FRAME_DURATION: float = 0.1


func _ready():
	add_to_group("towers")
	# Stats per tower type; visuals and range come from TowerVisuals
	if tower_type == "arrow":
		base_fire_rate = 1.5
		tower_cost = 75
		base_tower_damage = 8
		projectile_texture_path = "res://assets/sprites/arrow.png"
	elif tower_type == "shells":
		base_fire_rate = 0.5
		tower_cost = 120
		base_tower_damage = 30
		projectile_texture_path = "res://assets/sprites/Shell.png"
	else: # spear (default)
		base_fire_rate = 1.0
		tower_cost = 50
		base_tower_damage = 10
		projectile_texture_path = "res://assets/sprites/Spear.png"

	base_attack_range = TowerVisuals.attack_range(tower_type)
	footprint_radius = TowerVisuals.footprint_radius(tower_type)
	total_gold_invested = tower_cost

	# Load visuals: animation frames if this type has them, otherwise one texture
	var sprite = get_node("Sprite2D")
	frame_textures = TowerVisuals.load_frames(tower_type)
	if frame_textures.is_empty():
		sprite.texture = null
	else:
		# Randomize the starting frame so towers don't wave in lockstep
		frame_index = randi() % frame_textures.size()
		frame_timer = randf() * FRAME_DURATION
		sprite.texture = frame_textures[frame_index]
		# Scale and offset come from frame 0 so every frame lines up identically
		sprite.scale = TowerVisuals.scale_for(frame_textures[0])
		sprite.offset = TowerVisuals.base_offset(frame_textures[0])

	_apply_level_stats()

	# Click hitbox matches the sprite so the whole tower is selectable
	var collision_shape = get_node("CollisionShape2D")
	var rect_shape = RectangleShape2D.new()
	if sprite.texture != null:
		rect_shape.size = sprite.texture.get_size() * sprite.scale
	else:
		rect_shape.size = Vector2(64.0, 64.0)
	collision_shape.shape = rect_shape
	# Follow wherever the sprite actually ended up, offset and all
	collision_shape.position = sprite.offset * sprite.scale

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


func _process(delta):
	_advance_flag_animation(delta)

	# Manually check distance to all enemies in the scene
	enemies_in_range.clear()
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= attack_range:
			enemies_in_range.append(enemy)


func _advance_flag_animation(delta: float) -> void:
	if frame_textures.size() < 2:
		return
	frame_timer += delta
	if frame_timer < FRAME_DURATION:
		return
	frame_timer -= FRAME_DURATION
	frame_index = (frame_index + 1) % frame_textures.size()
	get_node("Sprite2D").texture = frame_textures[frame_index]


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

func _draw() -> void:
	if not range_visible:
		return
	draw_circle(Vector2.ZERO, attack_range, Color(0.2, 0.6, 1.0, 0.15))
	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(0.2, 0.6, 1.0, 0.8), 2.0)

func show_range() -> void:
	range_visible = true
	queue_redraw()

func hide_range() -> void:
	range_visible = false
	queue_redraw()


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
	if range_visible:
		queue_redraw()


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
