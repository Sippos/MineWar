# AGENTS.md

Rules for AI assistants and automation working on MineWar.

## Product context

MineWar is a Godot fantasy mining-defense game inspired by Warcraft III fun maps such as Hero Line Wars. The goal is a polished, playable indie game with a reliable GitHub -> itch.io deployment workflow.

## Non-negotiables

- Keep `main` playable.
- Prefer small branches and reviewable pull requests.
- Do not mass-move Godot files unless every `res://` reference is updated in the same change.
- Do not hide editable UI inside code-created controls unless there is a strong reason.
- Preserve the deployment workflow.
- Favor readable Godot scenes and simple GDScript over clever abstractions.

## Godot UI rules

- Major menus belong in `.tscn` files.
- Scripts should connect signals and update text/state, not generate whole menu layouts.
- Use stable node names for controls that scripts reference.
- Keep button behavior in one script per menu.
- When a scene gets messy, replace it with a clean named hierarchy instead of adding more nested duplicates.

## Code rules

- Avoid large all-in-one files when touching a system repeatedly.
- Add helper methods when a script has repeated path or currency logic.
- Do not introduce new gameplay data in multiple places; centralize it before balancing.
- Keep changes compatible with web export unless explicitly working on platform-specific code.

## Current cleanup priority

1. Stabilize `upgrade_menu.tscn` and `upgrade_menu.gd`.
2. Document the workflow and architecture.
3. Move UI files into `scenes/ui` and `scripts/ui` in small PRs.
4. Split world generation/waves/input/save systems after the playtest loop is stable.

## Installed Agent Skills & Frameworks

Project-level and global agent skills are installed in `.agents/skills/` (mirrored from `~/.hermes/skills/game-development/` and `~/.gemini/config/skills/`):

- **Player Motivation & Design Frameworks:**
  - `quantic-foundry-motivation`: 12-factor player motivation model (Destruction, Excitement, Challenge, Strategy, Power, Completion, Discovery) to audit mechanics and score gameplay feel.
  - `game-designer`: Systems & core loops consultant (nested loops, 3-tier feedback).
  - `systems-designer` & `economy-designer`: Mathematical modeling, curve health, loot drop tables, dual-currency roguelite stability.
  - `balance-check`: Outlier and dominant strategy detection across combat, loot, and progression curves.

- **Godot 4 Engine & Quality Skills:**
  - `godot-gdscript`, `godot-nodes-scenes`, `godot-animation`, `godot-audio`, `godot-shaders`, `godot-signals-groups`, `godot-ui-control`, `godot-tilemap`, `godot-resources`, `godot-2d-movement`.
  - `godot-gdscript-headless-testing` & `smoke-check`: Headless CI test runner and verification gate (`godot --headless --path . --check-only`).
  - `game-feel`: Screen shake, hit-stop, squash & stretch, impact frames, layered sensory juice.
  - `audio-design`: Sound design, bus layering, priority ducking, and acoustic cues.
  - `playtest-report`: Structured playtest observation, regression detection, and action extraction.

## Verification Gate (Before Marking Any Task Done)

Autonomous workers must execute:
1. `godot --headless --path . --check-only` (Syntax & resource integrity check).
2. Relevant test runner in `tests/` (e.g. `godot --headless --path . -s tests/minewars_complete_run_runner.gd`).
3. If UI/visual changes: live smoke check via `godot-live-mcp` (assert nodes, grab `game_screenshot`, check `game_logs`).

