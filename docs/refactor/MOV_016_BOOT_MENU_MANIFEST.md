# MOV-016 Boot and Main Menu Manifest

Status: implemented on `refactor/mov-016-boot-main-menu`

## Frozen manifest

- `menu.tscn` → `scenes/menus/main/menu.tscn`
- `menu.gd` and `menu.gd.uid` → `scripts/ui/menus/main/`
- `main.tscn` → `scenes/boot/main.tscn`

Main-menu artwork remains at its existing paths and is explicitly excluded.

## Startup contract

`project.godot` continues to start `res://launch_router.tscn`. The router selects the relocated main menu for ordinary clients, while `boot.gd` routes between the relocated gameplay wrapper and relocated menu. No project setting changes are required.

## Reference scope

All tracked exact runtime `res://` references are updated, including router/boot flow, return-to-menu paths, hero-selection start flow, tests, and generated-maintenance source templates. Tracked Python utilities that directly open one of the moved files now use the new repository-relative path.

## Path-only scope

No scene contents, node hierarchy, UI layout, startup logic, navigation behavior, filenames, UIDs, or artwork are changed.


## Validation

- `git diff --check` passed.
- All modified tracked Python utilities compiled with `python3 -m py_compile`.
- Clean Godot 4.7 headless editor import passed with exit code 0.
- `launch_router.tscn`, relocated menu, relocated gameplay wrapper, `level.tscn`, hero selection, Controls, and Lexicon loaded directly with exit code 0.
- Configured cold launch, direct relocated menu launch, and direct relocated gameplay-wrapper launch remained running without a game-script failure.
- `project.godot` remained unchanged and still points to `res://launch_router.tscn`.
- No stale exact `res://menu.tscn`, `res://menu.gd`, or `res://main.tscn` paths remained.
- The editor-only MCP test suites were not rerun in the clean worktree because their runner is provided by the intentionally untracked Godot AI addon. MOV-016 is path-only; scene import and runtime launch validation covered every moved entry resource.
