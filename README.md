# MineWar

MineWar is a Godot fantasy mining-defense game inspired by Warcraft III custom maps such as Hero Line Wars, with digging/mining, base upgrades, hero/faction identity, enemy waves, and a GitHub-to-itch.io release workflow.

## Current loop

1. Pick a hero/faction from the main menu.
2. Dig into the mine, collect gems/resources, and return them to the base.
3. Buy upgrades at the base.
4. Survive waves or, in VS mode, send enemies to the opponent while improving income.

## Development rule

Keep the game playable on `main`. Bigger cleanup work should happen in branches and land in small pull requests:

- one gameplay change at a time,
- one UI refactor at a time,
- no mass file moves without updating Godot `res://` references in the same change,
- keep itch.io deployment green after every merge.

## Important docs

- `docs/PROJECT_VISION.md` — product direction and target game feel.
- `docs/ARCHITECTURE.md` — current Godot architecture and folder plan.
- `docs/REFACTOR_PLAN.md` — cleanup roadmap.
- `AGENTS.md` — rules for AI/code assistants working in this repo.
