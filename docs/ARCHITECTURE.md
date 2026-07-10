# MineWar Architecture

## Current Godot entry points

- `project.godot` starts at `res://menu.tscn`.
- `menu.tscn` uses `menu.gd` and opens hero selection, controls, lexicon, VS local, or VS online.
- `main.tscn` instances `level.tscn`.
- `vs_mode.tscn` instances two copies of `level.tscn` inside subviewports.
- `level.tscn` owns the core runtime objects: `World`, `HUD`, `UpgradeMenu`, `Base`, `BlockLayer`, `Player`, and related TileMap layers.

## Current gameplay modules

- `world.gd`: world generation, fog/edge/front-wall updates, waves, enemy spawning, VS income.
- `player.gd`: movement, digging, combat, carrying gems, stat upgrades, XP/level-up handling.
- `base.gd`: gem deposit, healing, upgrade prompt, base damage, faction item spawning.
- `hud.gd`: visible resources, health, stats, XP, minimap, stomp cooldown, game-over UI.
- `upgrade_menu.gd`: base upgrade UI, HUD unlocks, stat upgrades, faction purchases, VS enemy sending.
- `global.gd`: save data, selected heroes, hero sprite data, seen monsters.

## Target folder structure

The repo currently keeps most Godot files in the project root. Do not mass-move files blindly because Godot scenes use `res://` references. Move in phases:

```text
res://
  scenes/
    core/          # main.tscn, level.tscn
    ui/            # menu, hero select, HUD, upgrade menus, pause, level up
    actors/        # player, enemies, peons, base, minecart, gems
    items/         # rail items, drops, pickups
  scripts/
    core/
    ui/
    actors/
    systems/       # world generation, waves, input, save, balance
  assets/
    sprites/
      characters/
      tiles/
      ui/
    audio/
  data/
    heroes/
    enemies/
    upgrades/
  docs/
```

## Refactor principle

Move from "scene does everything" to "scene owns layout, script owns behavior, data files own balance." In practice:

- UI scenes should be editable in Godot. Avoid creating major menus entirely in code.
- Gameplay constants should move into resources/data files before balance tuning.
- Big systems like world generation and waves should be split out of `world.gd` after tests/playtest notes confirm behavior.
- Keep compatibility wrappers while moving files so existing scenes keep loading.
