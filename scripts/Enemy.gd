extends PathFollow2D

# Signal emitted when enemy reaches end of path — carries damage amount
signal enemy_reached_end(damage_amount)

# Signal emitted when enemy is defeated by combat — carries gold reward
signal enemy_defeated(gold_reward)

# Exported variable for enemy type selection
@export var enemy_type: String = "peasant"

# Health system
var health: int = 0
@export var speed: float = 100.0

# Gold reward when defeated in combat
var gold_reward: int = 0

var anim_time: float = 0.0
var base_scale: Vector2 = Vector2.ONE


func _ready():
	print("Enemy created with type: ", enemy_type)
	
	# Prevent looping — clamp at end of path so reached-end logic fires once
	loop = false
	rotates = false
	
	# Set stats based on enemy type directly
	if enemy_type == "slime":
		health = 20
		speed = 60
		gold_reward = 5
	elif enemy_type == "slime_big":
		health = 60
		speed = 45
		gold_reward = 15
	elif enemy_type == "goblin_small":
		health = 40
		speed = 90
		gold_reward = 10
	elif enemy_type == "goblin_fast":
		health = 45
		speed = 120
		gold_reward = 15
	elif enemy_type == "hobgoblin":
		health = 150
		speed = 60
		gold_reward = 30
	else:
		# fallback for peasant/knight (keep for compatibility, but shouldnt be used)
		health = 30
		speed = 100
		gold_reward = 10
	
	print("Enemy type: ", enemy_type, " - Health: ", health, " - Speed: ", speed)
	
	# Apply texture to sprite
	var sprite_node = get_node("Sprite2D")
	if enemy_type == "slime":
		sprite_node.texture = preload("res://assets/sprites/Enemy/slime.png")
		sprite_node.scale = Vector2(0.05, 0.05)
	elif enemy_type == "slime_big":
		sprite_node.texture = preload("res://assets/sprites/Enemy/slime_big.png")
		sprite_node.scale = Vector2(0.07, 0.07)
	elif enemy_type == "goblin_small":
		sprite_node.texture = preload("res://assets/sprites/Enemy/goblin_small.png")
		sprite_node.scale = Vector2(0.05, 0.05)
	elif enemy_type == "goblin_fast":
		sprite_node.texture = preload("res://assets/sprites/Enemy/goblin_fast.png")
		sprite_node.scale = Vector2(0.05, 0.05)
	elif enemy_type == "hobgoblin":
		sprite_node.texture = preload("res://assets/sprites/Enemy/hobgoblin.png")
		sprite_node.scale = Vector2(0.06, 0.06)
	else:
		sprite_node.texture = preload("res://assets/sprites/Peasant.png")
		sprite_node.scale = Vector2(0.05, 0.05)
	
	# Start at the beginning of the path
	progress_ratio = 0.0
	base_scale = get_node("Sprite2D").scale


func _process(delta):
	anim_time += delta

	var sprite_node = get_node("Sprite2D")

	if enemy_type == "slime":
		# Scale pulse - 8 Hz, +/-15% amplitude
		var pulse: float = 1.0 + sin(anim_time * 8.0) * 0.15
		sprite_node.scale = Vector2(base_scale.x * pulse, base_scale.y * (2.0 - pulse))

	elif enemy_type == "slime_big":
		# Slower deeper pulse
		var pulse: float = 1.0 + sin(anim_time * 5.0) * 0.2
		sprite_node.scale = Vector2(base_scale.x * pulse, base_scale.y * (2.0 - pulse))

	elif enemy_type == "goblin_small":
		# Bobbing + rocking + subtle secondary bobbing
		sprite_node.offset.y = sin(anim_time * 10.0) * 13.68 + sin(anim_time * 3.3) * 5.46
		sprite_node.rotation = sin(anim_time * 22.5) * 0.109

	elif enemy_type == "goblin_fast":
		# Faster bobbing + rocking + subtle secondary bobbing
		sprite_node.offset.y = sin(anim_time * 14.0) * 20.55 + sin(anim_time * 4.2) * 6.87
		sprite_node.rotation = sin(anim_time * 31.5) * 0.147

	elif enemy_type == "hobgoblin":
		# Slow heavy rocking
		sprite_node.rotation = sin(anim_time * 13.5) * 0.064
		sprite_node.offset.y = sin(anim_time * 3.0) * 9.0

	# Move forward along the path based on speed and delta time
	progress_ratio += delta * speed / get_parent().curve.get_baked_length()
	
	# Clamp progress so it doesn't exceed 1.0 (loop=false prevents wrap, but be explicit)
	if progress_ratio > 1.0:
		progress_ratio = 1.0
	
	# Check if enemy has reached the end of the path
	if progress_ratio >= 1.0:
		var damage: int = 1
		if enemy_type == "slime_big":
			damage = 2
		elif enemy_type == "hobgoblin":
			damage = 3
		print(enemy_type, " reached base! Dealing ", damage, " damage.")
		enemy_reached_end.emit(damage)
		queue_free()	


func take_damage(damage: int):
	health -= damage
	if health <= 0:
		print(enemy_type, " defeated")
		enemy_defeated.emit(gold_reward)
		queue_free()
