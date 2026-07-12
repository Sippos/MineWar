# MOV-017 Brick Family Manifest

Status: implemented locally on `refactor/mov-017-brick-family`; not pushed or merged

Base commit: `29d8e9e`

## Scope

This MOV-017 terrain-family sub-batch moves the three active flat brick textures and their tracked import sidecars:

- `Easy_Brick.png` → `assets/sprites/world/terrain/bricks/Easy_Brick.png`
- `Medium_Brick.png` → `assets/sprites/world/terrain/bricks/Medium_Brick.png`
- `Hard_Brick.png` → `assets/sprites/world/terrain/bricks/Hard_Brick.png`

Updated active consumers:

- `scenes/world/mine/level.tscn`
- `resize_assets.py`

The following remain untouched because they are pre-existing stale boot-wrapper patchers or gradient migration scripts rather than active world-scene consumers:

- `fix_everything.py`
- `fix_top_tiles.py`
- `fix_tscn_assets.py`

No gradient art, border art, edge atlases, front-wall art, damage art, fog, rail, TileSet extraction, source-ID change, collision change, atlas-coordinate change, durability change, or gameplay change is included.

## Frozen contracts

- `TileSet_main` source IDs remain: easy `1`, medium `2`, hard/boundary `3`.
- Each atlas region remains `64 × 64` with active coordinate `(0,0)`.
- Existing collision polygons remain unchanged.
- Easy, medium, and hard durability/type mappings remain unchanged.
- World-generation thresholds, boundary behavior, mining damage, drops, and navigation updates remain untouched.
- Source image bytes are unchanged.

## Validation gate

- Review the complete diff and run `git diff --check`.
- Confirm only three images, three sidecars, the level scene, `resize_assets.py`, and this manifest are changed.
- Confirm old root sources and sidecars no longer exist.
- Confirm new sources and sidecars exist.
- Confirm stale active `res://Easy_Brick.png`, `res://Medium_Brick.png`, and `res://Hard_Brick.png` references remain only in historical documentation or explicitly excluded stale patchers.
- Run Godot 4.7 headless editor import/check.
- Run a bounded startup smoke test.
- Before merge, manually validate easy/medium/hard rendering, collision, mining durability, boundary behavior, and drops.

## Rollback

Reverse only this commit: restore the six files to the root, restore level and resize-tool paths, regenerate ignored Godot cache as needed, and repeat validation. Do not reset or clean unrelated work.
