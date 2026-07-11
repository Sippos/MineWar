# Refactor Progress Ledger

Status: authoritative restart point

Updated: 2026-07-11

Baseline: `main` and `origin/main` at merge commit `597eba6`.

## Current repository state

- Active task branch: `audit/peon-characterization`.
- The branch starts from `main` at `597eba6`.
- No Peon gameplay source file is changed in this batch.
- The batch adds one deterministic test suite and Peon behavior documentation.

## Upgrade-menu refactor — merged

The upgrade-menu stabilization track is complete and merged into `main` through `597eba6`.

Included work:

- hierarchy flattening to 61 nodes,
- explicit styler geometry types,
- safe deferred styling through instance IDs,
- Player 2 ability-action refresh after late player-ID assignment,
- compact VS one-time unlock disabled states,
- compact VS first-button focus.

Runtime validation passed in single-player and Local VS for layout, focus, hero-specific controls, costs, deductions, unlock states, menu closing, and return to gameplay.

## Peon characterization — complete on task branch

Added:

- `tests/test_peon_characterization.gd`
- `docs/refactor/PEON_CHARACTERIZATION.md`

The suite validates current behavior against a deterministic synthetic world without editing:

- `peon.gd`
- `peon_coordinator.gd`
- `base.gd`
- `world.gd`

Final result:

- 5 tests
- 32 assertions
- 0 failures
- 0 skipped
- no fresh editor errors on the final run

Covered contracts:

1. Reachable-gem paths use only non-solid, dug cells.
2. Disconnected gems are ignored.
3. Pickup enters return-to-base and deposits exactly once.
4. Coordinator reconciliation leaves only one duplicate target owner.
5. Invalid targets reset the Peon to `IDLE` with an empty path and zero velocity.

## Peon gaps recorded for later work

- Future path cells are not explicitly invalidated or rebuilt when terrain changes.
- Target reservations are reconciled after independent target selection.
- Gem deletion happens before return-path success is known.
- No stuck/progress watchdog exists.
- Runtime evidence is still needed for the reported upward/through-wall movement symptom.

## Next refactor task

Create a focused runtime-reproduction branch for the Peon tunnel-navigation defect only after this characterization branch is reviewed and merged.

The next batch must:

- begin with the green characterization suite,
- reproduce one concrete navigation invariant violation,
- add one regression test,
- change one defect only,
- validate in both the suite and real single-player Shaman runtime,
- and avoid unrelated worker-framework redesign.

Do not merge any task branch into `main` without explicit confirmation.
