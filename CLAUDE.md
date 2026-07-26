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
assets/
  grass_mask.png            generated — do not hand-edit
  terrain/                  tileset sources (road SVG, grass PNG)
  sprites/
    Towers/spear_tower/     Spear_Tower_1..5.png (flag idle), Projectile_Spear.png
    Enemy/                  static enemy PNGs
    Enemy/small_goblin/     <dir>_side/small_goblin_<dir>_side_01..09.png
  decor/                    hand-placed props (trees, rocks, crystals)
scenes/                     Main.tscn, Tower.tscn, Projectile.tscn, UI scenes
scripts/                    all GDScript
shaders/                    .gdshader files + gradient.png, noise.png, clouds.png
```

---

## Architecture

### Core scripts

**`Main.gd`** — game loop: waves, gold, placement, camera, speed control.
`WAVE_CONFIG` holds 13 waves; endless mode repeats the last entry.

Placement goes through `_can_place_tower_at(pos, type)`, which chains:
gold check → `_is_on_enemy_path` (road collision) → `_is_on_decor` → `_is_too_close_to_tower`.
The drag ghost reuses the same function, so validity feedback stays in sync
automatically.

**`TowerVisuals.gd`** (`RefCounted`, all static) — **single source of truth** for
tower visuals. Both `Tower.gd` and `TowerGhost.gd` read from here; that's the
whole point, so don't reintroduce per-script duplicates.

Owns: per-type `DATA` (sprite paths, frame counts, range, projectile, muzzle),
`scale_for()`, `base_offset()` (measures opaque pixels so transparent padding is
ignored), `footprint_radius()`, `opaque_local_rect()` (snug click hitbox),
`base_extents()` / `base_query_shape()` (placement ellipse from the sprite's
bottom slice), and factories `make_cast_shadow()` / `make_shadow()`.

Towers render 240px tall with the sprite's **base** on the placement point.

**`Enemy.gd`** (`PathFollow2D`) — stats per type, HP bar, movement, animation.

Two animation styles coexist: **procedural** wiggle (sin-based bob/pulse) for
static-sprite types, and **frame-based** directional walk for `goblin_small`.
A type must use one or the other — running both makes them fight.

**`Tower.gd`** (`Area2D`) — per-tower stats, upgrade levels, shooting, build-pop.
`shoot_timer` is stored as a member so `_apply_level_stats()` can refresh
`wait_time`; otherwise fire-rate upgrades silently do nothing.

**`DecorSprite.gd`** (`Sprite2D`) — hand-placed props. Handles depth sorting,
shadow creation, and build blocking. Configure one node, then Ctrl+D copies.

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

1. Add a plain `Node` child to Main's **root**, name it `MaskGen`, attach `scripts/MaskGen.gd`
2. Run the scene once. Watch Output for `road_pixels=` and `carved N decor pixels` — both must be non-zero
3. Close the game, **restart Godot** (or Reimport the PNG) so the new file is picked up
4. **Delete the MaskGen node**, or it regenerates on every launch

**The script must be its own child node, never attached to the root.** Doing that
overwrites `Main.gd` on the root and the scene comes up blank.

Tuning knobs, all global: `SUBDIV` (mask resolution — cost grows fast, 38 is
~1.8M physics queries and a visible freeze), `PROBE_RADIUS` (keep ≥ 1.0; below
that the probe slips through micro-seams between per-tile colliders and punches
holes in the mask), `CARVE_SLICE_RATIO` (~0.18, how much of a sprite's bottom
counts as ground contact), `CARVE_DILATE`.

Colliders are **not** registered on physics frame 1 — the script waits ~30 frames
before sampling, otherwise `road_pixels` comes back 0.

### Placing decor

Children of the `Decor` node in Main.tscn. Configure one, then Ctrl+D and drag.
Vary rotation, scale and `Flip H` so copies don't read as clones.

Per-node exports appear at the **top** of the inspector, above `Texture`:
`ground_anchor`, `shadow_mode`, shadow tuning groups, `blocks_building` +
`block_radius`, `carves_grass`.

Shadows are built in `_ready()`, so they're invisible in the editor — judge them
only in a running scene. `block_center` is likewise computed once at startup.

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
