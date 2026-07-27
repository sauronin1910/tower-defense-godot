@tool
class_name DecorKind
extends Resource

# One kind of decor prop — a tree species, a boulder — authored as a .tres in
# res://data/decor/kinds/.
#
# A kind holds everything that is the SAME for every copy of that prop: which
# texture, which material, how its shadow is shaped, whether it carves grass.
# Where each copy stands lives in data/decor/placements.json instead. The split
# is the whole point: 204 decor sprites used to be 204 node blocks in Main.tscn,
# each carrying its own copy of nine identical property lines because Ctrl+D
# duplicated them along with the position.
#
# Paths are plain strings rather than Texture2D/Material references, matching
# EnemyType — it keeps the .tres hand-editable and diffing cleanly, and Godot
# caches the load anyway.

@export var id: String = ""

@export_group("Art")
@export var texture_path: String = ""
@export var material_path: String = ""
## Sprite2D.texture_filter. 1 = Nearest, which is what the pixel art wants.
@export var texture_filter: int = 1
## Scale applied to every copy unless a placement overrides it.
@export var default_scale: Vector2 = Vector2.ONE

@export_group("Placement")
## Where the object touches the ground, as a fraction of sprite height from its
## centre. Sprites are centred, so 0.5 = the very bottom edge.
@export var ground_anchor: float = 0.45
@export var carves_grass: bool = true
@export var blocks_building: bool = true
## Blocking radius as a fraction of the sprite's opaque width. A tree's canopy
## is much wider than its trunk, so lower this for trees, raise it for boulders.
@export var block_radius: float = 0.45

@export_group("Shadow")
## Matches DecorSprite.ShadowMode: 0 NONE, 1 BLOB, 2 SILHOUETTE.
@export var shadow_mode: int = 1
@export var blob_width: float = 0.4
@export var blob_squash: float = 0.45
@export var blob_offset: Vector2 = Vector2.ZERO
@export var cast_skew: float = 0.9
@export var cast_squash: float = 0.5
@export var cast_offset: Vector2 = Vector2(14.0, 4.0)


# Copies this kind's settings onto a DecorSprite. Called before the sprite
# enters the tree, so its _ready() sees the finished configuration.
func apply_to(sprite: Sprite2D) -> void:
	if texture_path != "":
		sprite.texture = load(texture_path)
	if material_path != "":
		sprite.material = load(material_path)
	sprite.texture_filter = texture_filter as CanvasItem.TextureFilter
	sprite.ground_anchor = ground_anchor
	sprite.shadow_mode = shadow_mode
	sprite.blob_width = blob_width
	sprite.blob_squash = blob_squash
	sprite.blob_offset = blob_offset
	sprite.cast_skew = cast_skew
	sprite.cast_squash = cast_squash
	sprite.cast_offset = cast_offset
	sprite.carves_grass = carves_grass
	sprite.blocks_building = blocks_building
	sprite.block_radius = block_radius
