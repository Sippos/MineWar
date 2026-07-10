# MineWars Remote Session Handoff

Updated: 2026-07-11

## Purpose

This file is the durable restart point for continuing MineWars work from a phone while the laptop hosts the local filesystem, Godot, and Git MCP servers.

## Connection model

- Repository: `/home/sebastian-berger/mining`.
- `localFS` must expose `/home/sebastian-berger/mining`.
- `localGD` must report a ready Godot session for project `Mining`.
- `localGit` must report the same repository and the expected branch.
- Godot AI normally listens on `127.0.0.1:8000` for MCP and `127.0.0.1:9500` for the editor WebSocket.
- The restricted Git MCP normally listens on `127.0.0.1:8001`.
- Do not launch duplicate servers while those ports are already occupied.
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
7. Do not assume the previous task was committed or pushed.
8. Preserve unrelated changes and work in one focused batch.
9. Prefer a task branch; do not edit directly on `main` when avoidable.

## Current authoritative repository baseline

- Baseline commit: `aba8253` on `main`, aligned with `origin/main` at the start of the 2026-07-11 recovery session.
- Godot version: 4.7 stable.
- The documentation recovery batch is on branch `refactor/recover-refactor-docs`.
- The batch restores the architecture notes, minecart characterization, progress ledger, this handoff, and status annotations in the planning documents.
- No gameplay or resource path changes belong in the documentation batch.

## Preserved uncommitted work

The previously mixed worktree was separated without discarding it. Recovery material is stored under ignored local paths inside:

`.godot/refactor_recovery_20260711/`

That storage contains the partial `MOV-011` minecart move and the unrelated local Git MCP connector files. Do not commit `.godot/` content. Restore only the files required for the next focused branch.

## Next safe task after documentation recovery

`MOV-011 — Move transport scene group`

Scope only:

- `minecart.tscn`
- `minecart.gd`
- `minecart.gd.uid`
- the required preload/path updates
- progress and handoff updates

Keep rail scenes, rail art, transport art, connector tooling, and unrelated cleanup out of that batch.

## Validation and completion rules

Before committing a batch:

1. Validate every changed `res://` path.
2. Run a Godot filesystem scan and wait for it to settle.
3. Inspect editor and game errors from a fresh validation run.
4. Inspect the full Git diff and staged diff.
5. Confirm unrelated files are absent from the commit.
6. Update `REFACTOR_PROGRESS.md` and this handoff.
7. Commit with a focused message and push the task branch.
8. Merge into `main` only after successful validation and explicit confirmation.
9. Push `main` only after confirming the merge result.
