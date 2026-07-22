extends Sprite2D

# Cloud-shadow blobs drifting across the whole map, wrapping seamlessly.
# Texture = transparent PNG with black semi-transparent cloud blobs (no visible
# cloud, just the shadow). The sprite covers the whole map via region_rect and
# tiles the PNG with texture_repeat; the region origin scrolls to drift.
#
# Speed and direction are SEPARATE now:
#   - direction: which way clouds move (its length doesn't matter, it's normalized)
#   - speed: how fast, in world pixels per second (small = slow). Independent of
#            cloud size, so changing tile_world_size no longer changes speed.

@export var direction: Vector2 = Vector2(-1.0, 0.2)  # movement direction (normalized internally)
@export var speed: float = 7.0                        # world px/sec (small = slow drift)

@export var map_origin: Vector2 = Vector2(-1248.0, -384.0)
@export var map_size: Vector2 = Vector2(4512.0, 2592.0)

# World pixels one texture tile spans. Bigger = bigger clouds, fewer of them.
@export var tile_world_size: Vector2 = Vector2(2500.0, 1980.0)

# Accumulated drift in WORLD pixels (kept in world units so speed stays in world px/sec)
var _scroll_world: Vector2 = Vector2.ZERO


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	region_enabled = true
	centered = false
	position = map_origin
	scale = Vector2.ONE
	_update_region()


func _process(delta: float) -> void:
	# Move by speed (world px/sec) along the normalized direction.
	var dir: Vector2 = direction
	if dir.length() > 0.0:
		dir = dir.normalized()
	_scroll_world += dir * speed * delta
	_update_region()


func _update_region() -> void:
	var tex: Texture2D = texture
	if tex == null:
		return
	var tex_size: Vector2 = tex.get_size()
	# How many texture tiles span the whole map.
	var tiles: Vector2 = map_size / tile_world_size
	# Convert the world-space scroll into texture pixels for region_rect.
	# One tile_world_size of world movement == one tex_size of texture movement.
	var scroll_tex: Vector2 = (_scroll_world / tile_world_size) * tex_size
	region_rect = Rect2(scroll_tex, tiles * tex_size)
	# Stretch the drawn region back up to cover the whole map.
	scale = map_size / (tiles * tex_size)
