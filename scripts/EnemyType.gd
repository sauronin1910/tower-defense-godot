class_name EnemyType
extends Resource

# One enemy type, authored as a .tres in res://data/enemies/.
# Dropping a new .tres in that folder is the ONLY step needed to make a type
# exist — EnemyTypes scans the folder, Enemy.gd reads every number from here,
# and waves refer to it by `id`.
#
# Texture paths are plain strings rather than Texture2D references so the .tres
# files stay hand-editable and diff cleanly; Godot caches the load anyway.

@export var id: String = ""

# ── Combat ──
@export var health: int = 30
## Design speed. Enemy.SPEED_MULTIPLIER scales every type at once for the map.
@export var speed: float = 100.0
## Gold granted when killed.
@export var gold: int = 10
## Base health lost if this unit reaches the end of the path.
@export var leak_damage: int = 1

# ── Death split (slime_big -> slime_mini) ──
## Enemy id spawned on death; empty = this unit doesn't split.
@export var splits_into: String = ""
@export var split_count: int = 0

# ── Art: EITHER a static texture OR directional walk frames ──
# A type must not have both: the procedural wiggle and the frame animation
# fight each other if they run together.
@export_file("*.png") var texture_path: String = ""
## Sprite scale for static-texture types.
@export var scale: float = 1.0

## Folder holding <dir>_side/ subfolders of walk frames. Empty = static sprite.
@export_dir var walk_path: String = ""
## Filename prefix inside those folders.
@export var walk_prefix: String = ""
## Frames per direction.
@export var walk_frame_count: int = 9
## On-map height in pixels; scale is derived from it and the frame resolution.
@export var walk_height: float = 120.0

# ── Procedural wiggle, for static-texture types only ──
# Optional keys, all dictionaries of floats:
#   pulse {freq, amp}                — squash/stretch scale
#   bob   {freq, amp, freq2, amp2}   — vertical offset, second wave optional
#   rock  {freq, amp}                — rotation in radians
@export var wiggle: Dictionary = {}


func uses_walk_frames() -> bool:
	return walk_path != ""


func splits() -> bool:
	return splits_into != "" and split_count > 0
