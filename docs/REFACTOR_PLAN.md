# Refactor Plan

Execution status and the authoritative restart point are tracked in
`docs/refactor/REFACTOR_PROGRESS.md`.

## Phase 1: Stabilize the upgrade UI

Status: started.

Goals:

- Replace messy duplicated upgrade-menu nodes with named, editable sections.
- Keep buttons as scene nodes so Godot UI editing works.
- Connect button signals in `upgrade_menu.gd` instead of relying on missing or fragile scene signal wiring.
- Keep existing gameplay behavior: stat upgrades, HUD unlocks, faction purchases, VS enemy sending.

## Phase 2: Document and protect the release workflow

Goals:

- Document GitHub -> itch.io deployment.
- Add a release checklist.
- Keep `main` playable.
- Use branches/PRs for risky refactors.

## Phase 3: Move UI files

Goal structure:

```text
scenes/ui/
scripts/ui/
assets/sprites/ui/
```

Move one UI area at a time:

1. main menu,
2. hero selection,
3. upgrade menu,
4. HUD,
5. pause/level-up/controls/lexicon.

Each move must update `project.godot`, scene `ext_resource` paths, and script preload/change_scene paths in the same commit.

## Phase 4: Split gameplay systems

Candidates:

- `scripts/systems/input_bindings.gd`
- `scripts/systems/world_generation.gd`
- `scripts/systems/wave_director.gd`
- `scripts/systems/save_game.gd`
- `scripts/data/hero_database.gd`
- `scripts/data/enemy_database.gd`

## Phase 5: Balance data

Move tunables out of scripts:

- block health/dig time,
- stat upgrade costs,
- enemy costs/income,
- wave scaling,
- hero/faction upgrades.

This makes playtest changes faster and safer.
