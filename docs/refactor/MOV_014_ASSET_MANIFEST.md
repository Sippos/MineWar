# MOV-014 HUD Stat and Health Asset Manifest

Status: implemented on `refactor/mov-014-hud-assets`

## Frozen manifest

HUD-only:

- `HealthBarRed.png` and `HealthBarRed.png.import` → `assets/sprites/ui/hud/`

Shared HUD/upgrade/stat resources:

- `Healthbar.png` and sidecar
- `HealthBarPurple.png` and sidecar
- `Strenght.png` and sidecar
- `Agility.png` and sidecar
- `Int.png` and sidecar
- `StatRessources.png` and sidecar

These six shared pairs move to `assets/sprites/ui/common/stats/`. Existing spelling and casing are intentionally preserved.

## Ownership findings and exclusions

- `GoldCoin.png` is used by HUD, upgrade runtime code, and the collectible coin-drop scene. It is excluded because its ownership is broader than HUD/UI and the target structure identifies collectible ownership.
- `GoldCoinPile.png` is upgrade-only and is excluded from MOV-014.
- `Stat_Ressources_Overlay_Front.png` and `Easy_Edge_Atlas-1-Stat-Ressources.png` are world rendering assets despite their names and are excluded.

## Path-only scope

All tracked exact `res://` references, including active scenes/scripts, archived scene text, maintenance scripts, and `.import` `source_file` values, are updated. No image content, import settings, filenames, casing, node hierarchy, or gameplay behavior is changed.

## Validation

- `git diff --check` passed.
- A clean Godot 4.7 headless editor import completed with exit code 0 and no parser/import errors.
- `hud.tscn`, `upgrade_menu.tscn`, and `scenes/entities/collectibles/gems/gem.tscn` each loaded directly with exit code 0.
- A bounded headless main-project launch remained running without a game-script failure.
- Affected Python maintenance scripts compiled successfully.
- No stale exact root-level `res://` references or old root manifest files remained.
- The focused and full MCP suites were not rerun in the clean worktree. The branch intentionally does not contain the untracked Godot AI addon that provides the editor-only `McpTestSuite` runner, and a second editor could not register with the active MCP server. Earlier MOV-013 baselines remain 4/4 collectible tests and 10/10 full discovered tests; MOV-014 changes only asset paths and sidecars.
