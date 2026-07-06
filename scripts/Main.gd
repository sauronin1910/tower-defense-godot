extends Node2D

# Class-level state
var enemies_spawned = 0
var current_wave_number = 1

# Base health system
@export var base_health: int = 20
const BASE_MAX_HEALTH = 20

# Exported variables for wave spawning
@export var spawn_interval = 1.0

# Timer for enemy spawning
var spawn_timer: Timer

# Reference to the HP label UI node
var health_label: Label

# Reference to the wave number label UI node
var wave_label: Label

# Delay timer between waves
var next_wave_timer: Timer


func damage_base(amount: int):
	base_health -= amount
	if base_health <= 0:
		print("GAME OVER - Base destroyed!")
		get_tree().paused = true
		if is_instance_valid(health_label):
			health_label.text = "GAME OVER"
	else:
		if is_instance_valid(health_label):
			health_label.text = "Base HP: %d/%d" % [base_health, BASE_MAX_HEALTH]


# Called when the node enters the scene tree for the first time.
func _ready():
	# Build the enemy curve path
	build_curve()
	
	# Get references to UI label nodes
	health_label = get_node("CanvasLayer/Control/HealthLabel")
	wave_label = get_node("CanvasLayer/Control/WaveLabel")
	update_health_display()
	update_wave_display()
	
	# Create and configure the spawn timer
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.connect("timeout", Callable(self, "_on_spawn_timer_timeout"))
	
	# Create the between-waves delay timer
	next_wave_timer = Timer.new()
	add_child(next_wave_timer)
	next_wave_timer.connect("timeout", Callable(self, "_on_next_wave_delay_done"))
	
	# Start the first wave
	start_wave(current_wave_number)


func update_health_display():
	if is_instance_valid(health_label):
		health_label.text = "Base HP: %d/%d" % [base_health, BASE_MAX_HEALTH]


func update_wave_display():
	if is_instance_valid(wave_label):
		wave_label.text = "Wave: %d" % current_wave_number


# Function to build the enemy path curve
func build_curve():
	var enemy_path = get_node("EnemyPath")
	var curve = Curve2D.new()
	
	# Add the 6 points for the enemy path
	curve.add_point(Vector2(360, 50))
	curve.add_point(Vector2(100, 200))
	curve.add_point(Vector2(600, 350))
	curve.add_point(Vector2(200, 500))
	curve.add_point(Vector2(500, 650))
	curve.add_point(Vector2(360, 800))
	
	# Assign the curve to the EnemyPath node
	enemy_path.curve = curve


func _get_enemies_per_wave(wave: int) -> int:
	return 5 + (wave - 1)


func _get_knight_count(wave: int) -> int:
	var total = _get_enemies_per_wave(wave)
	var max_knights = floor(total / 2.0)
	return min(wave, max_knights)


# Function to spawn an enemy of a specific type
func spawn_enemy(enemy_type: String):
	var enemy_scene = preload("res://scenes/Enemy.tscn")
	var new_enemy = enemy_scene.instantiate()
	new_enemy.enemy_type = enemy_type
	
	# Connect the enemy_reached_end signal so Main knows when to deal damage
	new_enemy.enemy_reached_end.connect(damage_base)
	
	# Add the enemy as child of EnemyPath so PathFollow2D works properly
	get_node("EnemyPath").add_child(new_enemy)
	
	# Register in group so towers can find them via get_tree().get_nodes_in_group("enemies")
	new_enemy.add_to_group("enemies")


# Function to start a wave of enemies
func start_wave(wave_number: int):
	print("Wave ", wave_number, " started")
	current_wave_number = wave_number
	
	enemies_spawned = 0
	
	# Set wave-specific enemy count and update UI
	var total_enemies = _get_enemies_per_wave(wave_number)
	spawn_timer.wait_time = spawn_interval
	update_wave_display()
	
	# Start the first wave
	spawn_timer.start()


# Called when the spawn timer times out
func _on_spawn_timer_timeout():
	var wave = current_wave_number
	var total = _get_enemies_per_wave(wave)
	var knight_count = _get_knight_count(wave)
	
	if enemies_spawned < total - knight_count:
		spawn_enemy("peasant")
	else:
		spawn_enemy("knight")
	
	enemies_spawned += 1
	
	if enemies_spawned >= total:
		print("Wave ", wave, " complete")
		spawn_timer.stop()
		
		# Start delay timer before next wave (3 seconds)
		next_wave_timer.wait_time = 3.0
		next_wave_timer.start()


func _on_next_wave_delay_done():
	if base_health > 0:
		start_wave(current_wave_number + 1)


# Handle input events for tower placement
func _unhandled_input(event):
	# Check if this is a mouse button press (for desktop) or screen touch (for mobile)
	if event is InputEventMouseButton:
		# Only respond to left mouse button clicks
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			place_tower(event.position)

	elif event is InputEventScreenTouch:
		# Only respond to first touch (primary finger)
		if event.pressed:
			place_tower(event.position)


# Function to place a tower at the given position
func place_tower(tap_position):
	# Load the Tower scene
	var tower_scene = preload("res://scenes/Tower.tscn")
	
	# Instance the tower
	var new_tower = tower_scene.instantiate()
	
	# Set the position where the tap occurred
	new_tower.position = tap_position
	
	# Add it as a child to this node (Main)
	add_child(new_tower)
