extends Node2D

# ── Wave Configuration: 7 defined waves, then endless uses last entry ──
const WAVE_CONFIG := [
	{"peasants": 5, "knights": 0},     # Wave 1
	{"peasants": 10, "knights": 1},    # Wave 2
	{"peasants": 15, "knights": 2},    # Wave 3
	{"peasants": 20, "knights": 3},    # Wave 4
	{"peasants": 25, "knights": 4},    # Wave 5
	{"peasants": 30, "knights": 5},    # Wave 6
	{"peasants": 40, "knights": 8},    # Wave 7 (max — reused for endless)
]

const MAX_WAVE := 7

# � Tower Costs �
const TOWER_COSTS := {
	"spear": 50,
	"arrow": 75,
	"shells": 120,
}


# ── State ──
var current_wave_number: int = 1
var enemies_spawned: int = 0
var total_enemies_to_spawn: int = 0
var active_enemy_count: int = 0
var gold: int = 100
var base_health: int = 20

@onready var spawn_timer: Timer = $SpawnTimer
@onready var next_wave_timer: Timer = $NextWaveTimer
@onready var enemy_scene := preload("res://scenes/Enemy.tscn")

@onready var start_wave_button: Button = %StartWaveButton
@onready var health_label: Label = $CanvasLayer/Control/HealthLabel
@onready var wave_label: Label = $CanvasLayer/Control/WaveLabel
@onready var gold_label: Label = $CanvasLayer/Control/GoldLabel



func build_curve() -> void:
	var enemy_path: Path2D = $EnemyPath
	var curve := Curve2D.new()
	curve.add_point(Vector2(360, 50))
	curve.add_point(Vector2(100, 200))
	curve.add_point(Vector2(600, 350))
	curve.add_point(Vector2(200, 500))
	curve.add_point(Vector2(500, 650))
	curve.add_point(Vector2(360, 800))
	enemy_path.curve = curve


func _ready():
	build_curve()

	# ── Timers ──
	spawn_timer.wait_time = 0.8
	next_wave_timer.wait_time = 15.0

	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	next_wave_timer.timeout.connect(_on_next_wave_timer_timeout)

	# ── Tower buttons ──
	$CanvasLayer/Control/TowerButtonsDock/SpearButton.pressed.connect(
		func(): _select_tower_type("spear"))
	$CanvasLayer/Control/TowerButtonsDock/ArrowButton.pressed.connect(
		func(): _select_tower_type("arrow"))
	$CanvasLayer/Control/TowerButtonsDock/ShellsButton.pressed.connect(
		func(): _select_tower_type("shells"))

	# ── Start Wave button (Task 3) ──
	if is_instance_valid(start_wave_button):
		start_wave_button.pressed.connect(_on_start_wave_pressed)
		start_wave_button.visible = false

	# ── Initial state ──
	current_wave_number = 1
	enemies_spawned = 0
	gold = 100
	base_health = 20
	_update_labels()

	next_wave_timer.start()


# ════════════════════════════════════════════
#  TASK 1 — SPAWN LOGIC (fixed)
# ════════════════════════════════════════════

func _on_spawn_timer_timeout():
	var config: Dictionary = _get_wave_config(current_wave_number)

	# Spawn all peasants first, then all knights
	if enemies_spawned < config.peasants:
		_spawn_enemy("peasant")
	elif enemies_spawned < total_enemies_to_spawn:
		_spawn_enemy("knight")


func _spawn_enemy(type: String) -> void:
	var enemy: PathFollow2D = enemy_scene.instantiate() as PathFollow2D
	enemy.enemy_type = type

	var path: Path2D = $EnemyPath as Path2D
	path.add_child(enemy)

	enemy.progress_ratio = 0.0
	enemy.add_to_group("enemies")

	var config: Dictionary = _get_wave_config(current_wave_number)
	total_enemies_to_spawn = config.peasants + config.knights

	enemies_spawned += 1
	active_enemy_count += 1

	enemy.enemy_defeated.connect(_on_enemy_defeated)
	enemy.enemy_reached_end.connect(_on_enemy_reached_end)


func _on_enemy_defeated(gold_reward: int) -> void:
	gold += gold_reward
	_update_labels()
	active_enemy_count -= 1
	if active_enemy_count <= 0:
		_advance_to_next_wave()


func _on_enemy_reached_end(damage: int) -> void:
	base_health -= damage
	if base_health < 0:
		base_health = 0
	_update_labels()

	active_enemy_count -= 1
	if active_enemy_count <= 0:
		_advance_to_next_wave()


# ════════════════════════════════════════════
#  WAVE MANAGEMENT
# ════════════════════════════════════════════

func start_wave(wave_num: int) -> void:
	current_wave_number = wave_num
	enemies_spawned = 0
	total_enemies_to_spawn = 0
	active_enemy_count = 0

	spawn_timer.start()

	_update_labels()

	# Hide Start Wave button while a wave is active (Task 3)
	if is_instance_valid(start_wave_button):
		start_wave_button.visible = false


func _advance_to_next_wave() -> void:
	spawn_timer.stop()
	next_wave_timer.start()

	# Show Start Wave button during inter-wave delay (Task 3)
	if is_instance_valid(start_wave_button):
		start_wave_button.visible = true

	_update_labels()


func _on_next_wave_timer_timeout():
	start_wave(current_wave_number + 1)


# ════════════════════════════════════════════
#  TASK 3 — MANUAL START WAVE BUTTON
# ════════════════════════════════════════════

func _on_start_wave_pressed() -> void:
	next_wave_timer.stop()
	start_wave(current_wave_number + 1)


# ════════════════════════════════════════════
#  TOWER PLACEMENT (existing logic, kept)
# ════════════════════════════════════════════

var selected_tower_type: String = "spear"

func _select_tower_type(type: String):
	selected_tower_type = type


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			place_tower(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			place_tower(event.position)


func place_tower(tap_position: Vector2) -> void:
	if _is_ui_hit(tap_position):
		return
	if _is_on_enemy_path(tap_position):
		print("Cannot place tower on enemy path!")
		return
	if _is_too_close_to_tower(tap_position):
		print("Too close to another tower!")
		return
	var cost: int = TOWER_COSTS[selected_tower_type]
	if gold < cost:
		print("Not enough gold! Need ", cost, ", have ", gold)
		return
	gold -= cost
	_update_labels()

	var tower_scene := preload("res://scenes/Tower.tscn")
	var new_tower := tower_scene.instantiate() as Area2D
	new_tower.tower_type = selected_tower_type
	new_tower.position = tap_position
	add_child(new_tower)


func _is_ui_hit(tap_pos: Vector2) -> bool:
	var spear_btn: Button = $CanvasLayer/Control/TowerButtonsDock/SpearButton
	var arrow_btn: Button = $CanvasLayer/Control/TowerButtonsDock/ArrowButton
	var shells_btn: Button = $CanvasLayer/Control/TowerButtonsDock/ShellsButton
	if is_instance_valid(spear_btn) and spear_btn.get_global_rect().has_point(tap_pos):
		return true
	if is_instance_valid(arrow_btn) and arrow_btn.get_global_rect().has_point(tap_pos):
		return true
	if is_instance_valid(shells_btn) and shells_btn.get_global_rect().has_point(tap_pos):
		return true
	if is_instance_valid(start_wave_button) and start_wave_button.visible and start_wave_button.get_global_rect().has_point(tap_pos):
		return true
	return false

func _is_on_enemy_path(tap_pos: Vector2, min_distance: float = 40.0) -> bool:
	var enemy_path: Path2D = $EnemyPath as Path2D
	if not is_instance_valid(enemy_path) or enemy_path.curve == null:
		return false
	var closest_point: Vector2 = enemy_path.curve.get_closest_point(tap_pos)
	return tap_pos.distance_to(closest_point) < min_distance

func _is_too_close_to_tower(tap_pos: Vector2, min_distance: float = 50.0) -> bool:
	var towers := get_tree().get_nodes_in_group("towers")
	for tower in towers:
		if not is_instance_valid(tower):
			continue
		if tap_pos.distance_to(tower.global_position) < min_distance:
			return true
	return false

func _update_labels():
	health_label.text = "Base HP: %d/%d" % [base_health, 20]
	wave_label.text   = "Wave: %d" % current_wave_number
	gold_label.text   = "Gold: %d" % gold


# ── Game Over ──
# -- Wave Config Helper --
func _get_wave_config(wave: int) -> Dictionary:
	var index: int = min(wave - 1, MAX_WAVE - 1)
	return WAVE_CONFIG[index]

func _show_game_over():
	$CanvasLayer/GameOverScreen.visible = true
	spawn_timer.stop()
	next_wave_timer.stop()