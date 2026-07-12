# MOV-017 Damage Family Manifest

Status: implemented locally on `refactor/mov-017-damage-family`; not pushed or merged

Base commit: `90603b5`

## Scope

Moves rear damage textures into `assets/sprites/world/terrain/damage/` and front damage textures into `assets/sprites/world/terrain/front_damage/`, including matching import sidecars.

Updated active consumers:

- `scenes/world/mine/level.tscn`
- `resize_assets.py` for `First_Hitting.png` and `Second_Hitting.png`

Stale wrapper patchers and unrelated alternate damage art remain unchanged.

## Frozen contracts

- TileSet source IDs remain rear damage `7` and `8`, front damage `13` and `14`.
- Damage thresholds, overlay visibility, atlas coordinates, layer ordering, mining logic, scene hierarchy, and gameplay remain unchanged.
- Source image bytes remain unchanged.

## Validation

Run `git diff --check`, Godot 4.7 headless import/check, and a bounded startup smoke test. Before merge, manually verify both rear and front damage stages while mining.
