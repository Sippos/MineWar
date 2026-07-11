# Refactor Progress Ledger

Status: authoritative restart point

Updated: 2026-07-11

Baseline: `main` at `a2527ac` after the upgrade-menu hierarchy cleanup merge and push.

## Purpose

This ledger records what actually landed, what remains pending, and which task
is safe to start next. Planning details remain in `PROJECT_AUDIT.md` and
`TARGET_STRUCTURE.md`; this file owns execution status when those documents
and Git history differ.

## Current repository state

- Documentation recovery landed in commit `2daab5d`.
- `MOV-011` landed in commit `f16f045` and was merged into `main` as `8f33c82`.
- The unrelated local Git MCP connector files remain preserved only in ignored `.godot/refactor_recovery_20260711/` storage and are not part of the refactor commits.
- Local `main` and `origin/main` are synchronized at `a2527ac`.
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
| `MOV-011` | Complete and merged | `f16f045`, merge `8f33c82` | Scene/script/UID moved; Base preload and scene script path updated; Godot scan, scene load, script outline, and level load passed for changed resources. |
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

## Upgrade-menu baseline batch

Branch `refactor/upgrade-menu-baseline` inspects the current menu before structural cleanup. The scene contains deeply duplicated `GoldPileIcon` and `BranchTitle` descendants that require a separate hierarchy cleanup after usage is mapped.

The first focused repair adds explicit `Rect2` and `Vector2` types in `upgrade_menu_ui_styler.gd`, resolving the current type-inference parse failure without changing layout or gameplay behavior.

## Upgrade-menu hierarchy cleanup

Branch `refactor/upgrade-menu-hierarchy` flattens the legacy decorative hierarchy without changing the visible layout. All 59 panel controls are now direct children with stable descriptive names. Stat cost labels, currency icons, section titles, button signals, and controller paths were preserved or updated explicitly.

Validation completed:

- `upgrade_menu.tscn` saved and force-reloaded successfully.
- The scene contains 61 nodes total: the CanvasLayer, Panel, and 59 direct panel children.
- No panel child contains nested decorative descendants.
- `upgrade_menu.gd` parses with all 47 functions and its `send_enemy` signal.
- `upgrade_menu_ui_styler.gd` parses with all 12 functions.
- A full Godot filesystem scan completed and settled.

## Player 2 ability-input repair

Branch `fix/p2-ability-inputs` addresses the Local VS initialization-order defect where both `HeroAbilities` controllers configured Player 1 secondary/ultimate actions before the parent VS scene assigned Player 2's final ID.

The controller now remembers the player ID used for input setup and re-runs `_ensure_inputs()` when the owning Player's ID changes.

Validation completed:

- `hero_abilities.gd` retained all 81 functions and passed Godot read/outline validation.
- A full filesystem scan completed and settled.
- Local VS reached `VSMode`.
- All four runtime actions existed: `p1_secondary`, `p1_ultimate`, `p2_secondary`, and `p2_ultimate`.
- Controller configuration matched final player IDs for both players.
- The repeated missing Player 2 action errors did not recur.
- The branch intentionally excludes the separate runtime-styler fix `a35f1a9`; the known stale deferred-node errors therefore remain on this isolated branch.

## Recommended next task

Commit and push `fix/p2-ability-inputs`. Then create an integration validation branch from `test/upgrade-menu-runtime`, merge the Player 2 input branch there, and finish Local VS upgrade-menu validation with both fixes present. Do not merge into `main` without explicit confirmation.
