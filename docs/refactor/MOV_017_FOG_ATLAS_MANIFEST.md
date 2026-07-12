# MOV-017 Fog Atlas Manifest

Status: implemented locally on `refactor/mov-017-fog-atlas`; not pushed or merged

Base commit: `03a29cb`

## Scope

This MOV-017 terrain-family sub-batch moves only the active fog mask atlas and its tracked import sidecar:

- `fog_mask_atlas.png` → `assets/sprites/world/fog/fog_mask_atlas.png`
- `fog_mask_atlas.png.import` → `assets/sprites/world/fog/fog_mask_atlas.png.import`

Updated active consumers and producers:

- `scenes/world/mine/level.tscn`
- seven fog-atlas generator scripts
- `test_mask.py`

`update_tscn.py` remains untouched because it is a pre-existing stale wrapper patcher. `update_tileset.py` remains untouched because its replacement rule documents an obsolete `_256` migration rather than generating or consuming the active source directly.

No brick, edge, front, damage, rail, background, placeholder, TileSet extraction, source-ID change, atlas-coordinate change, fog algorithm change, or gameplay change is included.

## Frozen contracts

- `TileSet_main` source ID `9` remains `Source_fog`.
- Atlas region size remains `64 × 64`.
- The atlas remains a 4×4 grid representing masks `0` through `15`.
- Cardinal mask mapping remains top `1`, right `2`, bottom `4`, left `8`.
- Atlas coordinates remain `Vector2i(mask % 4, int(mask / 4))`.
- Fog generation logic and pixel output are unchanged; only output paths move.
- `FogLayer`, world reveal logic, scene hierarchy, and node names remain untouched.

## Exact references

Before this move, the active source path appeared in:

- `scenes/world/mine/level.tscn`
- `fog_mask_atlas.png.import`
- seven generator scripts
- `test_mask.py`
- historical exclusion text in `docs/refactor/MOV_017_WORLD_CORE_MANIFEST.md`
- stale migration/patch scripts explicitly excluded above

Historical documentation and excluded stale scripts remain unchanged because they describe prior state or obsolete transformations outside this sub-batch.

## Validation gate

- Review the complete diff and run `git diff --check`.
- Confirm only the image, sidecar, level scene, seven generators, test reader, and this manifest are changed.
- Confirm the old root source and sidecar no longer exist.
- Confirm the new source and sidecar exist.
- Confirm no stale active `res://fog_mask_atlas.png` reference remains outside historical documentation and explicitly excluded stale scripts.
- Run Godot 4.7 headless editor import/check.
- Run a bounded startup smoke test.
- Before merge, manually validate fog reveal edges and all 16 mask variants.

## Rollback

Reverse only this commit: restore the image and sidecar to the root, restore level/generator/test paths, regenerate ignored Godot cache as needed, and repeat validation. Do not reset or clean unrelated work.
