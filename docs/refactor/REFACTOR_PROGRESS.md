# Refactor Progress Ledger

Status: authoritative restart point

Updated: 2026-07-11

## Current repository state

- Repository: `/home/sebastian-berger/mining`
- Active task branch: `fix/peon-tunnel-navigation`
- Branch base: `audit/peon-characterization`
- Remote base: `origin/audit/peon-characterization`
- Characterization baseline: `0dbdadc`
- `pixel_sprite_output/` is unrelated untracked work and must remain excluded.
- `.godot/` content and temporary MCP helper settings must never be committed.
- `project.godot` is not part of this task.

## Upgrade-menu refactor — merged

The upgrade-menu stabilization track is complete and merged into `main` through `597eba6`.

Included work:

- hierarchy flattening,
- explicit styler geometry types,
- safe deferred styling through instance IDs,
- Player 2 ability-action refresh after late player-ID assignment,
- compact VS one-time unlock disabled states,
- compact VS first-button focus.

Runtime validation passed in single-player and Local VS for layout, focus, hero-specific controls, costs, deductions, unlock states, menu closing, and return to gameplay.

## Peon characterization and tunnel-navigation fix

The deterministic characterization suite now contains six tests. The added regression test is:

- `test_cached_path_stops_before_newly_solid_next_cell`

The real single-player Shaman defect was reproduced with three Peons in the actual Level. A Peon at cell `(0, -1)` retained `(0, 0)` as its next cached path cell after that cell became solid and received BlockLayer source ID `1`. While still in `MOVE_TO_GEM`, it moved 16 pixels toward the blocked cell.

This established the concrete invariant violation: a Peon continued following a cached path after its next path cell became solid.

The focused change in `peon.gd` updates `move_along_path()` to validate the next cached cell before movement and again after advancing the path index during the same call. If that cell is no longer walkable, the function clears the path, resets the path index, zeros velocity, and returns without movement.

No broader Peon framework redesign was introduced.

## Validation result

Automated suite:

- suite: `peon_characterization`
- 6 tests
- 36 assertions
- 0 failures
- 0 skipped
- no fresh editor errors after the established cursor

Real paused Shaman runtime validation with three Peons confirmed:

- current cell remained `(0, -1)`,
- newly solid next cell remained `(0, 0)`,
- movement distance was `0`,
- velocity was zero,
- cached path size was `0`,
- path index was `0`,
- `last_walkable_cell` remained `(0, -1)`.

The previously reproduced movement toward the newly solid cell is cancelled.

## Remaining Peon gaps

- Duplicate target selection can occur before coordinator reconciliation.
- Gem deletion happens before return-path success is known.
- No stuck/progress watchdog exists.

## Scope rule

Future Peon work should remain one defect per focused branch, with a regression test, the full characterization suite, real single-player Shaman runtime validation, a fresh editor-error check, and a full Git diff review.

Do not merge any task branch into `main` without explicit confirmation.

## MOV-012 — Peon worker relocation

Completed on 2026-07-12. The Peon scene and script now live at  and . All known runtime, test, and maintenance-script references were updated. Validation: Peon characterization 6/6 tests, 36 assertions; project launch successful; no new MOV-012 errors.

## AUD-012 collectible characterization — complete

- Added : 4 tests, 23 assertions.
- Full discovered suite: 10 tests, 0 failures.
- Documented contracts in .
- MOV-013 is now unblocked as a path-only inheritance-coupled move.
