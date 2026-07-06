extends PathFollow2D

# Exported variable for enemy speed (pixels per second)
@export var speed: float = 100.0

func _ready():
	print("Enemy created")
	# Start at the beginning of the path
	progress_ratio = 0.0

func _process(delta):
	# Move forward along the path based on speed and delta time
	progress_ratio += delta * speed / get_parent().curve.get_baked_length()
	
	# Check if enemy has reached the end of the path
	if progress_ratio >= 1.0:
		print("Enemy reached the end")
		queue_free() # Remove this enemy from the scene
