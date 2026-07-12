# MOV-017 Rail Atlas Manifest

Status: implemented locally on `refactor/mov-017-rail-atlas`; not pushed or merged

Base commit: `2addf1bc28116576256ed73c4c56e51ab844d9fe`

## Scope

This MOV-017 terrain-family sub-batch moves only the active rail atlas and its tracked import sidecar:

- `rail_trail_atlas.png` → `assets/sprites/world/rails/rail_trail_atlas.png`
- `rail_trail_atlas.png.import` → `assets/sprites/world/rails/rail_trail_atlas.png.import`

The only runtime resource-path update is in `scenes/world/mine/level.tscn`.

No rail item art, placeholder atlas, scene, script, TileSet extraction, source-ID change, atlas-coordinate change, navigation change, minecart change, or gameplay change is included.

## Frozen contracts

- `TileSet_main` source ID `15` remains `Source_rail`.
- Atlas region size remains `64 × 64`.
- The 4×4 atlas cells remain unchanged.
- Cardinal mask mapping remains top `1`, right `2`, bottom `4`, left `8`.
- Atlas coordinates remain `Vector2i(mask % 4, int(mask / 4))`.
- Isolated rail mask remains `5`.
- `world.gd`, minecart behavior, rail-item behavior, node names, and scene hierarchy are untouched.

## Exact references

Before this move, the active source path appeared only in:

- `scenes/world/mine/level.tscn`
- `rail_trail_atlas.png.import`
- historical exclusion text in `docs/refactor/MOV_017_WORLD_CORE_MANIFEST.md`

The historical world-core manifest remains unchanged because it records that the atlas was excluded from that earlier commit.

## Validation gate

- Review full diff and `git diff --check`.
- Confirm only the image, sidecar, level scene, and this manifest are changed.
- Confirm old root source and sidecar no longer exist.
- Confirm new source and sidecar exist.
- Confirm no stale active `res://rail_trail_atlas.png` path remains outside historical documentation.
- Run Godot 4.7 headless editor import/check.
- Run a bounded startup smoke test.
- Before merge, manually validate rail placement/autotiling and minecart path refresh.

## Rollback

Reverse only this commit: restore the image and sidecar to the root, restore the level scene path, regenerate ignored Godot cache as needed, and repeat validation. Do not reset or clean unrelated work.
