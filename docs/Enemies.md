# Enemies

Six enemy types walking a fixed 51-point `Path2D` curve. Implementation: `scripts/Enemy.gd` (527 lines), scene `scenes/Enemy.tscn`.

Enemies are `PathFollow2D` nodes parented to `EnemyPath` at runtime and added to the `enemies` group.

Related: [[Economy#Wave payouts]] for gold and wave composition, [[Towers#Targeting and firing]] for what shoots them, [[Architecture]] for the spawn/signal wiring, [[TODO]] for the fix list.

---

## Enemy types

| Type | HP | Base speed | Effective speed | Gold | Base damage | Notes |
|---|---:|---:|---:|---:|---:|---|
| `slime` | 20 | 60 | **120** | 5 | 1 | Squash-and-stretch pulse, 8 Hz |
| `slime_big` | 60 | 45 | **90** | 15 | 2 | Splits into 3 × `slime_mini` on death |
| `slime_mini` | 15 | 35 | **70** | 1 | 1 | Spawn-only; never in a wave config |
| `goblin_small` | 40 | 90 | **180** | 10 | 1 | 4-direction, 9-frame walk cycle |
| `goblin_fast` | 45 | 120 | **240** | 15 | 1 | Bobbing + rocking wiggle |
| `hobgoblin` | 150 | 60 | **120** | 30 | 3 | Boss unit; wave 13 is 15 of them |
| *fallback* | 30 | 100 | **200** | 10 | 1 | Peasant/knight compatibility branch, unused |

Effective speed is base × `SPEED_MULTIPLIER = 2.0` (`Enemy.gd:16`), a global scale added when the map grew. `ANIM_SPEED_MULTIPLIER = 2.0` does the same for the procedural wiggle clock so its rhythms stay in proportion.

All of this lives in a hand-written `if/elif` chain in `Enemy._ready()` (`Enemy.gd:84-119`), with a **second parallel chain** for sprites and scales (`Enemy.gd:128-154`).

> ⚠️ `scripts/enemy_types.gd` is a `Resource` designed to hold exactly this data. It is orphaned, referenced by nothing, and describes `peasant` and `knight` — units that no longer exist. See [[Architecture#3. Adding one enemy type requires five edits]] and [[TODO#P1 — Structural|TODO #6]].

---

## Splitting

`slime_big` emits `split_requested(global_position, progress_ratio)` from `take_damage` **before** `enemy_defeated`, so both fire in the same frame.

`Main._on_slime_split` (`Main.gd:707`) spawns 3 `slime_mini` at `progress_ratio - 0.005 * i`, clamped to `[0, 0.999]`, and increments `active_enemy_count` by 3. Net effect on the counter that frame: `+3 − 1 = +2`.

A big slime is therefore worth `15 + 3 × 1 = 18` gold and forces 3 extra kills. Minis do not split further. This is why the kill counts in [[Economy#Wave payouts]] exceed the spawn counts.

---

## Movement

```gdscript
var curve_len := get_parent().curve.get_baked_length()
var target    := progress_ratio + delta * speed / curve_len
var limit     := _follow_limit(curve_len)
progress_ratio = min(target, max(progress_ratio, limit))
```

`loop = false` and `rotates = false`. At `progress_ratio >= 1.0` the enemy emits `enemy_reached_end(damage)` and frees itself.

### Follow gap

`_follow_limit()` (`Enemy.gd:316`) caps forward progress so an enemy cannot get closer than `MIN_FOLLOW_GAP = 30` world px to the one ahead — but **only** if that one is within `CROWD_WIDTH * 0.5 = 15` px laterally. Enemies in a different lateral position pass freely.

### Crowd separation

`_update_lane()` (`Enemy.gd:363`) replaced an earlier discrete lane/overtake system. Every neighbour within `CROWD_RANGE = 70` px along the path and `CROWD_WIDTH = 30` px sideways contributes a sideways shove:

```
near    = 1 - along / CROWD_RANGE          # closer along the path = stronger
overlap = (CROWD_WIDTH - |lateral|) / CROWD_WIDTH
push   += -sign(lateral) * near * overlap
```

Then:
```gdscript
lane_offset += push * CROWD_PUSH * delta          # CROWD_PUSH = 90 px/s
lane_offset = lerp(lane_offset, 0.0, delta * CROWD_RETURN)   # CROWD_RETURN = 1.5
lane_offset = clamp(lane_offset, -LANE_MAX, LANE_MAX)        # LANE_MAX = 34
h_offset = perp.x * lane_offset
v_offset = perp.y * lane_offset
```

Two enemies sitting exactly on top of each other (`|lateral| < 0.5`) break the tie by comparing `get_instance_id()` — deterministic every frame, so they can't oscillate.

There are no states to flip between, which is why this design replaced the lane system. At spawn each enemy gets a random `lane_offset` in ±`LANE_SPAWN_SPREAD = 12` px so they don't stack perfectly.

### Depth sorting

```gdscript
z_index = clampi(int(global_position.y) + 2000, 0, 8000)
```

Whoever stands further down the screen draws in front. Towers and decor use the identical formula, so units correctly pass in front of and behind towers. Note this duplicates the root node's `y_sort_enabled = true` — see [[Architecture#4. Two competing depth systems]] and [[TODO#P1 — Structural|TODO #9]].

---

## Animation

### Directional walk cycles

Only `goblin_small` uses real frame animation. `_load_directional_walk()` loads four folders:

```
assets/sprites/Enemy/small_goblin/<dir>_side/small_goblin_<dir>_side_NN.png
    dir ∈ {front, back, left, right},  NN = 01..09
```

- `WALK_FRAME_COUNT = 9`, `WALK_FRAME_DURATION = 0.0576` s → ~17 fps, ~0.52 s per cycle.
- Facing comes from the **path tangent** (`_path_dir`), not from actual movement — so a sideways crowd-separation shove never spins the sprite.
- Four facings only. `_update_facing` compares `|dir.x|` against `|dir.y|`; extending to 8 sectors via `_path_dir.angle()` is noted as a TODO in the code comment.
- Turning preserves `walk_index` modulo the new array size instead of snapping to frame 0.
- Scale is derived from `GOBLIN_SMALL_HEIGHT = 120` px and the frame's own resolution, with `SNAP_PIXEL_SCALE` rounding to whole numbers when upscaling so pixel art stays crisp.

### Procedural wiggle

Types **without** frame animation get a sin-driven wiggle in `_process`, deliberately mutually exclusive so the two systems never fight:

| Type | Effect |
|---|---|
| `slime` | Scale pulse, 8 Hz, ±15 %, volume-preserving (`x * pulse`, `y * (2 - pulse)`) |
| `slime_big` | Same, slower and deeper: 5 Hz, ±20 % |
| `goblin_fast` | `offset.y` bob at 14 Hz + 4.2 Hz secondary; rotation rock at 31.5 Hz, ±0.147 rad |
| `hobgoblin` | Slow heavy rock: rotation 13.5 Hz ±0.064 rad, `offset.y` 3 Hz |

---

## HP bar and shadow

Both are built in code in `_ready()`, no scene nodes involved.

**HP bar** — two `ColorRect`s, 24 × 4 px, positioned at `-sprite_height * 0.5 - 8` above the enemy centre.
- `hp_displayed_ratio` lerps toward the true ratio at `delta * 8.0` for a smooth drain.
- Colour switches on the **target** ratio, not the displayed one, so feedback is immediate: green > 50 %, yellow > 25 %, red below.
- `_update_hp_bar()` is called from `take_damage` but is an empty function — all the work happens in `_process`.

**Shadow** — a `TowerShadow` blob (squashed ellipse, `alpha 0.25`) placed at the enemy's true base. The base is found by scanning `_opaque_bounds()` for the sprite's visible pixels, since the node origin is the sprite *centre*. Width is `opaque_width * 0.3`.

> Note: enemy shadows are added as direct children with `z_index = -1`, **not** to the shared `ShadowLayer` CanvasGroup that decor uses. Overlapping enemy shadows will stack and darken. See [[Architecture#Rendering pipeline]] and [[TODO#P1 — Structural|TODO #14]].

---

## Path

`EnemyPath` is a `Path2D` with a 51-point `Curve2D` running roughly from `(-41, 325)` to `(2038, 898)` — a long S through the map. Enemies spawn at `progress_ratio = 0.0` and the path has no branches, no alternate routes, and no flying lane.

---

## Known issues

All prioritised in [[TODO]]; structural framing in [[Architecture#Structural problems]].

- **`Enemy.gd:204` contains a stray string literal** — `"res://scripts/LevelComplete.gd"` alone in the class body, left by a bad automated edit. Harmless at runtime.
- **Dead lane system.** `_blocker_ahead`, `_follower_behind`, `_lane_taken`, `overtake_side`, `target_lane`, `LANE_WIDTH`, `OVERTAKE_LOOKAHEAD`, `YIELD_LOOKBEHIND` are all leftovers from the design that crowd separation replaced. `_update_lane` also ends with a dangling comment block that reads as if it belongs to the next function.
- **O(n²) per frame.** Each enemy walks every sibling twice (`_follow_limit`, `_update_lane`) and calls `get_baked_length()` three or more times per frame. Fine at 30 enemies, not fine at 200.
- **`get_node("Sprite2D")` every frame** at `Enemy.gd:211`, re-assigning the already-cached `sprite_node`.
- **`_opaque_bounds()` decompresses a texture at every spawn** to place the shadow. Should be cached per texture, the way `TowerVisuals` caches its measurements.
- **Stats and sprites are two parallel if/elif chains** — adding a type means editing both, plus three places in `Main.gd`.
- **`print()` on every spawn and every death**, plus two more prints in `_ready`.
- **Enemy shadows bypass the shared `ShadowLayer`**, so they stack where decor shadows don't.
- **Damage-to-base is a third if/elif chain**, inline in `_process` (`Enemy.gd:258-262`), rather than a per-type stat.
