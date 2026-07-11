# MineWars Remote Session Handoff

Updated: 2026-07-11

## Mandatory restart procedure

Before changing files in a new chat:

1. Read `AGENTS.md`.
2. Read this file, `REFACTOR_PROGRESS.md`, and `PEON_CHARACTERIZATION.md`.
3. Confirm `localFS`, `localGD`, and `localGit` are connected.
4. Confirm the active Godot session points to `/home/sebastian-berger/mining/` and no game process is running.
5. Fetch `origin`.
6. Inspect branch, status, remotes, latest commit, staged changes, unstaged changes, and untracked files.
7. Preserve unrelated changes and work in one focused batch.
8. Do not edit `main` directly.

## Current repository state

- Repository: `/home/sebastian-berger/mining`
- `main` and `origin/main` are synchronized at merge commit `597eba6`.
- Upgrade-menu runtime fixes are merged into `main`.
- Active task branch: `audit/peon-characterization`, created from `597eba6`.
- The task branch contains only Peon characterization tests and refactor documentation.
- Godot AI reinstall material remains under ignored `.godot/refactor_recovery_20260711/`; never commit `.godot/` content.

## Upgrade-menu refactor status

The complete validated chain is merged into `main` through `597eba6`:

- flattened 61-node upgrade-menu hierarchy,
- deferred styler instance-ID safety,
- Player 2 secondary/ultimate action refresh,
- compact VS one-time unlock disabled states,
- compact VS first-button focus.

Validated single-player and Local VS flows included layout, focus, hero-specific options, costs, deductions, unlock states, closing, and movement restoration.

## Peon characterization batch

Files added:

- `tests/test_peon_characterization.gd`
- `docs/refactor/PEON_CHARACTERIZATION.md`

The deterministic suite uses a synthetic world and validates current behavior without modifying Peon gameplay code.

Final validation:

- suite: `peon_characterization`
- 5 tests
- 32 assertions
- 0 failures
- 0 skipped
- 0 fresh errors on the final run

Locked contracts:

- reachable paths stay on open, dug cells,
- unreachable gems are ignored,
- pickup returns to Base and deposits once,
- duplicate targets are reduced to one Peon,
- invalid targets recover to `IDLE`.

## Known Peon gaps

Do not treat these as fixed:

- No explicit path cancellation/rebuild when a future path cell becomes solid.
- Duplicate target selection can occur before coordinator reconciliation.
- The gem is deleted before a return path is guaranteed.
- No stuck/progress watchdog exists.
- The reported runtime symptom of Peons appearing to move upward or through walls has not yet been reproduced in a focused fixture.

## Next focused batch

Reproduce the real single-player Shaman Peon navigation defect before changing gameplay code.

Required sequence:

1. Start from clean `main` after the characterization branch is merged, or create a dedicated fix branch from the characterization branch when explicitly requested.
2. Run `peon_characterization` first.
3. Launch a single-player Shaman game with the MCP helper live.
4. Buy or spawn multiple Peons.
5. Observe actual Peon cell, path, state, target, `last_walkable_cell`, and BlockLayer/A* walkability while reproducing the upward/through-wall symptom.
6. Capture one concrete invariant violation.
7. Add one failing regression test for that violation.
8. Make one focused fix only.
9. Run the characterization suite and a real runtime check.
10. Update all three refactor documents, commit, and push the task branch.

Do not merge into `main` without explicit confirmation.
