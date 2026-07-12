# MOV-017 Front-Wall Family Manifest

Status: implemented locally on `refactor/mov-017-front-wall-family`; not pushed or merged

Base commit: `21af919`

## Scope

Moves the three active front-wall textures and matching import sidecars into `assets/sprites/world/terrain/front_walls/`.

Updated active consumer:

- `scenes/world/mine/level.tscn`

Historical wrapper patchers and alternative front-art files remain unchanged.

## Frozen contracts

- TileSet source IDs remain easy `10`, medium `11`, hard `12`.
- Atlas region size and active coordinate remain unchanged.
- Front-wall selection, layer ordering, rendering, scene hierarchy, and gameplay remain unchanged.
- Source image bytes remain unchanged.

## Validation

Run `git diff --check`, Godot 4.7 headless import/check, and a bounded startup smoke test. Before merge, manually inspect easy, medium, and hard front-wall rendering and ordering.
