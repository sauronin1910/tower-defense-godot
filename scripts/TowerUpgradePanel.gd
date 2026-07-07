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


func _ready() -> void:
	upgrade_button.pressed.connect(func(): upgrade_requested.emit())
	sell_button.pressed.connect(func(): sell_requested.emit())
	close_button.pressed.connect(func(): close_requested.emit())
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

	# Position the panel above the tower
	global_position = tower.global_position + Vector2(-100, -260)
	visible = true
