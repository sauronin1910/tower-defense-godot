# Architecture

How the project is wired together, what each script owns, and where the structure is currently fighting itself.

Start at [[Overview]] for what the game is. Per-system detail lives in [[Towers]], [[Enemies]] and [[Economy]]; everything flagged here as a problem has a prioritised entry in [[TODO]].

---

## Scene graph — `scenes/Main.tscn`

```
CanvasLayer            (Node2D — misnamed; y_sort_enabled = true, script: Main.gd)
├── SpawnTimer         Timer, 0.8 s, repeating
├── NextWaveTimer      Timer, 15 s, one-shot
├── Sprite2D           CloudShadows.gd — scrolling cloud shadow overlay
├── GrassMask          TileMapLayer (empty TileSet, vestigial)
├── ColorRect          cloud_shadows.gdshader (hidden)
├── Grass              ColorRect + grass.gdshader, script: Grass.gd
├── ShadowLayer        CanvasGroup, group "shadow_layer" — shared shadow blending
├── Decor              ~230 Sprite2D children, each with DecorSprite.gd
├── TileMapLayer       terrain tiles + road colliders (physics layer 5)
├── EnemyPath          Path2D, 51-point Curve2D — enemies are children at runtime
├── CanvasLayer        (a real one) — all UI
│   ├── TowerUpgradePanel   instanced scene
│   ├── Control
│   │   ├── StartWaveButton, SpeedButton, BuildButton
│   │   ├── HealthLabel, WaveLabel, GoldLabel
│   │   └── TowerButtonsDock → SpearButton, ArrowButton, ShellsButton
│   ├── GameOverScreen      process_mode = WHEN_PAUSED
│   ├── PauseMenu           process_mode = WHEN_PAUSED
│   └── LevelComplete       instanced scene, process_mode = WHEN_PAUSED
├── Camera2D            zoom 3×, position smoothing on
└── MaskGen             Node + MaskGen.gd  ⚠️ runs a 1.3 M-query bake at launch
```

> The root `Node2D` is **named** `CanvasLayer` and there is also a real `CanvasLayer` child with the same name. This is purely confusing; the root should be renamed `Main`.

Runtime children added to the root: `Tower` instances (via `Main._place_tower_at`), `Projectile` instances (parented to the tower's parent, i.e. the root), and the drag `TowerGhost`.

Runtime children added to `EnemyPath`: `Enemy` instances (`PathFollow2D`).

---

## Scripts

| Script | Lines | Extends | Responsibility |
|---|---:|---|---|
| `Main.gd` | 718 | `Node2D` | Everything: waves, gold, HP, camera, input, placement, UI, pause, game over |
| `Enemy.gd` | 527 | `PathFollow2D` | Enemy stats, pathing, crowd separation, animation, HP bar, shadow |
| `TowerVisuals.gd` | 330 | `RefCounted` | **Static** single source of truth for tower art, scale, footprint, muzzle |
| `Tower.gd` | 282 | `Area2D` | Tower stats, targeting, firing, upgrade levels, click hitbox |
| `TowerUpgradePanel.gd` | 170 | `PanelContainer` | Upgrade/sell UI, builds its own styling and close button in code |
| `MaskGen.gd` | 168 | `Node` | One-shot bake of `grass_mask.png` from road colliders + decor |
| `DecorSprite.gd` | 139 | `Sprite2D` | Depth sort, shadow generation, grass carving flags, build blocking |
| `TowerGhost.gd` | 105 | `Node2D` | Drag preview: tower sprite, range ring, buildable/blocked cell grid |
| `Projectile.gd` | 69 | `Area2D` | Homing projectile, distance-based hit |
| `CloudShadows.gd` | 56 | `Sprite2D` | Scrolling tiled cloud shadow |
| `TowerShadow.gd` | 34 | `Node2D` | `class_name TowerShadow` — draws a squashed ellipse blob shadow |
| `Grass.gd` | 29 | `ColorRect` | Pushes world-placement uniforms into the grass shader |
| `LevelComplete.gd` | 16 | `Control` | Three buttons → three signals |
| `enemy_types.gd` | 13 | `Resource` | **Orphaned** — describes peasant/knight, referenced by nothing |
| `MainMenu.gd` | 8 | `Control` | Play button → change scene |

Only two `class_name` registrations exist: `TowerShadow` and `TowerVisuals`. There are **no autoloads**.

Deep dives: the tower scripts are documented in [[Towers]], `Enemy.gd` in [[Enemies]], and the
gold/wave constants held by `Main.gd` in [[Economy]].

---

## Data flow

### Wave lifecycle

```
_on_start_wave_pressed / _on_next_wave_timer_timeout
        │
        ▼
start_wave(n)                       Main.gd:232
    current_wave_number = n
    total_enemies_to_spawn = sum of the wave's dict values
    spawn_timer.start()
        │
        ▼  every 0.8 s
_on_spawn_timer_timeout             Main.gd:167
    walks a hand-unrolled cumulative counter to pick the next type
        │
        ▼
_spawn_enemy(type)                  Main.gd:194
    instantiate → set enemy_type → EnemyPath.add_child → add to group "enemies"
    connect enemy_defeated / enemy_reached_end / split_requested
        │
        ▼  enemy dies or arrives
_on_enemy_defeated(gold) / _on_enemy_reached_end(damage)
    active_enemy_count -= 1
    if 0 and all spawned ──▶ _advance_to_next_wave()
                                 └─ wave 13 ──▶ _trigger_level_complete()
```

Wave contents, payouts and timing constants: [[Economy#Wave payouts]] and [[Economy#Timing]].
Enemy spawning and splitting behaviour: [[Enemies#Splitting]].

### Combat

```
Tower._process        every frame, rebuilds enemies_in_range by distance
Tower._on_shoot_timer picks the enemy with the highest progress_ratio
Tower.shoot(target)   instantiates Projectile, parents it to get_parent()
Projectile._process   homes on target.global_position
Projectile.hit_target target.take_damage(damage)
Enemy.take_damage     health -= dmg; at ≤0 emits split_requested (big slime)
                      then enemy_defeated(gold_reward), then queue_free()
```

Targeting rules and projectile behaviour: [[Towers#Targeting and firing]].
Enemy stats and HP: [[Enemies#Enemy types]].

### Placement

```
SpearButton.button_down ──▶ Main._start_drag("spear")
    gold check → spawn TowerGhost → follow the mouse in _unhandled_input
        │
        ▼ each motion event
_can_place_tower_at(pos, type)      Main.gd:662
    ├─ gold >= cost
    ├─ not _is_on_enemy_path   shape query, ellipse from TowerVisuals, road layer 5
    ├─ not _is_on_decor        distance test vs group "decor", Y squashed
    └─ not _is_too_close_to_tower   footprint radii vs group "towers"
        │
        ▼ mouse release
_finish_drag ──▶ _place_tower_at ──▶ gold -= cost, instantiate Tower
```

Full validity rules, the footprint ellipse and the ghost preview: [[Towers#Placement]].

### Signals

All gameplay signals terminate in `Main.gd`. Nothing is broadcast globally.

| Emitter | Signal | Handler |
|---|---|---|
| `Enemy` | `enemy_defeated(gold_reward)` | `Main._on_enemy_defeated` |
| `Enemy` | `enemy_reached_end(damage)` | `Main._on_enemy_reached_end` |
| `Enemy` | `split_requested(pos, ratio)` | `Main._on_slime_split` |
| `Tower` | `tower_clicked(tower)` | `Main._on_tower_clicked` |
| `TowerUpgradePanel` | `upgrade_requested` / `sell_requested` / `close_requested` | `Main._on_*` |
| `LevelComplete` | `retry_requested` / `main_menu_requested` / `next_level_requested` | `Main._on_level_complete_*` |

---

## Collision layers

| Layer | Bit | Used by |
|---|---|---|
| 5 | `1 << 4` = 16 | Road tiles from `TileMapLayer` |

`ROAD_COLLISION_MASK` is redeclared in three places — `Main.gd:77`, `TowerGhost.gd:19` (as `ROAD_MASK`), and `MaskGen.gd:15` — each with a comment saying it must match the others. Towers are `Area2D` but their collision shape is only used for click detection; projectiles build a `CircleShape2D` that nothing ever queries.

---

## Rendering pipeline

1. **`TileMapLayer`** draws terrain and roads at `z_index = -1`.
2. **`Grass` ColorRect** covers the whole map area and runs `grass.gdshader`, which samples `grass_mask.png` (white = grass, black = road/decor) to draw grass tufts, streaks, and a frayed edge that displaces by whisker length in world pixels.
3. **`ShadowLayer`** (`CanvasGroup`, `self_modulate.a = 0.3`) receives decor shadows drawn at full opacity; the group's alpha dims them all at once so overlaps don't compound.
4. **Decor sprites** sway via `decor_grass_wind.gdshader`. Their silhouette shadows use a *duplicate* of the same material with `as_shadow = true` so the grass fringe renders black instead of green.
5. **Towers, enemies, decor** all set `z_index = clampi(int(global_position.y) + 2000, 0, 8000)` for depth sorting.
6. **`CloudShadows`** scrolls a tiled dark texture over everything at `z_index = 3`.

### The mask bake

`MaskGen.gd` builds `assets/grass_mask.png`:
- Waits 30 physics frames for `TileMapLayer` colliders to register.
- Walks every sub-tile cell (`SUBDIV = 32`) and runs `intersect_shape` with a 1 px circle against the road layer. A circle rather than a point because per-tile colliders have hairline seams a point query slips through.
- Then stamps the bottom 18 % of every `carves_grass` decor sprite's opaque pixels into the mask, dilated by 2 px.
- Saves as `FORMAT_L8` PNG.

⚠️ For a ~47×27 tile map this is roughly **1 504 × 864 = 1.3 million blocking physics queries** on the main thread at startup, followed by `save_png("res://...")` which is read-only in an exported build. This must become a `@tool` script run on demand.

---

## Structural problems

Each of these has a prioritised, actionable entry in [[TODO]].

### 1. `Main.gd` is a god object

718 lines covering wave management, gold, base HP, camera zoom, camera pan, raw input routing, drag-and-drop placement, tower upgrade/sell, pause, game over, level complete, and slime splitting. There is no separation between game state and presentation, so none of it is testable or reusable for a second level.

Natural seams: `GameState` (autoload — gold, HP, wave), `WaveManager`, `PlacementController`, `CameraController`. See [[TODO#P1 — Structural|TODO #7]], and [[Architecture#The proposed seams cluster cleanly]] for graph evidence that these four are genuinely separable.

### 2. Duplicated sources of truth

| Fact | Lives in | And also in |
|---|---|---|
| Tower cost | `Main.TOWER_COSTS` (`Main.gd:20`) | `Tower._ready()` (`Tower.gd:47-58`) |
| Tower range / art | `TowerVisuals.DATA` | — |
| Tower damage / fire rate | `Tower._ready()` | — |
| Map extents | `Main.gd:562` → `(2000, 1500)` | `Grass.gd:11` and `CloudShadows.gd:26` → `(4512, 2592)` |
| Enemy stats | `Enemy._ready()` if/elif chain | — |
| Enemy sprites | a *second* if/elif chain in the same function | — |
| Road collision mask | `Main.gd:77` | `TowerGhost.gd:19`, `MaskGen.gd:15` |

The tower cost duplication is a live bug risk: `total_gold_invested` (and therefore the sell refund) is computed from `Tower.gd`'s copy, so changing a price in `Main.TOWER_COSTS` alone silently corrupts refunds. Cost tables: [[Towers#Tower types]] and [[Economy#Costs]].

The map-extent split is a live bug: `Main._clamp_camera_position` clamps to `(2000, 1500)` with origin `(0, 0)`, while the real map is `(4512, 2592)` at origin `(-1248, -384)`. There is in fact a third hardcoded copy — see [[Architecture#Coupling that is not duplication]].

### 3. Adding one enemy type requires five edits

`WAVE_CONFIG` dict keys → the hand-unrolled cumulative chain in `_on_spawn_timer_timeout` → the sum in `start_wave` → the stats chain in `Enemy._ready` → the sprite chain in `Enemy._ready`. Meanwhile `scripts/enemy_types.gd` — an actual `Resource` built for exactly this — is orphaned and describes units that no longer exist. Detail in [[Enemies#Enemy types]]; fix in [[TODO#P1 — Structural|TODO #6]].

### 4. Two competing depth systems

The root has `y_sort_enabled = true`, yet every entity also manually writes `z_index` from its Y position. One is redundant, and the manual formula silently saturates above `y = 6000`.

### 5. Performance hot spots

| Where | Cost |
|---|---|
| `Tower._process:141` | Rebuilds `get_nodes_in_group("enemies")` and distance-tests all of them, per tower, per frame |
| `Enemy._process` | Walks all siblings **twice** per frame (`_follow_limit` + `_update_lane`) |
| `Enemy._process` | Calls `get_parent().curve.get_baked_length()` 3+ times per frame |
| `Enemy._process:211`, `Tower.gd:157` | `get_node("Sprite2D")` string lookup every frame |
| `TowerGhost._draw` | ~289 physics point queries per frame while dragging |
| `MaskGen._generate` | ~1.3 M physics queries once at startup |

`Tower` is already an `Area2D` — range detection should use `area_entered`/`body_entered` rather than a manual scan. Per-hot-spot fixes are tabulated in [[TODO#P1 — Structural|TODO #8]]; the enemy-side costs are detailed in [[Enemies#Known issues]] and the ghost grid in [[Towers#The ghost preview]].

### 6. Fragile input routing

`Main._is_ui_hit()` (`Main.gd:360`) hand-enumerates every button's rect to decide whether a click landed on UI. Add a button and forget to update it, and clicks fall through to the map. Godot's `mouse_filter` and `_gui_input` already solve this.

Drag-and-drop has no pointer capture: releasing the mouse outside the window can strand the ghost.

### 7. Dead code

The lane/overtake system was superseded by crowd separation but left in place: `_blocker_ahead`, `_follower_behind`, `_lane_taken`, `overtake_side`, `target_lane`, `LANE_WIDTH`, `OVERTAKE_LOOKAHEAD`, `YIELD_LOOKBEHIND`.

Also: `Enemy._update_hp_bar()` is an empty function still called from `take_damage`; `Tower.set_footprint_visible()` is a no-op that `Main` still loops over all towers to call; `TowerVisuals.make_grass_tuft` and `make_shadow` are unused; `scenes/main.gd` is an empty stub; `Projectile`'s `CollisionShape2D` is never queried; `Enemy.gd:204` contains a stray orphaned string literal `"res://scripts/LevelComplete.gd"` left by a bad edit.

Full inventory: [[Enemies#Known issues]], [[Towers#Known issues]], [[TODO#P1 — Structural|TODO #11]].

### 8. Repository hygiene

Committed to git: 17 `scenes/Main.tscn*.tmp` files, `scenes/Enemy.tscn.backup`, `fix_line59.py`, `scripts/verify_temp.py`, `scripts/Main.gd.patch`, `scripts/tree_001.png` (an image in the scripts folder), and duplicate shaders in both `scenes/` and `shaders/`.

`.gitignore` excludes `*.import`. In Godot those **should** be tracked, or asset imports won't reproduce on another machine.

`scenes/Main.tscn` at 3 329 lines with ~230 hand-placed decor sprites is effectively unmergeable.

Cleanup list: [[TODO#P0 — Blocking|TODO #4]].

### 9. Version drift

`AGENTS.md` says Godot 4.3. `project.godot` declares `config/features = ("4.7", "Mobile")`. See [[TODO#P0 — Blocking|TODO #5]] and the engine row in [[Overview]].

---

## Dependency graph

Findings from a graph built over the 16 `.gd` scripts, 7 `.tscn` scenes, and the docs
(348 nodes, 511 edges, 18 communities — `graphify-out/graph.html`). This section records
only what the graph surfaced *beyond* the sections above; everything here was re-verified
against source before being written down.

> Provenance: graphify has no GDScript AST parser, so every edge came from LLM extraction
> rather than deterministic parsing. Treat the clustering as evidence, not proof.

### All signal wiring lives in code

There are **zero `[connection]` blocks in any `.tscn` file** in the project. Every entry in
the signal table above — plus all button and timer wiring — is connected imperatively at
runtime, almost entirely from `Main.gd._ready`.

Consequence: the scene files carry no record of what talks to what. Opening `Main.tscn` in
the editor tells you nothing about behaviour, and a renamed handler fails at runtime rather
than in the editor. This is the main reason `Main.gd` shows up as the bridge between six
otherwise-unrelated clusters.

### TowerVisuals is the one real seam

Four scripts call its static API, 21 call sites total:

| Caller | Calls | Uses |
|---|---:|---|
| `Tower.gd` | 9 | `load_frames`, `scale_for`, `base_offset`, `attack_range`, `muzzle_offset`, `make_cast_shadow` |
| `Main.gd` | 6 | `base_query_shape`, `base_extents`, `footprint_radius`, `projectile_path` |
| `TowerGhost.gd` | 5 | `load_frames`, `scale_for`, `attack_range`, `opaque_local_rect` |
| `TowerUpgradePanel.gd` | 1 | `opaque_local_rect` (panel positioning) |

(`TowerShadow.gd` mentions `TowerVisuals.make_shadow` in a comment only — not a call.)

This fan-in is why the drag ghost cannot drift out of sync with the placed tower, and it is
the pattern the `Main.gd` breakup should copy: a `RefCounted` holding static data plus pure
query functions, with no node-tree dependency. Function-by-function breakdown under
"Visual pipeline" in [[Towers]].

### Coupling that is not duplication

Distinct from the duplicated-sources table — these are separate facts that must *agree*:

| Constraint | Participants |
|---|---|
| Map origin `(-1248, -384)` / size `(4512, 2592)` | `Grass.gd:10-11`, `CloudShadows.gd:16-17`, **and `Main.tscn:47-48`** as shader params |
| Tower type string keys | `Main.TOWER_COSTS` ↔ `TowerVisuals.DATA` |
| Road layer bit | `Main.gd:77` ↔ `MaskGen.gd:15` ↔ `TowerGhost.gd:19` |
| Baked mask geometry | `MaskGen.OUTPUT_PATH` → `grass.gdshader` sampling in `Grass.gd` |
| Path curve | `Main/EnemyPath` `Curve2D` ↔ `Enemy` as `PathFollow2D` child |

⚠️ The map-extent problem is worse than section 2 records: there are **three** hardcoded
copies, not two. `Grass.gd` and `CloudShadows.gd` both declare them as `@export`, and
`Main.tscn` hardcodes a third copy in the `Grass` node's `shader_parameter/`. Meanwhile
`MaskGen` does *not* hardcode them — it derives the mask size from the tilemap's used rect
(`used.size * SUBDIV`). So the bake is authoritative and the three consumers are guesses
that happen to match today.

### The proposed seams cluster cleanly

Community detection put `GameState`, `WaveManager`, `PlacementController`, and
`CameraController` together in one cluster with cohesion **0.24** — the highest of any
non-trivial community in the graph (the rest sit between 0.08 and 0.16). Low cohesion
elsewhere reflects `Main.gd` threading through everything; the fact that the four seams
score high *as a group* is independent evidence they are genuinely separable rather than
aspirational.

Extraction order suggested by the edges: `GameState` first — the `gold` / `base_health` /
`WAVE_CONFIG` shared-state edges converge on it, so extracting it first shrinks the surface
the other three have to reach through. This refines the ordering in
[[TODO#Suggested order]].
