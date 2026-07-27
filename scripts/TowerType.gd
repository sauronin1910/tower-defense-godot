class_name TowerType
extends Resource

# One tower type, authored as a .tres in res://data/towers/.
# Art, range and combat stats in one place: TowerVisuals reads these, and
# Tower.gd / TowerGhost.gd / Main.gd all read TowerVisuals.
#
# As with EnemyType, paths are plain strings so the .tres files stay
# hand-editable and diff cleanly.

@export var id: String = ""

# ── Art ──
## Sprite path. Use a %d placeholder when frame_count > 1.
@export var sprite_path: String = ""
## 1 = static sprite, >1 = animation frames numbered from 1.
@export var frame_count: int = 1

# ── Combat ──
@export var attack_range: float = 180.0
@export_file("*.png") var projectile_path: String = ""
## Where shots leave the tower, as a fraction of TowerVisuals.TARGET_HEIGHT.
## 0.0 = ground, 1.0 = the very top.
@export_range(0.0, 1.0) var muzzle: float = 0.5

## Build price. Also seeds Tower.total_gold_invested, so the sell refund
## follows from this one number.
@export var cost: int = 50
## Level-1 damage; Tower._apply_level_stats scales it by 1.15^(level-1).
@export var damage: int = 10
## Level-1 shots per second, scaled the same way.
@export var fire_rate: float = 1.0
