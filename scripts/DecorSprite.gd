extends Sprite2D

# Depth-sorts a hand-placed decor sprite the same way enemies and towers do, and
# optionally gives it a shadow. Shadows go into the shared ShadowLayer
# (a CanvasGroup) so overlapping ones don't stack into dark blotches — they are
# drawn opaque there, and the group's own alpha sets how dark shadows end up.

enum ShadowMode { NONE, BLOB, SILHOUETTE }

# Where the object touches the ground, as a fraction of sprite height measured
# from its centre. Sprites are centred, so 0.5 = the very bottom edge.
@export var ground_anchor: float = 0.45
@export var shadow_mode: ShadowMode = ShadowMode.BLOB

@export_group("Blob shadow")
@export var blob_width: float = 0.4      # fraction of the sprite's opaque width
@export var blob_squash: float = 0.45
@export var blob_offset: Vector2 = Vector2.ZERO   # nudge in world pixels

@export_group("Silhouette shadow")
@export var cast_skew: float = 0.9       # lean in radians; + leans right
@export var cast_squash: float = 0.5     # vertical scale, lower = flatter
@export var cast_offset: Vector2 = Vector2(14.0, 4.0)
@export_group("Build blocking")
@export var blocks_building: bool = true
# Blocking radius as a fraction of the sprite's opaque width. A tree's canopy is
# much wider than its trunk, so lower this for trees and raise it for boulders.
@export var block_radius: float = 0.45

# Filled in at _ready and read by Main.gd's placement check.
var block_center: Vector2 = Vector2.ZERO
var block_extent: float = 0.0

func _ready() -> void:
	var h: float = 0.0
	if texture != null:
		h = texture.get_height() * abs(scale.y)
	z_index = clampi(int(global_position.y + h * ground_anchor) + 2000, 0, 8000)
	# Register as a build obstacle: towers can't be placed overlapping decor.
	if blocks_building and texture != null:
		var ob: Rect2 = _opaque_bounds()
		var bottom_y: float = ob.position.y + ob.size.y - texture.get_height() * 0.5
		block_center = to_global(Vector2(0.0, bottom_y))
		block_extent = ob.size.x * abs(scale.x) * block_radius
		add_to_group("decor")

	match shadow_mode:
		ShadowMode.BLOB:
			_add_blob_shadow()
		ShadowMode.SILHOUETTE:
			_add_cast_shadow()


func _shadow_layer() -> Node2D:
	return get_tree().get_first_node_in_group("shadow_layer") as Node2D


func _add_blob_shadow() -> void:
	if texture == null:
		return
	var opaque: Rect2 = _opaque_bounds()
	# Sprite is centred: bottom of the visible pixels, in local (texture) coords.
	var bottom: float = opaque.position.y + opaque.size.y - texture.get_height() * 0.5

	var shadow := TowerShadow.new()
	shadow.color = Color(0.0, 0.0, 0.0, 1.0)  # opaque — the group dims it
	shadow.x_offset = 0.0
	shadow.y_offset = 0.0
	shadow.width_mult = 1.0
	shadow.height_mult = 1.0

	var layer := _shadow_layer()
	if layer != null:
		# In the shared layer there's no inherited scale, so bake ours in.
		shadow.setup(opaque.size.x * blob_width * abs(scale.x), blob_squash)
		layer.add_child(shadow)
		shadow.global_position = to_global(Vector2(0.0, bottom)) + blob_offset
	else:
		# Fallback: keep it as a child if the layer is missing.
		shadow.setup(opaque.size.x * blob_width, blob_squash)
		shadow.position = Vector2(0.0, bottom) + blob_offset
		shadow.z_index = -1
		add_child(shadow)
		move_child(shadow, 0)


func _add_cast_shadow() -> void:
	if texture == null:
		return
	var shadow := Sprite2D.new()
	shadow.texture = texture
	shadow.skew = cast_skew
	shadow.modulate = Color(0.0, 0.0, 0.0, 1.0)  # opaque — the group dims it
	shadow.texture_filter = texture_filter
	# Share the wind material so the shadow sways with the canopy.
	# Share the material so the shadow sways with the canopy, but on a duplicate
	# with as_shadow on — otherwise the grass fringe would render green in it.
	if material != null:
		var shadow_mat: ShaderMaterial = material.duplicate() as ShaderMaterial
		if shadow_mat != null:
			shadow_mat.set_shader_parameter("as_shadow", true)
			shadow.material = shadow_mat
		else:
			shadow.material = material

	var layer := _shadow_layer()
	if layer != null:
		shadow.scale = Vector2(scale.x, scale.y * cast_squash)
		layer.add_child(shadow)
		# cast_offset is authored in local pixels, so scale it like the sprite.
		shadow.global_position = global_position + cast_offset * scale
	else:
		shadow.scale = Vector2(1.0, cast_squash)
		shadow.position = cast_offset
		shadow.z_index = -1
		add_child(shadow)
		move_child(shadow, 0)


# Tight bounds of the visible pixels, in texture pixels.
func _opaque_bounds() -> Rect2:
	var img: Image = texture.get_image()
	if img == null:
		return Rect2(Vector2.ZERO, texture.get_size())
	if img.is_compressed():
		img.decompress()
	var r: Rect2i = img.get_used_rect()
	if r.size.x <= 0 or r.size.y <= 0:
		return Rect2(Vector2.ZERO, texture.get_size())
	return Rect2(r.position, r.size)
