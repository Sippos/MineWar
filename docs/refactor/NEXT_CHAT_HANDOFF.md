# MineWars Refactor — New Chat Handoff

Paste the command below into a new ChatGPT project chat.

```text
Continue the MineWars refactor using the laptop connectors.

Repository: /home/sebastian-berger/mining
Expected branch: audit/peon-characterization
Main baseline: 597eba6

Start with a complete read-only inspection. Do not edit anything until it is finished.

1. Read:
   - /home/sebastian-berger/mining/AGENTS.md
   - /home/sebastian-berger/mining/docs/refactor/SESSION_HANDOFF.md
   - /home/sebastian-berger/mining/docs/refactor/REFACTOR_PROGRESS.md
   - /home/sebastian-berger/mining/docs/refactor/PEON_CHARACTERIZATION.md
2. Confirm localFS, localGD, and localGit are connected.
3. Confirm the active Godot session points to /home/sebastian-berger/mining/.
4. Fetch origin.
5. Inspect current branch, status, remotes, latest commit, staged changes, unstaged changes, and untracked files.
6. Inspect the active Godot scene and ensure no game process is running.
7. Trust inspected Git state over stale prose.

Completed and merged into main through 597eba6:

- Upgrade-menu hierarchy flattening.
- Deferred styler instance-ID safety.
- Player 2 secondary/ultimate input refresh.
- Compact VS unlock disabled states.
- Compact VS button focus.

Peon characterization completed on audit/peon-characterization:

- tests/test_peon_characterization.gd
- docs/refactor/PEON_CHARACTERIZATION.md
- 5 tests, 32 assertions, 0 failures, 0 skipped.
- No Peon gameplay source files were changed.

First action after inspection:

Run the Godot test suite named peon_characterization with verbose results and verify it remains green. Inspect fresh editor errors from a clean cursor.

Do not change Peon gameplay yet unless the characterization branch has already been reviewed and merged or I explicitly ask for a new fix branch.

Next intended focused refactor batch:

Reproduce the real single-player Shaman Peon tunnel-navigation defect where Peons appear to move upward or through walls.

Rules for that batch:

- Create a dedicated task branch; never edit main directly.
- Reproduce one concrete invariant violation before fixing it.
- Inspect Peon state, target, current path cell, next path cell, last_walkable_cell, BlockLayer source IDs, and A* solidity.
- Add one failing regression test for the confirmed violation.
- Handle one defect only.
- Run the full peon_characterization suite.
- Validate in a real single-player Shaman runtime scenario with multiple Peons.
- Inspect fresh editor/game errors and the full Git diff.
- Update SESSION_HANDOFF.md, REFACTOR_PROGRESS.md, and PEON_CHARACTERIZATION.md before commit.
- Commit and push the task branch.
- Do not merge into main without explicit confirmation.

Preserve unrelated changes and never commit .godot/ content or temporary MCP helper changes in project.godot.
```
