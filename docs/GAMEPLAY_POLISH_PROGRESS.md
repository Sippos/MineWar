# MineWars Gameplay Polish Progress

This file is the authoritative one-task-at-a-time queue for normal chats and scheduled development runs.

Project: `/home/sebastian-berger/mining`

## Queue rules

- Complete at most one gameplay task per run.
- Preserve every unrelated working-tree change.
- Do not reset, clean, restore, switch branches, commit, push, deploy, or delete files unless the developer explicitly requests it.
- Do not intentionally modify `.godot/` cache/import files.
- A task may be marked `COMPLETE` only after its acceptance criteria have been tested as far as the current project state permits.
- When validation is blocked by pre-existing project errors, mark the task `BLOCKED`; do not claim completion.
- After completing the Current task, promote the Next task to `READY`, but do not begin it in the same scheduled run.

## Current task

ID: `POLISH-001`

Title: Immersive wave and base-danger communication

Status: `COMPLETE`

Ownership note: This task is explicitly authorized for the next normal or scheduled worker. No implementation changes for this task had been made when this queue file was created; `IN_PROGRESS` reserves it so the existing scheduled-worker decision rules will take ownership and finish it rather than guessing.

### Goal

Preserve the unlockable Dome Keeper-style HUD while ensuring that a player far underground can understand that a wave has begun, that the base is being attacked, and that the situation has become critical.

### Scope

- On wave spawn, show a brief high-priority message such as `Enemies have entered the mine.`
- Notify the HUD explicitly whenever the base takes damage.
- Add an always-available compact base-danger indicator without displaying exact health.
- Use three nonnumeric states based on base health: stable, damaged, and critical.
- Flash or pulse the indicator on each base hit.
- Add a screen-edge directional cue toward the base when the player is sufficiently far away.
- Avoid text spam on every individual hit.
- Keep the exact Base HP bar, Wave Timer, minimap, and enemy locations locked behind their existing upgrades.
- Do not add a repeated tutorial sequence.
- Do not add audio assets in this task.
- Do not change combat balance, wave timing, enemy stats, resource economy, or hero abilities.

### Likely files

- `scripts/systems/world_generation/world.gd`
- `base.gd`
- `hud.gd`
- `hud.tscn` only when an editable scene node is preferable to contained runtime UI

### Acceptance criteria

- A player digging far from the base can tell when a wave has started.
- A player can tell when the base is taking damage off-screen.
- A player can distinguish damaged from critical danger without seeing an exact number.
- Buying Base HP and Wave Timer still reveals meaningfully more precise information.
- Warnings work with different heroes and screen sizes.
- Repeated base hits do not produce unreadable notice spam.
- No unrelated gameplay or visual assets are changed.

### Required validation

- Inspect Git status and the exact pre-task diff before editing.
- Inspect fresh Godot editor/game errors rather than relying only on retained errors.
- Run the Godot project check after edits.
- Enter a real single-player run through hero selection when the project can boot reliably.
- Test wave-start communication.
- Test off-screen base-hit communication while the player is far from the base.
- Test damaged and critical states.
- Confirm locked exact HUD elements remain locked.
- Review the exact task diff and record all files changed.

### Validation record

- Godot project check completed in headless editor mode with exit code 0.
- Isolated `hud.tscn` runtime validation passed for:
  - stable, damaged, and critical nonnumeric base states;
  - wave-start notice text;
  - base-hit pulse feedback;
  - six-second repeated-hit notice cooldown;
  - immediate critical-state notice override;
  - screen-edge base-direction cue while more than 520 pixels away;
  - exact Base HP, Wave Timer, Wave Bar, and minimap remaining hidden.
- `hud.gd` loaded successfully in the isolated runtime and created `BaseStatus` and `BaseDirectionCue` nodes.
- Exact diffs were reviewed for all task-touched files.
- Real single-player validation completed through the main menu and hero selection using the Dwarf.
- The generated mine loaded with the real `Level`, `Player`, `Base`, and `HUD` nodes active.
- The real wave-spawn path created an enemy and displayed `Enemies have entered the mine.` while exact Wave Label and Wave Bar remained hidden.
- The real `Base.take_damage()` signal path produced damaged and critical states, hit pulse feedback, cooldown-based notice suppression, and a visible edge cue while the player was about 1,264 pixels from the base.
- Exact Base HP and minimap remained hidden throughout the test.
- The current game run produced no runtime errors; its only game-log entries were the MCP helper registration and the spawned Rat discovery message.
- Other pre-existing editor errors remain in `hero_abilities.gd`, `undead_minion.gd`, and upgrade-tree experiments. They were not repaired and did not prevent the validated Dwarf run.

### Files modified by this task

- `hud.gd` — added the compact nonnumeric base-state panel, hit pulse, notice cooldown, wave notice entry point, and directional base cue. Existing unrelated hero-portrait changes in this file were preserved.
- `base.gd` — forwards each base hit explicitly to the HUD and clamps health at zero.
- `scripts/systems/world_generation/world.gd` — sends one high-priority notice when a wave begins.
- `docs/GAMEPLAY_POLISH_PROGRESS.md` — recorded completed validation and promoted `POLISH-002` to `READY`.

## Completed task

ID: `POLISH-002`

Title: Improve mining, block destruction, gem reveal, pickup, and deposit feedback

Status: `COMPLETE`

Implementation has begun in the current local tree. Do not start `POLISH-003` until `POLISH-002` is either validated and marked `COMPLETE` or explicitly marked `BLOCKED`.

### Validation record

The contained feedback implementation is accepted after headless and real-run validation:

- `player.gd` emits throttled mining-impact feedback and a stronger final-break/gem-reveal event.
- `scripts/systems/world_generation/world.gd` creates contained mining, pickup, deposit, flash, and label effects.
- `scripts/gameplay/collectibles/gems/gem.gd` emits pickup feedback after a successful tether.
- `base.gd` emits deposit feedback for carried and directly deposited gems.
- A Godot 4.7 headless editor/project check completed successfully; duplicate UID warnings from local backup folders and the untracked `upgrade_tree_lab.tscn` parse error remain pre-existing and unrelated.
- GitHub Pages and Itch export workflows now clear and deterministically rebuild `.godot` imports before exporting, preventing stale `.ctex` preload failures.
- Real single-player smoke exercised rapid mining, final break/gem reveal, pickup, and carried/direct deposit feedback; 8 temporary feedback effects were created and 0 remained after cleanup.
- The validated run produced no project-specific runtime errors, and feedback remained bounded during the rapid-mining/deposit check.

### Scope and acceptance

- Repeated mining impacts are readable without becoming visually noisy.
- The final break is stronger than intermediate strikes and gem discovery is immediately recognizable.
- Pickup and deposit each have distinct feedback.
- No economy, gem frequency, upgrade price, or audio behavior changed.

POLISH-003 is now READY and was not started in this run.

### Intended scope

- Add clearer visual impact for mining strikes.
- Add a stronger final block-destruction burst.
- Add a distinct gem-reveal flash or particle response.
- Improve gem pickup feedback.
- Improve base-deposit feedback.
- Reuse contained effects and existing assets where practical.
- Do not add or generate audio assets yet.
- Do not change gem frequency, resource value, upgrade prices, or other economy balance.

### Intended acceptance criteria

- Repeated mining impacts are readable and satisfying without becoming visually noisy.
- The final break is clearly stronger than intermediate strikes.
- Discovering a gem is immediately recognizable.
- Pickup and deposit each have distinct feedback.
- Performance remains acceptable during rapid mining and multi-gem deposits.

## Completed task

ID: `POLISH-003`

Title: Conditional enemy health bars and stronger hit reactions

Status: `COMPLETE`

Implementation is limited to enemy combat readability. Do not change enemy health, damage, speed, rewards, wave timing, hero damage, or economy balance.

### Scope

- Keep untouched distant enemies free of health-bar clutter.
- Show an enemy health bar when damaged, targeted, or near the player.
- Fade ordinary enemy bars after combat inactivity.
- Keep the boss bar visible throughout its fight.
- Animate immediate and delayed health loss instead of snapping.
- Strengthen hit response with a contained flash, sprite punch, and short impact burst.

### Validation record

- enemy.tscn now contains an editable two-layer health bar that starts hidden.
- enemy.gd shows ordinary bars when damaged, targeted, or within 170 pixels of a player, then fades them after combat inactivity.
- Boss bars remain visible and use a 1.35x larger display.
- Current health animates quickly while the delayed damage layer catches up more slowly.
- Hits now combine a short overbright flash, sprite punch/jitter, and contained orange impact particles.
- Godot 4.7 headless project check exited with code 0.
- Real single-player Dwarf run booted through hero selection with no new project-specific runtime errors.
- Godot Live runtime evaluation confirmed damaged-bar visibility, current/delayed values, ordinary-bar fade to invisible after 3.6 seconds away, boss-bar visibility at range, and transient impact-particle cleanup.
- No enemy health, damage, speed, rewards, wave timing, hero damage, or economy values changed.
- Pre-existing editor warnings remain in mobile_controls.gd, match_flow.gd, hero_selection_menu.gd, player.gd, world.gd, map_bounds.gd, minecart.gd, and hud.gd; they did not originate in this task.

POLISH-004 is now READY and was not started in this run.

## Next task

ID: `POLISH-004`

Title: Connect Strength to free carrying allowance and clarify STR/AGI/INT effects

Status: `READY`

## Later queue

1. `POLISH-005` — Add a smaller physical collision footprint to the base while preserving its interaction Area2D.
2. `POLISH-006` — Add one small cave reward prototype, such as a bag or boots, only after the earlier polish tasks are stable.

## Known pre-existing blockers and hazards

- The working tree is extremely dirty with unrelated code, assets, imports, animation experiments, and untracked files.
- `upgrade_tree_lab.gd` and `upgrade_tree_lab.tscn` are untracked experiments with parse errors.
- Backup sprite directories inside the project may produce duplicate UID warnings.
- Other pre-existing parse errors may prevent reliable runtime validation; do not repair unrelated systems merely to keep the queue moving.
- If `scenes/world/mine/level.tscn`, `hero_abilities.gd`, or another required dependency cannot parse, document the exact blocker and mark the Current task `BLOCKED` rather than claiming it passed.

## Last queue update

`POLISH-001`, `POLISH-002`, and `POLISH-003` are `COMPLETE`. POLISH-003 passed the real enemy-health-bar and hit-reaction smoke checks; `POLISH-004` is `READY` and was not started in this run.
