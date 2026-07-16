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

Status: `COMPLETE`

### Validation record

- `player.gd` now exposes free-carry allowance, load, overload, and penalty helpers.
- Strength starts with one free gem and adds one more free gem at Strength 4, 7, 10, and so on; overload still slows movement by 15% per gem and remains capped at 75%.
- The investment panel now explains Strength's carrying thresholds, Agility's movement/attack/digging role, and Intelligence's ability/brood role in both button text and tooltips.
- Godot 4.7 headless project check completed with exit code 0 and no stderr.
- Godot Live characterization tests passed: 11/11 tests across collectible and peon suites, including a regression test for Strength carry thresholds and overload penalties.
- A real single-player smoke reached the hero-selection flow and entered the generated mine; runtime evaluation confirmed the carrying allowance changes from 1 at Strength 1 to 2 at Strength 4 with no carried load penalty.
- No economy prices, gem values, pickup/deposit rules, attack damage, or other unrelated systems were changed.

## Later queue

1. `POLISH-005` — Add a smaller physical collision footprint to the base while preserving its interaction Area2D. **COMPLETE**

### Validation record

- `base.tscn` preserves the original 128×64 Area2D interaction shape for healing, deposits, and upgrades.
- Added a separate `SolidBody2D` StaticBody2D while preserving the larger interaction area. Follow-up player feedback refined the blocker to a compact 72×32 rectangle centered inside the visible building, so the hero collides with the structure rather than an invisible strip beneath it.
- Godot 4.7 headless project check completed with exit code 0 and no stderr.
- Real single-player smoke reached hero selection and entered the generated mine; the interaction prompt remained active, the default hero spawn stayed at `(0, -32)`, and moving into the foundation produced one slide collision without displacement.
- Godot Live characterization tests passed: 11/11 tests across collectible and peon suites, including a regression test for Strength carry thresholds and overload penalties.
- Fresh game logs contained only the helper registration; remaining editor entries are pre-existing warnings in unrelated scripts.
- Files modified for this task: `base.tscn` and this progress document.

2. `POLISH-006` — Add one small cave reward prototype, such as a bag or boots, only after the earlier polish tasks are stable. **COMPLETE**

### Validation record

- Added a single-player Miner’s Satchel prototype that is revealed by the first block mined at depth 8 or deeper.
- The reward is disabled in VS mode, can spawn only once per world, and uses a contained procedural icon rather than introducing an unreviewed art dependency.
- Collecting the satchel grants exactly one additional penalty-free gem slot for the current run; repeated application and unknown reward identifiers are rejected.
- Reveal and pickup use bounded particle/label feedback: `SATCHEL FOUND` and `+1 FREE CARRY`.
- Godot 4.7 headless project check exited with code 0; the only stderr entry was the pre-existing headless Blender-path warning.
- Godot Live characterization tests passed: 12/12 tests across collectible, peon, and satchel reward suites.
- A real single-player run reached the generated mine. Runtime evaluation confirmed the depth-7 gate rejects spawning, depth 8 spawns exactly one reward, pickup changes free carry from 1 to 2, duplicate pickup is rejected, and the reward node cleans itself up.
- Follow-up polish keeps the satchel visible in-world for at least 0.8 seconds before collection becomes active, then adds a permanent top-HUD badge showing `MINER'S SATCHEL` and `+1 FREE CARRY`.
- The base physical footprint was refined again after playtest feedback: it is now a 72×32 rectangle centered at the base origin, fully inside the visible artwork and blocking the building’s central body rather than a lower invisible ledge.
- Added automated regression coverage for the persistent reward HUD and for keeping the physical base collision within visible sprite pixels.
- Fresh game logs contained only the MCP helper registration and the existing Rat discovery message.
- Files modified for this task: `player.gd`, `scripts/systems/world_generation/world.gd`, the Miner’s Satchel scene/script, the satchel regression suite, and this progress document.

3. `POLISH-007` — Make the base upgrade prompt contextual and resource-aware. **COMPLETE**

### Validation record

- `base.gd` no longer shows the upgrade prompt merely because the player starts inside the base interaction area.
- In single player, the prompt appears only when the player is in the base zone and can afford at least one current stat or gold-based base action.
- Stat affordability follows the existing `(level × 2) - 1` gem costs; gold affordability begins at the existing 10-gold base-action threshold.
- VS mode preserves its always-available Base Options prompt while the player is in range.
- The visible prompt was shortened to `E / Y  Upgrade Base`, given a high-contrast outline, and animated with a contained fade/pop when it becomes relevant.
- Healing, automatic gem deposits, interaction input, prices, and upgrade behavior were not changed.
- Godot 4.7 headless project check completed with no project parse errors; the only stderr entry was the pre-existing headless Blender-path warning.
- Godot Live characterization tests passed: 16/16 tests across base collision, base prompt, collectible, peon, and satchel suites.
- A real single-player run confirmed the player begins inside the interaction zone with zero resources and no prompt; adding one affordable gem showed the prompt at full opacity, and spending it faded the prompt out again.
- Fresh game logs contained only the MCP helper registration and the existing Rat discovery message.
- Files modified for this task: `base.gd`, `tests/test_base_prompt.gd`, and this progress document.

4. `POLISH-008` — Restore and lock the reviewed hero animation baseline after the Druid animation regression. **COMPLETE**

### Validation record

- Dwarf walking remains at scale `0.85`; the smaller hammer-swing artwork uses an independent `1.12` attack scale and corrected foot anchor so the hero no longer shrinks during attacks.
- Druid humanoid movement selects the walk texture before advancing frames. Mole Form uses the reviewed crawl sheet while moving and the separate reviewed action sheet while digging or attacking.
- Replaced the remaining Shaman mismatch with the approved matching walk/staff-action production pair. The sheets use the same model, camera, lighting, weapon hand, direction-row order, and grounded frame envelope.
- Removed the obsolete Shaman horizontal-mirroring and opposite-row remapping. Walk and action now share scale `0.58` and sprite position `(0, -5)`, eliminating the former shoulder/spacing jump.
- Replaced the Nerubian mismatch with the compact production walk/action pair rendered from one source rig. Both states use scale `0.46` at `(0, -9)` and share one silhouette, exposure, center, and uncropped frame envelope.
- Rerendered `undead_minion_walk_spritesheet_25d.png` from the original `undeadMinion` Blender rig and `UndeadMinion_Walk` action using the complete animation envelope. All 64 frames retain transparent margins; the minion scene uses scale `0.56` at `(0, -8)`.
- Added `docs/HERO_ANIMATION_BASELINE.md` to record authoritative sheets, fitted scales, anchors, direction rules, the Undead-minion atlas, and regression expectations.
- Expanded `tests/test_hero_animation_baseline.gd` to cover sheet import/layout, Dwarf fit, corrected Shaman row/ground alignment, substantial Shaman/Nerubian stride motion, matched Nerubian paths and fit, Druid humanoid walking, Mole state selection, and the Undead-minion safe-margin scene fit.
- A clean animated review using the exact current production assets and runtime fits confirmed the grounded Shaman walk/action pair, matched uncropped Nerubian movement/action silhouettes, and clean Undead-minion rendering in right, diagonal, down, and left directions.
- Godot 4.7 headless project/import check exited with code 0 and no project parse/import failure.
- Godot Live characterization tests passed: **26/26** across base collision, base prompt, collectible, hero animation, peon, and satchel suites.
- The temporary review scenes and MCP autoload/editor configuration were removed, and `project.godot` was restored to the repository version.

## Completed task

ID: `POLISH-009`

Title: Restore reliable hero ability and compact base-upgrade cards

Status: `COMPLETE`

### Validation record

- Ported the still-relevant intent from GitHub PR #11 onto the current project layout without replacing newer local gameplay work.
- The shared hero level-up menu now uses explicit `TextureRect` and `Label` children for ability icons, names, ranks, descriptions, and lock reasons instead of depending on fragile `Button` icon/text rendering.
- Narrow and split-screen-sized views use a scrollable one-column ability layout; wider views retain a scrollable two-column layout.
- Missing icons receive a visible fallback, empty option sets and missing controllers show readable error text, and locked ultimate abilities remain disabled with their hero-level requirement visible.
- `player.gd` now passes the exact leveling player into the menu, preventing split-screen ambiguity while preserving the existing upgrade signal flow.
- The compact base-upgrade overlay now uses the same explicit child-card approach, keeps costs readable, and labels already-owned unlocks as `OWNED`.
- Godot 4.7 headless editor/project check exited with code 0; the only stderr entry was the existing headless Blender-path warning.
- Focused Godot Live regression coverage passed **4/4** tests for explicit icon/label content, visible lock reasons, compact base-upgrade costs, and owned-state labeling.
- The broader suite reported **29/30** passing; the remaining Nerubian walk-motion assertion is unrelated to this UI task and belongs to the existing animation worktree.
- Real game-side visual capture was unavailable because the current project configuration does not include the `_mcp_game_helper` autoload. The bounded headless game process launched and stayed active until the validation timeout, with only Godot shutdown/leak diagnostics after forced termination.
- Files modified for this task: `scripts/ui/menus/level_up/level_up_menu.gd`, `compact_vs_upgrade_menu.gd`, the targeted level-up call in `player.gd`, `tests/test_upgrade_card_ui.gd`, and this progress document.

## Completed task

ID: `POLISH-010`

Title: Complete real-game validation and split-screen input routing for upgrade cards

Status: `COMPLETE`

### Validation record

- Completed real single-player validation through the main menu, hero selection, generated mine, and the actual `Player.level_up()` path.
- At 1152×648, the first live pass exposed clipped two-column content and zero-size icon controls. The level-up layout now switches to the compact one-column presentation at viewport widths below 760 pixels, keeps icon controls at a nonzero minimum size, wraps headings, and clips child content to each card.
- Single-player selection upgraded Ground Stomp from rank 1 to rank 2 for the exact player, removed the menu, and resumed the paused tree.
- Completed real local-VS validation with two 570×648 subviewports. Player 1 and Player 2 each received a readable menu confined to their own viewport, with the locked ultimate and its level requirement visible.
- Added a guarded VS input bridge that runs while paused and forwards only recognized UI or active-player movement/interact actions from the parent viewport into the subviewport containing the active level-up menu. Mouse routing and normal gameplay movement remain unchanged.
- Live keyboard validation moved focus from Ground Stomp to Throwing Hammer in each subviewport, confirmed the focused card, upgraded only the active player's Throwing Hammer from rank 0 to rank 1, closed the correct menu, and resumed gameplay.
- Focused `upgrade_card_ui` coverage passes **5/5** tests with 21 assertions, including nonzero icon geometry, wrapped/clipped card content, locked and owned states, and player-specific VS action mapping.
- The complete Godot Live regression suite passes **31/31** tests across seven suites.
- The retained `run_test.gd` editor parse messages predate this task and did not occur as current-run errors or block the validated launch-router and local-VS flows.
- Files modified for this task: `scripts/ui/menus/level_up/level_up_menu.gd`, `vs_mode.gd`, `tests/test_upgrade_card_ui.gd`, and this progress document.

## Completed task

ID: `POLISH-011`

Title: Center and tighten the main-menu button stack

Status: `COMPLETE`

### Validation record

- Live inspection at 1152×648 confirmed the four main actions were forced to a 280-pixel maximum and their stack sat about 40 pixels above the menu panel's visual center.
- The responsive layout now constrains action buttons to 190–232 pixels, uses the theme's true 55-pixel minimum height, and centers the complete stack around 51% of the viewport height.
- Compact layouts preserve title clearance, keep the final action inside the viewport, and narrow the buttons further instead of stretching them across the panel.
- A real themed 480×360 layout check confirmed an 8-pixel title gap, 5-pixel gaps between all four buttons, no overlap, and the final button ending at y=340.8.
- Real-game capture confirmed all four buttons are horizontally centered at x=576, visually balanced inside the panel, and retain comfortable hit areas.
- Initial keyboard focus remains on Single Player, and Down navigation moves correctly to VS Mode (Local).
- Focused `main_menu_layout` coverage passes **2/2** tests with 22 assertions at 1152×648 and 480×360.
- The complete Godot Live regression suite passes **33/33** tests across eight suites.
- Files modified for this task: `scripts/ui/menus/main/menu.gd`, `tests/test_main_menu_layout.gd`, and this progress document.

## Completed task

ID: `POLISH-012`

Title: Refine the main-menu title and bestiary action

Status: `COMPLETE`

### Validation record

- Reduced the responsive MineWars title from a 60-pixel maximum to a 48-pixel maximum and bounded it to a centered 220–520 pixel region so it fits the top sign instead of dominating the upper third.
- Compact title sizing now scales down to 34 pixels at 480×360 while preserving clear separation from the primary action stack.
- Resized the bottom-right encyclopedia/bestiary control to a responsive 44–64 pixel secondary action with explicit safe margins instead of the previous 48–96 pixel corner treatment.
- Added a visible `BESTIARY` caption, a `Bestiary` tooltip, pointing-hand mouse feedback, and explicit keyboard/gamepad focus routing from Controls to the bestiary action.
- Live 1152×648 validation measured the title at 48 pixels in a 520-pixel centered region, the bestiary at 58.32 pixels with a 20-pixel safe margin, and the caption fully on-screen above it.
- Live compact layout validation measured a 34-pixel title, a 44-pixel bestiary button with a 12-pixel safe margin, and all title, caption, button, and primary-action rectangles inside the 480×360 layout.
- Keyboard focus moved from Controls to Bestiary with Down, and Enter opened the real `res://scenes/menus/lexicon/lexikon.tscn` scene.
- Focused `main_menu_layout` coverage passes **2/2** tests with 33 assertions.
- The complete Godot Live regression suite passes **35/35** tests across nine suites.
- Files modified for this task: `scripts/ui/menus/main/menu.gd`, `tests/test_main_menu_layout.gd`, and this progress document.

## Completed task

ID: `POLISH-013`

Title: Recompose the hero-selection layout inside the menu panel

Status: `COMPLETE`

### Validation record

- Live 1152×648 inspection confirmed the previous content began only 18 pixels inside an ornate 820×520 panel, the ability list retained a 48-pixel dead inset, navigation appeared as ambiguous tiny arrows, and Back occupied a separate row against the lower frame.
- The selector now uses the artwork's real safe interior: 86-pixel desktop side insets, an 18-pixel ability-content inset, a 24-pixel portrait-to-ability gap, and a 32-pixel lower safe margin.
- Portrait, hero name, and ability preview now form one aligned content row; single player uses a compact HERO caption while local VS retains PLAYER 1 / PLAYER 2 captions.
- Replaced the ambiguous arrow-only controls with readable Previous and Next hero actions, sized responsively for desktop and compact layouts.
- Back and Start now share one centered footer row instead of consuming two vertical rows; Start remains the default focus and the explicit focus graph routes Start → Next Hero, hero navigation → footer, and Back ↔ Start.
- Compact 480×360 layout validation used a 451.2×350 panel with a 371.2×304 artwork-safe content region, 40-pixel side insets, a 92-pixel portrait, a 150-pixel ability minimum, and a 32-pixel lower inset. All content stayed inside the visible wooden interior.
- Live main-menu validation changed Dwarf to Shaman through the real Next action without leaving the selector. Keyboard navigation then moved Start → Next Hero → Start → Back → Start as intended.
- Focused `hero_selection_layout` coverage passes **2/2** tests with 16 assertions.
- The complete Godot Live regression suite passes **37/37** tests across ten suites.
- The retained intermediate `source_style` parse messages predate the final successful reload; the completed script launches with `current_run_errors=[]` and the helper live.
- Files modified for this task: `hero_selection_menu.gd`, `hero_selection_menu.tscn`, `tests/test_hero_selection_layout.gd`, and this progress document.

## Completed task

ID: `POLISH-014`

Title: Recompose unlockable HUD modules into player-left and base-right clusters

Status: `COMPLETE`

### Validation record

- Live inspection confirmed the previous HUD formed one loose top-left chain while the right side remained unused.
- Player modules now grow downward from the left cluster: stats, player health, XP, and cave rewards.
- Base modules now grow downward from the right cluster: base status, exact base health, wave information, and minimap.
- The layout reacts to viewport-size changes with 240-pixel desktop and 210-pixel compact module widths.
- Focused `hud_module_layout` coverage passes **2/2** tests with 10 assertions.
- The complete Godot Live regression suite passes **39/39** tests across eleven suites.
- Files modified: `hud.gd`, `tests/test_hud_module_layout.gd`, and this progress document.

No later gameplay-polish task is selected yet.

## Known pre-existing blockers and hazards

- The working tree is extremely dirty with unrelated code, assets, imports, animation experiments, and untracked files.
- `upgrade_tree_lab.gd` and `upgrade_tree_lab.tscn` are untracked experiments with parse errors.
- Backup sprite directories inside the project may produce duplicate UID warnings.
- Other pre-existing parse errors may prevent reliable runtime validation; do not repair unrelated systems merely to keep the queue moving.
- If `scenes/world/mine/level.tscn`, `hero_abilities.gd`, or another required dependency cannot parse, document the exact blocker and mark the Current task `BLOCKED` rather than claiming it passed.

## Completed task

ID: `POLISH-015`

Title: Recompose the gameplay HUD around semantic screen anchors

Status: `COMPLETE`

### Validation record

- Implemented the approved first mockup directly in the running game.
- Player portrait and resources remain top-left; purchased player health is a compact red bar beneath them and purchased stats follow below.
- Purchased XP is bottom-center, leaving the upper-left secondary-resource slot free for a future mana system.
- Large cave rewards move to bottom-left until dedicated small item sprites exist.
- Purchased wave information anchors top middle-right.
- The base is a sprite-only top-right card with no status text; frame color communicates danger and the purchased exact base-health bar sits beneath it.
- Player, base, wave, and XP bars use a compact shared treatment with centered values.
- Existing hero ability and cooldown controls remain bottom-right.
- Live 1152x648 validation confirmed the sprite-only base treatment and preserved the ability controls.
- Focused hud_module_layout coverage passes 2/2 tests with 15 assertions.
- The complete regression suite passes 39/39 tests across eleven suites.
- Files modified: hud.gd, tests/test_hud_module_layout.gd, and this progress document.

## Completed task

ID: `POLISH-016`

Title: Rebuild the base upgrade menu as a live-world upgrade tree

Status: `COMPLETE`

### Validation record

- Replaced the legacy 992×624 absolute-position artboard, previously scaled to at most 46% of the screen, with a runtime-built Dome Keeper-style upgrade tree.
- At 1152×648 the desktop tree uses a 806.4×594 left-side board and preserves an approximately 327.6-pixel live-world strip on the right.
- Added a central Base Core, visible branch connectors, and readable Survival, Player Info, Exploration, Base, Attributes, and Faction branches.
- The 750×720 scrollable canvas keeps 154×86 upgrade nodes readable instead of shrinking the entire menu; lower Attribute and faction upgrades remain accessible below the fold.
- Cards use explicit icon, title, cost, state, and detail content. They communicate AVAILABLE, INSUFFICIENT RESOURCES, REQUIRES MINIMAP, and OWNED states.
- Existing prices, purchase handlers, HUD unlock behavior, stat upgrades, faction actions, and economy values were preserved.
- Minimap → Enemy Sight is now represented as a real dependency. Live validation purchased Minimap, enabled Enemy Sight, then purchased Enemy Sight; gold changed from 120 to 50.
- Live validation purchased Strength through the lower tree, changing Strength from 1 to 2 and gems from 30 to 29 while the existing world-space particle burst remained visible.
- Opening the menu disables player movement without pausing the world. The camera pans the player, base, enemies, ability HUD, and upgrade VFX into the live right-side strip.
- Closing the menu restores the original camera offset, hides the board, and restores player movement.
- Dwarf rail and minecart nodes and the Shaman peon node remain gated by the active hero; the Wave Timer node remains unavailable in VS mode.
- Focused `upgrade_tree_layout` coverage passes **2/2** tests with 20 assertions, and focused `upgrade_tree_ui` coverage passes **3/3** tests with 30 assertions.
- The complete Godot Live regression suite passes **44/44** tests across thirteen suites.
- The retained `hero_selection_menu.gd` source-style parse messages predate this task; validated runs launched with `current_run_errors=[]` and the helper live.
- Files modified for this task: `upgrade_menu.gd`, `tests/test_upgrade_tree_layout.gd`, `tests/test_upgrade_tree_ui.gd`, and this progress document.

## Last queue update

`POLISH-001` through `POLISH-016` are `COMPLETE`. POLISH-016 replaces the tiny absolute-position base menu with a large scrollable live-world upgrade tree, preserves a visible combat/VFX strip, and leaves the complete suite at 44/44. No later polish task is selected yet.


## Completed task

ID: `POLISH-017`

Title: Recompose the base upgrade tree into horizontal category lanes

Status: `COMPLETE`

### Validation record

- Replaced the central branching chart with independent horizontal Survival, Player Info, Exploration, Base, and Faction upgrade lanes.
- Each lane reads left-to-right with visible connectors and retains the existing purchase costs, dependencies, and hero gating.
- Moved Strength, Agility, and Intelligence into a fixed 92-pixel QUICK STATS strip beneath the scrolling category area so gem upgrades never scroll out of reach.
- The branch canvas is now 980x610 and scrolls independently while the quick-stat strip and description remain fixed.
- Live 1152x648 validation confirmed the tree board still preserves the right-side gameplay strip and automatic camera framing.
- Scrolling from the upper rows to Base and Faction left the Quick Stats rectangle unchanged at y=467 with a 790x92 size.
- The camera-offset method only updates the existing Camera2D and a short Tween; it does not allocate another viewport or render target.
- Focused upgrade_tree_layout coverage passes 2/2 tests with 21 assertions.
- The complete Godot Live regression suite passes 44/44 tests across thirteen suites.
- Files modified: upgrade_menu.gd, tests/test_upgrade_tree_layout.gd, tests/test_upgrade_tree_ui.gd, and this progress document.

## Last queue update

`POLISH-001` through `POLISH-017` are `COMPLETE`. POLISH-017 converts the base menu into horizontal category trees with a permanently accessible quick-stat strip. No later polish task is selected yet.


## Completed task

ID: `POLISH-018`

Title: Rebuild upgrade categories as real parallel dependency trees

Status: `COMPLETE`

### Validation record

- Replaced category-only horizontal lists with explicit gameplay roots and real parallel child branches.
- HUD Modules now owns Player HP, Base HP, XP Display, Wave Timer, and Stat Display as independent sibling unlocks; no HUD element falsely depends on another.
- Survival now splits from a Hero root into Repair Hero and +20 Hero HP.
- Exploration preserves the real Minimap -> Enemy Sight dependency.
- Base now has real Repair Base and +25 Base HP actions, backed by base max-health state; Fortification is shown as a clearly disabled future defence branch using the existing fortification sprite.
- Faction keeps rail -> minecart for Dwarf and the game peon sprite for Shaman. Game sprites are used for the base, rail, minecart, and peon nodes; dedicated upgrade sprites are used for HUD and health nodes.
- Quick Stats remains fixed outside the scrollable tree for repeated gem spending.
- The live-world camera strip remains unchanged and lightweight.
- Focused upgrade-tree layout coverage passes 2/2.
- The complete Godot Live regression suite passes 44/44 across thirteen suites.
- Files modified: base.gd, upgrade_menu.gd, tests/test_upgrade_tree_layout.gd, tests/test_upgrade_tree_ui.gd, and this progress document.

## Last queue update

`POLISH-001` through `POLISH-018` are `COMPLETE`. POLISH-018 converts the upgrade board from category rows into coherent parallel dependency trees and adds real base repair/max-health mechanics. No later polish task is selected yet.


## Completed task

ID: `POLISH-019`

Title: Replace the upgrade board with a graph-driven parallel tech tree

Status: `COMPLETE`

### Validation record

- Replaced the hand-positioned upgrade layout with a data-driven graph definition and recursive automatic layout.
- Each graph node can own multiple parallel children; spacing is derived from subtree leaf counts rather than hard-coded row coordinates.
- HUD Modules now branches into independent Hero HP, Base HP, XP, Waves, and Stats paths.
- Hero HP is the gateway for Repair Hero and +20 Hero HP. Base HP is the gateway for Repair Base and +25 Base HP, which leads to the future Fortification path.
- Exploration preserves Minimap -> Enemy Sight. Faction preserves Rail -> Minecart for Dwarf and the independent Peon path for Shaman.
- Upgrade cards are icon-first and use a gold/gem sprite plus a number instead of repeated currency text. Long descriptions remain in the fixed detail panel.
- Compact state marks replace verbose per-card status sentences; unaffordable, locked, owned, and future states remain visually distinct.
- Quick Stats remains fixed outside the scrolling graph for rapid repeated gem purchases.
- The live-world camera strip, player-movement lock, purchase handlers, economy values, and world-space upgrade VFX remain unchanged.
- Live dependency validation confirmed Hero HP enabled only Repair Hero and +20 Hero HP while Base Repair remained locked; purchasing Base HP then enabled only Repair Base and +25 Base HP. Gold changed from 120 to 100.
- Focused upgrade_tree_layout coverage passes 2/2 with 23 assertions. Focused upgrade_tree_ui coverage passes 4/4 with 38 assertions.
- The complete Godot Live regression suite passes 45/45 across thirteen suites.
- Files modified: upgrade_menu.gd, tests/test_upgrade_tree_layout.gd, tests/test_upgrade_tree_ui.gd, and this progress document.

## Last queue update

`POLISH-001` through `POLISH-019` are `COMPLETE`. POLISH-019 replaces the upgrade-board presentation with a true graph-driven parallel tech tree while preserving the live-world strip and quick-stat dock. No later polish task is selected yet.


## Completed task

ID: `POLISH-020`

Title: Rework upgrade-tree sprite integration and visual paths

Status: `COMPLETE`

### Validation record

- Replaced raster upgrade-icon references with the authored SVG files in `assets/sprites/ui/upgrades` for hero health, base health, healing, max health, XP, wave timer, minimap, enemy sight, and fortification.
- Added a shared icon loader that crops spritesheets to a single AtlasTexture frame, preventing minecart and peon icons from displaying an entire sheet.
- Reduced graph nodes from 148x78 to 116x72, changed roots to icon-only 72x72 tiles, shortened depth spacing, and removed duplicated root labels.
- Kept Hero HP and Base HP as independent HUD gateways with their own parallel child paths. Exploration remains Minimap -> Enemy Sight; Dwarf faction remains Rail -> Minecart.
- Quick Stats remains fixed below the scrolling graph and was reduced to a 78-pixel strip.
- Live 1152x648 validation confirmed crisp SVG health/base/exploration icons, readable lower Exploration/Faction paths, and AtlasTexture use for minecart and peon game sheets.
- Focused upgrade-tree suites pass 6/6 and the complete regression suite passes 45/45 across thirteen suites.
- Files modified: `upgrade_menu.gd`, `tests/test_upgrade_tree_ui.gd`, and this progress document.

## Last queue update

`POLISH-001` through `POLISH-020` are `COMPLETE`. POLISH-020 replaces raster upgrade icons with the authored SVG set, crops game spritesheets to single frames, and tightens the graph into cleaner icon-first paths. No later polish task is selected yet.
