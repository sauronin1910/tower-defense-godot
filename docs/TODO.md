# TODO

Prioritised work list derived from the codebase analysis. P0 items block shipping or correctness; P1 items are structural debt that gets more expensive the longer it sits; P2 is polish and content.

Background for these items: [[Architecture#Structural problems]], [[Towers#Known issues]], [[Enemies#Known issues]], [[Economy#Balance summary]]. Start at [[Overview]].

---

## P0 — Blocking

### 1. Take `MaskGen` out of the runtime scene
`scenes/Main.tscn:3328` still instantiates `MaskGen.gd`, which runs at every launch.

- For a ~47×27 tile map at `SUBDIV = 32` that is roughly **1 504 × 864 ≈ 1.3 million blocking `intersect_shape` calls** on the main thread (`MaskGen.gd:98-110`).
- It then calls `img.save_png("res://assets/grass_mask.png")` — `res://` is **read-only in an exported build**, so this fails outside the editor.

**Fix:** convert to an `@tool` script or editor plugin, run on demand, and remove the node from `Main.tscn`. The already-baked `assets/grass_mask.png` is what the game should ship with. Bake details: [[Architecture#The mask bake]].

### 2. Fix the camera clamp
`Main._clamp_camera_position:562` hard-codes `map_size = Vector2(2000, 1500)` with an implicit origin of `(0, 0)`. The real map is `(4512, 2592)` at origin `(-1248, -384)` per `Grass.gd:11` and `CloudShadows.gd:26`.

**Fix:** one shared constant (or an exported property on the root) consumed by all three, and make the clamp origin-aware.

> There is a **third** hardcoded copy in `Main.tscn` as a `shader_parameter` on the `Grass` node — see [[Architecture#Coupling that is not duplication]]. `MaskGen` derives its extents from the tilemap, so the bake is authoritative.

### 3. Remove debug values from the shipped path
- `gold = 3000` — set twice, at `Main.gd:35` and `Main.gd:111`.
- `DEBUG_MODE` at `Main.gd:34` is declared but never read.
- The `4.0` entry in `SPEED_LEVELS`.
- `print()` on every enemy spawn and death (`Enemy.gd:77, 124, 263, 285`).

**Fix:** gate all of it behind `DEBUG_MODE`, set real starting gold (see [[Economy#Suggested first pass]]), and drop the prints or move them behind a verbosity flag.

### 4. Repository cleanup
Currently tracked in git and should not be:

```
scenes/Main.tscn*.tmp        (17 files)
scenes/Enemy.tscn.backup
fix_line59.py
scripts/verify_temp.py
scripts/Main.gd.patch
scripts/tree_001.png         (an image inside the scripts folder)
scenes/Tower.gdshader        (duplicate of shaders/)
scenes/tower_streaks.gdshader (duplicate of shaders/)
scenes/main.gd               (empty stub script)
```

Also: `.gitignore` excludes `*.import`. In Godot those **must** be tracked, or asset imports won't reproduce on another machine.

### 5. Reconcile the engine version
`AGENTS.md` says Godot 4.3; `project.godot` declares `config/features = ("4.7", "Mobile")`. Pick one and update the other.

---

## P1 — Structural

### 6. Make tower and enemy data resource-driven
Adding one enemy type currently requires **five** edits: `WAVE_CONFIG` keys, the hand-unrolled cumulative chain in `_on_spawn_timer_timeout` (`Main.gd:172-191`), the sum in `start_wave`, the stats chain in `Enemy._ready`, and the sprite chain in `Enemy._ready`.

**Fix:** one `.tres` per enemy type and per tower type. `scripts/enemy_types.gd` is already a `Resource` built for this — it is orphaned and describes units (peasant, knight) that no longer exist. Either revive it properly or delete it. Current stat tables: [[Enemies#Enemy types]], [[Towers#Tower types]].

While doing this, collapse the duplicated sources of truth:

| Fact | Currently in | Should be in |
|---|---|---|
| Tower cost | `Main.TOWER_COSTS` **and** `Tower._ready()` | one resource |
| Tower damage / fire rate | `Tower._ready()` | same resource as range/art |
| Tower range / art / muzzle | `TowerVisuals.DATA` | same resource |
| Enemy base damage | inline if/elif in `Enemy._process:258` | enemy resource |
| Road collision mask | `Main.gd:77`, `TowerGhost.gd:19`, `MaskGen.gd:15` | one constant |

> The tower-cost duplication is a live bug risk: `total_gold_invested` — and therefore the sell refund — is seeded from `Tower.gd`'s copy, not `Main`'s.

### 7. Break up `Main.gd`
718 lines covering waves, gold, HP, camera zoom, camera pan, input routing, drag-and-drop placement, upgrade/sell, pause, game over, level complete, and slime splitting.

Suggested seams:
- `GameState` (autoload) — gold, base HP, current wave
- `WaveManager` — `WAVE_CONFIG`, spawn queue, wave advance
- `PlacementController` — drag, ghost, validity rules
- `CameraController` — zoom, pan, clamp

Graph clustering supports this split and argues for extracting `GameState` first — see [[Architecture#The proposed seams cluster cleanly]]. Copy the `TowerVisuals` pattern: [[Architecture#TowerVisuals is the one real seam]].

### 8. Fix the per-frame hot spots

| Where | Problem | Fix |
|---|---|---|
| `Tower._process:141` | Rebuilds `get_nodes_in_group("enemies")` and distance-tests all, per tower, per frame | `Tower` is already an `Area2D` — use `area_entered`/`area_exited` |
| `Enemy._process` | Walks all siblings twice (`_follow_limit` + `_update_lane`) | Single pass collecting both results |
| `Enemy._process` | `get_baked_length()` 3+ times per frame | Cache once per frame, or once per level |
| `Enemy._process:211` | `get_node("Sprite2D")` every frame despite `sprite_node` being cached | Delete the re-assignment |
| `Tower.gd:157` | Same string lookup in the animation tick | Cache the node reference |
| `TowerGhost._draw` | ~289 physics point queries per frame while dragging | Sample the baked `grass_mask.png` instead, or cache per grid position |
| `Enemy._ready` | `_opaque_bounds()` decompresses a texture per spawn | Cache per texture, like `TowerVisuals` does |

### 9. Pick one depth-sorting system
The root has `y_sort_enabled = true`, yet `Enemy`, `Tower` and `DecorSprite` all also write `z_index = clampi(int(global_position.y) + 2000, 0, 8000)`. One is redundant, and the manual formula saturates above `y = 6000`. See [[Architecture#4. Two competing depth systems]] and [[Enemies#Depth sorting]].

### 10. Replace `_is_ui_hit` with real UI hit-testing
`Main._is_ui_hit:360` hand-enumerates each button's rect. Add a button and forget this function, and clicks fall through to the map. Godot's `mouse_filter` and `_gui_input` already solve this.

Related: drag-and-drop has no pointer capture, so releasing outside the window can strand the ghost.

### 11. Delete dead code

**Enemy lane system** (superseded by [[Enemies#Crowd separation]]): `_blocker_ahead`, `_follower_behind`, `_lane_taken`, `overtake_side`, `target_lane`, `LANE_WIDTH`, `OVERTAKE_LOOKAHEAD`, `YIELD_LOOKBEHIND`. Also the dangling comment block at `Enemy.gd:396-398` that reads as if it belongs to the next function.

**Other:**
- `Enemy.gd:204` — a stray orphaned string literal `"res://scripts/LevelComplete.gd"` left by a bad edit.
- `Enemy._update_hp_bar()` — empty function still called from `take_damage`.
- `Tower.set_footprint_visible()` — no-op that `Main._set_all_footprints_visible` still loops over all towers to call.
- `TowerVisuals.make_grass_tuft` and `make_shadow` — unused.
- `Projectile`'s `CollisionShape2D` — built in `_ready`, never queried (hits are distance-based).
- `scenes/main.gd` — empty stub.
- `GrassMask` TileMapLayer in `Main.tscn` — empty TileSet, appears vestigial.

### 12. Make `Main.tscn` maintainable
3 329 lines, 242 nodes, ~230 of them hand-placed decor sprites. This is effectively unmergeable.

**Fix:** move decor placement to data (a `.tres` or JSON list of position/texture/flags) plus a spawner node, or a scatter tool. Also rename the root node — it is a `Node2D` **named** `CanvasLayer`, and there is a real `CanvasLayer` child with the same name.

### 13. Stop using `Engine.time_scale` for game speed
`Main._on_speed_button_pressed:530` sets a global multiplier that also affects UI tweens and the build-pop animation, and degrades the `delta`-driven crowd separation at 4×. A per-system speed multiplier would be cleaner.

### 14. Route enemy shadows through `ShadowLayer`
Decor shadows go into the shared `CanvasGroup` so overlaps blend rather than compound. Enemy shadows (`Enemy.gd:177-186`) are added as direct children instead, so a cluster of enemies produces stacked dark blobs.

---

## P2 — Content and polish

### 15. Economy rebalance
Detailed in [[Economy#Balance summary]], with a concrete plan in [[Economy#Suggested first pass]]. Headline items:
- Total gold across all 13 waves is **3 120**, roughly equal to the current starting gold.
- Upgrades are strictly worse value than building a second tower at every tier.
- Upgrade cost is flat, so L2→L3 beats L1→L2 — the inverse of the usual curve.
- Spear has the best DPS/gold at every level; arrow and shells have no compensating role.
- 20 base HP against a wave-13 potential of 45 damage makes leaks binary rather than attritional.

### 16. Give towers distinct roles
Three towers currently sit on the same DPS-per-gold line with different constants — see [[Economy#Value analysis]]. Splash for shells, slow or pierce for arrow, and the choice becomes interesting.

### 17. Fix stale comments and strings
- `Main.gd:2` — *"7 defined waves, then endless uses last entry"*. There are 13 waves and no endless mode.
- `Main.gd:420` — `"Base HP: %d/20"` hard-codes 20 in the format string as well as the variable.
- `Main.gd:96-98` — references `build_background()` and `build_curve()`, removed long ago.

### 18. Missing features
- No audio at all.
- No save/load, no persistence between sessions.
- No settings menu (volume, resolution, speed default).
- `_on_level_complete_next()` is an empty placeholder — there is no second level.
- No endless mode, despite `_get_wave_config` already clamping for it.
- Enemy directional walk is 4-facing only; `Enemy._update_facing:486` notes extending to 8 sectors once diagonal frames exist.

### 19. Testing
There are no tests of any kind. Once P1 #6 and #7 land, the extracted `WaveManager` and economy calculations are the obvious first candidates — they are pure logic with no scene dependencies.

---

## Suggested order

1. **P0 #1** (MaskGen) — largest single win, unblocks exported builds.
2. **P0 #2** (camera clamp) — small fix, currently visibly wrong.
3. **P0 #4, #5** (repo cleanup, version) — cheap, stops the mess growing.
4. **P1 #8** (hot spots) — mostly mechanical, immediate frame-time win.
5. **P1 #11** (dead code) — makes everything after this easier to read.
6. **P1 #6** (resource-driven data) — unlocks fast content iteration.
7. **P1 #7** (split `Main.gd`) — do it after #6, when the data it juggles is already extracted.
8. **P0 #3 + P2 #15** (debug values, then rebalance) — balance is meaningless until the debug gold is gone.
