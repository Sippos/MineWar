# MOV-017 Edge Family Manifest

Status: implemented locally on `refactor/mov-017-edge-family`; not pushed or merged

Base commit: `446483f`

## Scope

Moves the three active edge atlases and matching import sidecars into `assets/sprites/world/terrain/edges/`.

Updated active paths in:

- `scenes/world/mine/level.tscn`
- `generate_edge_atlases.py`
- `generate_edge_atlases_final.py`
- `generate_edge_atlases_fixed.py`
- `generate_edge_atlases_fixed2.py`
- `generate_edge_atlases_pure.py`

Excluded unchanged stale tooling:

- `fix_edge_sources.py` targets the stale boot wrapper.
- `update_tileset.py` encodes an obsolete `_256` migration.
- Historical MOV-017 documentation remains unchanged.

## Frozen contracts

- TileSet source IDs remain easy `4`, medium `5`, hard `6`.
- Every atlas remains a 4×4 grid of 64×64 cells.
- Mask bits remain top `1`, right `2`, bottom `4`, left `8`.
- Atlas coordinates remain `Vector2i(mask % 4, int(mask / 4))`.
- Edge selection, layer ordering, world update logic, scene hierarchy, and gameplay remain unchanged.
- Source image bytes remain unchanged.

## Validation

Run `git diff --check`, Godot 4.7 headless import/check, and a bounded startup smoke test. Before merge, manually inspect all 16 masks for all three edge types.
