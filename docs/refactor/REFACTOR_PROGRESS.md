# Refactor Progress Ledger

Status: authoritative restart point

Updated: 2026-07-11

Baseline: `main` at `aba8253` after PR #16, successful Godot 4.7 validation,
Web export, and itch.io deployment.

## Purpose

This ledger records what actually landed, what remains pending, and which task
is safe to start next. Planning details remain in `PROJECT_AUDIT.md` and
`TARGET_STRUCTURE.md`; this file owns execution status when those documents
and Git history differ.

## Current repository state

- Documentation recovery was completed on branch `refactor/recover-refactor-docs` on 2026-07-11. It restores the authoritative architecture notes, minecart characterization, progress ledger, session handoff, and migration-status annotations without gameplay changes.
- The previously mixed partial `MOV-011` work and local connector tooling remain preserved only in ignored local recovery storage and are not part of this documentation batch.
- Local `main` and `origin/main` were aligned at `aba8253` when this ledger was
  created.
- The reconciled history is preserved by PR #16.
- The validated startup corrections are commit `4f5e269`.
- The working baseline launches the configured router, main menu,
  single-player world, local VS, level-up overlay, and lexicon probe under the
  standard Godot 4.7 binary. A release Web export and the GitHub-to-itch.io
  deployment also completed successfully.
- The local Mono binary remains an environment problem because its Snap .NET
  runtime cannot load `hostfxr`; use the standard Godot 4.7 build for project
  validation until that installation is repaired.

## Audit and planning tasks

| Task | State | Evidence | Notes |
| --- | --- | --- | --- |
| `AUD-001` | Complete | `8c485b9`, `VALIDATION_CHECKLIST.md` | Checklist exists and was used during startup recovery. |
| `AUD-002` | Complete | `docs/refactor/ARCHITECTURE_NOTES.md` | Current boot/scene flow, six autoloads, runtime paths, signals, inputs, collision, tile/A*, rendering, Peon/minecart, UI, and deployment contracts are recorded with static/runtime confidence boundaries. |
| `AUD-003` | Complete | `6ea2281`, `ARTIFACT_CLASSIFICATION.md` | Classification only; it did not authorize bulk cleanup. |
| `AUD-004` | Complete with execution updates needed | `914ad47`, `TARGET_STRUCTURE.md` | The move protocol exists. Status annotations were incomplete until this ledger task. |
| `MCT-001` | Complete | `docs/refactor/MINECART_CHARACTERIZATION.md` | Minecart spawn, rail-following, path extension, gem loading, passive income, stored-gem delivery, node ownership, and signal routing are characterized for the current baseline. |
| `AUD-005`–`AUD-008` | Pending | Backlog only | No claim of implementation. |
| `AUD-009` | Incomplete | No focused Peon characterization fixture | Runtime fixes landed, but the specified repeatable behavior scenarios do not exist. |
| `AUD-010` | Partially superseded, not complete as specified | `2cfe100` | A Peon return-loop fix landed without the `AUD-009` regression fixture required by the task. Do not mark the task complete retroactively. |
| `AUD-011`–`AUD-016` | Pending | Backlog only | No claim of implementation. |

## Migration tasks

| Task | State | Evidence | Notes |
| --- | --- | --- | --- |
| `MOV-001` | Pending | No matching move commit | Content-check tools remain at root. |
| `MOV-002` | Pending | No matching move commit | Debug weight scripts remain at root. |
| `MOV-003` | Complete | `2ab5d36` | Controls scene/controller moved and references updated. |
| `MOV-004` | Complete | `1b41aea` | Pause overlay moved and references updated. |
| `MOV-005` | Complete | `8e577f5` | Level-up overlay moved and references updated. |
| `MOV-006` | Complete | `61cd22e` | Shared `Button.png` and `MenuPanel.png` assets moved. |
| `MOV-007` | Complete | `757cb50` | Coin/XP drop group and XP art moved. |
| `MOV-008` | Complete | `dd6fbcc` | Dwarf art family moved. |
| `MOV-009` | Complete | `ad6d6de` | Rat art family moved. |
| `MOV-010` | Complete | `6481f0f` | Lexicon scene/controller moved and probes updated. |
| `MOV-011` | Pending | Backlog only | The contract baseline and minecart characterization are complete; move the transport scene group only when the batch is intentionally started. |
| `MOV-012` | Blocked | Backlog only | Requires `AUD-009` and any resulting focused Peon regression repair. |
| `MOV-013`–`MOV-029` | Pending | Backlog only | Do not infer readiness from task numbering. Apply each task's prerequisites. |

## Upgrade-menu track

Upgrade-menu stabilization remains the first priority in `AGENTS.md`, but its
history contains competing approaches:

- Current `main` uses the restored handcrafted menu plus later targeted fixes
  and startup compatibility changes.
- `assistant/foundation-cleanup` contains a large alternative scene/controller
  rewrite based on the older commit `999e24a`.
- Do not merge or rebase that branch wholesale. Recover an individual idea
  only through a new, focused task against current `main`, with a complete
  before/after path and behavior review.

## Open GitHub work at ledger creation

- PR #11, `fix/ability-upgrade-cards`, is conflicting with current `main` and
  touches files changed by the reconciliation/startup work.
- PR #2, `fix/shaman-sprite-scale-y-sort`, is conflicting with current `main`.
- Neither PR is part of the migration sequence. Triage each independently;
  do not resolve either as collateral work in a refactor move.

## Restart rule

Do not start `MOV-011` merely because it is the next number. The migration
crossed prerequisite boundaries during reconciliation, and transport behavior
is too coupled to move without a recorded contract.

The exactly one recommended next task is:

### MOV-011 — Move transport scene group

Group `minecart.tscn`, `minecart.gd`, and `.uid` only, with the now-recorded
characterization baseline. Keep rails and art out of this batch unless a new
reference search proves they belong with the transport scene move.
