extends Control

func _ready():
	$CenterContainer/VBoxContainer/PlayButton.pressed.connect(_on_play_pressed)
	$CenterContainer/VBoxContainer/ExitButton.pressed.connect(_on_exit_pressed)


func _on_play_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_exit_pressed():
	get_tree().quit()
