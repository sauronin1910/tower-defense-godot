extends Control

signal retry_requested
signal main_menu_requested
signal next_level_requested

@onready var retry_button: Button = $CenterContainer/VBoxContainer/RetryButton
@onready var main_menu_button: Button = $CenterContainer/VBoxContainer/MainMenuButton
@onready var next_level_button: Button = $CenterContainer/VBoxContainer/NextLevelButton


func _ready() -> void:
	retry_button.pressed.connect(func(): retry_requested.emit())
	main_menu_button.pressed.connect(func(): main_menu_requested.emit())
	next_level_button.pressed.connect(func(): next_level_requested.emit())
	visible = false
