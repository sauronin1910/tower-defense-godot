extends PathFollow2D

# Signal emitted when enemy reaches end of path — carries damage amount
signal enemy_reached_end(damage_amount)

# Signal emitted when enemy is defeated by combat — carries gold reward
signal enemy_defeated(gold_reward)

signal split_requested(spawn_position, spawn_progress_ratio)

# Exported variable for enemy type selection
@export var enemy_type: String = "peasant"

# Global tuning for the larger map. Base values below stay readable as
# "design speed"; these scale every type at once.
const SPEED_MULTIPLIER: float = 2.0
const ANIM_SPEED_MULTIPLIER: float = 2.0

# Health system
var health: int = 0
var max_health: int = 0
@export var speed: float = 100.0

# Gold reward when defeated in combat
var gold_reward: int = 0

var hp_bar_bg: ColorRect = null
var hp_bar_fill: ColorRect = null
var hp_displayed_ratio: float = 1.0
var sprite_node: Sprite2D = null

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
		max_health = health
		speed = 60
		gold_reward = 5
	elif enemy_type == "slime_big":
		health = 60
		max_health = health
		speed = 45
		gold_reward = 15
	elif enemy_type == "goblin_small":
		health = 40
		max_health = health
		speed = 90
		gold_reward = 10
	elif enemy_type == "goblin_fast":
		health = 45
		max_health = health
		speed = 120
		gold_reward = 15
	elif enemy_type == "hobgoblin":
		health = 150
		max_health = health
		speed = 60
		gold_reward = 30
	elif enemy_type == "slime_mini":
		health = 15
		max_health = health
		speed = 35
		gold_reward = 1
	else:
		# fallback for peasant/knight (keep for compatibility, but shouldnt be used)
		health = 30
		max_health = health
		speed = 100
		gold_reward = 10
	
	# Scale every type at once for the bigger map
	speed *= SPEED_MULTIPLIER
	
	print("Enemy type: ", enemy_type, " - Health: ", health, " - Speed: ", speed)
	
	# Apply texture to sprite
	sprite_node = get_node("Sprite2D")
	if enemy_type == "slime":
		sprite_node.texture = preload("res://assets/sprites/Enemy/slime.png")
		sprite_node.scale = Vector2(0.1125, 0.1125)
	elif enemy_type == "slime_big":
		sprite_node.texture = preload("res://assets/sprites/Enemy/slime_big.png")
		sprite_node.scale = Vector2(0.1575, 0.1575)
	elif enemy_type == "goblin_small":
		sprite_node.texture = preload("res://assets/sprites/Enemy/goblin_small.png")
		sprite_node.scale = Vector2(0.1125, 0.1125)
	elif enemy_type == "goblin_fast":
		sprite_node.texture = preload("res://assets/sprites/Enemy/goblin_fast.png")
		sprite_node.scale = Vector2(0.1125, 0.1125)
	elif enemy_type == "hobgoblin":
		sprite_node.texture = preload("res://assets/sprites/Enemy/hobgoblin.png")
		sprite_node.scale = Vector2(0.135, 0.135)
	elif enemy_type == "slime_mini":
		sprite_node.texture = preload("res://assets/sprites/Enemy/slime.png")
		sprite_node.scale = Vector2(0.0675, 0.0675)
	else:
		sprite_node.texture = preload("res://assets/sprites/Peasant.png")
		sprite_node.scale = Vector2(0.1125, 0.1125)
	
	# Start at the beginning of the path
	progress_ratio = 0.0
	base_scale = get_node("Sprite2D").scale

	# Calculate HP bar offset based on sprite size
	sprite_node = get_node("Sprite2D")
	var sprite_height: float = 0.0
	if sprite_node.texture != null:
		sprite_height = sprite_node.texture.get_height() * abs(sprite_node.scale.y)
	var bar_y_offset: float = -sprite_height * 0.5 - 8.0
	# Blob shadow at the enemy's real base. Origin is the enemy CENTER, so we
	# measure the opaque pixels to find the true bottom and put the shadow there.
	var opaque := _opaque_bounds(sprite_node)
	var sprite_width: float = opaque.size.x * abs(sprite_node.scale.x)
	# opaque.position.y is texture-space top of the visible pixels; bottom edge:
	var opaque_bottom_local: float = (opaque.position.y + opaque.size.y - sprite_node.texture.get_height() * 0.5) * abs(sprite_node.scale.y)
	var enemy_shadow := TowerShadow.new()
	enemy_shadow.setup(sprite_width * 0.3, 0.5)
	enemy_shadow.color = Color(0.0, 0.0, 0.0, 0.25)
	enemy_shadow.y_offset = opaque_bottom_local
	enemy_shadow.z_index = -1
	enemy_shadow.x_offset = 0.0
	enemy_shadow.width_mult = 1.0
	enemy_shadow.height_mult = 1.0
	add_child(enemy_shadow)
	move_child(enemy_shadow, 0)

	# Create HP bar (background)
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.color = Color(0.15, 0.15, 0.15, 0.9)
	hp_bar_bg.size = Vector2(24, 4)
	hp_bar_bg.position = Vector2(-12, bar_y_offset)
	hp_bar_bg.z_index = 10
	add_child(hp_bar_bg)

	# Create HP bar (fill)
	hp_bar_fill = ColorRect.new()
	hp_bar_fill.color = Color(0.2, 0.9, 0.2, 1.0)
	hp_bar_fill.size = Vector2(24, 4)
	hp_bar_fill.position = Vector2(-12, bar_y_offset)
	hp_bar_fill.z_index = 11
	add_child(hp_bar_fill)


func _process(delta):
	# Driving the clock faster speeds up every sin() below at once,
	# keeping their relative rhythms intact
	anim_time += delta * ANIM_SPEED_MULTIPLIER

	sprite_node = get_node("Sprite2D")

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

	# Smooth HP bar interpolation
	if is_instance_valid(hp_bar_fill) and max_health > 0:
		var target_ratio: float = float(max(health, 0)) / float(max_health)
		hp_displayed_ratio = lerp(hp_displayed_ratio, target_ratio, min(delta * 8.0, 1.0))
		hp_bar_fill.size.x = 24.0 * hp_displayed_ratio
		# Color transition based on target (not displayed) for immediate color feedback
		if target_ratio > 0.5:
			hp_bar_fill.color = Color(0.2, 0.9, 0.2, 1.0)
		elif target_ratio > 0.25:
			hp_bar_fill.color = Color(0.9, 0.8, 0.2, 1.0)
		else:
			hp_bar_fill.color = Color(0.9, 0.2, 0.2, 1.0)


func take_damage(damage: int):
	health -= damage
	_update_hp_bar()
	if health <= 0:
		print(enemy_type, " defeated")
		if enemy_type == "slime_big":
			split_requested.emit(global_position, progress_ratio)
		enemy_defeated.emit(gold_reward)
		queue_free()

func _update_hp_bar() -> void:
	# This is called from take_damage() but we no longer update the size directly here.
	# Actual smooth interpolation happens in _process.
	pass

# Tight bounds of the sprite's visible (opaque) pixels, in TEXTURE pixels.
func _opaque_bounds(spr: Sprite2D) -> Rect2:
	var tex: Texture2D = spr.texture
	if tex == null:
		return Rect2(0, 0, 0, 0)
	var img: Image = tex.get_image()
	if img == null:
		return Rect2(Vector2.ZERO, tex.get_size())
	if img.is_compressed():
		img.decompress()
	var r: Rect2i = img.get_used_rect()
	if r.size.x <= 0 or r.size.y <= 0:
		return Rect2(Vector2.ZERO, tex.get_size())
	return Rect2(r.position, r.size)
