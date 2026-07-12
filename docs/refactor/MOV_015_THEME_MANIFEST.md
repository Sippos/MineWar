# MOV-015 Global Theme Manifest

Status: implemented on `refactor/mov-015-global-theme`

## Frozen manifest

- `global_theme.tres` → `assets/themes/global/global_theme.tres`

The destination follows the confirmed classification in `ARTIFACT_CLASSIFICATION.md`: a Godot `Theme` is a UI style resource, not a material.

## Reference manifest

Active runtime references updated:

- `global.gd` (`GAME_UI_THEME_PATH`)
- `menu.gd` (`MENU_THEME` preload)
- `scenes/menus/controls/controls_menu.tscn`

Documentation references that describe the exact runtime path or MOV-015 destination are updated. The theme's internal texture paths remain unchanged because `Button.png` and `MenuPanel.png` already live under `assets/sprites/ui/common/`.

## Path-only scope

No style values, UIDs, texture paths, node hierarchy, project settings, or gameplay/UI behavior are changed.


## Validation

- `git diff --check` passed.
- Clean Godot 4.7 headless editor import passed with exit code 0.
- `menu.tscn`, `scenes/menus/controls/controls_menu.tscn`, `hud.tscn`, and `upgrade_menu.tscn` loaded directly with exit code 0.
- A bounded headless main-project launch remained running without a game-script failure.
- No stale active `res://global_theme.tres` reference or old root theme file remained.
- Internal `Button.png` and `MenuPanel.png` theme dependencies remained unchanged and valid.
