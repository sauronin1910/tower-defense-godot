extends Node

func _ready():
	print("Game started")
	# Build the curve programmatically
	build_curve()
	# Spawn one enemy at the beginning of the path
	spawn_enemy()

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

func spawn_enemy():
	var enemy_scene = preload("res://scenes/Enemy.tscn")
	var enemy_instance = enemy_scene.instantiate()
	
	# Add to scene tree as child of EnemyPath (not Main)
	$EnemyPath.add_child(enemy_instance)
	
	# Ensure the enemy has proper path reference by checking parent structure
	print("Spawned enemy as child of: ", $EnemyPath.name)
