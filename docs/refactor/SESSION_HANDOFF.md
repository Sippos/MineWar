# MineWars Remote Session Handoff

Updated: 2026-07-11

## Purpose

This file is the durable restart point for continuing MineWars work from a phone while the laptop hosts the local filesystem, Godot, and Git MCP servers.

## Mandatory restart procedure

Before changing files in a new chat:

1. Read `AGENTS.md`.
2. Read this file and `REFACTOR_PROGRESS.md`.
3. Confirm `localFS`, `localGD`, and `localGit` are connected.
4. Inspect the active Godot session and open scenes.
5. Fetch `origin`, then inspect branch, status, remotes, and latest commit.
6. Review every staged, unstaged, and untracked change before editing.
7. Do not assume the previous task was committed, pushed, merged, or deployed.
8. Preserve unrelated changes and work in one focused batch.
9. Prefer a task branch; do not edit directly on `main`.

## Current repository state

- `main` and `origin/main` are synchronized at merge commit `8f33c82`.
- Documentation recovery is commit `2daab5d`.
- The minecart transport move is commit `f16f045` and is merged into `main`.
- Active task branch: `refactor/upgrade-menu-baseline`.
- Ignored recovery material remains under `.godot/refactor_recovery_20260711/`; never commit `.godot/` content.

## Upgrade-menu baseline findings

- `upgrade_menu.tscn` opens in Godot 4.7.
- The scene has 61 visible hierarchy entries in the inspection depth, including deeply nested duplicate `GoldPileIcon` and `BranchTitle` chains.
- `upgrade_menu.gd` directly references some of those nested labels for stat costs, so duplicate-node deletion must not be done blindly.
- `upgrade_menu_ui_styler.gd` had a type-inference parse failure for local rectangle calculations.
- The focused repair adds explicit `Rect2` and `Vector2` types only; it does not change menu layout, node names, prices, or gameplay behavior.

## Validation required before commit

1. Scan the Godot filesystem and wait for it to settle.
2. Confirm `upgrade_menu_ui_styler.gd` outlines successfully.
3. Open `upgrade_menu.tscn` and inspect the hierarchy.
4. Check editor logs and confirm no new error references the changed lines after reload; the Errors dock may retain stale baseline rows.
5. Inspect the complete Git diff and staged diff.
6. Confirm only the styler and the two refactor documents are included.
7. Commit with a focused message and push `refactor/upgrade-menu-baseline`.
8. Do not merge into `main` without explicit confirmation.

## Next structural batch

After this baseline repair is merged, create a separate upgrade-menu hierarchy cleanup branch. First map every script-referenced node path, then remove only proven decorative duplicates while preserving cost labels, button signals, focus behavior, and visible layout.
