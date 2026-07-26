# Towers

Three tower types, three upgrade levels each, drag-and-drop placement.

Implementation: `scripts/Tower.gd`, `scripts/TowerVisuals.gd`, `scripts/TowerGhost.gd`, `scripts/TowerShadow.gd`, `scripts/TowerUpgradePanel.gd`, scene `scenes/Tower.tscn`.

Related: [[Economy]] for cost/DPS balance, [[Enemies]] for what these shoot at, [[Architecture]] for how the scripts are wired, [[TODO]] for the fix list.

---

## Tower types

| | Spear | Arrow | Shells |
|---|---:|---:|---:|
| Cost | 50 | 75 | 120 |
| Damage (L1) | 10 | 8 | 30 |
| Fire rate (L1) | 1.0 /s | 1.5 /s | 0.5 /s |
| Range (L1) | 180 px | 200 px | 130 px |
| **DPS (L1)** | **10.0** | **12.0** | **15.0** |
| DPS per gold | 0.200 | 0.160 | 0.125 |
| Muzzle height | 0.4 × sprite | 0.75 × sprite | 0.75 × sprite |
| Animation | 5-frame flag wave | static | static |
| Projectile | `Projectile_Spear.png` | `arrow.png` | `Shell.png` |

Damage, fire rate and cost live in `Tower._ready()` (`Tower.gd:47-58`). Range, art path, frame count, projectile and muzzle height live in `TowerVisuals.DATA` (`TowerVisuals.gd:35`). Cost is **also** declared in `Main.TOWER_COSTS` (`Main.gd:20`) — see the warning below.

> ⚠️ **Cost is duplicated.** `Main.TOWER_COSTS` is what the player pays; `Tower.tower_cost` is what seeds `total_gold_invested` and therefore the sell refund and the upgrade price. Changing one without the other silently desyncs the economy. See [[Architecture#2. Duplicated sources of truth]] and [[TODO#P1 — Structural|TODO #6]].

---

## Upgrade system

Three levels. Each level applies a flat multiplier of `pow(1.15, level - 1)` to damage, fire rate and range (`Tower._apply_level_stats:241`).

| Level | Multiplier | Spear dmg / rate / range | Arrow | Shells |
|---|---|---|---|---|
| 1 | 1.000 | 10 / 1.00 / 180 | 8 / 1.50 / 200 | 30 / 0.50 / 130 |
| 2 | 1.150 | 11 / 1.15 / 207 | 9 / 1.73 / 230 | 34 / 0.58 / 150 |
| 3 | 1.323 | 13 / 1.32 / 238 | 10 / 1.98 / 265 | 39 / 0.66 / 172 |

Damage is truncated with `int()`, so a level-2 spear deals 11 rather than 11.5.

**Upgrade cost is flat**: `int(tower_cost * 0.75)` regardless of current level (`Tower.get_upgrade_cost:262`). Both upgrades cost the same. See [[Economy#Value analysis]] for what this does to balance.

**Visual feedback**: each level darkens the sprite by 25 % via `modulate` — level 1 = 1.0, level 2 = 0.75, level 3 = 0.5. There is no distinct art per level.

**Selling** returns `int(total_gold_invested * 0.7)` — 70 % of everything put into that tower, including upgrades.

---

## Placement

Drag a button from the tower dock onto the map. `Main._start_drag(type)` spawns a `TowerGhost` that follows the cursor; releasing the left mouse button commits.

### Validity rules — `Main._can_place_tower_at:662`

A position is buildable when **all** of these hold:

1. **Affordable** — `gold >= TOWER_COSTS[type]`.
2. **Not on the road** — `_is_on_enemy_path`. Runs `intersect_shape` against collision layer 5 using a 16-segment convex ellipse built by `TowerVisuals.base_query_shape(type)`, offset down by `BASE_CHECK_Y_OFFSET = 6.0` px.
3. **Not on decor** — `_is_on_decor`. A plain distance test against the `decor` group (trees and rocks have no colliders), comparing against `d.block_extent`. Y is divided by `FOOTPRINT_VERTICAL_RATIO` first, since the ground is seen at an angle.
4. **Not overlapping another tower** — `_is_too_close_to_tower`. Sum of the two footprint radii, with the same Y squash.

### The footprint ellipse

`TowerVisuals.base_extents(type)` measures the tower's actual stone foot rather than guessing:

- Take the bottom `BASE_SLICE_RATIO = 18 %` of the sprite's opaque pixels.
- Find the widest span of pixels with alpha > 0.3 in that slice.
- Half that width × sprite scale × `BASE_MARGIN = 1.04` is the horizontal radius.
- Vertical radius is that × `FOOTPRINT_VERTICAL_RATIO = 0.7`.

Results are cached per type in `_base_extents_cache`.

### The ghost preview

`TowerGhost.gd` draws:
- The tower's first frame, tinted green (`0.5, 1.0, 0.5, 0.7`) when valid or red (`1.0, 0.4, 0.4, 0.7`) when blocked.
- A black range ring that animates open over ~0.17 s.
- A 12 px cell grid extending 96 px in each direction, each cell tinted green or red by a physics point query against the road layer.

> ⚠️ That grid is `(96/12 × 2 + 1)² = 289` physics point queries **per frame** while dragging. See [[Architecture#5. Performance hot spots]] and [[TODO#P1 — Structural|TODO #8]].

All ghost visuals come from `TowerVisuals`, so the preview cannot drift out of sync with the real tower — this is the cleanest abstraction in the codebase.

---

## Targeting and firing

`Tower._process` rebuilds `enemies_in_range` every frame by iterating `get_tree().get_nodes_in_group("enemies")` and distance-testing each one against `attack_range`.

A `Timer` at `1.0 / fire_rate` calls `_on_shoot_timer`, which picks the enemy with the **highest `progress_ratio`** — i.e. first-in-path, the enemy closest to the base. There is no other targeting mode. `progress_ratio` is the `PathFollow2D` position described in [[Enemies#Movement]].

`shoot(target)`:
- Instantiates `scenes/Projectile.tscn`, sets `target`, `damage` and `texture_path`.
- Parents it to `get_parent()` (the map root), not to the tower, so shots in flight survive tower removal.
- Positions it at `global_position + TowerVisuals.muzzle_offset(type)` — `-TARGET_HEIGHT × muzzle` on Y, so shots leave the top of the tower rather than its base.

### Projectiles — `scripts/Projectile.gd`

- Speed 400 px/s, perfect homing on `target.global_position`.
- Rotation is `direction.angle() + PI/2` because the art points up (`-Y`) while angle 0 is `+X`.
- Scaled to `TARGET_LENGTH = 25.9` px regardless of source resolution.
- **Hit detection is distance-based**, not physics: when `distance < speed * delta`, apply damage and free. The `CollisionShape2D` built in `_ready()` is dead weight.
- If the target dies mid-flight, `is_instance_valid` fails and the projectile frees itself — no splash, no re-target.

---

## Visual pipeline — `TowerVisuals.gd`

A `RefCounted` with only static functions and static caches. It is the single source of truth for how a tower looks, and both `Tower.gd` and `TowerGhost.gd` read from it. The full fan-in — four callers, 21 call sites — is tabulated in [[Architecture#TowerVisuals is the one real seam|Architecture → dependency graph]].

| Function | Purpose | Cached |
|---|---|---|
| `frame_paths` / `load_frames` | Resolve `%d` frame paths, load textures, warn on misses | no |
| `scale_for(tex)` | Uniform scale rendering any resolution at `TARGET_HEIGHT = 240` | no |
| `base_offset(tex)` | Sprite offset that puts the tower's **base** on the node origin, measured from opaque pixels, then nudged down by `BASE_NUDGE_RATIO = 0.15` | `_offset_cache` |
| `footprint_radius(type)` | Opaque width × scale × `FOOTPRINT_WIDTH_RATIO = 0.5` | `_footprint_cache` |
| `opaque_local_rect(type)` | Tight bounds of visible pixels in local space, for the click hitbox | `_opaque_cache` |
| `base_extents(type)` | Half-width/height of the ground ellipse (see above) | `_base_extents_cache` |
| `base_query_shape(type)` | 16-point `ConvexPolygonShape2D` ellipse for physics queries | no |
| `muzzle_offset(type)` | Where shots leave the tower | no |
| `make_cast_shadow(type)` | Black skewed silhouette copy for the ground shadow | no |
| `make_shadow(type)` | Blob shadow — **unused** | no |
| `make_grass_tuft(type)` | Grass ring around the base — **unused** | no |

### Tuning constants

```gdscript
TARGET_HEIGHT             = 240.0   # on-map sprite height (tile = 96)
BASE_NUDGE_RATIO          = 0.15    # push the sprite down so it sits on the cursor
FOOTPRINT_WIDTH_RATIO     = 0.5     # 0.5 = towers touch exactly
FOOTPRINT_VERTICAL_RATIO  = 0.7     # ellipse squash; ground seen at an angle
SHADOW_SKEW               = 0.9     # cast shadow lean, radians
SHADOW_SQUASH             = 0.8
SHADOW_ALPHA              = 0.33
SHADOW_OFFSET_X / _Y      = 20.0 / 5.0
```

Light is assumed to come from the upper left, so shadows fall to the lower right.

### Cast shadow

`make_cast_shadow` clones the sprite texture into a black, skewed, squashed `Sprite2D` placed as child index 0. `Tower._advance_flag_animation` assigns the current animation frame to it each tick, so the spear tower's shadow waves in sync with its flag.

---

## Click hitbox

Built in `Tower._ready()` from `TowerVisuals.opaque_local_rect(type)`:
- Width = opaque width × 1.1.
- Height = opaque height × `HITBOX_HEIGHT_RATIO = 0.75` — the **bottom** 75 %, dropping the roof and flag so stacked towers don't overlap each other's hitboxes.
- Centred on the opaque rect's X centre and the kept slice's Y centre.

`input_pickable` starts `false` and is enabled one frame later via `call_deferred("_enable_input_after_frame")`, so the click that *placed* the tower doesn't immediately re-open the upgrade panel.

---

## Build animation

`_play_build_pop()` scales the sprite from 5 % to full over 0.22 s with `EASE_OUT` / `TRANS_BACK`. Scale-only by design, so it never fights the flag animation (which drives `texture`) or the level tint (which drives `modulate`).

Animation frames start at a random index with a random timer offset so towers don't wave in lockstep.

---

## Upgrade panel — `TowerUpgradePanel.gd`

A `PanelContainer` that builds nearly all of its own styling in `_ready()` — `StyleBoxFlat` background, a circular close button in its own `HBoxContainer` row, per-state colours. The comment at line 34 notes scene edits weren't sticking on the instance, which is why it is all in code.

`_reposition()` runs every frame while visible and re-anchors the panel to the tracked tower using `get_global_transform_with_canvas()` — so it follows camera zoom and pan. It tries four placements in order: upper-right of the tower, upper-left, centred above, below; then clamps to the viewport with a 16 px margin.

`contains_point()` asks the panel's own `get_global_rect()` rather than guessing, and feeds `Main._is_ui_hit` so clicks on the panel don't close it.

---

## Known issues

All of these are prioritised in [[TODO]]; the structural framing is in [[Architecture#Structural problems]].

- **Cost duplication** between `Main.TOWER_COSTS` and `Tower.tower_cost` (see above).
- **Per-frame group scan** for targeting, per tower — `Tower` is an `Area2D` and should use area/body signals instead.
- **289 physics queries per frame** in the ghost's placement grid.
- **Flat upgrade cost** makes level 3 strictly better value than level 2 for no reason.
- **`set_footprint_visible()` is a no-op** that `Main._set_all_footprints_visible` still loops over all towers to call on every drag start and end.
- **`make_grass_tuft` and `make_shadow` are dead** — the grass tuft is instead baked into `Tower.tscn` as a shader material on the sprite.
- **No sell confirmation**, no undo, and selling while the panel is open leaves `selected_tower = null` with the panel hidden — correct, but only by luck of ordering.
