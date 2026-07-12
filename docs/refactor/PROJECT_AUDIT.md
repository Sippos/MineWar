# MineWars Project Audit

This audit records the repository as inspected on 2026-07-10. It is a static analysis intended to support incremental planning; it does not implement the existing refactor plan or assert untested runtime behavior.

## 1. Project overview

- **Engine:** Godot `4.7` (`config_version=5`, GL Compatibility renderer). The installed local binary reports `4.7.stable.mono`, while CI downloads standard Godot 4.7 and its export templates.
- **Project identity:** `project.godot` names the application `Mining`; repository documentation calls it MineWar/MineWars.
- **Entry point:** `res://launch_router.tscn`, which routes ordinary clients to `res://scenes/menus/main/menu.tscn`.
- **Primary target:** Web export to `build/web/index.html`, deployed from `main` to itch.io by `.github/workflows/deploy.yml`.
- **Core loop:** select a hero, enter a generated mine, dig blocks, collect/deposit gems, purchase upgrades, and survive enemy waves. Local and experimental online VS modes add enemy purchasing and income.
- **Autoloads:** `Global` (`global.gd`) stores hero selection, unlocks, encyclopedia data, WebRTC objects, input setup, and save access. `_mcp_game_helper` belongs to the enabled `addons/godot_ai` editor/runtime integration.

## 2. Current directory overview

Most first-party files are in the repository root: 343 tracked root files were counted, including scenes/scripts, 76 PNGs, 74 Python utilities, generated `.import` files, test probes, configuration, and deployment files.

| Area | Current location and contents |
| --- | --- |
| Gameplay | Root-level `player.gd`, `world.gd`, `enemy.gd`, `peon.gd`, `base.gd`, `minecart.gd`, collectible and totem scripts/scenes |
| UI | Root-level menu, HUD, upgrade, pause, controls, lexicon, level-up, lobby, and hero-selection scenes/scripts |
| World assets | Root-level block, edge, fog, rail, background, overlay, and UI textures |
| Character assets | `character_sprites/`, plus several character-related imports still at root |
| Tooling | Roughly 74 root Python scripts named `build_*`, `fix_*`, `patch_*`, `generate_*`, `resize_*`, and `update_*` |
| Tests/probes | Root-level `test_*.gd`, `run_test*.gd/.tscn`, debug scripts, and a few Python image/content checks; no unified test runner command is documented |
| Documentation | `docs/PROJECT_VISION.md`, `docs/ARCHITECTURE.md`, and `docs/REFACTOR_PLAN.md` |
| Third-party | Large `addons/godot_ai/` plugin, enabled in `project.godot` |

The flat root obscures ownership and makes broad path changes risky. `.godot/`, `build/`, and imported metadata are generated concerns rather than source modules.

## 3. Main scene and runtime flow

The normal scene flow is:

1. `menu.tscn` displays Single Player, local VS, online VS, controls, and lexicon choices.
2. Hero selection is instantiated as an overlay. It writes `Global.hero_p1`, `Global.hero_p2`, and `Global.current_hero`.
3. Single player changes to `main.tscn`, a seven-line wrapper that instances `level.tscn`.
4. `level.tscn` instances `HUD`, `UpgradeMenu`, and `Base`, defines seven `TileMapLayer` nodes, and embeds the `Player`. Its root uses `world.gd`.
5. `world.gd` creates the A* grid and terrain, configures input, handles pause, maintains tile overlays, runs waves/income, and spawns enemies.

Local VS changes to `vs_mode.tscn`, which instances two `level.tscn` copies in subviewports and forwards purchased enemies across levels. Online VS goes through `online_lobby.tscn`, creates WebSocket/WebRTC peers stored in `Global`, then manually installs `vs_online.tscn` as the current scene. The online seed is passed but `vs_online.gd` notes that deterministic regeneration is not implemented.

Other transitions are direct: menu to lexicon; pause/game-over/lexicon back to menu. Controls and hero selection are overlays. Pause is added to the scene-tree root rather than owned by the active level.

## 4. System inventory

### Player systems

`player.gd` (718 lines) owns movement, collision rays, animation selection, hero visuals, digging, melee attacks, damage/death/respawn, gem carrying, stat upgrades, XP/level-up UI, stomp, magic orbs, and the Shaman totem wheel/casting. Hero identity comes from `Global`; many HUD and world calls use fixed sibling names.

### Digging and terrain

`world.gd` (476 lines) generates a fixed A* region and procedural block layers, tracks gem-bearing cells, updates fog/edge/front-wall/damage overlays, controls rail autotiling, refreshes minecart paths, and directs waves. `player.gd` chooses adjacent cells through four runtime-created raycasts, applies dig timing/damage, asks `world.gd` to remove cells, and spawns mined gems. Tile source IDs and atlas coordinates are numeric constants embedded across scripts and `level.tscn`.

### Gems and collectibles

`gem.gd` implements physics-based, tethered carried gems and group-based proximity. The player owns nearby/carried lists and deposit behavior. `Base` accepts player deposits and direct gem bodies. `coin_drop.gd` credits gold directly to `HUD`; `xp_drop.gd` credits the player. `rail_item.gd` subclasses `gem.gd` to reuse carrying but suppresses gem deposits. `minecart.gd` duplicates parts of pickup/tether registration and can consume gems into an internal count.

### Workers and transport

`peon.gd` (314 lines) uses string states, scans the global `gems` group, reads its parent world's A* and `BlockLayer`, finds reachable targets, carries one target to the sibling `Base`, and falls back to wandering. It has no physics collision layer/mask. `minecart.gd` (342 lines) creates/follows rail paths, extends rails toward the base, moves manually, creates passive income, stores gems, and emits the base's deposit signal directly.

### Enemies and hazards

`enemy.gd` owns enemy type data, wave scaling, textures, A* path rebuilding, movement/animation, base/player attacks, drops, encyclopedia discovery, and boss hero unlocking. All enemy balance values are hardcoded. Base spikes retaliate during attacks. Player stomp and Shaman magic orb/totems are additional combat/hazard interactions. There are no dedicated hazard scenes beyond these code paths.

### Base and upgrades

`base.gd` provides healing, deposit zone behavior, upgrade requests, health/game-over, faction sprite selection, and spawning rails, peons, and minecarts. `upgrade_menu.gd` (410 lines) owns prices, resource spending, HUD unlock state, stat purchases, healing, spikes, faction purchases, and VS enemy sends. It directly mutates `Player`, `Base`, `HUD`, and parent-world properties. `upgrade_menu.tscn` is 732 lines with deeply repeated purchase-row structures.

### HUD and menus

`hud.gd` (463 lines) owns gem/gold totals, health/stats/XP/wave displays, minimap rendering, mobile control creation, notices, Shaman wheel/status, respawn, and game-over navigation. Some important controls (game-over button, notice, stomp UI, totem UI) are built in code instead of `hud.tscn`. Other UI is split among `menu`, `hero_selection_menu`, `pause_menu`, `controls_menu`, `lexikon`, `level_up_menu`, and online lobby scenes.

### Input

Input actions are not declared in `project.godot`. `Global._ready()` adds UI/pause bindings, while every `world.gd` instance adds player keyboard/gamepad bindings. In local VS this runs twice; `InputMap.action_add_event()` can therefore add duplicate events. `mobile_controls.gd` simulates those actions, and `base.gd`, `player.gd`, and `world.gd` consume them independently.

### Audio, saving, and settings

No first-party audio stream, audio player, or `.wav`/`.ogg`/`.mp3` asset was found. No settings system or `ConfigFile` use was found. Saving is limited to `Global.unlocked_heroes`, serialized with `store_var()` to `user://savegame.save`; `seen_monsters`, settings, progression beyond unlocks, and schema/version metadata are not saved.

### Physics and rendering

Terrain TileSet physics uses layer 1. Enemies use collision layer 3 (`4`) and mask 1; the player adds enemy layer 3 to its mask and uses raycast mask `5` (terrain plus enemies). Base adds enemy layer 3 to its mask. Coin/XP drops use mask 1; gems, rails, minecarts, and peons use layer/mask 0 and rely on areas, groups, or manual movement.

`Level` is Y-sorted. `BlockLayer`, `FrontWallLayer`, `DamageLayer`, and `FrontDamageLayer` also enable Y-sort. Explicit Z values include background `-5`, rails `-1`, edges/damage `1`, front gem overlay `2`, magic orb `7`, fog `10`, and XP particles `10`. Mixed nested Y-sort, hardcoded Z values, and sprite offsets (`-24`, `-16`, `+8`) form an implicit rendering contract that is not documented or centralized.

## 5. Dependency and coupling problems

- `level.tscn` node names are an API: scripts repeatedly call parent/sibling paths such as `Player`, `HUD`, `Base`, `BlockLayer`, `RailLayer`, and deeply nested upgrade controls.
- `world.gd` mixes terrain generation, presentation masks, navigation, input registration, pause, waves, VS economy, spawning, and rail notifications.
- `player.gd` mixes actor control with terrain damage, inventory, combat, progression, hero-specific abilities, particles, and HUD control.
- `HUD` is the authoritative wallet for gold and gems; pickups and upgrades call UI methods to mutate game state.
- `upgrade_menu.gd` contains both UI behavior and economy/gameplay rules, then mutates other nodes directly.
- `Global` mixes persistence, content databases, input bootstrapping, selections, unlocks, and networking state.
- Enemy, peon, and minecart navigation all depend on the concrete parent world and tile-node names; their path strategies are separate and partly duplicated.
- Hero/enemy texture paths and Shaman totem metadata are duplicated among `global.gd`, `player.gd`, `enemy.gd`, `hud.gd`, and `shaman_totem.gd`.
- Local/online VS controllers reach into level internals (`ENEMY_SCENE`, `block_layer`, `income`) instead of using a narrow level interface.
- Signals exist for base/HUD and enemy sending, but other interactions bypass signals by accessing fields or emitting another node's signal.

## 6. Folder-structure problems

- Scenes, scripts, assets, test probes, generated imports, and maintenance utilities share the project root.
- Script/scene pairs cannot be discovered by subsystem without filename knowledge.
- Root image names are inconsistent (`First-Hit-Front` versus `First_Hitting`, `Medium-Brick-Front` versus `Medium_Front`, `Healthbar` versus `HealthBarRed`, and misspellings such as `Strenght`/`Ressources`). Renaming is unsafe until references and visual use are verified.
- Numerous similarly named generation/fix scripts preserve historical attempts without stating whether they remain reproducible or obsolete.
- Test scripts are mixed with production resources and may be included by the export preset's `all_resources` policy.
- `.tscn.txt` variants (`menu_free.tscn.txt`, `upgrade_menu_free.tscn.txt`) look like archived alternatives and require provenance checks.
- `main.tscn` is a thin wrapper whose purpose is unclear, but it is part of active scene flow and cannot be removed casually.
- The large third-party addon is mixed into the runtime configuration through both an enabled editor plugin and an autoload; its production/export necessity should be decided before restructuring.

## 7. Gameplay and UX problems visible from the implementation

These are static observations, not runtime-confirmed defects:

- Controls are hardcoded and displayed rather than configurable; there is no settings menu, audio, or persistence for preferences.
- Purchase buttons are deliberately kept enabled and opaque even when unaffordable; failed purchases provide no visible feedback in the examined methods.
- HUD unlock flags live only in the upgrade menu and are reset with the scene. Economy state lives in HUD, making progression and save support fragile.
- The Shaman selection/status UI, game-over button, and notices are code-created, making layout and controller focus harder to inspect in the editor.
- Hero availability is duplicated: selection offers Dwarf/Shaman, `Global.hero_data` also includes Mech, and unlock behavior is mode-specific.
- `seen_monsters` is not saved, so lexicon discovery appears session-only.
- Online play uses a hardcoded signaling URL and public STUN server; seed synchronization is acknowledged but not implemented, so terrain parity is unknown.
- Enemy contact damage is checked through slide collisions only while moving along a path; exact combat feel needs runtime verification.
- Peon targeting, wandering, and return behavior have several nearest-cell fallbacks and string states, indicating edge cases around unreachable gems and changed terrain.
- Minimap redraw scans a fixed 40-by-32 grid each frame while visible and globally queries all enemies; split-screen ownership and performance need testing.

## 8. High-risk areas

1. **`level.tscn` and tile resources:** it embeds source IDs, collision data, layer order, active scene instances, and node-name contracts. Any move or edit can affect most systems.
2. **Terrain/navigation contract:** digging changes tiles, overlays, A* solidity/weights, enemy routes, Peon routes, rail placement, and minecart paths.
3. **Rendering order:** world and actor visuals combine parent Y-sort, child offsets, layer Y-sort, and explicit Z indices. A seemingly cosmetic move can hide gems, actors, or front walls.
4. **Player decomposition:** `player.gd` contains the playable loop and hero-specific behavior; extraction without characterization tests risks controls, timing, combat, and animation.
5. **Economy/upgrades:** state is distributed across HUD, menu, player, base, world, minecart, and VS controllers.
6. **Scene/node renames:** many `$Path` and `get_node()` calls are not guarded; the 732-line upgrade scene is especially path-sensitive.
7. **Online flow:** global peer state, manual scene replacement, RPC authority, external signaling, and nondeterministic terrain require multi-client validation.
8. **Asset moves:** all active content uses hardcoded `res://` paths across scenes, scripts, themes, imports, and content dictionaries. Godot UID support is inconsistent in the current text resources.

## 9. Existing technical debt

- Oversized scripts/scenes: `player.gd` 718 lines, `world.gd` 476, `hud.gd` 463, `upgrade_menu.gd` 410, `minecart.gd` 342, `peon.gd` 314, `level.tscn` 337, and `upgrade_menu.tscn` 732.
- Hardcoded balance, tile source IDs, cell bounds, layer masks, Z values, asset paths, node paths, world dimensions, signaling endpoints, and input mappings.
- Duplicate animation-direction code in player/enemy/minecart/peon paths; duplicate pickup animation in coin/XP; repeated totem metadata and input registration.
- No documented automated suite or coverage requirement. Root `test_*.gd` files appear to be ad hoc SceneTree probes, and several have no `res://` consumers; that does not prove they are unused because they may be invoked from the CLI.
- Static resource-path checking found no missing first-party `res://` targets. The local Godot editor check could not reach project parsing because the installed Mono binary crashed while locating Snap/.NET host libraries.
- Suspected unused assets include `MineTrails.png` and `StompSprite.png` because no non-import `res://` reference was found. Numerous test/debug scripts and `.tscn.txt` alternatives are also candidates, not deletion-ready conclusions.
- Existing docs already propose a target structure and broad phases, but do not provide per-move reference manifests or validation gates.
- The export preset includes all resources, potentially shipping test/debug/archival resources.

## 10. Recommended refactor order

1. Establish repeatable validation and record manual smoke-test flows before changing behavior.
2. Document scene/node, input, collision, rendering, and tile-ID contracts.
3. Inventory active versus generated/archive/test files without deleting anything.
4. Define a target structure and a move protocol with reference manifests.
5. Centralize duplicated data and nonbehavioral constants in small, tested steps.
6. Separate economy state from UI, then simplify upgrade/HUD dependencies.
7. Characterize and repair Peon behavior before restructuring worker navigation.
8. Extract narrow services from `world.gd` one at a time, beginning with input or wave logic rather than terrain mutation.
9. Decompose player hero abilities only after input/digging/combat regression checks exist.
10. Move one low-coupling UI group, actor group, or asset family per task; defer `level.tscn`, terrain assets, and online systems.

## 11. Proposed small-task backlog

All tasks below are independently reviewable. No task is marked large; anything larger must be split again during planning.

### AUD-001 — Create a validation checklist

- **Objective:** Document exact launch, menu, mining, deposit, upgrade, wave, death/respawn, local-VS, web-export, and error-log checks.
- **System/directory:** `docs/refactor/`.
- **Expected files:** `docs/refactor/VALIDATION_CHECKLIST.md` only.
- **Dependencies:** None.
- **Risk:** Low.
- **Validation:** Compare checklist to active scene flow and CI export preset.
- **Scope/type:** Small; documentation.

### AUD-002 — Record project contracts

- **Objective:** Document active scene names, required child paths, autoloads, signal connections, input actions, collision layers, tile source IDs, and render-order rules.
- **System/directory:** Core scenes and `docs/refactor/`.
- **Expected files:** Read `project.godot`, `level.tscn`, actor scenes/scripts; create `docs/refactor/ARCHITECTURE_NOTES.md`.
- **Dependencies:** AUD-001.
- **Risk:** Low.
- **Validation:** Cross-check every documented contract with repository searches.
- **Scope/type:** Medium; documentation.

### AUD-003 — Classify repository artifacts

- **Objective:** Produce a keep/generated/test/archive/suspected-unused manifest without moving or deleting files.
- **System/directory:** Root tools, tests, textures, `.tscn.txt`, generated metadata.
- **Expected files:** One new inventory document under `docs/refactor/`; no source changes.
- **Dependencies:** AUD-001.
- **Risk:** Low.
- **Validation:** `git ls-files`, inbound-reference search, export configuration review, and manual asset provenance notes.
- **Scope/type:** Medium; documentation.

### AUD-004 — Define the target structure and move protocol

- **Objective:** Turn the existing conceptual tree into explicit destinations, move batches, reference-search steps, rollback points, and validation gates.
- **System/directory:** Entire repository structure; `docs/refactor/TARGET_STRUCTURE.md`.
- **Expected files:** `docs/refactor/TARGET_STRUCTURE.md` only.
- **Dependencies:** AUD-001, AUD-002, AUD-003.
- **Risk:** Low.
- **Validation:** Ensure every tracked source category has a destination and every batch remains small.
- **Scope/type:** Medium; documentation.

### AUD-005 — Consolidate input registration

- **Objective:** Make input actions register once while preserving current keyboard/gamepad/mobile behavior.
- **System/directory:** Input bootstrapping.
- **Expected files:** `global.gd`, `world.gd`; possibly one focused input helper and its UID.
- **Dependencies:** AUD-001, AUD-002.
- **Risk:** Medium.
- **Validation:** Automated project parse; single-player and two-player keyboard/gamepad/manual mobile checks; verify no duplicate `InputMap` events.
- **Scope/type:** Medium; refactoring.

### AUD-006 — Centralize hero and totem metadata

- **Objective:** Remove duplicated hero visual and Shaman totem labels/textures without changing balance or behavior.
- **System/directory:** Hero/totem data consumers.
- **Expected files:** `global.gd`, `player.gd`, `hud.gd`, `shaman_totem.gd`, `hero_selection_menu.gd`; possibly one data script/resource.
- **Dependencies:** AUD-001, AUD-002.
- **Risk:** Medium.
- **Validation:** Parse/load checks; hero selection and all four Shaman totem visual/manual checks.
- **Scope/type:** Medium; refactoring.

### AUD-007 — Move economy state out of HUD

- **Objective:** Give gems/gold a gameplay-owned interface while retaining HUD display and current costs.
- **System/directory:** Economy interactions.
- **Expected files:** `hud.gd`, `upgrade_menu.gd`, `coin_drop.gd`, `base.gd`, `minecart.gd`; one new economy component/service and UID.
- **Dependencies:** AUD-001, AUD-002.
- **Risk:** Medium.
- **Validation:** Deposit, pickup, passive minecart income, every purchase currency, and local-VS enemy purchase checks.
- **Scope/type:** Medium; refactoring.

### AUD-008 — Move code-created HUD widgets into the scene

- **Objective:** Make one related HUD group editor-owned; first batch should be notice plus game-over controls only.
- **System/directory:** HUD UI.
- **Expected files:** `hud.tscn`, `hud.gd`.
- **Dependencies:** AUD-001, AUD-002.
- **Risk:** Medium.
- **Validation:** Focus/navigation, pause processing, viewport sizing, notice fade, and game-over return checks in single/local/online modes.
- **Scope/type:** Small; UX/refactoring.

### AUD-009 — Characterize Peon behavior

- **Objective:** Add repeatable scenarios for idle, reachable/unreachable gem selection, return/deposit, terrain change, and wandering without changing AI.
- **System/directory:** Peon, gem, base, and world navigation.
- **Expected files:** Focused test scene/script plus `VALIDATION_CHECKLIST.md` updates.
- **Dependencies:** AUD-001, AUD-002.
- **Risk:** Low.
- **Validation:** Run scenarios headlessly where possible and manually visualize paths in Godot.
- **Scope/type:** Medium; documentation/testing.

### AUD-010 — Repair one confirmed Peon pathfinding defect

- **Objective:** Fix exactly one reproducible failure found by AUD-009, with a regression case.
- **System/directory:** `peon.gd` and its focused test fixture.
- **Expected files:** `peon.gd`; relevant test scene/script only.
- **Dependencies:** AUD-009 and a confirmed defect.
- **Risk:** Medium.
- **Validation:** Regression scenario plus manual dig/collect/deposit playthrough.
- **Scope/type:** Small; bug fixing.

### AUD-011 — Extract wave scheduling from world

- **Objective:** Separate wave timers, scaling, and selection from terrain mutation while keeping `world.gd` responsible for actual placement initially.
- **System/directory:** Wave/enemy spawning.
- **Expected files:** `world.gd`; one wave-director script/resource and UID; focused tests.
- **Dependencies:** AUD-001, AUD-002; preferably economy separation for VS-aware design.
- **Risk:** Medium.
- **Validation:** Timers, boss cadence, enemy counts/types, scaling, HUD wave updates, and local-VS behavior.
- **Scope/type:** Medium; refactoring.

### AUD-012 — Standardize collectible pickup behavior

- **Objective:** Share only the duplicated spawn/pickup presentation between coin and XP drops while preserving different destinations.
- **System/directory:** Collectibles.
- **Expected files:** `coin_drop.gd`, `xp_drop.gd`; possibly one base script and UID.
- **Dependencies:** AUD-001; AUD-007 if economy API changes first.
- **Risk:** Low.
- **Validation:** Coin/XP values, delayed overlap pickup, animation, particles, and cleanup.
- **Scope/type:** Small; refactoring.

### AUD-013 — Move one low-risk menu group

- **Objective:** Pilot the move protocol with `controls_menu.tscn/.gd` only; update all references in the same change.
- **System/directory:** Root UI to target UI scene/script directories.
- **Expected files:** Move `controls_menu.tscn`, `controls_menu.gd`, and UID; update `menu.gd` and `pause_menu.gd` paths.
- **Dependencies:** AUD-001 through AUD-004.
- **Risk:** Medium.
- **Validation:** Reference search, project parse, menu and paused controls overlay navigation, web export.
- **Scope/type:** Small; file movement.

### AUD-014 — Inventory and move character sprites by one actor family

- **Objective:** Move only Peon sprite assets as the first character-asset pilot, preserving imports and references.
- **System/directory:** `character_sprites/` to the approved target asset path.
- **Expected files:** Peon PNG/import plus `peon.tscn` references; exact list determined by AUD-003/004.
- **Dependencies:** AUD-001 through AUD-004, AUD-009 recommended.
- **Risk:** Medium.
- **Validation:** Pre/post reference manifest, import check, Peon animation frames/scale/render order, web export.
- **Scope/type:** Small; file movement.

### AUD-015 — Define settings persistence

- **Objective:** Specify settings schema, defaults, versioning, failure behavior, and initial scope without implementing it.
- **System/directory:** `docs/refactor/` and future `user://` configuration.
- **Expected files:** One focused settings design document or `ARCHITECTURE_NOTES.md` update.
- **Dependencies:** AUD-001, AUD-002.
- **Risk:** Low.
- **Validation:** Review against current input/display/export settings and save behavior.
- **Scope/type:** Small; documentation.

### AUD-016 — Implement settings persistence core

- **Objective:** Persist only an approved minimal settings schema; UI and input rebinding remain separate tasks.
- **System/directory:** Global/settings service.
- **Expected files:** One settings service script/UID, `project.godot` autoload only if approved, focused tests.
- **Dependencies:** AUD-015.
- **Risk:** Medium.
- **Validation:** First-run defaults, save/load, malformed/old file recovery, and web `user://` behavior.
- **Scope/type:** Medium; gameplay infrastructure.

## 12. Unknowns requiring runtime or manual investigation

- Whether all active scenes parse without warnings under the exact CI standard Godot 4.7 binary.
- Actual menu focus/controller behavior, overlay stacking, pause behavior, and split-screen viewport layout.
- Current playability of single-player, local VS, and online VS; online authority, signaling, disconnect, and deterministic-world behavior require two clients and network access.
- Peon behavior with unreachable, moving, removed, or minecart-consumed gems and with A* changes after digging.
- Enemy navigation when paths are absent or change, collision/contact damage timing, and spikes retaliation.
- Gem physics/tether stability, rail-item pickup, minecart placement/path reversal/deposit, and collision-free worker overlap.
- Whether nested Y-sort and explicit Z indices produce consistent ordering for actors, front walls, embedded gems, fog, particles, and totems in every direction.
- Whether `FrontDamageLayer` is actively updated; it exists in `level.tscn` but is not among `world.gd`'s cached layers.
- Whether suspected unused assets/scripts are intentionally retained source material, CLI tools, or safe archival candidates.
- Save compatibility expectations and whether lexicon discovery, hero selection, HUD unlocks, or settings should persist.
- Audio design and asset requirements, since no audio implementation is present.
- Mobile/browser performance of minimap redraw, procedural world generation, particles, and WebRTC export.
- The production need and export impact of `_mcp_game_helper` and the enabled Godot AI plugin.

The audit's recommended next planning task is **AUD-001 — Create `docs/refactor/VALIDATION_CHECKLIST.md`**. It establishes the safety gate needed by every later refactor and must be completed without beginning implementation work.
