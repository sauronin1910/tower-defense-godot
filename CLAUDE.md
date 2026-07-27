# CLAUDE.md

Guidance for AI agents working in this repository. Read this before making changes.

`AGENTS.md` exists for other tooling — treat **this** file as the single source of
truth and keep `AGENTS.md` as a short pointer to it, so the two can't drift apart.

---

## Project

A medieval-fantasy Tower Defense game. Solo project, treated as a **portfolio
piece**, not a toy — code quality and consistency matter.

| | |
|---|---|
| Engine | Godot 4.7 stable, Forward Mobile renderer |
| Language | GDScript |
| Repo | `github.com/sauronin1910/tower-defense-godot` |
| Local path | `D:\Projects\TowerDefense` |
| Branch | `main` — single branch, single worktree |
| Viewport | 1280x720 landscape; map area 2000x1500; `ZOOM_MIN` 0.64 fits the whole map |
| Tile size | 96x96 |
| Art pipeline | Pixel art generated locally in PixelLab.ai (previously ComfyUI) |

Everything is built locally — local agent, locally generated assets. Keep it that way.

---

## Working rules

These are not suggestions. Violating them has cost real rework.

**Make surgical edits.** Find-and-replace on specific blocks, never a full-file
rewrite. If a rewrite genuinely seems necessary, say so and wait for a decision.

**Multi-line edits go through Python**, with tabs written as `\t`. GDScript is
indentation-sensitive and mixes badly with space-indented insertions.

**Never delete an existing function** to make room for a new one.

**Save UTF-8 without BOM.** Verify line counts before and after an edit.

**Give precise anchors.** When telling the user where to paste code, quote a
**unique block** to search for — not a variable name that appears six times. This
has caused broken files more than once.

**Commit after every working feature.** Frequent commits are the rollback net.
`git checkout -- <file>` is the standard recovery move here.

---

## Layout

```
data/
  enemies/*.tres            one EnemyType per enemy — the whole type table
  towers/*.tres             one TowerType per tower
  decor/kinds/*.tres        one DecorKind per prop (texture, shadow, carving)
  decor/materials/*.tres    the two shared decor materials (wind / grass fringe)
  decor/placements.json     where every copy stands — 168 rows, one per line
assets/
  grass_mask.png            generated — do not hand-edit
  terrain/                  tileset sources (road SVG, grass PNG)
  sprites/
    Towers/spear_tower/     Spear_Tower_1..5.png (flag idle), Projectile_Spear.png
    Enemy/                  static enemy PNGs
    Enemy/small_goblin/     <dir>_side/small_goblin_<dir>_side_01..09.png
  decor/                    prop art (trees, rocks, crystals)
scenes/                     Main.tscn, Tower.tscn, Projectile.tscn, UI scenes
scripts/                    all GDScript
shaders/                    .gdshader files + gradient.png, noise.png, clouds.png
```

---

## Architecture

### Core scripts

**`Main.gd`** — game loop: waves, gold, placement, camera, speed control.
`WAVE_CONFIG` holds 14 waves; endless mode repeats the last entry. Rows are
**sparse** `{enemy_id: count}` — list only what a wave contains.

`start_wave()` expands the row into `spawn_queue`, a flat list of ids, and
`_on_spawn_timer_timeout` just pops from it. `total_enemies_to_spawn` is the
queue's size, so the count can't drift from what actually spawns.

Placement goes through `_can_place_tower_at(pos, type)`, which chains:
gold check → `_is_on_enemy_path` (road collision) → `_is_on_decor` → `_is_too_close_to_tower`.
The drag ghost reuses the same function, so validity feedback stays in sync
automatically.

**`TowerVisuals.gd`** (`RefCounted`, all static) — **single source of truth** for
tower definitions: art, range *and* combat stats. `Tower.gd`, `TowerGhost.gd`
and `Main.gd` all read from here; that's the whole point, so don't reintroduce
per-script duplicates.

Cost, damage and fire rate used to live in `Tower._ready()`, with a second copy
of the prices in `Main.TOWER_COSTS`. `total_gold_invested` — and so the sell
refund — is seeded from the tower's own copy, so a price changed in only one
place silently paid the wrong refund. Both copies are gone.

Owns: per-type `DATA` (sprite paths, frame counts, range, projectile, muzzle,
cost, damage, fire_rate),
`scale_for()`, `base_offset()` (measures opaque pixels so transparent padding is
ignored), `footprint_radius()`, `opaque_local_rect()` (snug click hitbox),
`base_extents()` / `base_query_shape()` (placement ellipse from the sprite's
bottom slice), and the factory `make_cast_shadow()`.

Towers render 240px tall with the sprite's **base** on the placement point.

**`enemy_types.gd`** (`class_name EnemyTypes`, `RefCounted`, all static) — the
registry: scans `data/enemies/` and keys every `EnemyType` by its `id`.
`TowerVisuals` does the same for `data/towers/`; both go through
`ResourceRegistry.load_dir()`.

Adding an enemy is **one step — drop a `.tres` in `data/enemies/`.** It used to
be five: two `if/elif` chains in `Enemy.gd`, a key in every row of
`WAVE_CONFIG`, a branch in the unrolled cumulative chain in
`_on_spawn_timer_timeout`, and the hand-written sum in `start_wave`. Don't let
any of them grow back.

**`Enemy.gd`** (`PathFollow2D`) — HP bar, movement, animation. All per-type
numbers come from `EnemyTypes.entry()`, which never returns null: an unknown id
warns and yields a visible placeholder.

Two animation styles coexist: **procedural** wiggle (sin-based bob/pulse) for
static-sprite types, and **frame-based** directional walk for `goblin_small`.
A type must use one or the other — running both makes them fight. The data
enforces this by shape: `walk_path` selects frames, `texture` selects a static
sprite, and frame-animated types carry an empty `wiggle`.

**`Tower.gd`** (`Area2D`) — per-tower stats, upgrade levels, shooting, build-pop.
`shoot_timer` is stored as a member so `_apply_level_stats()` can refresh
`wait_time`; otherwise fire-rate upgrades silently do nothing.

**`DecorSprite.gd`** (`class_name DecorSprite`, `Sprite2D`) — one prop. Handles
depth sorting, shadow creation, and build blocking. Not placed by hand any
more: `DecorSpawner` builds these from data and configures them via
`DecorKind.apply_to()`.

**`DecorSpawner.gd`** (`@tool`, `Node2D`) — the `Decor` node in Main.tscn.
Reads `data/decor/placements.json`, looks each row's `kind` up in `DecorKinds`,
and instantiates a `DecorSprite` per row.

Main.tscn used to hold all 204 props as nodes: 3326 lines, 241 nodes, and about
2000 of those lines were the same nine properties that Ctrl+D had copied along
with the position. It is now 610 lines and 37 nodes.

Editor placement survives because the script is `@tool`: it spawns the props at
edit time so they can still be dragged by eye, but adds them **without an
owner**, which is what stops Godot serialising them back into the scene. A
`bake_now` checkbox writes the current children back to the JSON. **Moves exist
only in the tree until baked** — `reload_now`, reopening the scene or a script
reload all rebuild from the file and discard unbaked drags.

**`MaskGen.gd`** — one-shot tool, not runtime code. See workflow below.

### Depth sorting

`Enemy.gd`, `Tower.gd` and `DecorSprite.gd` each set
`z_index = clampi(int(global_position.y) + 2000, 0, 8000)` so whoever stands
lower on screen draws in front.

The `+2000` offset is **required**: the map starts at `y = -384`, and negative
z-index would sink nodes below `ShadowLayer`.

Child `z_index` is **relative** to the parent. That's why HP bars use 1/2 rather
than 10/11 — a bar at +10 would render over a neighbour standing slightly lower.

Anchor mismatch to be aware of: enemies sort by sprite centre, towers by their
base. `DecorSprite` bridges this with an exported `ground_anchor`.

### Shadows

| Object | Style | Built by |
|---|---|---|
| Towers | skewed silhouette, frame-synced to the flag | `TowerVisuals.make_cast_shadow` |
| Enemies | blob ellipse under the feet | `TowerShadow.gd` |
| Decor rocks | blob | `DecorSprite.gd` |
| Decor trees | silhouette, sways with the wind material | `DecorSprite.gd` |
| Clouds | drifting tiled PNG over the whole map | `CloudShadows.gd` |

Light is assumed **upper-left**, so shadows fall lower-right. Keep every new
shadow consistent with that or the scene reads as having two suns.

Overlapping translucent shadows compound into dark blotches. Fix: the
`ShadowLayer` **CanvasGroup** (in group `shadow_layer`) — children are drawn
**opaque** and the group's `Self Modulate` alpha (~0.3) dims them once. That
alpha is the single global knob for shadow darkness.

Decor shadows already live there. Tower and enemy shadows do **not** yet and
still stack with each other — that's the remaining piece. Enemies move, so their
shadow position would need per-frame updates.

---

## Shaders

**`grass.gdshader`** — on a `ColorRect` over the map. Diagonal light streaks with
a 2-tone profile, plus the living road edge. Reads `road_mask`, `gradient.png`
(3-tone palette) and `noise.png`.

Key uniform split, learned the hard way: `band_scale` is **spacing only**, while
`light_width` / `shadow_width` are thickness in **absolute world pixels**.
Changing spacing must not change thickness.

`edge_length` (world px) controls the fuzzy whiskers by displacing **where the
mask is sampled**. The older `edge_jitter` nudged the threshold instead and is
now dead — it silently shortened the whiskers whenever the mask got crisper.

`edge_band_width` is in 0..1 mask units; sane range is 0.02-0.06. Above ~0.1 the
rim swallows the entire light streak.

**`tower_base_grass.gdshader`** — overlay on the tower `Sprite2D`. Grass blades
along the bottom band of opaque pixels, pointing up and curving sideways.
Composes fine with build-pop (scale) and level tint (modulate).

**`decor_grass_wind.gdshader`** — **one** shader for all decor, because a
`CanvasItem` has a single material slot and trees need wind *and* the grass
fringe simultaneously. `wind_strength = 0` for rocks, `> 0` for trees.

Cast shadows use a **duplicate** of the material with `as_shadow = true`. The
shader writes `COLOR` directly, and Godot then drops the node's `modulate` — so
without the flag a tree's shadow renders its grass fringe bright green.

**`cloud_shadows.gdshader`** — legacy; the sprite-based `CloudShadows.gd` is what
ships.

---

## Workflows

### Regenerating the grass mask

`assets/grass_mask.png` encodes where grass may grow. It bakes in both the road
collision outline **and** the decor silhouettes.

Re-run it whenever road collision polygons change, or decor is moved, added,
rescaled, or its `carves_grass` flag flipped. Stale mask = a rim hanging where an
object no longer is.

1. Open `scenes/MaskGenTool.tscn` and play **that scene** (F6). It instances
   Main and puts the `MaskGen` node beside it, so Main.tscn itself stays clean
2. Watch Output for `road_pixels=` and `carved N decor pixels` — both must be non-zero
3. Close the game, **restart Godot** (or Reimport the PNG) so the new file is picked up

**Never add `MaskGen` to Main.tscn.** It ran there once and cost ~1.3M blocking
physics queries on every launch, plus a `save_png` to `res://` that can only fail
in an exported build. `MaskGen.gd` now refuses to run unless
`OS.has_feature("editor")`, and it must never be the project's main scene.

**The script must be its own child node, never attached to a scene root.** Doing
that overwrites the root's script and the scene comes up blank.

Tuning knobs, all global: `SUBDIV` (mask resolution — cost grows fast, 38 is
~1.8M physics queries and a visible freeze), `PROBE_RADIUS` (keep ≥ 1.0; below
that the probe slips through micro-seams between per-tile colliders and punches
holes in the mask), `CARVE_SLICE_RATIO` (~0.18, how much of a sprite's bottom
counts as ground contact), `CARVE_DILATE`.

Colliders are **not** registered on physics frame 1 — the script waits ~30 frames
before sampling, otherwise `road_pixels` comes back 0.

### Adding an enemy or tower type

Copy an existing `.tres` in `data/enemies/` or `data/towers/`, rename it, and
edit it in the inspector. Set `id` to match the filename — the registry keys on
`id`, and a duplicate or empty one is skipped with an error in Output.

For an enemy: either `texture_path` + `scale` (static sprite, optional
`wiggle`), **or** `walk_path` + `walk_prefix` + `walk_height` (directional
frames, no `wiggle`) — never both. Then add the id to a `WAVE_CONFIG` row.

For a tower it's the `.tres` plus a dock button wired in `Main._ready()`, since
the three buttons are still placed by hand in `Main.tscn`.

**Registries are cached statically.** Like the `TowerVisuals` measurement
caches, they load once and survive a scene restart — restart Godot after
editing a `.tres` if the change doesn't show up.

### Placing decor

Select the `Decor` node in Main.tscn and tick **`edit_mode`**. Drag the props
around, then tick **`bake_now`**, which saves and drops back out of edit mode.

`edit_mode` exists because of Godot's selection rule: the 2D editor won't let
you click a node whose `owner` isn't the edited scene — and giving it an owner
is exactly what makes the scene file swallow it again. So the spawner spawns
props unowned normally (visible, not clickable, scene stays 610 lines) and owned
while editing (draggable, and the scene would take all 168 if you saved it
then). Bake strips ownership again.

`bake_now` is the save button — nothing else persists a move, Ctrl+S does not.
`reload_now` throws the current children away and rebuilds from the file, which
is how you undo a bad drag.

Vary rotation, scale and `Flip H` so copies don't read as clones; `bake` only
writes those fields when they differ from the kind, so a plain copy stays a
two-field row.

To add a **new prop type**, drop a `.tres` in `data/decor/kinds/` — that is the
whole procedure, same as enemies. `id` must match the filename. Then place
copies of it and bake.

To add **more copies** of an existing prop, turn on `edit_mode`, duplicate a
spawned node in the viewport, and bake. A hand-added `Sprite2D` works too: bake matches it to a kind
by texture path if it has no `decor_kind` metadata.

Per-prop settings live on the `DecorKind`, not the node: `ground_anchor`,
`shadow_mode`, the shadow tuning values, `blocks_building` + `block_radius`,
`carves_grass`. Editing one changes every copy at once — which is the point, and
also why the registry cache matters (below).

Shadows are built in `DecorSprite._ready()`, so they're invisible in the editor —
judge them only in a running scene. `block_center` is likewise computed once at
startup.

`DecorKinds` caches like the other registries, so `reload_now` clears it before
respawning. After hand-editing a `.tres`, tick `reload_now` rather than hunting
for a stale value.

Decor carving is by **silhouette**, not radius. A per-object radius was tried and
rejected: shapes differ too much (round canopies vs narrow trunks vs wide boulder
bases) for one number to fit.

### Generating sprites

PixelLab.ai, camera preset **low top-down** on every generation — that matches
the existing art, where tower facades and enemy fronts are visible rather than
roofs and heads. Never mix in sidescroller or high top-down.

Prompts: short and plain English. Long detailed prompts produce worse results.
`goblin warrior, green skin, leather armor, front view` is the right shape.

Keep **one source resolution** across enemies and **one scale multiplier** across
decor, with `Filter = Nearest`. Mixed multipliers make some objects look more
detailed than others and the set falls apart. Prefer whole-number scales.

Trees need transparent margins at the sides — wind shifts the canopy sideways and
it gets clipped at the texture edge otherwise.

---

## Pitfalls

Every item here cost real debugging time.

**`return` is illegal in `fragment()`.** Use a flag plus `else` branches.

**`MODULATE` doesn't exist** in this version's canvas shaders, and a shader that
writes `COLOR` directly loses the node's modulate. Pass what you need as a
uniform.

**Enemy facing must come from the path tangent** (`_update_path_dir`), not from
raw movement. Crowd separation moves units sideways, and reading raw movement
spins the sprite mid-manoeuvre.

**Crowd separation must stay stateless.** Discrete lanes were tried twice and both
versions oscillated: stepping aside removed the condition that caused it, so the
unit snapped back and re-triggered every frame. The current version is a
continuous lateral force with ties broken by `get_instance_id()` comparison, so a
pair picks the same opposite directions every frame.

**A `ColorRect` eats all mouse input** unless `Mouse Filter = Ignore`. Full-map
overlays silently break tower placement otherwise.

**Cached measurements survive constant changes.** `TowerVisuals` caches offsets,
footprints and extents in static dictionaries. Restart the scene after changing
those constants or you'll be looking at stale values.

**4x speed distorts everything.** It works via `Engine.time_scale`, so `delta`
quadruples. Don't judge balance or crowd smoothness at 4x, and expect projectile
hit checks to tunnel.

**Autotiling means tile granularity lies.** Edge tiles are part road, part grass,
so `source_id` checks and boolean custom-data layers are both too coarse for
placement. Per-tile collision polygons on collision **layer 5** (value 16) are
what actually works.

---

## Debug flags — revert before release

In `Main.gd`:

- `DEBUG_MODE = true` gates starting gold at **3000** instead of 100. Set at both
  game start and the post-Game-Over reset; miss one and it falls back mid-run.
- `SPEED_LEVELS` includes a `4.0` entry, so the speed button cycles 1x/1.5x/2x/4x.

Both are marked with reminder comments in the code.

---

## Pending work

Content first, mechanics second. That order is deliberate.

- **Arrow and shells towers** still use single static sprites and `muzzle 0.75`
- **Remaining enemies** still on static sprites + procedural wiggle; the
  directional walk system exists and is ready to take them
- **Diagonal walk frames** don't exist yet. When they do, only `_update_facing`
  needs changing — split into 8 sectors via `_path_dir.angle()`
- **Tower and enemy shadows** into `ShadowLayer` so they stop stacking
- **Wave balance** after the enemy speed doubling — deferred until progression exists
- **Progression system** (the big one): enemies grant XP, level-up offers a choice
  HoMM-style. Local buffs arrive as pickable cards to apply to a chosen tower;
  global buffs (economy, all-towers) apply immediately with no card

Found during a code review, not yet addressed:

- **Crowd separation overshoots at large `delta`.** `lane_offset += push *
  CROWD_PUSH * delta` (`Enemy.gd`) is an explicit integration, so a big step
  jumps past the target. Needs sub-stepping or a clamp. This is **not** caused
  by `Engine.time_scale` and won't be fixed by removing it
- **`Engine.time_scale` is a global speed hack.** It also speeds up the camera
  zoom lerp, tower range reveal, the build-pop tween and cloud drift, and it's
  assigned in five places that must stay in sync. The fix is a `GameSpeed`
  multiplier threaded through gameplay `delta` and the three timers — Godot 4
  has no per-subtree time scale. Worth doing when progression lands and tweens
  stop being cosmetic
- **Four `.import` files have no source art** (`assets/decor/grass_01.png`,
  `assets/road_cobblestone.png`, `assets/sprites/Enemy/Goblin_faster.png`,
  `assets/sprites/Enemy/Slime_bigger.png`). Deliberately kept — that art may
  come back. Don't "clean" them up
- **The decor round-trip is unverified in the editor.** `edit_mode` → drag →
  `bake_now` → `reload_now` has never been run end to end. Check it before
  relying on it for a big placement session
