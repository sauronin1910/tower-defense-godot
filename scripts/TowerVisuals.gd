class_name TowerVisuals
extends RefCounted

# Single source of truth for tower visuals and range.
# Both Tower.gd (the placed tower) and TowerGhost.gd (the drag preview) read
# from here, so the ghost can never drift out of sync with the real tower again.

# On-map height of a tower sprite, in map pixels (tile = 96)
const TARGET_HEIGHT: float = 240.0

# Nudges the sprite down, as a fraction of its height, after the base has been
# measured. Positive = lower. Tweak by eye until the tower sits on the cursor.
const BASE_NUDGE_RATIO: float = 0.15

# Ground footprint radius, as a fraction of the sprite's opaque width.
# 0.5 = towers touch exactly; lower it to let them sit closer together.
const FOOTPRINT_WIDTH_RATIO: float = 0.5

# The footprint is an ellipse, not a circle: the ground is seen at an angle, so
# the same real gap looks shorter on screen vertically than horizontally.
# 1.0 = circle; lower = towers may stack closer above/below each other.
const FOOTPRINT_VERTICAL_RATIO: float = 0.7

# ── Cast shadow (variant B) — skewed silhouette cast on the ground ──
# All tweakable by eye. Light is assumed upper-left, so the shadow falls to the
# lower-right (positive skew / positive x offset).
const SHADOW_SKEW: float = 0.9              # lean in radians; + leans right, - left
const SHADOW_SQUASH: float = 0.8           # vertical scale (lower = flatter on ground)
const SHADOW_ALPHA: float = 0.33            # darkness (0 = invisible, 1 = solid black)
const SHADOW_OFFSET_X: float = 20.0         # base offset from the tower foot (+ = right)
const SHADOW_OFFSET_Y: float = 5.0          # base offset (+ = down)

# path: file path; use a %d placeholder when frames > 1
# frames: 1 = static sprite, >1 = animation frames numbered from 1
const DATA := {
	"spear": {
		"path": "res://assets/sprites/Towers/spear_tower/Spear_Tower_%d.png",
		"frames": 5,
		"range": 180.0,
		"projectile": "res://assets/sprites/Towers/spear_tower/Projectile_Spear.png",
		"muzzle": 0.4,
	},
	"arrow": {
		"path": "res://assets/sprites/Tower_basic_arrow.png",
		"frames": 1,
		"range": 200.0,
		"projectile": "res://assets/sprites/arrow.png",
		"muzzle": 0.75,
	},
	"shells": {
		"path": "res://assets/sprites/Tower_basic_shells.png",
		"frames": 1,
		"range": 130.0,
		"projectile": "res://assets/sprites/Shell.png",
		"muzzle": 0.75,
	},
}


static func _entry(type: String) -> Dictionary:
	if DATA.has(type):
		return DATA[type]
	return DATA["spear"]


static func frame_paths(type: String) -> Array:
	var entry: Dictionary = _entry(type)
	if int(entry["frames"]) <= 1:
		return [entry["path"]]
	var paths: Array = []
	for i in range(1, int(entry["frames"]) + 1):
		paths.append(entry["path"] % i)
	return paths


# Returns loaded textures; skips (and warns about) any that fail to load
static func load_frames(type: String) -> Array:
	var textures: Array = []
	for path in frame_paths(type):
		var tex: Texture2D = load(path)
		if tex == null:
			push_warning("TowerVisuals: missing texture at %s" % path)
			continue
		textures.append(tex)
	return textures


# Uniform scale that renders any source resolution at TARGET_HEIGHT
static func scale_for(tex: Texture2D) -> Vector2:
	if tex == null or tex.get_size().y <= 0.0:
		return Vector2.ONE
	var s: float = TARGET_HEIGHT / tex.get_size().y
	return Vector2(s, s)


# Cache: textures are shared, so the alpha scan runs once per file
static var _offset_cache: Dictionary = {}


# Sprite offset (in texture pixels) that puts the tower's base on the node origin.
# Measures the opaque pixels, so transparent padding around the art is ignored.
static func base_offset(tex: Texture2D) -> Vector2:
	if tex == null:
		return Vector2.ZERO

	var key: String = tex.resource_path
	if key != "" and _offset_cache.has(key):
		return _offset_cache[key]

	var height: float = tex.get_size().y
	# Fallback: assume the art fills the texture
	var offset: Vector2 = Vector2(0.0, -height * 0.5)

	var img: Image = tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var used: Rect2i = img.get_used_rect()
		if used.size.y > 0:
			var opaque_bottom: float = float(used.position.y + used.size.y)
			offset = Vector2(0.0, height * 0.5 - opaque_bottom)

	offset.y += height * BASE_NUDGE_RATIO

	if key != "":
		_offset_cache[key] = offset
	return offset


static var _footprint_cache: Dictionary = {}


# Radius of the tower's footprint on the ground, in map pixels.
# Two towers overlap when the distance between them is less than the sum of theirs.
static func footprint_radius(type: String) -> float:
	if _footprint_cache.has(type):
		return _footprint_cache[type]

	var radius: float = 48.0
	var frames: Array = load_frames(type)
	if not frames.is_empty():
		var tex: Texture2D = frames[0]
		var width: float = tex.get_size().x
		var img: Image = tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var used: Rect2i = img.get_used_rect()
			if used.size.x > 0:
				width = float(used.size.x)
		radius = width * scale_for(tex).x * FOOTPRINT_WIDTH_RATIO

	_footprint_cache[type] = radius
	return radius


static var _opaque_cache: Dictionary = {}


# The tight bounding box of the tower's visible pixels, in LOCAL sprite space
# (already scaled and shifted by the sprite's offset). Returns a Rect2 whose
# position is relative to the node origin. Used to build a snug click hitbox
# instead of one padded out by the texture's transparent margins.
static func opaque_local_rect(type: String) -> Rect2:
	var frames: Array = load_frames(type)
	if frames.is_empty():
		return Rect2(-32, -64, 64, 64)
	var tex: Texture2D = frames[0]
	var key: String = tex.resource_path
	if key != "" and _opaque_cache.has(key):
		return _opaque_cache[key]

	var tex_size: Vector2 = tex.get_size()
	var used := Rect2i(Vector2i.ZERO, Vector2i(tex_size))
	var img: Image = tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var r: Rect2i = img.get_used_rect()
		if r.size.x > 0 and r.size.y > 0:
			used = r

	var s: Vector2 = scale_for(tex)
	var off: Vector2 = base_offset(tex)
	# Sprite is centered: texture pixel (px,py) maps to local
	#   (px - tex_w/2)*s + off*s ... offset is already in texture px, so scale it too
	var local_pos: Vector2 = (Vector2(used.position) - tex_size * 0.5 + off) * s
	var local_size: Vector2 = Vector2(used.size) * s
	var rect := Rect2(local_pos, local_size)

	if key != "":
		_opaque_cache[key] = rect
	return rect


static func attack_range(type: String) -> float:
	return float(_entry(type)["range"])


static func projectile_path(type: String) -> String:
	return str(_entry(type)["projectile"])


# Where shots leave the tower, relative to its origin (which sits at the base).
# "muzzle" is a fraction of TARGET_HEIGHT: 0.0 = ground, 1.0 = very top.
static func muzzle_offset(type: String) -> Vector2:
	return Vector2(0.0, -TARGET_HEIGHT * float(_entry(type)["muzzle"]))


# Creates a ready-to-use blob shadow node for a tower of this type. The caller
# adds it as the FIRST child of the tower so it draws under the sprite, at the
# base (node origin). Kept for enemies (variant A); towers use make_cast_shadow.
static func make_shadow(type: String) -> TowerShadow:
	var shadow := TowerShadow.new()
	shadow.setup(footprint_radius(type), FOOTPRINT_VERTICAL_RATIO)
	return shadow


# Builds a cast-shadow Sprite2D (variant B): same silhouette as the sprite,
# filled black, skewed and squashed onto the ground. Tower.gd assigns the
# current animation frame to it each tick so it waves in sync with the flag.
# Returns null if the type has no frames.
static func make_cast_shadow(type: String) -> Sprite2D:
	var frames: Array = load_frames(type)
	if frames.is_empty():
		return null
	var tex: Texture2D = frames[0]
	var shadow := Sprite2D.new()
	shadow.texture = tex
	shadow.scale = Vector2(scale_for(tex).x, scale_for(tex).y * SHADOW_SQUASH)
	shadow.offset = base_offset(tex)
	shadow.skew = SHADOW_SKEW
	shadow.position = Vector2(SHADOW_OFFSET_X, SHADOW_OFFSET_Y)
	shadow.modulate = Color(0.0, 0.0, 0.0, SHADOW_ALPHA)
	shadow.z_index = -1  # under the tower sprite
	return shadow
