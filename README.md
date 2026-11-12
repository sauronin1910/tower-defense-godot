# Tower Defense (Godot 4)

A medieval-fantasy tower defense prototype in Godot 4 and GDScript, built with AI coding agents running on local models.

One playable map, 14 waves, 3 tower types and 6 enemy types. This is a finished prototype: the lessons from it now feed a new project designed from scratch.

## Gameplay

- **Free tower placement.** Drag a tower onto the map; a ghost preview shows whether the spot is valid. The road, decor and other towers block building, checked against per-tile road collision rather than whole tiles.
- **Towers:** spear, arrow and shells, each with upgrades and a sell option.
- **Enemies:** slimes that split into smaller slimes, fast and small goblins, and a hobgoblin boss. After wave 14, endless mode repeats the last wave.
- **Camera and speed:** zoom and pan, pause, and a game-speed toggle.

## Visuals

- Animated grass shader with light streaks and a living road edge, driven by a generated mask that also carves around trees and rocks.
- Decor that sways in the wind, cast shadows for towers and trees, and drifting cloud shadows.
- Y-depth sorting, so units walk correctly in front of and behind towers.
- Pixel art generated with PixelLab (earlier with ComfyUI) using fixed prompt and camera conventions so assets stay consistent.

## How it was built

The code was written with AI coding agents (Codex CLI and OpenCode) running Qwen models locally in LM Studio. See `opencode.json` for the local model setup.

- **Agent rules.** [`CLAUDE.md`](CLAUDE.md) is the single source of truth for any agent working here: surgical find-and-replace edits only, Python for multi-line edits, UTF-8 without BOM, line counts checked before and after every edit, and a commit after each working feature as a rollback net.
- **Codebase analysis.** The project was mapped into a knowledge graph with Graphify (348 nodes, 511 edges). The graph surfaced defects and showed where to split the main game script.
- **Documentation.** `docs/` is an Obsidian vault with an overview, architecture, towers, enemies, economy, game design notes and a prioritised TODO list.
- **Data-driven content.** Enemies, towers and decor are `.tres` resources and JSON, so adding an enemy type means dropping one file into `data/enemies/`.

## Running the project

1. Install [Godot 4.7](https://godotengine.org/) (Mobile renderer).
2. Clone the repository and open `project.godot`.
3. Press F5. The game starts at the main menu.

Debug settings are still on: starting gold is 3000 and the speed button includes 4x.

## Controls

| Input | Action |
|---|---|
| Drag a tower button onto the map | Place a tower |
| Left click a tower | Open the upgrade and sell panel |
| Mouse wheel, or Ctrl + / Ctrl - | Zoom |
| Middle mouse drag | Pan the camera |
| Esc | Pause |

## Project layout

```
data/      enemy, tower and decor definitions (.tres, JSON)
assets/    sprites, terrain and the generated grass mask
scenes/    main scene, towers, projectiles, UI
scripts/   all GDScript
shaders/   grass, decor wind, tower base grass, cloud shadows
docs/      design and architecture notes (Obsidian vault)
```
