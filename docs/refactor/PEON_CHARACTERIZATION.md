# Peon Characterization

Updated: 2026-07-11

This records current Peon behavior before further refactoring. It is a characterization of existing contracts, not a redesign.

## Ownership

- `base.gd` spawns Peons and emits `gems_deposited(amount)`.
- `peon.gd` owns states, targeting, path creation, wandering, pickup, return, deposit, and animation.
- `peon_coordinator.gd` reconciles duplicate targets, clears stale reservations, and maintains status/carry UI.
- `world.gd` owns the A* grid and synchronizes dug cells with `BlockLayer`.

## Current behavior

States are `IDLE`, `MOVE_TO_GEM`, and `RETURN_TO_BASE`.

A walkable cell must be inside the A* region, non-solid in A*, and empty in `BlockLayer`. Paths are four-directional.

A collectible gem must be valid, not queued for deletion, not on rails, and not tethered. Gems with no reachable nearby walkable cell are ignored.

Pickup occurs within 24 pixels. The gem is queued for deletion immediately, then the Peon builds a path to Base. Within 36 pixels of Base it emits `gems_deposited(1)` once and searches for another job.

The coordinator keeps only one Peon assigned to a duplicate target and resets duplicate assignees to `IDLE` with an empty path and zero velocity.

## Automated suite

`tests/test_peon_characterization.gd` uses a synthetic world, A* grid, TileMapLayer, Base, gems, and scripted Peons.

Final validation on 2026-07-11:

- 5 tests
- 32 assertions
- 0 failures
- 0 skipped
- 0 fresh errors

Covered contracts:

1. Reachable paths contain only open, dug cells.
2. Disconnected gems are ignored.
3. Pickup returns to Base and deposits exactly once.
4. Duplicate targets are reduced to one owner.
5. Invalid targets recover to `IDLE` with an empty path and zero velocity.

Run with:

```text
test_run(suite="peon_characterization", verbose=true)
```

## Known gaps

- Future path cells are not explicitly cancelled or rebuilt when terrain changes.
- Duplicate selection may occur before coordinator reconciliation.
- The gem is deleted before return-path success is guaranteed.
- No stuck/progress watchdog exists.
- `last_walkable_cell` can be used as a fallback when the Peon is outside a walkable cell.
- The reported upward/through-wall runtime symptom still needs focused reproduction.

## Refactor rule

For each Peon change: add one regression test, change one defect, run this suite, validate a real single-player Shaman Peon scenario, inspect fresh errors, and review the full Git diff.
