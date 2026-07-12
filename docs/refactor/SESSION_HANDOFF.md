# MineWars Remote Session Handoff

Updated: 2026-07-11

## Mandatory restart procedure

Before changing files in a new chat:

1. Read `AGENTS.md`.
2. Read this file, `REFACTOR_PROGRESS.md`, and `PEON_CHARACTERIZATION.md`.
3. Confirm `localFS`, `localGD`, and `localGit` are connected.
4. Confirm the active Godot session points to `/home/sebastian-berger/mining/` and no game process is running.
5. Fetch `origin`.
6. Inspect branch, HEAD, status, remotes, staged changes, unstaged changes, untracked files, and the full diff.
7. Preserve unrelated work, especially `pixel_sprite_output/`, and never commit `.godot/` content or temporary MCP helper settings.
8. Do not merge into `main` without explicit confirmation.

## Current repository state

- Repository: `/home/sebastian-berger/mining`
- Active focused branch: `fix/peon-tunnel-navigation`
- Branch base: `audit/peon-characterization`
- Remote base: `origin/audit/peon-characterization`
- Characterization baseline commit: `0dbdadc`
- The unrelated untracked directory `pixel_sprite_output/` must remain untracked and unstaged.
- `project.godot` is not part of this fix.

## Peon tunnel-navigation defect

The real single-player Shaman defect was reproduced in the actual Level with three Peons.

Before the fix, a Peon had:

- current cell `(0, -1)`,
- cached next path cell `(0, 0)`,
- BlockLayer source ID `1` at the next cell,
- the next A* cell marked solid,
- state `MOVE_TO_GEM`.

Despite that terrain change, the Peon moved 16 pixels toward the blocked cell. This confirmed the invariant violation: a Peon could continue following a cached path after its next path cell became solid.

## Focused fix

`peon.gd` now validates the current cached path cell in `move_along_path()` before movement. The same validation is repeated after advancing to another path cell during the same call.

When the next cached cell is no longer walkable, the Peon:

- clears `astar_path`,
- resets `path_index` to `0`,
- sets velocity to `Vector2.ZERO`,
- returns without moving.

This is intentionally limited to cached-path cancellation and does not redesign the Peon framework.

## Regression coverage

`tests/test_peon_characterization.gd` includes:

- `test_cached_path_stops_before_newly_solid_next_cell`

The test creates a three-cell open path, marks the next cached cell solid, invokes `move_along_path()`, and verifies that the Peon does not move, velocity becomes zero, and the invalid cached path is cleared.

Final automated validation:

- suite: `peon_characterization`
- 6 tests
- 36 assertions
- 0 failures
- 0 skipped
- 0 fresh editor errors after the established cursor

## Real runtime validation

The same deterministic paused Shaman scenario was repeated after the fix with three real Peons present.

Observed result:

- current cell remained `(0, -1)`,
- next cell `(0, 0)` still had BlockLayer source ID `1`,
- the next A* cell was solid,
- movement distance was `0`,
- velocity was zero,
- path size was `0`,
- path index was `0`,
- `last_walkable_cell` remained `(0, -1)`.

The Peon no longer moved toward the newly solid cell.

## Remaining known Peon gaps

Do not treat these as fixed:

- Duplicate target selection can occur before coordinator reconciliation.
- The gem is deleted before return-path success is guaranteed.
- No stuck/progress watchdog exists.

Do not merge this branch into `main` without explicit confirmation.

## MOV-012 completion

Completed on 2026-07-12 on branch . Final paths:  and . The focused Peon suite passed 6/6 tests with 36 assertions and the project launched successfully. Next planned work is AUD-012 collectible characterization before MOV-013.

## Current next task

AUD-012 collectible characterization is complete on . The next structural task is MOV-013, moving  and  together with all exact path updates and no behavior changes.

## MOV-013 status

The gem and rail-item scene/script pairs have been relocated together on `refactor/mov-013-collectibles`. Their new paths are under `scenes/entities/collectibles/{gems,rail_items}/` and `scripts/gameplay/collectibles/{gems,rail_items}/`. The rail-item script continues to inherit from the relocated gem script by exact `res://` path. Focused collectible validation passed 4/4 tests (23 assertions), and the full discovered suite passed 10/10.

