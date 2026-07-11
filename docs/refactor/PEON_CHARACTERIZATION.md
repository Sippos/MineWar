# Peon Characterization

Updated: 2026-07-11

This records the current Peon behavior and the focused cached-path cancellation fix. It is a characterization of existing contracts, not a framework redesign.

## Ownership

- `base.gd` spawns Peons and emits `gems_deposited(amount)`.
- `peon.gd` owns states, targeting, path creation, wandering, pickup, return, deposit, movement, and animation.
- `peon_coordinator.gd` reconciles duplicate targets, clears stale reservations, and maintains status/carry UI.
- `world.gd` owns the A* grid and synchronizes dug cells with `BlockLayer`.

## Current behavior

States are `IDLE`, `MOVE_TO_GEM`, and `RETURN_TO_BASE`.

A walkable cell must be inside the A* region, non-solid in A*, and empty in `BlockLayer`. Paths are four-directional.

A collectible gem must be valid, not queued for deletion, not on rails, and not tethered. Gems with no reachable nearby walkable cell are ignored.

Pickup occurs within 24 pixels. The gem is queued for deletion immediately, then the Peon builds a path to Base. Within 36 pixels of Base it emits `gems_deposited(1)` once and searches for another job.

The coordinator keeps only one Peon assigned to a duplicate target and resets duplicate assignees to `IDLE` with an empty path and zero velocity.

`move_along_path()` now revalidates the current next cached path cell before movement. It also revalidates after advancing to another path cell during the same call. If the next cell is no longer walkable, the Peon clears the cached path, resets `path_index`, zeros velocity, and does not move during that call.

## Reproduced tunnel-navigation invariant violation

The real single-player Shaman scenario was reproduced in the actual Level with three Peons.

Before the fix:

- current cell: `(0, -1)`,
- cached next path cell: `(0, 0)`,
- next BlockLayer source ID: `1`,
- next A* cell: solid,
- Peon state: `MOVE_TO_GEM`,
- movement toward the blocked cell: 16 pixels.

The violated invariant was that a Peon continued moving toward a cached path cell after that cell became solid.

## Automated suite

`tests/test_peon_characterization.gd` uses a synthetic world, A* grid, TileMapLayer, Base, gems, and scripted Peons.

Final validation on 2026-07-11:

- suite: `peon_characterization`
- 6 tests
- 36 assertions
- 0 failures
- 0 skipped
- 0 fresh editor errors after the established cursor

Covered contracts:

1. Reachable paths contain only open, dug cells.
2. Disconnected gems are ignored.
3. Pickup returns to Base and deposits exactly once.
4. Duplicate targets are reduced to one owner.
5. Invalid targets recover to `IDLE` with an empty path and zero velocity.
6. A cached path is cancelled before movement when its next cell becomes newly solid.

The regression test `test_cached_path_stops_before_newly_solid_next_cell` creates a three-cell open path, marks the next cached cell solid, invokes `move_along_path()`, and verifies no movement, zero velocity, and an empty invalid path.

Run with:

```text
test_run(suite="peon_characterization", verbose=true)
```

## Real runtime result after the fix

The same paused deterministic Shaman scenario was rerun with three real Peons.

- current cell remained `(0, -1)`,
- next cell `(0, 0)` had BlockLayer source ID `1`,
- next A* cell was solid,
- movement distance was `0`,
- velocity was zero,
- path size was `0`,
- path index was `0`,
- `last_walkable_cell` remained `(0, -1)`.

The Peon did not move toward the newly solid cell.

## Known gaps

- Duplicate selection may occur before coordinator reconciliation.
- The gem is deleted before return-path success is guaranteed.
- No stuck/progress watchdog exists.
- `last_walkable_cell` remains available as a fallback when the Peon is outside a walkable cell.

## Refactor rule

For each future Peon change: add one regression test, change one defect, run this suite, validate a real single-player Shaman Peon scenario, inspect fresh errors, and review the full Git diff.
