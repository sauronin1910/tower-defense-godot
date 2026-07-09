extends PanelContainer

signal upgrade_requested
signal sell_requested
signal close_requested

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var upgrade_button: Button = $VBoxContainer/UpgradeButton
@onready var sell_button: Button = $VBoxContainer/SellButton
@onready var close_button: Button = $VBoxContainer/CloseButton


var tracked_tower: Node2D = null

func _ready() -> void:
	upgrade_button.pressed.connect(func(): upgrade_requested.emit())
	sell_button.pressed.connect(func(): sell_requested.emit())
	close_button.pressed.connect(func(): close_requested.emit())
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.35, 1.0)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	visible = false


func show_for_tower(tower) -> void:
	title_label.text = tower.tower_type.capitalize() + " Tower"
	level_label.text = "Level %d/%d" % [tower.level, tower.MAX_LEVEL]
	stats_label.text = "Damage: %d\nRange: %.0f\nRate: %.2f" % [tower.tower_damage, tower.attack_range, tower.fire_rate]

	if tower.level >= tower.MAX_LEVEL:
		upgrade_button.text = "MAX LEVEL"
		upgrade_button.disabled = true
	else:
		upgrade_button.text = "Upgrade (%dg)" % tower.get_upgrade_cost()
		upgrade_button.disabled = false

	sell_button.text = "Sell (%dg)" % tower.get_sell_value()

	# Convert tower's world position to screen position (accounts for camera zoom/pan)
	var tower_screen_pos: Vector2 = tower.get_global_transform_with_canvas().origin
	global_position = tower_screen_pos + Vector2(-100, -260)
	visible = true

	tracked_tower = tower


func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(tracked_tower):
		return
	var screen_pos: Vector2 = tracked_tower.get_global_transform_with_canvas().origin
	global_position = screen_pos + Vector2(-100, -260)
