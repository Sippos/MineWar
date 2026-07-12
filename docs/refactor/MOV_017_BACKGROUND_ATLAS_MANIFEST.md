# MOV-017 Background Atlas Manifest

Status: implemented locally on `refactor/mov-017-background-atlas`; not pushed or merged

Base commit: `d383733`

## Scope

This MOV-017 terrain-family sub-batch moves only the active mine background texture and its tracked import sidecar:

- `Black_BG_TransparentBorder.png` → `assets/sprites/world/terrain/Black_BG_TransparentBorder.png`
- `Black_BG_TransparentBorder.png.import` → `assets/sprites/world/terrain/Black_BG_TransparentBorder.png.import`

Runtime/resource-path updates are limited to:

- `scenes/world/mine/level.tscn`
- `resize_assets.py`, which directly processes the source image by repository-relative path

`fix_tscn_assets.py` remains untouched because it is a pre-existing stale patcher targeting the thin boot wrapper rather than the active world scene.

No brick, edge, fog, front, damage, rail, placeholder, TileSet extraction, source-ID change, atlas-coordinate change, rendering property change, or gameplay change is included.

## Frozen contracts

- `TileSet_main` source ID `0` remains `Source_bg`.
- Atlas region size remains `64 × 64`.
- The active atlas coordinate remains `(0,0)`.
- `BackgroundLayer` remains `z_index = -5` and continues using `TileSet_main`.
- The source image bytes are unchanged.
- Scene hierarchy, node names, collision data, and world logic remain untouched.

## Exact active references

Before the move, the source path appeared in:

- `scenes/world/mine/level.tscn`
- `Black_BG_TransparentBorder.png.import`
- `resize_assets.py`
- historical exclusion text in `docs/refactor/MOV_017_WORLD_CORE_MANIFEST.md`
- stale wrapper patcher `fix_tscn_assets.py`

Historical documentation and the stale wrapper patcher remain unchanged because they describe or encode pre-existing state outside this sub-batch.

## Validation gate

- Review the complete diff and run `git diff --check`.
- Confirm only the image, sidecar, level scene, `resize_assets.py`, and this manifest are changed.
- Confirm the old root source and sidecar no longer exist.
- Confirm the new source and sidecar exist.
- Confirm no stale active `res://Black_BG_TransparentBorder.png` path remains outside historical documentation and the explicitly excluded stale patcher.
- Run Godot 4.7 headless editor import/check.
- Run a bounded startup smoke test.
- Before merge, manually confirm the mine background renders identically.

## Rollback

Reverse only this commit: restore the image and sidecar to the root, restore the level and resize-tool paths, regenerate ignored Godot cache as needed, and repeat validation. Do not reset or clean unrelated work.
