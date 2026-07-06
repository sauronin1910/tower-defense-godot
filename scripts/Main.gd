extends Node2D

# Class-level state
var enemies_spawned = 0
var current_wave_number = 1

# Base health system
@export var base_health: int = 20
const BASE_MAX_HEALTH = 20

# Gold/economy system
@export var starting_gold: int = 100
var current_gold: int = 0

# Tower selection state
var selected_tower_type: String = "spear"

# Tower type stats dictionary (mirrors Tower.gd)
const TOWER_STATS = {
	"spear": {"cost": 50, "attack_range": 150.0, "fire_rate": 1.0, "damage": 10},
	"arrow": {"cost": 75, "attack_range": 200.0, "fire_rate": 1.5, "damage": 8},
	"shells": {"cost": 120, "attack_range": 130.0, "fire_rate": 0.5, "damage": 30}
}

func gold_earned(amount: int):
	current_gold += amount
	if is_instance_valid(gold_label):
		gold_label.text = "Gold: %d" % current_gold

func can_afford(cost: int) -> bool:
	return current_gold >= cost

func spend_gold(amount: int):
	current_gold -= amount
	if is_instance_valid(gold_label):
		gold_label.text = "Gold: %d" % current_gold

# Exported variables for wave spawning
@export var spawn_interval = 1.0

# Timer for enemy spawning
var spawn_timer: Timer

# Reference to the HP label UI node
var health_label: Label

# Reference to the wave number label UI node
var wave_label: Label

# Reference to the gold label UI node
var gold_label: Label

# Delay timer between waves
var next_wave_timer: Timer

# Game over screen nodes
var game_over_screen: Control
var restart_button: Button

# Tower selection buttons
var spear_button: Button
var arrow_button: Button
var shells_button: Button

# Highlight style for the selected tower button
var highlight_style: StyleBoxFlat


func damage_base(amount: int):
	base_health -= amount
	if base_health <= 0:
		print("GAME OVER - Base destroyed!")
		get_tree().paused = true
		if is_instance_valid(health_label):
			health_label.text = "GAME OVER"
		if is_instance_valid(game_over_screen):
			game_over_screen.visible = true
	else:
		if is_instance_valid(health_label):
			health_label.text = "Base HP: %d/%d" % [base_health, BASE_MAX_HEALTH]


func restart_game():
	get_tree().paused = false
	get_tree().reload_current_scene()



# --- Enemy path curve ---

func build_curve():
	var enemy_path = $EnemyPath
	var curve = Curve2D.new()
	curve.add_point(Vector2(360, 50))
	curve.add_point(Vector2(100, 200))
	curve.add_point(Vector2(600, 350))
	curve.add_point(Vector2(200, 500))
	curve.add_point(Vector2(500, 650))
	curve.add_point(Vector2(360, 800))
	enemy_path.curve = curve

# Called when the node enters the scene tree for the first time.
func _ready():
	# Build the enemy curve path
	build_curve()

	# Get references to UI label nodes
	health_label = get_node("CanvasLayer/Control/HealthLabel")
	wave_label = get_node("CanvasLayer/Control/WaveLabel")
	gold_label = get_node("CanvasLayer/Control/GoldLabel")
	game_over_screen = get_node("CanvasLayer/GameOverScreen")
	restart_button = game_over_screen.get_node("RestartButton")

	# Get references to tower selection buttons
	spear_button = get_node("CanvasLayer/Control/TowerButtonsDock/SpearButton")
	arrow_button = get_node("CanvasLayer/Control/TowerButtonsDock/ArrowButton")
	shells_button = get_node("CanvasLayer/Control/TowerButtonsDock/ShellsButton")

	# Create highlight style (3px accent border)
	highlight_style = StyleBoxFlat.new()
	highlight_style.set_border_width_all(3)
	highlight_style.set_border_color(Color(0.2, 0.85, 1, 1))

	current_gold = starting_gold
	update_health_display()
	update_wave_display()
	update_gold_display()

	# Connect Restart button to restart_game
	restart_button.pressed.connect(restart_game)

	# Connect tower selection buttons
	spear_button.pressed.connect(_on_spear_selected)
	arrow_button.pressed.connect(_on_arrow_selected)
	shells_button.pressed.connect(_on_shells_selected)

	# Set initial selection (spear is default)
	update_tower_selection_ui()

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


func update_gold_display():
	if is_instance_valid(gold_label):
		gold_label.text = "Gold: %d" % current_gold


# --- Tower selection UI ---

func _on_spear_selected():
	selected_tower_type = "spear"
	update_tower_selection_ui()


func _on_arrow_selected():
	selected_tower_type = "arrow"
	update_tower_selection_ui()


func _on_shells_selected():
	selected_tower_type = "shells"
	update_tower_selection_ui()


func update_tower_selection_ui():
	var type_to_button = {
		"spear": spear_button,
		"arrow": arrow_button,
		"shells": shells_button
	}
	for key in type_to_button:
		var btn = type_to_button[key]
		if is_instance_valid(btn):
			if key == selected_tower_type:
				btn.add_theme_stylebox_override("normal", highlight_style)
			else:
				btn.remove_theme_stylebox_override("normal")


# --- Wave spawning (unchanged) ---

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

	# Connect the enemy_defeated signal so Main earns gold
	new_enemy.enemy_defeated.connect(gold_earned)

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
	var _total_enemies = _get_enemies_per_wave(wave_number)
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
	# Get stats for the currently selected tower type
	var stats = TOWER_STATS[selected_tower_type]
	var tower_cost = stats["cost"]

	# Check if player can afford this tower
	if not can_afford(tower_cost):
		print("Not enough gold!")
		return

	# Spend gold and place the tower
	spend_gold(tower_cost)

	# Load and instantiate the Tower scene
	var tower_scene = preload("res://scenes/Tower.tscn")
	var new_tower = tower_scene.instantiate()

	# Set the tower type so Tower.gd configures its stats/texture
	new_tower.tower_type = selected_tower_type

	# Set the position where the tap occurred
	new_tower.position = tap_position

	# Add it as a child to this node (Main)
	add_child(new_tower)
