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

# ── Directional walk animation (4 facings x N frames) ──
# Used by types that ship per-direction frame folders instead of one static PNG.
const WALK_FRAME_COUNT: int = 9
const WALK_FRAME_DURATION: float = 0.0576
# On-map height in pixels for frame-animated types. Scale is derived from this
# and the frame's own resolution, so the source size doesn't matter.
const GOBLIN_SMALL_HEIGHT: float = 120.0
# Round the sprite scale to whole numbers when upscaling, so pixel art stays
# crisp instead of picking up uneven stair-stepping.
const SNAP_PIXEL_SCALE: bool = true

# ── Spacing and overtaking ──
# Minimum spacing between enemies along the path, in world pixels.
const MIN_FOLLOW_GAP: float = 30.0
# Sideways lanes so faster units can overtake instead of queueing forever.
const LANE_WIDTH: float = 26.0        # how far aside a passing unit steps
const LANE_MAX: float = 34.0          # never stray further than this from the path centre
const LANE_LERP_SPEED: float = 6.0    # how quickly it slides into / out of a lane
const LANE_SPAWN_SPREAD: float = 12.0 # small random lane at spawn so units don't stack perfectly
const OVERTAKE_LOOKAHEAD: float = 95.0 # spot the unit ahead this early, in world px
const YIELD_LOOKBEHIND: float = 70.0   # notice someone coming up behind this early
# ── Crowd separation (replaces the lane logic) ──
const CROWD_RANGE: float = 70.0   # look this far along the path for neighbours
const CROWD_WIDTH: float = 30.0   # lateral gap they try to keep between each other
const CROWD_PUSH: float = 90.0    # how hard they shove apart, px/sec
const CROWD_RETURN: float = 1.5   # how quickly they drift back to the road centre

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

# Directional walk state
var walk_frames: Dictionary = {}   # "front"/"back"/"left"/"right" -> Array[Texture2D]
var walk_index: int = 0
var walk_timer: float = 0.0
var facing: String = "front"
var uses_directional_walk: bool = false

# Lane state
var lane_offset: float = 0.0
var target_lane: float = 0.0
var spawn_lane: float = 0.0
var _path_dir: Vector2 = Vector2.RIGHT
var overtake_side: float = 1.0   # this unit's preferred side to pass on (+1 right, -1 left)

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
		# 4-direction walk cycle: assets/sprites/Enemy/small_goblin/<dir>_side/
		_load_directional_walk("res://assets/sprites/Enemy/small_goblin", "small_goblin")
		var first: Texture2D = _first_walk_frame()
		if first != null:
			sprite_node.texture = first
			sprite_node.scale = _scale_for_height(first, GOBLIN_SMALL_HEIGHT)
		else:
			push_warning("Enemy: no walk frames loaded for goblin_small")
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
	# Small random lane so units don't spawn perfectly stacked
	spawn_lane = randf_range(-LANE_SPAWN_SPREAD, LANE_SPAWN_SPREAD)
	lane_offset = spawn_lane
	target_lane = spawn_lane
	overtake_side = 1.0 if randf() < 0.5 else -1.0

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
	hp_bar_bg.z_index = 1
	add_child(hp_bar_bg)

	# Create HP bar (fill)
	hp_bar_fill = ColorRect.new()
	hp_bar_fill.color = Color(0.2, 0.9, 0.2, 1.0)
	hp_bar_fill.size = Vector2(24, 4)
	hp_bar_fill.position = Vector2(-12, bar_y_offset)
	hp_bar_fill.z_index = 2
	add_child(hp_bar_fill)

"res://scripts/LevelComplete.gd"

func _process(delta):
	# Driving the clock faster speeds up every sin() below at once,
	# keeping their relative rhythms intact
	anim_time += delta * ANIM_SPEED_MULTIPLIER

	sprite_node = get_node("Sprite2D")

	# Procedural wiggle only for types WITHOUT real frame animation — otherwise
	# the two animations fight each other.
	if enemy_type == "slime":
		# Scale pulse - 8 Hz, +/-15% amplitude
		var pulse: float = 1.0 + sin(anim_time * 8.0) * 0.15
		sprite_node.scale = Vector2(base_scale.x * pulse, base_scale.y * (2.0 - pulse))

	elif enemy_type == "slime_big":
		# Slower deeper pulse
		var pulse: float = 1.0 + sin(anim_time * 5.0) * 0.2
		sprite_node.scale = Vector2(base_scale.x * pulse, base_scale.y * (2.0 - pulse))

	elif enemy_type == "goblin_fast":
		# Faster bobbing + rocking + subtle secondary bobbing
		sprite_node.offset.y = sin(anim_time * 14.0) * 20.55 + sin(anim_time * 4.2) * 6.87
		sprite_node.rotation = sin(anim_time * 31.5) * 0.147

	elif enemy_type == "hobgoblin":
		# Slow heavy rocking
		sprite_node.rotation = sin(anim_time * 13.5) * 0.064
		sprite_node.offset.y = sin(anim_time * 3.0) * 9.0

	# Move along the path. Blocked only by units in the SAME lane — a faster unit
	# steps aside (see _update_lane) and passes instead of piling up behind.
	var curve_len: float = get_parent().curve.get_baked_length()
	if curve_len > 0.0:
		_update_path_dir(curve_len)
		var target: float = progress_ratio + delta * speed / curve_len
		var limit: float = _follow_limit(curve_len)
		progress_ratio = min(target, max(progress_ratio, limit))
		_update_lane(delta)
		# Depth sorting: whoever stands further down the screen draws in front.
		z_index = clampi(int(global_position.y) + 2000, 0, 8000)

	# Frame-animated types: pick a facing from the path, then step frames
	if uses_directional_walk:
		_update_facing()
		_advance_walk(delta)
	
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


# ════════════════════════════════════════════
#  SPACING, LANES AND OVERTAKING
# ════════════════════════════════════════════

# Tangent of the path at our current position — used both for facing and for
# working out which way "sideways" is.
func _update_path_dir(curve_len: float) -> void:
	var curve: Curve2D = get_parent().curve
	if curve == null:
		return
	var here: float = progress_ratio * curve_len
	var ahead: float = min(here + 8.0, curve_len)
	var d: Vector2 = curve.sample_baked(ahead) - curve.sample_baked(here)
	if d.length() > 0.01:
		_path_dir = d.normalized()


# How far this enemy may advance without bumping the one ahead IN ITS LANE.
# Units in another lane are free to pass.
func _follow_limit(curve_len: float) -> float:
	var gap_ratio: float = MIN_FOLLOW_GAP / curve_len
	var limit: float = 1.0
	for other in get_parent().get_children():
		if other == self or not is_instance_valid(other):
			continue
		if not (other is PathFollow2D) or not ("lane_offset" in other):
			continue
		if other.progress_ratio <= progress_ratio:
			continue
		if abs(other.lane_offset - lane_offset) > CROWD_WIDTH * 0.5:
			continue
		var cap: float = other.progress_ratio - gap_ratio
		if cap < limit:
			limit = cap
	return limit


# Nearest unit ahead of us in our own lane, spotted early enough to step aside
# before we actually run into it.
func _blocker_ahead() -> Node:
	var curve_len: float = get_parent().curve.get_baked_length()
	if curve_len <= 0.0:
		return null
	var reach: float = OVERTAKE_LOOKAHEAD / curve_len
	var best: Node = null
	var best_progress: float = 2.0
	for other in get_parent().get_children():
		if other == self or not is_instance_valid(other):
			continue
		if not (other is PathFollow2D) or not ("lane_offset" in other):
			continue
		if other.progress_ratio <= progress_ratio:
			continue
		if other.progress_ratio - progress_ratio > reach:
			continue
		if abs(other.lane_offset - lane_offset) > LANE_WIDTH * 0.7:
			continue
		if other.progress_ratio < best_progress:
			best_progress = other.progress_ratio
			best = other
	return best


# Continuous crowd separation instead of discrete lanes: every neighbour nearby
# contributes a sideways shove, and a weak pull returns us to the road centre.
# No states to flip between, so nothing can oscillate.
func _update_lane(delta: float) -> void:
	var curve_len: float = get_parent().curve.get_baked_length()
	var push: float = 0.0
	if curve_len > 0.0:
		for other in get_parent().get_children():
			if other == self or not is_instance_valid(other):
				continue
			if not (other is PathFollow2D) or not ("lane_offset" in other):
				continue
			var along: float = abs(other.progress_ratio - progress_ratio) * curve_len
			if along > CROWD_RANGE:
				continue
			var lateral: float = other.lane_offset - lane_offset
			if abs(lateral) >= CROWD_WIDTH:
				continue
			# closer along the path AND closer sideways = stronger shove
			var near: float = 1.0 - along / CROWD_RANGE
			var overlap: float = (CROWD_WIDTH - abs(lateral)) / CROWD_WIDTH
			var dir: float = 0.0
			if abs(lateral) < 0.5:
				# dead centre on each other — break the tie the same way every
				# frame, otherwise they'd shove back and forth
				dir = -1.0 if get_instance_id() < other.get_instance_id() else 1.0
			else:
				dir = -signf(lateral)
			push += dir * near * overlap
	lane_offset += push * CROWD_PUSH * delta
	lane_offset = lerp(lane_offset, 0.0, min(delta * CROWD_RETURN, 1.0))
	lane_offset = clamp(lane_offset, -LANE_MAX, LANE_MAX)
	var perp: Vector2 = _path_dir.orthogonal()
	h_offset = perp.x * lane_offset
	v_offset = perp.y * lane_offset
	
	# Is anyone near us already sitting in that lane? Checks both ahead and behind,
# since stepping into an occupied lane would just move the collision sideways.
# Anyone right behind us in our lane? That's who we're getting out of the way of.
func _follower_behind() -> Node:
	var curve_len: float = get_parent().curve.get_baked_length()
	if curve_len <= 0.0:
		return null
	var reach: float = YIELD_LOOKBEHIND / curve_len
	for other in get_parent().get_children():
		if other == self or not is_instance_valid(other):
			continue
		if not (other is PathFollow2D) or not ("lane_offset" in other):
			continue
		if other.progress_ratio >= progress_ratio:
			continue
		if progress_ratio - other.progress_ratio > reach:
			continue
		if abs(other.lane_offset - lane_offset) > LANE_WIDTH * 0.7:
			continue
		return other
	return null
func _lane_taken(lane: float) -> bool:
	var curve_len: float = get_parent().curve.get_baked_length()
	if curve_len <= 0.0:
		return false
	var reach: float = OVERTAKE_LOOKAHEAD / curve_len
	for other in get_parent().get_children():
		if other == self or not is_instance_valid(other):
			continue
		if not (other is PathFollow2D) or not ("lane_offset" in other):
			continue
		if abs(other.progress_ratio - progress_ratio) > reach:
			continue
		if abs(other.lane_offset - lane) < LANE_WIDTH * 0.7:
			return true
	return false


# ════════════════════════════════════════════
#  DIRECTIONAL WALK ANIMATION
# ════════════════════════════════════════════

# Loads four folders of walk frames laid out as:
#   <base_path>/<dir>_side/<prefix>_<dir>_side_NN.png   (NN = 01..WALK_FRAME_COUNT)
func _load_directional_walk(base_path: String, prefix: String) -> void:
	var folders := {
		"front": "front_side",
		"back": "back_side",
		"left": "left_side",
		"right": "right_side",
	}
	var loaded_any: bool = false
	for key in folders.keys():
		var arr: Array = []
		for i in range(1, WALK_FRAME_COUNT + 1):
			var p: String = "%s/%s/%s_%s_%02d.png" % [base_path, folders[key], prefix, folders[key], i]
			var tex: Texture2D = load(p)
			if tex == null:
				push_warning("Enemy: missing walk frame %s" % p)
				continue
			arr.append(tex)
		if not arr.is_empty():
			loaded_any = true
		walk_frames[key] = arr
	uses_directional_walk = loaded_any


func _first_walk_frame() -> Texture2D:
	for key in ["front", "right", "left", "back"]:
		if walk_frames.has(key):
			var arr: Array = walk_frames[key]
			if not arr.is_empty():
				return arr[0]
	return null


# Scale that renders a frame at the given on-map height. Snaps to whole numbers
# when upscaling so pixel art keeps clean, even pixels.
func _scale_for_height(tex: Texture2D, target_h: float) -> Vector2:
	if tex == null or tex.get_size().y <= 0.0:
		return Vector2.ONE
	var s: float = target_h / tex.get_size().y
	if SNAP_PIXEL_SCALE and s >= 1.0:
		s = max(1.0, round(s))
	return Vector2(s, s)


# Facing comes from the PATH tangent, not raw movement — a sideways overtaking
# manoeuvre must not spin the sprite. No diagonals yet: extend this to 8 sectors
# via _path_dir.angle() once diagonal frames exist.
func _update_facing() -> void:
	if _path_dir.length() < 0.01:
		return
	var new_facing: String = facing
	if abs(_path_dir.x) > abs(_path_dir.y):
		new_facing = "right" if _path_dir.x > 0.0 else "left"
	else:
		# +Y points down in Godot 2D: moving down = walking toward the viewer.
		new_facing = "front" if _path_dir.y > 0.0 else "back"
	if new_facing != facing:
		facing = new_facing
		# Keep the step in sync when turning instead of snapping back to frame 0.
		var arr: Array = walk_frames.get(facing, [])
		if not arr.is_empty():
			walk_index = walk_index % arr.size()


func _advance_walk(delta: float) -> void:
	var frames: Array = walk_frames.get(facing, [])
	if frames.is_empty():
		return
	walk_timer += delta
	while walk_timer >= WALK_FRAME_DURATION:
		walk_timer -= WALK_FRAME_DURATION
		walk_index = (walk_index + 1) % frames.size()
	sprite_node.texture = frames[walk_index]


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
