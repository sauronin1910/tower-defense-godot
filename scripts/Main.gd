extends Node2D
# ── Wave Configuration: 7 defined waves, then endless uses last entry ──
const WAVE_CONFIG := [
	{"slime": 8,  "slime_big": 0, "goblin_small": 0, "goblin_fast": 0, "hobgoblin": 0},   # Wave 1
	{"slime": 12, "slime_big": 0, "goblin_small": 0, "goblin_fast": 0, "hobgoblin": 0},   # Wave 2
	{"slime": 8,  "slime_big": 2, "goblin_small": 0, "goblin_fast": 0, "hobgoblin": 0},   # Wave 3
	{"slime": 10, "slime_big": 0, "goblin_small": 4, "goblin_fast": 0, "hobgoblin": 0},   # Wave 4
	{"slime": 6,  "slime_big": 3, "goblin_small": 6, "goblin_fast": 0, "hobgoblin": 0},   # Wave 5
	{"slime": 0,  "slime_big": 4, "goblin_small": 8, "goblin_fast": 2, "hobgoblin": 0},   # Wave 6
	{"slime": 5,  "slime_big": 3, "goblin_small": 5, "goblin_fast": 5, "hobgoblin": 0},   # Wave 7
	{"slime": 0,  "slime_big": 5, "goblin_small": 6, "goblin_fast": 6, "hobgoblin": 1},   # Wave 8
	{"slime": 0,  "slime_big": 0, "goblin_small": 8, "goblin_fast": 8, "hobgoblin": 2},   # Wave 9
	{"slime": 0,  "slime_big": 6, "goblin_small": 5, "goblin_fast": 8, "hobgoblin": 3},   # Wave 10
	{"slime": 0,  "slime_big": 4, "goblin_small": 6, "goblin_fast": 10, "hobgoblin": 5},  # Wave 11
	{"slime": 0,  "slime_big": 8, "goblin_small": 4, "goblin_fast": 8, "hobgoblin": 8},   # Wave 12
	{"slime": 0,  "slime_big": 0, "goblin_small": 0, "goblin_fast": 0, "hobgoblin": 15},  # Wave 13 (BOSS)
]
const MAX_WAVE := 13
# -- Tower Costs --  
const TOWER_COSTS := {
	"spear": 50,
	"arrow": 75,
	"shells": 120,
}

@onready var spawn_timer: Timer = $SpawnTimer
@onready var next_wave_timer: Timer = $NextWaveTimer
@onready var tilemap: TileMapLayer = $TileMapLayer

# Health system
var base_health: int = 20

# Gold system
var gold: int = 0

# Wave management
var current_wave_number: int = 0
var wave_in_progress: bool = false
var enemies_spawned: int = 0
var total_enemies_to_spawn: int = 0
var active_enemy_count: int = 0

# Selected tower type
var selected_tower_type: String = "spear"

# Enemy scene reference for spawning
var enemy_scene = preload("res://scenes/Enemy.tscn")

# UI labels — using existing node paths
@onready var health_label: Label = $CanvasLayer/Control/HealthLabel
@onready var wave_label: Label = $CanvasLayer/Control/WaveLabel
@onready var gold_label: Label = $CanvasLayer/Control/GoldLabel

@onready var game_over_screen: Control = $CanvasLayer/GameOverScreen
@onready var restart_button: Button = $CanvasLayer/GameOverScreen/RestartButton
@onready var pause_menu: Control = %PauseMenu
@onready var resume_button: Button = %ResumeButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var upgrade_panel = %TowerUpgradePanel
@onready var start_wave_button: Button = %StartWaveButton
@onready var speed_button: Button = %SpeedButton
@onready var build_button: Button = %BuildButton
@onready var tower_buttons_dock: Control = $CanvasLayer/Control/TowerButtonsDock
@onready var level_complete: Control = %LevelComplete
@onready var game_camera: Camera2D = %Camera2D

# Speed control
var speed_index: int = 0
const SPEED_LEVELS: Array = [1.0, 1.5, 2.0]

# Zoom control
const ZOOM_MIN: float = 0.64
const ZOOM_MAX: float = 2.0
const ZOOM_STEP: float = 0.1
const TOWER_FOOTPRINT_RADIUS: float = 32.0
const ROAD_COLLISION_MASK: int = 1 << 4
var target_zoom: float = 1.0

# Camera pan
var is_panning: bool = false
var pan_start_mouse: Vector2 = Vector2.ZERO
var pan_start_camera: Vector2 = Vector2.ZERO

# Drag-and-drop tower placement
var tower_ghost: Node2D = null
var is_dragging_tower: bool = false
var dock_was_open: bool = false
var dragging_tower_type: String = ""

var selected_tower = null



func _ready():
	# NOTE: build_background() and build_curve() removed.
	# New map is drawn via TileMapLayer in the scene.
	# The enemy path will be drawn manually as a Path2D in the editor.

	spawn_timer.wait_time = 0.8
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	next_wave_timer.wait_time = 15.0
	next_wave_timer.one_shot = true
	next_wave_timer.timeout.connect(_on_next_wave_timer_timeout)

	# Initialize state
	current_wave_number = 0
	enemies_spawned = 0
	gold = 100
	base_health = 20
	_update_labels()

	# Show Start Wave button so player can start first wave manually
	if is_instance_valid(start_wave_button):
		start_wave_button.visible = true

	# Game Over setup
	if is_instance_valid(restart_button):
		restart_button.pressed.connect(_on_restart_pressed)
	if is_instance_valid(game_over_screen):
		game_over_screen.visible = false

	# Pause menu setup
	if is_instance_valid(resume_button):
		resume_button.pressed.connect(_on_resume_pressed)
	if is_instance_valid(main_menu_button):
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if is_instance_valid(pause_menu):
		pause_menu.visible = false

	# Tower upgrade panel setup
	if is_instance_valid(upgrade_panel):
		upgrade_panel.upgrade_requested.connect(_on_upgrade_requested)
		upgrade_panel.sell_requested.connect(_on_sell_requested)
		upgrade_panel.close_requested.connect(_on_close_upgrade_panel)

	# Start Wave button
	if is_instance_valid(start_wave_button):
		start_wave_button.pressed.connect(_on_start_wave_pressed)

	# Speed button
	if is_instance_valid(speed_button):
		speed_button.pressed.connect(_on_speed_button_pressed)
		speed_button.text = "1x"

	# Build button toggles tower panel
	if is_instance_valid(build_button):
		build_button.pressed.connect(_on_build_button_pressed)
	if is_instance_valid(tower_buttons_dock):
		tower_buttons_dock.visible = false

	# Tower selection buttons — drag-and-drop
	$CanvasLayer/Control/TowerButtonsDock/SpearButton.button_down.connect(_start_drag.bind("spear"))
	$CanvasLayer/Control/TowerButtonsDock/ArrowButton.button_down.connect(_start_drag.bind("arrow"))
	$CanvasLayer/Control/TowerButtonsDock/ShellsButton.button_down.connect(_start_drag.bind("shells"))

	# Level Complete setup
	if is_instance_valid(level_complete):
		level_complete.retry_requested.connect(_on_level_complete_retry)
		level_complete.main_menu_requested.connect(_on_level_complete_main_menu)
		level_complete.next_level_requested.connect(_on_level_complete_next)
		level_complete.visible = false


func _on_spawn_timer_timeout():
	if not wave_in_progress:
		return
	if enemies_spawned >= total_enemies_to_spawn:
		return
	var config: Dictionary = _get_wave_config(current_wave_number)
	var cumulative: int = config.slime
	if enemies_spawned < cumulative:
		_spawn_enemy("slime")
		return
	cumulative += config.slime_big
	if enemies_spawned < cumulative:
		_spawn_enemy("slime_big")
		return
	cumulative += config.goblin_small
	if enemies_spawned < cumulative:
		_spawn_enemy("goblin_small")
		return
	cumulative += config.goblin_fast
	if enemies_spawned < cumulative:
		_spawn_enemy("goblin_fast")
		return
	cumulative += config.hobgoblin
	if enemies_spawned < cumulative:
		_spawn_enemy("hobgoblin")


func _spawn_enemy(type: String) -> void:
	var enemy: PathFollow2D = enemy_scene.instantiate() as PathFollow2D
	enemy.enemy_type = type

	var path: Path2D = $EnemyPath as Path2D
	path.add_child(enemy)

	enemy.progress_ratio = 0.0
	enemy.add_to_group("enemies")

	enemies_spawned += 1
	active_enemy_count += 1

	enemy.enemy_defeated.connect(_on_enemy_defeated)
	enemy.enemy_reached_end.connect(_on_enemy_reached_end)
	enemy.split_requested.connect(_on_slime_split)


func _on_enemy_defeated(gold_reward: int) -> void:
	gold += gold_reward
	_update_labels()
	active_enemy_count -= 1
	if active_enemy_count <= 0 and enemies_spawned >= total_enemies_to_spawn and total_enemies_to_spawn > 0:
		_advance_to_next_wave()


func _on_enemy_reached_end(damage: int) -> void:
	base_health -= damage
	if base_health < 0:
		base_health = 0
	_update_labels()
	_check_game_over()

	active_enemy_count -= 1
	if active_enemy_count <= 0 and enemies_spawned >= total_enemies_to_spawn and total_enemies_to_spawn > 0:
		_advance_to_next_wave()


func start_wave(wave_num: int) -> void:
	current_wave_number = wave_num
	wave_in_progress = true
	enemies_spawned = 0
	var config: Dictionary = _get_wave_config(wave_num)
	total_enemies_to_spawn = config.slime + config.slime_big + config.goblin_small + config.goblin_fast + config.hobgoblin
	active_enemy_count = 0

	spawn_timer.start()

	_update_labels()

	# Hide Start Wave button while a wave is active
	if is_instance_valid(start_wave_button):
		start_wave_button.visible = false


func _advance_to_next_wave() -> void:
	spawn_timer.stop()
	wave_in_progress = false

	# Check if we just completed the final wave
	if current_wave_number >= MAX_WAVE:
		_trigger_level_complete()
		return

	# If more waves possible, start delay timer and show button
	next_wave_timer.start()
	if is_instance_valid(start_wave_button):
		start_wave_button.visible = true

	_update_labels()


func _on_next_wave_timer_timeout():
	if not wave_in_progress:
		start_wave(current_wave_number + 1)


func _on_start_wave_pressed() -> void:
	if wave_in_progress:
		return
	next_wave_timer.stop()
	start_wave(current_wave_number + 1)


func _select_tower_type(type: String) -> void:
	selected_tower_type = type
	print("Selected tower type: ", type)
	if is_instance_valid(tower_buttons_dock):
		tower_buttons_dock.visible = false


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	# Update ghost during drag
	if is_dragging_tower and event is InputEventMouseMotion:
		if is_instance_valid(tower_ghost):
			tower_ghost.position = get_local_mouse_position()
			_update_ghost_validity()
		return

	# Release drag
	if is_dragging_tower and event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_finish_drag()
			get_viewport().set_input_as_handled()
			return

	# Mouse wheel zoom
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, ZOOM_STEP)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, -ZOOM_STEP)
			get_viewport().set_input_as_handled()
			return

	# Keyboard zoom (Ctrl + plus/minus)
	if event is InputEventKey and event.pressed and event.ctrl_pressed:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS:
			_zoom_at(get_viewport().get_mouse_position(), ZOOM_STEP)
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_MINUS:
			_zoom_at(get_viewport().get_mouse_position(), -ZOOM_STEP)
			get_viewport().set_input_as_handled()
			return

	# Camera pan start (middle mouse button pressed)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			is_panning = true
			pan_start_mouse = event.position
			if is_instance_valid(game_camera):
				pan_start_camera = game_camera.position
			get_viewport().set_input_as_handled()
			return
		else:
			is_panning = false
			get_viewport().set_input_as_handled()
			return

	# Camera pan drag (middle button held)
	if is_panning and event is InputEventMouseMotion:
		if is_instance_valid(game_camera):
			var mouse_delta: Vector2 = event.position - pan_start_mouse
			var zoom_factor: float = game_camera.zoom.x
			var new_pos: Vector2 = pan_start_camera - mouse_delta / zoom_factor
			game_camera.position = _clamp_camera_position(new_pos)
		return

	# Left click on map closes upgrade panel if open
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_instance_valid(upgrade_panel) and upgrade_panel.visible:
			if not _is_ui_hit(event.position):
				upgrade_panel.visible = false
				if is_instance_valid(selected_tower):
					selected_tower.hide_range()
				selected_tower = null


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
	if is_instance_valid(upgrade_panel) and upgrade_panel.visible and upgrade_panel.get_global_rect().has_point(tap_pos):
		return true
	if is_instance_valid(speed_button) and speed_button.get_global_rect().has_point(tap_pos):
		return true
	if is_instance_valid(build_button) and build_button.get_global_rect().has_point(tap_pos):
		return true
	return false


func _is_on_enemy_path(tap_pos: Vector2, _min_distance: float = 55.0) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = TOWER_FOOTPRINT_RADIUS
	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, tap_pos)
	params.collision_mask = ROAD_COLLISION_MASK
	params.collide_with_bodies = true
	params.collide_with_areas = false
	return space.intersect_shape(params, 1).size() > 0


func _is_too_close_to_tower(tap_pos: Vector2, type: String = "spear") -> bool:
	var new_radius: float = TowerVisuals.footprint_radius(type)
	var towers := get_tree().get_nodes_in_group("towers")
	for tower in towers:
		if not is_instance_valid(tower):
			continue
		var delta: Vector2 = tap_pos - tower.global_position
		delta.y /= TowerVisuals.FOOTPRINT_VERTICAL_RATIO
		if delta.length() < new_radius + tower.footprint_radius:
			return true
	return false


func _update_labels() -> void:
	if is_instance_valid(health_label):
		health_label.text = "Base HP: %d/20" % base_health
	if is_instance_valid(gold_label):
		gold_label.text = "Gold: %d" % gold
	if is_instance_valid(wave_label):
		wave_label.text = "Wave: %d" % current_wave_number


# -- Wave Config Helper --
func _get_wave_config(wave: int) -> Dictionary:
	var index: int = min(wave - 1, MAX_WAVE - 1)
	return WAVE_CONFIG[index]


# ════════════════════════════════════════════
#  GAME OVER
# ════════════════════════════════════════════

func _check_game_over() -> void:
	if base_health <= 0:
		_trigger_game_over()


func _trigger_game_over() -> void:
	print("GAME OVER")
	spawn_timer.stop()
	next_wave_timer.stop()
	get_tree().paused = true
	if is_instance_valid(game_over_screen):
		game_over_screen.visible = true


func _on_restart_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# ════════════════════════════════════════════
#  PAUSE MENU
# ════════════════════════════════════════════

func _toggle_pause() -> void:
	var new_state: bool = not get_tree().paused
	get_tree().paused = new_state
	if is_instance_valid(pause_menu):
		pause_menu.visible = new_state


func _on_resume_pressed() -> void:
	get_tree().paused = false
	if is_instance_valid(pause_menu):
		pause_menu.visible = false


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


# ════════════════════════════════════════════
#  TOWER UPGRADE / SELL
# ════════════════════════════════════════════

func _on_tower_clicked(tower) -> void:
	if is_instance_valid(selected_tower) and selected_tower != tower:
		selected_tower.hide_range()
	selected_tower = tower
	tower.show_range()
	if is_instance_valid(upgrade_panel):
		upgrade_panel.show_for_tower(tower)


func _on_upgrade_requested() -> void:
	if not is_instance_valid(selected_tower):
		return
	var cost: int = selected_tower.get_upgrade_cost()
	if gold < cost:
		print("Not enough gold to upgrade! Need ", cost, ", have ", gold)
		return
	if selected_tower.upgrade():
		gold -= cost
		_update_labels()
		upgrade_panel.show_for_tower(selected_tower)


func _on_sell_requested() -> void:
	if not is_instance_valid(selected_tower):
		return
	gold += selected_tower.get_sell_value()
	_update_labels()
	selected_tower.queue_free()
	selected_tower = null
	if is_instance_valid(upgrade_panel):
		upgrade_panel.visible = false


func _on_close_upgrade_panel() -> void:
	if is_instance_valid(selected_tower):
		selected_tower.hide_range()
	selected_tower = null
	if is_instance_valid(upgrade_panel):
		upgrade_panel.visible = false


# ════════════════════════════════════════════
#  SPEED CONTROL
# ════════════════════════════════════════════

func _on_speed_button_pressed() -> void:
	speed_index = (speed_index + 1) % SPEED_LEVELS.size()
	var new_speed: float = SPEED_LEVELS[speed_index]
	Engine.time_scale = new_speed
	if is_instance_valid(speed_button):
		if new_speed == 1.0:
			speed_button.text = "1x"
		elif new_speed == 1.5:
			speed_button.text = "1.5x"
		else:
			speed_button.text = "2x"


# ════════════════════════════════════════════
#  ZOOM & PAN
# ════════════════════════════════════════════

func _zoom_at(_screen_pos: Vector2, delta_zoom: float) -> void:
	if not is_instance_valid(game_camera):
		return
	target_zoom = clamp(target_zoom + delta_zoom, ZOOM_MIN, ZOOM_MAX)


func _process(delta: float) -> void:
	# Smooth zoom lerp
	if is_instance_valid(game_camera):
		var current: float = game_camera.zoom.x
		var new_zoom: float = lerp(current, target_zoom, min(delta * 8.0, 1.0))
		game_camera.zoom = Vector2(new_zoom, new_zoom)
		game_camera.position = _clamp_camera_position(game_camera.position)


func _clamp_camera_position(pos: Vector2) -> Vector2:
	var map_size: Vector2 = Vector2(2000, 1500)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var zoom_factor: float = 1.0
	if is_instance_valid(game_camera):
		zoom_factor = game_camera.zoom.x
	var half_view: Vector2 = viewport_size / (2.0 * zoom_factor)
	var min_x: float = half_view.x
	var max_x: float = map_size.x - half_view.x
	var min_y: float = half_view.y
	var max_y: float = map_size.y - half_view.y
	if min_x > max_x:
		var center: float = map_size.x * 0.5
		return Vector2(center, clamp(pos.y, min_y, max_y) if min_y <= max_y else map_size.y * 0.5)
	if min_y > max_y:
		var center_y: float = map_size.y * 0.5
		return Vector2(clamp(pos.x, min_x, max_x), center_y)
	return Vector2(clamp(pos.x, min_x, max_x), clamp(pos.y, min_y, max_y))


# ════════════════════════════════════════════
#  BUILD TOGGLE
# ════════════════════════════════════════════

func _on_build_button_pressed() -> void:
	if is_instance_valid(tower_buttons_dock):
		tower_buttons_dock.visible = not tower_buttons_dock.visible


# ════════════════════════════════════════════
#  LEVEL COMPLETE
# ════════════════════════════════════════════

func _trigger_level_complete() -> void:
	print("LEVEL COMPLETE!")
	spawn_timer.stop()
	next_wave_timer.stop()
	get_tree().paused = true
	if is_instance_valid(level_complete):
		level_complete.visible = true
	if is_instance_valid(start_wave_button):
		start_wave_button.visible = false


func _on_level_complete_retry() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _on_level_complete_main_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_level_complete_next() -> void:
	# Placeholder — no next level exists yet
	pass


# ════════════════════════════════════════════
#  TOWER DRAG-AND-DROP PLACEMENT
# ════════════════════════════════════════════

func _set_all_footprints_visible(value: bool) -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower):
			tower.set_footprint_visible(value)


func _start_drag(type: String) -> void:
	var cost: int = TOWER_COSTS[type]
	if gold < cost:
		print("Not enough gold to build ", type)
		return
	dragging_tower_type = type
	is_dragging_tower = true
	_set_all_footprints_visible(true)
	if is_instance_valid(tower_buttons_dock):
		dock_was_open = tower_buttons_dock.visible
		tower_buttons_dock.visible = false
	if tower_ghost != null:
		tower_ghost.queue_free()
	var ghost_scene: GDScript = load("res://scripts/TowerGhost.gd")
	tower_ghost = Node2D.new()
	tower_ghost.set_script(ghost_scene)
	add_child(tower_ghost)
	tower_ghost.set_tower_type(type)
	tower_ghost.position = get_local_mouse_position()
	_update_ghost_validity()


func _update_ghost_validity() -> void:
	if not is_instance_valid(tower_ghost):
		return
	var pos: Vector2 = tower_ghost.position
	var valid: bool = _can_place_tower_at(pos, dragging_tower_type)
	tower_ghost.set_valid(valid)


func _can_place_tower_at(pos: Vector2, type: String) -> bool:
	var cost: int = TOWER_COSTS[type]
	if gold < cost:
		return false
	if _is_on_enemy_path(pos):
		return false
	if _is_too_close_to_tower(pos, type):
		return false
	return true


func _finish_drag() -> void:
	if not is_dragging_tower:
		return
	is_dragging_tower = false
	_set_all_footprints_visible(false)
	var final_pos: Vector2 = Vector2.ZERO
	if is_instance_valid(tower_ghost):
		final_pos = tower_ghost.position
		tower_ghost.queue_free()
		tower_ghost = null
	if _can_place_tower_at(final_pos, dragging_tower_type):
		_place_tower_at(final_pos, dragging_tower_type)
	if dock_was_open and is_instance_valid(tower_buttons_dock):
		tower_buttons_dock.visible = true


func _place_tower_at(pos: Vector2, type: String) -> void:
	var cost: int = TOWER_COSTS[type]
	gold -= cost
	_update_labels()
	var tower_scene := preload("res://scenes/Tower.tscn")
	var new_tower := tower_scene.instantiate() as Area2D
	new_tower.tower_type = type
	new_tower.position = pos
	new_tower.tower_clicked.connect(_on_tower_clicked)
	add_child(new_tower)


# ════════════════════════════════════════════
#  SLIME SPLIT
# ════════════════════════════════════════════

func _on_slime_split(_spawn_position: Vector2, spawn_progress_ratio: float) -> void:
	for i in range(3):
		var enemy: PathFollow2D = enemy_scene.instantiate() as PathFollow2D
		enemy.enemy_type = "slime_mini"
		var path: Path2D = $EnemyPath as Path2D
		path.add_child(enemy)
		enemy.progress_ratio = clamp(spawn_progress_ratio - 0.005 * i, 0.0, 0.999)
		enemy.add_to_group("enemies")
		enemy.enemy_defeated.connect(_on_enemy_defeated)
		enemy.enemy_reached_end.connect(_on_enemy_reached_end)
		enemy.split_requested.connect(_on_slime_split)
		active_enemy_count += 1
