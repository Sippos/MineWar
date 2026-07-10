# MineWars Remote Session Handoff

Updated: 2026-07-11

## Purpose

This file is the durable restart point for continuing MineWars work from a phone while the laptop hosts the local filesystem, Godot, and Git MCP servers.

## Connection model

- Repository: `/home/sebastian-berger/mining`.
- `localFS` must expose `/home/sebastian-berger/mining`.
- `localGD` must report a ready Godot session for project `Mining`.
- `localGit` must report the same repository and expected branch.
- Quick Tunnel URLs change after restart; update the matching ChatGPT connector whenever a tunnel URL changes.
- The laptop must remain awake, online, and running Godot plus the MCP/tunnel processes.

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

## Current branch state

- Documentation recovery commit: `2daab5d` on `refactor/recover-refactor-docs`, pushed to origin.
- Active task branch: `refactor/mov-011-minecart`.
- The task branch starts from `2daab5d`, not directly from `main`.
- `main` and `origin/main` remain at `aba8253` until explicit merge confirmation.

## MOV-011 completed scope

The task branch moves only:

- `minecart.tscn` to `res://scenes/entities/transport/minecart/minecart.tscn`
- `minecart.gd` and its UID to `res://scripts/gameplay/transport/minecart/`
- the Base preload path
- the scene-to-script resource path
- the progress ledger and this handoff

Rails, rail art, minecart art, connector tooling, and unrelated cleanup are outside the batch.

## Validation completed

- Godot 4.7 filesystem scan completed and settled.
- The moved minecart scene opened successfully and retained its expected five-node hierarchy.
- The moved script parsed for symbols and retained 28 functions.
- `level.tscn` opened successfully after the move.
- Godot resource search finds the moved scene and script only at their new paths.
- Current editor errors are pre-existing baseline errors in unrelated scripts/imports; no error references the moved minecart paths.

## Preserved unrelated material

Ignored recovery material remains under:

`.godot/refactor_recovery_20260711/`

It includes the unrelated local Git MCP connector files. Never commit `.godot/` content.

## Next required actions

1. Inspect the complete unstaged diff and confirm only the intended `MOV-011` files are present.
2. Commit with a focused message.
3. Push `refactor/mov-011-minecart`.
4. Stop for explicit confirmation before merging into `main`.
5. After confirmation, merge carefully, inspect the merge result, and only then push `main` with explicit confirmation.

## Merge rule

Do not merge either `refactor/recover-refactor-docs` or `refactor/mov-011-minecart` into `main` without explicit user confirmation. Because the minecart branch contains the documentation commit in its ancestry, merging the minecart branch should include both focused commits; do not merge both branches separately unless Git history is reviewed first.
