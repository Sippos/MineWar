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

- Documentation recovery was completed in commit `2daab5d` on branch `refactor/recover-refactor-docs`.
- `MOV-011` is completed on branch `refactor/mov-011-minecart`: the minecart scene, script, and UID moved to their transport directories, and all required paths were updated.
- The unrelated local Git MCP connector files remain preserved only in ignored `.godot/refactor_recovery_20260711/` storage and are not part of the refactor commits.
- Local `main` and `origin/main` remain at `aba8253` until explicit merge confirmation.
- The reconciled history is preserved by PR #16.
- The validated startup corrections are commit `4f5e269`.
- The working baseline previously launched the configured router, main menu,
  single-player world, local VS, level-up overlay, and lexicon probe under the
  standard Godot 4.7 binary. A release Web export and the GitHub-to-itch.io
  deployment also completed successfully.
- The current Godot editor still reports pre-existing baseline parse/import errors unrelated to `MOV-011`; the moved minecart scene and script load successfully.

## Audit and planning tasks

| Task | State | Evidence | Notes |
| --- | --- | --- | --- |
| `AUD-001` | Complete | `8c485b9`, `VALIDATION_CHECKLIST.md` | Checklist exists and was used during startup recovery. |
| `AUD-002` | Complete | `docs/refactor/ARCHITECTURE_NOTES.md` | Current boot/scene flow, six autoloads, runtime paths, signals, inputs, collision, tile/A*, rendering, Peon/minecart, UI, and deployment contracts are recorded with static/runtime confidence boundaries. |
| `AUD-003` | Complete | `6ea2281`, `ARTIFACT_CLASSIFICATION.md` | Classification only; it did not authorize bulk cleanup. |
| `AUD-004` | Complete with execution updates needed | `914ad47`, `TARGET_STRUCTURE.md` | The move protocol exists. |
| `MCT-001` | Complete | `docs/refactor/MINECART_CHARACTERIZATION.md` | Minecart spawn, rail-following, path extension, gem loading, passive income, stored-gem delivery, node ownership, and signal routing are characterized. |
| `AUD-005`–`AUD-008` | Pending | Backlog only | No claim of implementation. |
| `AUD-009` | Incomplete | No focused Peon characterization fixture | Runtime fixes landed, but the specified repeatable behavior scenarios do not exist. |
| `AUD-010` | Partially superseded, not complete as specified | `2cfe100` | A Peon return-loop fix landed without the `AUD-009` regression fixture required by the task. |
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
| `MOV-011` | Complete on task branch | `refactor/mov-011-minecart` | Scene/script/UID moved; Base preload and scene script path updated; Godot scan, scene load, script outline, and level load passed for changed resources. |
| `MOV-012` | Blocked | Backlog only | Requires `AUD-009` and any resulting focused Peon regression repair. |
| `MOV-013`–`MOV-029` | Pending | Backlog only | Do not infer readiness from task numbering. Apply each task's prerequisites. |

## Upgrade-menu track

Upgrade-menu stabilization remains the first priority in `AGENTS.md`, but its
history contains competing approaches. Do not merge or rebase
`assistant/foundation-cleanup` wholesale. Recover an individual idea only
through a new focused task against the current validated branch.

## Validation record for MOV-011

- Godot 4.7 filesystem scan completed and settled.
- `res://scenes/entities/transport/minecart/minecart.tscn` opened successfully.
- The moved scene retained its five-node hierarchy.
- `res://scripts/gameplay/transport/minecart/minecart.gd` parsed for symbols and retained all 28 functions.
- `res://level.tscn` opened successfully after the move.
- Godot resource search resolves the moved scene and script at their new paths.
- Existing editor errors concern unrelated baseline scripts/imports; no new error references the moved minecart paths.

## Recommended next task

Do not start another migration until `refactor/mov-011-minecart` has been reviewed and explicitly approved for merge. After merge, reassess the priority between upgrade-menu stabilization and the blocked Peon characterization track.
