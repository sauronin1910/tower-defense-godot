extends Node

# Exported variables for wave configuration
@export var enemies_per_wave: int = 5
@export var spawn_interval: float = 1.0

var current_wave: int = 0
var spawned_enemies: int = 0
var timer: Timer

func _ready():
	print("Game started")
	# Build the curve programmatically
	build_curve()
	
	# Initialize timer for wave spawning
	timer = Timer.new()
	add_child(timer)
	timer.connect("timeout", Callable(self, "_on_spawn_timer_timeout"))
	
	# Start first wave
	start_wave()

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

func start_wave():
	current_wave += 1
	spawned_enemies = 0
	print("Wave ", current_wave, " started")
	
	# Start spawning enemies at intervals
	timer.start(spawn_interval)

func _on_spawn_timer_timeout():
	if spawned_enemies < enemies_per_wave:
		# Determine enemy type for this spawn based on wave logic
		var enemy_type: String = "peasant"
		if spawned_enemies == enemies_per_wave - 1:  # Last enemy in wave is knight
			enemy_type = "knight"
		
		spawn_enemy(enemy_type)
		spawned_enemies += 1
		
		# If we haven't finished spawning all enemies, schedule next spawn
		if spawned_enemies < enemies_per_wave:
			timer.start(spawn_interval)
		else:
			# Wave complete
			print("Wave ", current_wave, " complete")
			# Start the next wave after a delay (optional)
			# timer.start(5.0)  # Wait 5 seconds before next wave

func spawn_enemy(enemy_type: String):
	var enemy_scene = preload("res://scenes/Enemy.tscn")
	var enemy_instance = enemy_scene.instantiate()
	
	# Set the enemy type
	enemy_instance.enemy_type = enemy_type
	
	# Add to scene tree as child of EnemyPath (not Main)
	$EnemyPath.add_child(enemy_instance)
	
	# Ensure the enemy has proper path reference by checking parent structure
	print("Spawned ", enemy_type, " enemy as child of: ", $EnemyPath.name)
