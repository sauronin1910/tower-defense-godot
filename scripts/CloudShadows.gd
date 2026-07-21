extends Sprite2D

# Cloud-shadow blobs drifting across the whole map, wrapping seamlessly.
# Texture = transparent PNG with black semi-transparent cloud blobs.
#
# Simple + robust: the sprite is sized to the whole map via region_rect, and
# texture_repeat tiles the PNG. cloud_scale sets how many world pixels ONE
# texture tile spans — bigger value = bigger clouds. Drift scrolls the region
# origin; repeat handles the wrap.

@export var drift: Vector2 = Vector2(-20.0, 4)   # world px/sec (direction + speed)
@export var map_origin: Vector2 = Vector2(-1248.0, -384.0)
@export var map_size: Vector2 = Vector2(4512.0, 2592.0)

# World pixels that one texture tile spans. Bigger = bigger clouds, fewer of them.
# Texture is 640x360, so 1280 makes each cloud ~2x its native size on the map.
@export var tile_world_size: Vector2 = Vector2(1600.0, 900.0)

var _scroll: Vector2 = Vector2.ZERO


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	region_enabled = true
	centered = false
	position = map_origin
	scale = Vector2.ONE
	_update_region()


func _process(delta: float) -> void:
	_scroll += drift * delta
	_update_region()


func _update_region() -> void:
	# region_rect is in TEXTURE pixels. To make one tile span tile_world_size on
	# the map while the sprite covers the whole map, we set the region to cover
	# the map measured in units of tile_world_size, times the texture size.
	var tex: Texture2D = texture
	if tex == null:
		return
	var tex_size: Vector2 = tex.get_size()
	# How many tiles fit across the map:
	var tiles: Vector2 = map_size / tile_world_size
	# Region in texture pixels = tiles * tex_size, scrolled by drift.
	var scroll_tex: Vector2 = (_scroll / tile_world_size) * tex_size
	region_rect = Rect2(scroll_tex, tiles * tex_size)
	# Sprite draws region stretched to region size (in px); scale it so the drawn
	# size equals the map.
	scale = map_size / (tiles * tex_size)
