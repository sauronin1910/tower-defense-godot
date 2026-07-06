extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

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
