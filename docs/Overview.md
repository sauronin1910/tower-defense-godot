# Overview

**TD game** — a 2D tower defense prototype built in Godot 4 with GDScript.

| | |
|---|---|
| Engine | Godot 4 (`project.godot` declares `config/features = 4.7`, `AGENTS.md` still says 4.3) |
| Renderer | Mobile, D3D12 on Windows |
| Viewport | 1280×720, `canvas_items` stretch, `expand` aspect |
| Entry scene | `scenes/MainMenu.tscn` |
| Language | GDScript, tabs for indentation, UTF-8 without BOM |
| Size | ~2 700 lines of GDScript across 15 scripts, 10 shaders, 7 scenes |

---

## What the game is

One map, one level. The player places towers alongside a fixed enemy path; enemies walk that path from one end to the other and damage the player's base if they arrive. Thirteen hand-authored waves, then the level ends in a victory screen.

- **3 tower types** — spear, arrow, shells. See [[Towers]].
- **6 enemy types** — slime, big slime, small goblin, fast goblin, hobgoblin, mini slime. See [[Enemies]].
- **Gold and base HP** — kill enemies for gold, spend it on towers and upgrades. See [[Economy]].
- **13 waves**, wave 13 is a hobgoblin boss wave. Payout table in [[Economy#Wave payouts]].

There is no save system, no second level, no audio, and no settings menu.

---

## Game flow

```
MainMenu.tscn  ──Play──▶  Main.tscn
                             │
                             ├─ Start Wave button (or 15 s auto-timer)
                             ├─ SpawnTimer drips enemies onto EnemyPath every 0.8 s
                             ├─ Towers auto-target and fire
                             ├─ wave clears ──▶ next wave
                             │
                             ├─ base HP ≤ 0  ──▶ GameOverScreen  ──▶ restart / menu
                             └─ wave 13 clears ──▶ LevelComplete ──▶ retry / menu / (next level: stub)
```

Pause is `Esc`; the pause menu, game-over screen, and level-complete screen all set `process_mode = WHEN_PAUSED` so their buttons stay clickable while the tree is paused.

The full scene graph and the signal wiring behind this flow are in [[Architecture]] — see [[Architecture#Signals]] for the emitter/handler table.

---

## Controls

| Input | Action |
|---|---|
| Drag a tower button onto the map | Place a tower (ghost preview shows validity) |
| Left click a tower | Open the upgrade / sell panel |
| Left click empty map | Close the upgrade panel |
| Mouse wheel | Zoom (0.64 – 2.0, smoothed) |
| `Ctrl` `+` / `Ctrl` `-` | Zoom via keyboard |
| Middle mouse drag | Pan the camera |
| `Esc` | Toggle pause |
| Build button | Toggle the tower dock |
| Speed button | Cycle 1× → 1.5× → 2× → 4× (`Engine.time_scale`) |

---

## Repository layout

```
project.godot           engine config
AGENTS.md               editing rules for AI assistants working on this repo
scenes/                 MainMenu, Main, Tower, Enemy, Projectile,
                        LevelComplete, TowerUpgradePanel
scripts/                all gameplay logic (15 .gd files)
shaders/                grass, wind, cloud shadows, tower base grass, tufts
assets/                 sprites (Enemy/, Towers/, decor/), terrain/, grass_mask.png
docs/                   this documentation
docs/TowerDefense/      an Obsidian vault (currently only Welcome.md)
.automaker/             metadata from an agent-runner tool
```

> The notes in `docs/` are cross-linked with Obsidian `[[wikilinks]]`. They resolve when the
> vault is opened at `docs/`; the `docs/TowerDefense/` vault config sits *below* them and does
> not see them.

`scenes/Main.tscn` is the whole game: 3 329 lines, 242 nodes, of which roughly 230 are hand-placed decor sprites — effectively unmergeable, see [[TODO#P1 — Structural|TODO #12]].

---

## Visual systems

The prototype invests heavily in ground and foliage presentation. Full pipeline in [[Architecture#Rendering pipeline]]:

- A **grass shader** (`shaders/grass.gdshader`) samples a baked `assets/grass_mask.png` to draw grass everywhere except roads and decor bases, with a frayed, trembling rim along the edges.
- `scripts/MaskGen.gd` **bakes that mask** by probing the road collision layer at 32× sub-tile resolution and stamping decor silhouettes into it.
- **Wind shaders** (`decor_grass_wind.gdshader`, `foliage_wind.gdshader`) sway trees, and the same material drives their cast shadows so shadow and canopy move together.
- A shared **`ShadowLayer` CanvasGroup** collects decor and enemy shadows so overlapping shadows blend instead of stacking into dark blotches.
- `scripts/CloudShadows.gd` scrolls a tiled shadow texture across the whole map.

⚠️ `MaskGen` is still wired into `Main.tscn` and runs at every game launch — see [[TODO#P0 — Blocking]].

---

## Where to go next

- [[GameDesign]] — core loop, player goals, economy and progression loops, failure conditions, expansion ideas
- [[Architecture]] — scene graph, script responsibilities, data flow, dependency graph, known structural issues
- [[Towers]] — tower stats, placement rules, upgrade system, visual pipeline
- [[Enemies]] — enemy stats, pathing, crowd separation, animation
- [[Economy]] — gold, costs, wave payouts, balance analysis
- [[TODO]] — prioritised work list

Editing rules for AI assistants working on this repo live in `AGENTS.md` and `CLAUDE.md`.
