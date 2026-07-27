extends Area2D

signal tower_clicked(tower)

# Tower type selection
@export var tower_type: String = "spear"

# Upgrade system
var level: int = 1
const MAX_LEVEL: int = 3
# Click hitbox height as a fraction of the sprite height (base-anchored)
const HITBOX_HEIGHT_RATIO: float = 0.75
var total_gold_invested: int = 0

# Tower stats (set in _ready() based on tower_type, then scaled by level)
var base_attack_range: float = 150.0
var base_fire_rate: float = 1.0
var shoot_timer: Timer = null
var base_tower_damage: int = 10
var attack_range: float = 150.0
var fire_rate: float = 1.0
var tower_cost: int = 50
var tower_damage: int = 10

# Projectile texture path (what this tower shoots at enemies)
var projectile_texture_path: String = ""

# Tower state tracking
var enemies_in_range = []
var range_visible: bool = false
var range_reveal: float = 0.0

# Ground footprint, used to stop towers overlapping each other
var footprint_radius: float = 48.0

# Idle animation state (flag waving)
var frame_textures: Array = []
# Cached in _ready — the flag animation swaps a texture every 0.1s and used to
# re-resolve the node path each time.
var sprite_node: Sprite2D = null
var cast_shadow: Sprite2D = null
var frame_index: int = 0
var frame_timer: float = 0.0
const FRAME_DURATION: float = 0.1


func _ready():
	add_to_group("towers")
	# Every per-type number — art, range, price and combat stats — comes from
	# the type's .tres. Tower used to keep its own copy of cost/damage/rate,
	# which meant a price change had to be made here AND in Main to keep the
	# sell refund honest.
	base_fire_rate = TowerVisuals.base_fire_rate(tower_type)
	tower_cost = TowerVisuals.cost(tower_type)
	base_tower_damage = TowerVisuals.base_damage(tower_type)

	projectile_texture_path = TowerVisuals.projectile_path(tower_type)
	base_attack_range = TowerVisuals.attack_range(tower_type)
	footprint_radius = TowerVisuals.footprint_radius(tower_type)
	total_gold_invested = tower_cost

	# Cast shadow (variant B): black skewed copy of the silhouette on the ground,
	# added first so it draws under the sprite. Frame-synced in
	# _advance_flag_animation so it waves with the flag.
	cast_shadow = TowerVisuals.make_cast_shadow(tower_type)
	if cast_shadow != null:
		add_child(cast_shadow)
		move_child(cast_shadow, 0)  # lowest: shadow on the ground

		
	# Load visuals: animation frames if this type has them, otherwise one texture
	var sprite = get_node("Sprite2D")
	sprite_node = sprite
	frame_textures = TowerVisuals.load_frames(tower_type)
	if frame_textures.is_empty():
		sprite.texture = null
	else:
		# Randomize the starting frame so towers don't wave in lockstep
		frame_index = randi() % frame_textures.size()
		frame_timer = randf() * FRAME_DURATION
		sprite.texture = frame_textures[frame_index]
		# Scale and offset come from frame 0 so every frame lines up identically
		sprite.scale = TowerVisuals.scale_for(frame_textures[0])
		sprite.offset = TowerVisuals.base_offset(frame_textures[0])
		# Sync the shadow's starting frame to the sprite
		if is_instance_valid(cast_shadow):
			cast_shadow.texture = frame_textures[frame_index]

	_apply_level_stats()

	# Click hitbox: snug around the tower's VISIBLE pixels, not the padded
	# texture. opaque_local_rect returns the tight bounds in the same local
	# space the sprite renders in, so the box lands exactly on the artwork.
	var collision_shape = get_node("CollisionShape2D")
	var rect_shape = RectangleShape2D.new()
	var opaque: Rect2 = TowerVisuals.opaque_local_rect(tower_type)
	# Keep the lower HITBOX_HEIGHT_RATIO of the tower (drop roof/flag) so
	# stacked towers don't overlap; 1.0 would cover the whole silhouette.
	var box_w: float = opaque.size.x * 1.1
	var box_h: float = opaque.size.y * HITBOX_HEIGHT_RATIO
	rect_shape.size = Vector2(box_w, box_h)
	collision_shape.shape = rect_shape
	# Center of the box = center-x of the opaque rect, and vertically the
	# center of the kept bottom slice.
	var center_x: float = opaque.position.x + opaque.size.x * 0.5
	var bottom_y: float = opaque.position.y + opaque.size.y
	var center_y: float = bottom_y - box_h * 0.5
	collision_shape.position = Vector2(center_x, center_y)

	# Setup timer for shooting
	shoot_timer = Timer.new()
	add_child(shoot_timer)
	shoot_timer.connect("timeout",Callable(self,"_on_shoot_timer"))
	shoot_timer.wait_time = 1.0 / fire_rate
	shoot_timer.start()

	# Enable input for click detection (deferred to avoid catching the placement click)
	input_pickable = false
	input_event.connect(_on_input_event)
	call_deferred("_enable_input_after_frame")

	_play_build_pop()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tower_clicked.emit(self)
		get_viewport().set_input_as_handled()


func _process(delta):
	_advance_flag_animation(delta)
	# Same depth sorting as enemies, so units pass in front of / behind towers.
	z_index = clampi(int(global_position.y) + 2000, 0, 8000)
	if range_visible and range_reveal < 1.0:
		range_reveal = min(range_reveal + delta * 6.0, 1.0)
		queue_redraw()


func _advance_flag_animation(delta: float) -> void:
	if frame_textures.size() < 2:
		return
	frame_timer += delta
	if frame_timer < FRAME_DURATION:
		return
	frame_timer -= FRAME_DURATION
	frame_index = (frame_index + 1) % frame_textures.size()
	if is_instance_valid(sprite_node):
		sprite_node.texture = frame_textures[frame_index]
	# Keep the cast shadow waving in sync with the flag
	if is_instance_valid(cast_shadow):
		cast_shadow.texture = frame_textures[frame_index]


# Enemies in range, rebuilt on demand. This used to run every frame in _process,
# which made target selection cost (towers x enemies) per frame for a list that
# is only ever read when the shoot timer fires — roughly once a second. Scanning
# here is both ~60x cheaper and more accurate, since it sees current positions
# rather than a list that could be a frame stale.
func _refresh_enemies_in_range() -> void:
	enemies_in_range.clear()
	var range_sq: float = attack_range * attack_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and global_position.distance_squared_to(enemy.global_position) <= range_sq:
			enemies_in_range.append(enemy)


func _on_shoot_timer():
	_refresh_enemies_in_range()
	if enemies_in_range.is_empty():
		return

	var best_target: Object = null
	var best_progress: float = -1.0

	for enemy in enemies_in_range:
		if not is_instance_valid(enemy):
			continue
		if enemy.progress_ratio > best_progress:
			best_progress = enemy.progress_ratio
			best_target = enemy

	if best_target != null:
		shoot(best_target)



func shoot(target):
	# Load and instantiate projectile
	var projectile_scene = preload("res://scenes/Projectile.tscn")
	var projectile = projectile_scene.instantiate()

	# Give projectile reference to target enemy
	projectile.target = target

	# Pass damage value to the projectile
	projectile.damage = tower_damage

	# Pass texture path so projectile loads its own visual
	projectile.texture_path = projectile_texture_path

	# Same parent as the tower, so a scene reload takes shots in flight with it
	get_parent().add_child(projectile)

	# Position after entering the tree, so global_position means what it says.
	# Shots leave the top of the tower, not its base.
	projectile.global_position = global_position + TowerVisuals.muzzle_offset(tower_type)

func _draw() -> void:
	if not range_visible:
		return
	# Range ring animates open on click, then holds at full size (static)
	var ring_r: float = attack_range * range_reveal
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64, Color(0.0, 0.0, 0.0, 1.0), 2.0)


func show_range() -> void:
	range_visible = true
	range_reveal = 0.0
	queue_redraw()

func hide_range() -> void:
	range_visible = false
	queue_redraw()


func _play_build_pop() -> void:
	# Build-in animation: the tower springs up from its base.
	# Scale-only, so it never fights the flag animation (texture) or
	# the level tint (modulate). Origin is at the base, so it grows upward.
	var sprite := get_node("Sprite2D")
	var final_scale: Vector2 = sprite.scale
	sprite.scale = Vector2(final_scale.x * 0.05, final_scale.y * 0.05)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "scale", final_scale, 0.22)


# ════════════════════════════════════════════
#  UPGRADE SYSTEM
# ════════════════════════════════════════════

func _apply_level_stats() -> void:
	# Each level: +15% damage, +15% fire rate, +15% range
	var multiplier: float = pow(1.15, level - 1)
	attack_range = base_attack_range * multiplier
	fire_rate = base_fire_rate * multiplier
	tower_damage = int(base_tower_damage * multiplier)

	# Push the new rate to the running timer (skipped during the first
	# _apply_level_stats in _ready, before the timer is created)
	if is_instance_valid(shoot_timer) and fire_rate > 0.0:
		shoot_timer.wait_time = 1.0 / fire_rate


	# Visual: darken by 25% per level (level 1 = 1.0, level 2 = 0.75, level 3 = 0.5)
	var sprite = get_node("Sprite2D")
	var darkness: float = 1.0 - (level - 1) * 0.25
	sprite.modulate = Color(darkness, darkness, darkness, 1.0)
	if range_visible:
		queue_redraw()


func get_upgrade_cost() -> int:
	if level >= MAX_LEVEL:
		return 0
	return int(tower_cost * 0.75)


func get_sell_value() -> int:
	return int(total_gold_invested * 0.7)


func upgrade() -> bool:
	if level >= MAX_LEVEL:
		return false
	var cost: int = get_upgrade_cost()
	total_gold_invested += cost
	level += 1
	_apply_level_stats()
	return true
func _enable_input_after_frame() -> void:
	await get_tree().process_frame
	input_pickable = true
