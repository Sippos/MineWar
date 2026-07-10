# MineWars Validation Checklist

Baseline recorded for AUD-001 on 2026-07-10. Checkbox state in the reusable sections is intentionally blank; check an item only when it is performed for a particular task.

## 1. Purpose

This document defines the minimum baseline checks to perform before and after every future MineWars refactor task. It is a characterization aid, not a claim that existing behavior is correct.

- **Automated checks** are repeatable commands with inspectable output and exit status.
- **Editor checks** use Godot's scene/resource inspectors, debugger, output panel, and import status.
- **Runtime smoke tests** establish that the application starts, reaches a usable state, and exits.
- **Manual gameplay checks** exercise behavior that the current repository does not cover with a reliable automated suite.
- **Task-specific checks** add focused assertions for the files and runtime flow affected by one backlog item.

Record what was actually run. Never infer a pass from static inspection or from a process exit code alone.

## 2. Environment baseline

| Item | Confirmed baseline |
| --- | --- |
| Required Godot version | Godot 4.7, from `config/features`; CI downloads Godot 4.7 stable. Local executable: `/home/sebastian-berger/.local/bin/godot`, reporting `4.7.stable.mono.official.5b4e0cb0f`. |
| Renderer | GL Compatibility (`renderer/rendering_method` and mobile variant are `gl_compatibility`). Windows rendering-device driver is configured as D3D12. |
| Entry scene | `res://menu.tscn` (`run/main_scene`). Single-player then enters `res://main.tscn`, which instances `res://level.tscn`. |
| Autoloads | `Global` → `res://global.gd`; `_mcp_game_helper` → `res://addons/godot_ai/runtime/game_helper.gd`. The `godot_ai` editor plugin is enabled. |
| Expected development/deployment platform | Local development platform is not documented. Current environment is Linux. CI runs Ubuntu and exports Web to `build/web/index.html`; `main` is deployed to itch.io. |
| Launch command | `/home/sebastian-berger/.local/bin/godot --path .` |
| Short headless launch | `/home/sebastian-berger/.local/bin/godot --headless --path . --quit-after 3 --log-file /tmp/minewars-launch-check.log` |
| Editor parse/import check | `/home/sebastian-berger/.local/bin/godot --headless --path . --editor --quit --log-file /tmp/minewars-editor-check.log` |
| Scene-specific launch | `/home/sebastian-berger/.local/bin/godot --path . --scene res://menu.tscn` (or add `--headless --quit-after 3` for a noninteractive load probe). |
| Web export | CI uses the `Web` preset with Godot 4.7 and export templates. Local command, only when templates are already installed: `/home/sebastian-berger/.local/bin/godot --headless --path . --export-debug Web build/web/index.html`. Export writes generated output, so review/revert it after validation. |
| External dependencies | Godot 4.7 and matching Web export templates for local export. Online signaling uses Node.js plus npm package `ws` via `package.json`; it is not required for single-player. The installed Mono binary currently also attempts to locate .NET host libraries even though no C# source was identified. Do not install dependencies as part of validation. |
| Automated tests | No unified, documented first-party test runner. Root `test_*.gd`, `run_test*.gd/.tscn`, and Python probes are ad hoc and must not be treated as a passing suite without reviewing and invoking each relevant probe explicitly. The addon contains its own testing utilities. |
| Lint/format tooling | No configured first-party GDScript linter or formatter was confirmed. `git diff --check` is available for patch whitespace validation. |

If a different executable is used, record its path and `--version` output. Do not assume `godot`, `godot4`, export templates, Node.js, npm dependencies, a display server, controller hardware, or two online clients are available.

## 3. Pre-change checks

- [ ] Run `git status --short` and preserve all unrelated changes.
- [ ] Run `git branch --show-current` and record the branch.
- [ ] Inspect the existing diff (`git diff -- <relevant paths>`); identify unrelated uncommitted work.
- [ ] Record the exact task ID, objective, exclusions, and completion criteria.
- [ ] List files expected to change; stop if the needed scope expands materially.
- [ ] Trace the affected flow from entry scene through relevant scenes, scripts, resources, autoloads, and direct node paths.
- [ ] Select the relevant automated, editor, runtime, gameplay, and task-specific checks below.
- [ ] Run the strongest practical baseline validation before editing.
- [ ] Save the command, exit status, Godot output/debugger messages, and manual result.
- [ ] Record pre-existing errors/warnings separately so they are not attributed to the task.
- [ ] Re-run `git status --short` after Godot starts/imports; identify and revert only validation-generated changes, never unrelated user changes.

## 4. Static project validation

### Automated where the environment supports it

- [ ] Confirm engine/config readability: `/home/sebastian-berger/.local/bin/godot --version` and inspect `project.godot`.
- [ ] Parse scripts and load editor resources: `/home/sebastian-berger/.local/bin/godot --headless --path . --editor --quit --log-file /tmp/minewars-editor-check.log`.
- [ ] Search the log for `SCRIPT ERROR`, `Parse Error`, `ERROR`, `WARNING`, missing dependencies, failed loads, invalid UIDs, and import failures; do not equate exit code 0 with a clean log.
- [ ] Load an affected scene directly with `--scene res://PATH.tscn --headless --quit-after 3 --log-file /tmp/minewars-scene-check.log`.
- [ ] Search changed text resources for `res://`, `preload(`, `load(`, `ExtResource`, and script-inheritance paths; verify every target exists and preserves case.
- [ ] Verify both autoload targets in `project.godot` exist and parse.
- [ ] Search inheritance declarations (`extends`), including path-based inheritance such as `rail_item.gd` → `res://gem.gd`; confirm the parent exists and remains compatible.
- [ ] Review `$Node`, `%UniqueNode`, `get_node()`, `get_parent()`, and sibling-name dependencies against the affected `.tscn` hierarchy.
- [ ] Inspect runtime `InputMap.add_action`/`action_add_event` calls in `global.gd` and `world.gd` for duplicate/conflicting bindings. Input actions are currently created at runtime rather than declared in `project.godot`.
- [ ] Run `git diff --check`.
- [ ] Run `git status --short` and inspect `.godot/`, `*.uid`, `*.import`, `build/`, logs, and other unexpected generated-file changes.

There is no confirmed standalone command that proves all node paths, dynamically composed resource paths, or gameplay-dependent navigation paths. Repository-wide resource-path searches supplement but do not replace Godot loading.

### Godot editor inspection when automation is unavailable or insufficient

- [ ] Open Project Settings and confirm main scene, renderer, autoloads, enabled plugins, display stretch, and configuration warnings.
- [ ] Inspect the Output and Debugger panels after project scan; record all parser, scene, resource, and autoload messages.
- [ ] Open each affected scene and confirm it instantiates without missing dependencies or orphaned external resources.
- [ ] Check FileSystem import status and reimport errors without deliberately changing import settings.
- [ ] Confirm script base classes and exported/property types resolve.
- [ ] Confirm referenced node paths exist with exact names and expected node types.
- [ ] Inspect Input Map plus runtime registration code for duplicate events and conflicts.
- [ ] Inspect changed resources for broken UIDs, missing textures/scripts, and invalid subresource references.

## 5. Launch smoke test

Minimum interactive procedure:

- [ ] Start from the repository root with the confirmed Godot executable.
- [ ] Confirm the process remains running without a fatal parser/resource/autoload error.
- [ ] Confirm `menu.tscn` loads and the **MineWars** title and main menu appear.
- [ ] Confirm the menu accepts at least one harmless focus/navigation input.
- [ ] Review Output/Debugger for fatal errors before interaction.
- [ ] Close the game through normal window/application behavior; confirm it exits cleanly.

**AUD-001 result:** a three-frame headless launch returned exit code 0 and `_mcp_game_helper` registered, but the run logged missing .NET host libraries. Headless execution cannot confirm that the title/menu rendered, accepted input, or closed interactively. The editor validation command crashed first. Therefore the launch smoke test is **not passed; interactive runtime remains untested**.

## 6. Main-menu validation

- [ ] Initial focus is visibly on **Single Player** (`menu.gd` requests it deferred).
- [ ] Mouse hover/click activates each visible control once.
- [ ] Keyboard direction/Tab navigation reaches Single Player, local VS, online VS, Controls, and Lexicon; focus remains visible and logical.
- [ ] Enter/Space activates the focused button once.
- [ ] Controller D-pad navigation and A activation work. **Applies in current code:** `Global` registers D-pad/A/B mappings; requires controller hardware/manual test.
- [ ] Back/Escape closes Controls or hero-selection overlays and returns focus appropriately. Record behavior for the root menu separately; root-menu Back/Escape behavior is unconfirmed.
- [ ] Controls opens and closes without leaking input to the menu beneath it.
- [ ] Settings access: **not applicable—no settings menu/system was found.**
- [ ] Single Player opens hero selection; unlocked/locked states are correct; Start enters `main.tscn`/`level.tscn` exactly once.
- [ ] Local VS and online VS buttons enter their intended overlays/flows without accidental double activation.
- [ ] Rapid mouse/controller/keyboard activation does not create stacked duplicate overlays or multiple transitions.
- [ ] Input used to close/activate an overlay does not also activate a control in the scene behind it.
- [ ] `MainMenuBackground.png`, both menu-panel sprites, title, buttons, and `Beastary.png` lexicon button appear with expected scale/layering at the tested resolution.

## 7. Core gameplay smoke test

Use Single Player with the default unlocked Dwarf unless a task explicitly requires another hero. Record seed/run details if visible.

- [ ] From menu, open Single Player hero selection and start the run; `main.tscn` and its `level.tscn` instance load.
- [ ] Player spawns near the base with visible sprite, shadow, camera, and HUD.
- [ ] Move in all four directions using documented controls; animation/facing and camera follow are coherent.
- [ ] Walk into intact terrain from multiple directions; the player does not pass through solid tiles.
- [ ] Dig one reachable block; timing/damage stages, tile removal, fog/edge/front overlays, and navigation update consistently.
- [ ] Dig below/behind a top/front tile; player and foreground overlap in the expected order.
- [ ] Locate a buried gem cell; indicator is visible before digging and appropriate to its front/top presentation.
- [ ] Dig out the gem; collectible appears at the correct cell/height and remains visible.
- [ ] Pick up the gem; carrying/nearby behavior updates once without duplicate pickup.
- [ ] Return to the base and deliver it; carried count and HUD resource/currency value update exactly once.
- [ ] Interact with the base; upgrade/purchase UI opens and focus/input do not leak to gameplay.
- [ ] With sufficient resources, purchase a Peon (or the currently labelled worker); cost is deducted once and one worker spawns.
- [ ] Dig a connected route and leave a reachable gem; worker travels only through valid dug cells.
- [ ] Provide multiple/reordered targets; worker selects a reachable target coherently and does not select solid/unreachable space.
- [ ] Worker reaches a resource, picks it up, returns to Base, deposits exactly once, and resumes a valid state.
- [ ] Pause with Escape/Start; gameplay timers/movement stop while pause UI remains responsive. Resume without duplicate input.
- [ ] Restart behavior: **unconfirmed; no dedicated restart path was established.** If a restart control exists in the tested flow, verify a clean new run.
- [ ] Leave through pause/game-over to menu; peer/pause state is cleared and a subsequent run starts normally.

No item in this section was runtime-tested during AUD-001.

## 8. Visual and rendering checks

Test at the default window size if known at runtime, then at 1280×720 and 1920×1080; also test a smaller common web viewport such as 960×540. The project does not declare a base viewport width/height, so record actual sizes rather than assuming them.

- [ ] Player, Peon, enemy, base, gem, rails, and effects retain expected sprite scale and offsets.
- [ ] Y-sorting is stable while actors cross above/below each other and the base. `Level`, `BlockLayer`, `FrontWallLayer`, `DamageLayer`, and `FrontDamageLayer` currently participate in Y-sort.
- [ ] Background (`z=-5`), rails (`z=-1`), edges/damage (`z=1`), front gem overlay (`z=2`), fog (`z=10`), actors, and effects order correctly.
- [ ] Top/front tiles cover the lower portion of actors appropriately without hiding them completely.
- [ ] Buried gem indicators appear on the appropriate tile face and disappear/update after digging.
- [ ] Collectible gems layer correctly against actors, walls, rails, fog, and UI.
- [ ] A collectible rests/floats at the intended height above ground; its idle/tether motion stays inside visible tunnel bounds.
- [ ] HUD, upgrade, pause, controls, hero selection, level-up, and game-over UI remain above gameplay and do not improperly overlap one another.
- [ ] Main-menu and overlay panel backgrounds render, cover their contents, and do not obscure focus indication.
- [ ] Camera follows the correct player, respects world bounds/expected framing, and behaves correctly after respawn and in split-screen.
- [ ] Text, buttons, HUD, world, and backgrounds remain visible and usable at each tested resolution/aspect ratio; record clipping or stretching.

## 9. Collision and navigation checks

- [ ] Inspect player collision layer/mask and runtime raycasts; confirm intended terrain/enemy detection. Audit baseline: terrain uses physics layer 1; player raycasts use mask `5` (terrain plus enemy layer 3), and player adds enemy layer 3 to its mask.
- [ ] Player, enemies, and relevant projectiles collide with intact terrain and react correctly after a tile is dug.
- [ ] Gem pickup detection works through its `PickupArea` despite the gem body having layer/mask 0; one player/worker/cart claims it once.
- [ ] Base interaction/deposit areas detect intended bodies, ignore unintended bodies, and do not double-deposit.
- [ ] Peon navigation uses the world's A* and current `BlockLayer`; Peon layer/mask 0 is acknowledged and manual wall/path behavior is verified.
- [ ] Workers never cross solid walls, including diagonal corners and newly changed terrain.
- [ ] Unreachable gems are not selected repeatedly in a tight loop; worker chooses another valid action.
- [ ] A worker recovers when its target disappears or its current path becomes invalid.
- [ ] Multiple workers select/claim targets without persistent overlap, duplicate pickup/deposit, or starvation.
- [ ] Enemies stay on valid paths, collide/attack intended player/base targets, and recover when terrain/path state changes.
- [ ] Hazard/projectile checks apply to currently implemented base spikes, player stomp, magic orbs, and Shaman totems; no separate generic hazard scene was confirmed.

## 10. Save and settings checks

Current static baseline: `Global` saves only `unlocked_heroes` with `FileAccess.store_var()` to `user://savegame.save`. There is no schema/version metadata. `seen_monsters` is not persisted. No first-party audio system, settings menu, `ConfigFile`, display setting, or input-rebinding persistence was confirmed.

- [ ] Settings persistence: **not applicable/absent.** Reassess when implemented.
- [ ] Audio volume: **not applicable/absent.** No first-party audio player/assets were confirmed.
- [ ] Display mode persistence: **not applicable/absent.**
- [ ] Input settings persistence/rebinding: **not applicable/absent; runtime bindings are created in code.**
- [ ] Tutorial completion state: **unconfirmed/likely absent; no persisted tutorial state was found in the inspected save code.**
- [ ] Trigger a hero unlock, confirm `user://savegame.save` is created, restart, and confirm the unlocked hero remains available.
- [ ] With a valid existing save, launch and confirm `unlocked_heroes` loads without changing unrelated state.
- [ ] With no save, launch and confirm default `Dwarf` availability and no fatal error.
- [ ] With a deliberately corrupted disposable save in an isolated test user-data directory, record behavior. **Current code only type-checks the loaded value; corruption handling is unconfirmed. Never overwrite a developer's real save.**
- [ ] After a project change, load a copy of a pre-change save and verify compatibility; document any migration/version requirement.
- [ ] Confirm session-only encyclopedia/tutorial-like state is not mistakenly reported as persisted.

## 11. Error and warning baseline

Runtime validation was attempted but could not be completed. The behavioral baseline is therefore based on static inspection plus a limited headless startup probe, not an interactive playthrough.

| ID / title | Relevant message | Occurrence / affected system | Severity | Pre-existing for future tasks? | Blocks later work? |
| --- | --- | --- | --- | --- | --- |
| ENV-DOTNET-001 — Mono host unavailable | `snap-confine has elevated permissions and is not confined...`; `.NET: One of the dependent libraries is missing`; `.NET: Failed to load hostfxr` | Both editor check and headless project launch, during Mono/.NET initialization | High for reliable local validation | Yes—observed before AUD-001 document creation and also recorded by `PROJECT_AUDIT.md` | Blocks editor parse validation and trustworthy local runtime validation with this binary; does not establish a project-source defect |
| ENV-CRASH-001 — Editor check crash | `handle_crash: Program crashed with signal 11` | `--headless --editor --quit`, after the hostfxr failure | High | Yes | Blocks automated editor/project scan in this environment |
| ENV-DISPLAY-001 — No GUI display | `Gtk-WARNING ... Failed to open display` | Headless commands when the Mono failure attempted to show a dialog | Medium/environmental | Yes | Blocks interactive visual/menu/gameplay checks in this session; headless probes remain possible but incomplete |
| CFG-INPUT-001 — runtime duplicate-input risk | `Global` and each `world.gd` instance call `InputMap.action_add_event`; local VS creates two worlds | Static inspection; input bootstrap | Warning / suspected behavior risk, not runtime-confirmed | Yes | Does not block documentation; must be checked around input or local-VS changes |
| TEST-001 — no unified suite | No documented command aggregates or asserts the root ad hoc probes | Test/tooling inventory | Warning / coverage gap | Yes | Does not block work, but requires manual and targeted validation |

The short headless launch returned 0 and registered `_mcp_game_helper`; it still emitted ENV-DOTNET-001. No new GDScript parse error, missing resource error, or project-specific warning was captured, but the failed editor scan means their absence was **not proven**. The static resource-path audit cited in `PROJECT_AUDIT.md` found no missing first-party `res://` targets.

## 12. Post-change checklist

- [ ] Review `git diff` in full.
- [ ] Confirm only expected files changed; separately preserve all pre-existing unrelated changes.
- [ ] Run `git diff --check`.
- [ ] Repeat relevant static/project/scene checks and retain logs/exit statuses.
- [ ] Launch the game and complete the launch smoke test.
- [ ] Test the exact affected runtime flow.
- [ ] Test one adjacent, expected-unaffected flow.
- [ ] Check console, Output, and Debugger for new errors/warnings relative to baseline.
- [ ] Check affected scenes and FileSystem/import state for missing resources.
- [ ] Confirm no unrelated controls, gameplay, rendering, collision, save, or scene transitions changed.
- [ ] Check `git status --short` for generated metadata/output and revert only task-generated artifacts.
- [ ] Document every manual check not performed and why.

## 13. Task-specific validation template

Copy this block into the task report, PR, or appropriate validation record:

```text
Task ID:
Task objective:
Affected systems:
Expected files:

Pre-change baseline result:
Automated checks performed (command, result, exit status):
Editor checks performed:
Runtime/manual checks performed:

Passed checks:
Failed checks:
Known pre-existing failures:
New regressions:

Files changed:
Remaining risks and manual checks:
Final result: PASS / CONDITIONAL PASS / FAIL
Rationale:
```

Use **conditional pass** only when the implemented scope is supported by completed checks but named environment/hardware/manual checks remain. Use **fail** for a new regression, a required failed check, or insufficient evidence for the task's core objective.

## 14. Current baseline result

### Confirmed working

- Git inspection commands work; repository is on `main` and the pre-existing `AGENTS.md` modification was identified.
- The installed executable responds to `--version` and `--help` as Godot `4.7.stable.mono`.
- A three-frame headless project start returned exit code 0 and registered `_mcp_game_helper`; this confirms only partial engine/autoload startup, not a successful rendered launch.
- The validation attempts did not leave new Godot-generated tracked or untracked files in `git status`.

### Confirmed failing

- Headless editor/project parsing crashes with SIGSEGV after the installed Mono build fails to locate `hostfxr` through the local Snap/.NET environment.
- Both attempted Godot modes log the .NET host-library failure; GUI dialog creation also reports no display.

### Statically inspected only

- Godot version/config features, renderer, entry scene, autoloads, display stretch, Web export preset/CI, scene flow, input registration, save implementation, collision/rendering setup, menu focus requests, worker dependencies, and available ad hoc probes.
- `PROJECT_AUDIT.md` reports no missing first-party `res://` targets from its static check; AUD-001 did not obtain a successful Godot resource scan to independently promote that result to runtime-confirmed.

### Not tested

- Interactive launch/title/menu rendering and normal close.
- All menu mouse, keyboard, controller, focus, overlay, and double-activation behavior.
- Core mining, gem, deposit, purchase, Peon, combat/wave, pause/resume, restart/leave, local VS, online VS, death/respawn, and Web-export behavior.
- Visual layering, camera, resolutions, collision/navigation edge cases, save creation/loading/corruption/compatibility, and any ad hoc root test probe.

### Blocked by environment or missing tools

- Reliable automated Godot editor parse/import validation: blocked by the local Mono/.NET host failure and crash.
- Interactive visual/gameplay testing: blocked in this session by the unavailable GUI display; controller and multi-client hardware/environment were also unavailable/unconfirmed.
- Local Web export was not attempted because installed matching export templates were not confirmed and export generation was unnecessary for this documentation-only task.
- Online signaling validation was not attempted; Node/npm availability and installed `ws` dependency were not established because online behavior was outside the minimum safe baseline run.
