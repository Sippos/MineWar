# MineWar Current Project Contracts

Task: `AUD-002`

Baseline inspected: `main` at `aba8253` on 2026-07-10

## 1. Purpose and evidence standard

This document records the runtime contracts that must survive later moves and
refactors. It describes the repository as it exists at the baseline above; it
does not propose a replacement architecture.

- **Confirmed (static)** means the contract is stated directly by a tracked
  scene, script, project setting, export preset, or workflow.
- **Inferred** means several static facts imply the behavior, but the complete
  behavior is not explicit in one place.
- **Runtime-unverified** means source establishes the intended wiring but this
  audit did not exercise it in a running game. Runtime uncertainties are
  collected in section 15.

Evidence was gathered with repository-wide searches for scene resources,
`preload`/`load`/scene changes, node lookups, signals, input registration and
consumption, groups, collision values, tile writes, A* calls, Y/Z ordering, and
deployment configuration, followed by direct inspection of the matching
scripts and scenes. Unless marked otherwise, facts below are confirmed
statically and behavior remains runtime-unverified.

## 2. Boot and scene routing

`project.godot` configures `res://launch_router.tscn`, not `menu.tscn`, as
`run/main_scene`. `launch_router.tscn` is a `Node` using `launch_router.gd`.
After `_ready()`, the router defers one scene change:

- ordinary desktop, Web, and iPad-like Web clients -> `res://menu.tscn`;
- native iOS, real iPhone/iPod Web user agents, and a constrained small mobile
  Web heuristic -> `res://boot.tscn`;
- `boot.tscn` exposes stable paths `Center/VBox/StartButton` and
  `Center/VBox/MenuButton`, routing directly to `main.tscn` or `menu.tscn`.

The normal menu flow is:

1. `menu.tscn` (`Menu`) instantiates `hero_selection_menu.tscn` as a child
   overlay for Single Player, local VS, or online VS.
2. Hero selection writes `Global.hero_p1`, `Global.hero_p2`, and
   `Global.current_hero`.
3. Single Player changes to `main.tscn`, whose `Main` root contains one
   `level.tscn` instance named `Level`.
4. Local VS changes to `vs_mode.tscn`. Its controller requires the two level
   instances at
   `HBoxContainer/SubViewportContainer1/SubViewport1/Level1` and
   `HBoxContainer/SubViewportContainer2/SubViewport2/Level2`. It sets their
   `player_id` to 1/2 and `is_vs_mode` true, installs a runtime
   `CompactVSUpgradeMenu`, and forwards each level's `send_enemy` request into
   the opposing level.
5. Online VS changes to `online_lobby.tscn`. The lobby requires
   `VBoxContainer/ConnectBtn`, `RoomInput`, `StatusLabel`, and `BackBtn`; it
   negotiates WebSocket signaling and WebRTC objects stored in `Global`. The
   host RPCs `start_game(seed)`, which loads `vs_online.tscn`, adds it to the
   tree, assigns it as `current_scene`, and frees the lobby. `vs_online.tscn`
   requires child `Level`, marks it VS, forwards enemy sends by RPC, and listens
   to `Base.game_over`.

Menu overlays and exits are also path contracts: Controls is
`res://scenes/menus/controls/controls_menu.tscn`, Lexicon is
`res://scenes/menus/lexicon/lexikon.tscn`, Pause is
`res://scenes/ui/overlays/pause/pause_menu.tscn`, and level-up is
`res://scenes/ui/overlays/level_up/level_up_menu.tscn`. Menu, pause, lexicon,
online-lobby back, HUD game-over, and match-result exits use
`res://menu.tscn` directly.

## 3. Autoload contracts

All active autoload entries in `project.godot` use `*`, so Godot enables them
as singleton nodes. Every target currently `extends Node`.

| Singleton | Path | Responsibility and required contracts |
| --- | --- | --- |
| `Global` | `res://global.gd` | Selected heroes; unlock/save state in `user://savegame.save`; hero/enemy asset dictionaries; session monster discovery; WebRTC peer/connection ownership; global UI/pause input bootstrap; applies `global_theme.tres` to scene branches except `boot.tscn` and `launch_router.tscn`. |
| `WebIOSLightingFallback` | `res://web_ios_lighting_fallback.gd` | Detects touch/mobile Web clients, adjusts mobile lighting/presentation, and preloads/owns `mobile_controls.tscn`. Depends on `JavaScriptBridge` only when available. |
| `HeroAbilityBootstrap` | `res://hero_ability_bootstrap.gd` | Watches added nodes and scans for `CharacterBody2D` nodes named exactly `Player`; adds a child named `HeroAbilities` using `hero_abilities.gd` if absent. |
| `UpgradeMenuUIStyler` | `res://upgrade_menu_ui_styler.gd` | Watches the tree for nodes named `UpgradeMenu`, styles their buttons/panel from the shared menu textures, and creates a runtime child named `RuntimeSectionFrames`. |
| `MatchFlow` | `res://match_flow.gd` | Recursively recognizes a single-player world by children `Base` and `HUD`, property `current_wave_number`, and false `is_vs_mode`; shows intro/result UI, treats wave 10 as final, reads HUD/player/base statistics, pauses on result, and routes replay/menu. |
| `PeonCoordinator` | `res://peon_coordinator.gd` | Recursively recognizes the same single-player world shape; reconciles nodes in group `peons` every 0.2 seconds, reserves gems with metadata `minewar_reserved_by_peon`, resolves duplicate targets, and adds runtime `JobStatus` and `CarryMarker` children. It deliberately does not coordinate VS worlds. |

The singleton names, paths, exact player/world recognition rules, and runtime
child names are APIs. Moving a target requires updating `project.godot` in the
same change; renaming `Player`, `Base`, `HUD`, `UpgradeMenu`, or the relevant
world properties changes autoload behavior.

## 4. Level hierarchy and stable runtime paths

`level.tscn` has a Y-sorted `Node2D` root named `Level`, scripted by
`world.gd`. These direct children are runtime APIs:

`MapBounds`, `HUD`, `UpgradeMenu`, `Base`, `BackgroundLayer`, `BlockLayer`,
`RailLayer`, `FrontWallLayer`, `EdgeLayer`, `DamageLayer`,
`FrontDamageLayer`, `FogLayer`, and `Player`.

`Player` must retain `Shadow`, `Sprite2D`, `CollisionShape2D`, `Camera2D`, and
`PointLight2D`. Actor scenes similarly require `Sprite2D`; `Gem`, `RailItem`,
and `Minecart` require `PickupArea/CollisionShape2D`; `Base` requires
`Sprite2D`, `CollisionShape2D`, and `PromptLabel`; `Peon` and `Enemy` require
their sprite/collision children. These names are read with `$...`, strict
`get_node()`, or runtime discovery rather than being merely descriptive.

Major sibling calls use the level as a service locator:

- Player repeatedly calls sibling `HUD` and `Base`; respawn uses
  `Base.global_position`.
- Base calls sibling `Player` and `HUD`, and spawns rail items, Peons, and a
  uniquely named direct child `Minecart` under the level.
- Enemy requires parent-world `BlockLayer` and `Base`.
- Hero abilities require parent-world `BlockLayer`, `DamageLayer`,
  `FrontDamageLayer`, `HUD`, `Base`, and player `Sprite2D`.
- HUD/minimap requires its parent world plus `Player`, `Base`, `BlockLayer`,
  and the global `enemies` group.
- VS controllers access level properties/methods directly: `player_id`,
  `is_vs_mode`, `income`, `ENEMY_SCENE`, `block_layer`, and
  `get_farthest_open_cell()`.

`MapBounds` dynamically creates a sibling `BoundaryLayer` if missing. Code
that enumerates or moves level layers must allow that runtime-owned node.

## 5. Resource-path contracts

The exact paths in section 2 and the following high-coupling paths must remain
valid or be updated atomically with a move:

- world/player/base: `enemy.tscn`, `gem.tscn`, `base.tscn`, `hud.tscn`,
  `upgrade_menu.tscn`, `rail_item.tscn`, `peon.tscn`, `minecart.tscn`;
- abilities: `hero_abilities.gd`, `shaman_totem.tscn`,
  `spider_minion.tscn`, `enemy_status.gd`, and `ability_icons/*.svg`;
- inheritance: `rail_item.gd` extends the concrete path `res://scripts/gameplay/collectibles/gems/gem.gd`;
- UI/theme: `global_theme.tres`,
  `assets/sprites/ui/common/MenuPanel.png`, and
  `assets/sprites/ui/common/Button.png`;
- drops: `scenes/entities/collectibles/drops/coin_drop.tscn` and
  `xp_drop.tscn`;
- hero/enemy art: dynamically loaded string paths in `Global.hero_data` and
  `Global.monster_data`, plus `DwarfBase.png` and `ShamanBase.png` preloaded
  by Base;
- world presentation: all terrain, edge, damage, fog, front-wall, rail, and
  embedded-gem textures declared by `level.tscn` or loaded by `world.gd`.

The export preset uses `all_resources`; lack of a preload is not evidence that
a tracked resource is excluded from Web output.

## 6. Signals and direct system calls

Scene-declared level connections are authoritative:

| Producer | Signal | Consumer |
| --- | --- | --- |
| `Base` | `gems_deposited(amount)` | `HUD.add_gems` |
| `Base` | `upgrade_requested` | `UpgradeMenu.show_menu` |
| `Base` | `base_damaged(new_health)` | `HUD.update_health` |
| `Base` | `game_over` | `HUD.on_game_over` |

Base also emits deposits for player auto-deposit, gem bodies entering its
area, Peon delivery, minecart passive income, and minecart stored-gem delivery.
Peon and minecart call `base.gems_deposited.emit(...)` directly rather than
calling a Base method. Mobile controls directly emit `Base.upgrade_requested`.

`UpgradeMenu.send_enemy(type)` is connected dynamically by local/online VS
controllers. Enemy type values are 0 Rat, 1 Spider, 2 Bat, 3 Trogg, and 4 Orc.
The level-up scene emits `upgrade_selected(String)` to the player-attached
ability controller. Menu and overlay button signals are connected either in
their owning scene or controller; their exact node paths therefore remain
part of the UI API.

Important direct mutations include UpgradeMenu changing HUD currency/unlock
flags, player stats/health, Base spike level/spawners, and world
`minecart_trail_length`; enemies calling Base/player damage; drops calling
HUD/player currency or XP methods; and VS controllers constructing enemies
inside the opposing level. These bypass a narrow interface and must be
rechecked in any affected refactor.

## 7. Input contracts

There is no `[input]` section in `project.godot`; actions are registered at
runtime.

| Registration owner | Actions and bindings | Main consumers |
| --- | --- | --- |
| `Global._ready()` | Existing Godot UI actions gain D-pad and A/B events; `pause` gains physical Escape and controller Start. | Godot Control focus/navigation; `world.gd` pause. |
| Every `world.gd._ready()` | `p1_left/right/up/down` = A/D/W/S; interact E; grab Space; drop Q; stomp R. `p2_*` = arrows; Enter; Ctrl; Shift; Period. Both players receive device-specific left-stick/D-pad movement and Y/A/B/X actions. It also repeats UI and pause registration. | `player.gd`, `base.gd`, abilities, mobile controls. |
| `hero_abilities.gd` attached to each Player | `pN_secondary` = F or keypad 1 plus device RB; `pN_ultimate` = T or keypad 2 plus device LB. Registration checks equivalent existing events before adding. | HeroAbility controller for hero-specific secondary/ultimate skills. |

`dwarf_abilities.gd` also contains legacy registration for equivalent
`pN_hammer`/`pN_avatar` actions, but the active bootstrap attaches
`hero_abilities.gd`; no current scene/autoload attaches `dwarf_abilities.gd`.
That status is confirmed statically, not proof the file is disposable.

`mobile_controls.gd` synthesizes movement, grab, drop, and stomp actions and
opens pause/upgrade UI directly. It does not expose interact, secondary, or
ultimate buttons. Because `Global` and every level append events, local VS can
register duplicate UI/pause/player events; runtime de-duplication behavior is
unverified and the existing repeated-registration behavior is not a desired
contract to preserve blindly.

## 8. Collision and detection contracts

Godot bit value `1` is physics layer 1; value `4` is layer 3.

| Object/system | Layer | Mask | Detection contract |
| --- | ---: | ---: | --- |
| Terrain (`BlockLayer` tiles and runtime `BoundaryLayer`) | 1 | Tile physics | 64x64 solid polygons; boundary tiles use source 3. |
| Player | default CharacterBody layer 1 | default 1, then OR 4 | Collides with terrain and enemies. Four runtime raycasts use mask 5 and originate at Y -24 with 34-pixel cardinal casts. During death, layer/mask 1 are disabled then restored at respawn. |
| Enemy | 4 (layer 3) | 1 | Collides with terrain/player layer; group `enemies`; contact behavior uses CharacterBody movement/collisions. |
| Base | default Area layer 1 | default 1, then OR 4 | Detects Player by exact name, gems by group, and enemies on layer 3; its area signals drive healing/deposit/interaction state. |
| Gem | 0 | 0 | Frozen RigidBody; child `PickupArea` (default area layer/mask) detects bodies and updates their nearby-gem list. Group `gems`. |
| Rail item | 0 | 0 | Inherits gem pickup behavior; group `rails`, excluded from gem deposits/Peon targets. |
| Peon | 0 | 0 | No physics wall collision; legal movement depends entirely on A* and `BlockLayer` checks. Group `peons` is added in code. |
| Minecart | 0 | 0 | Manual/tethered movement; child `PickupArea` detects Player for carry registration. Group `minecarts`; gem loading is a direct `load_gem()` call, not area auto-loading. |
| Coin/XP drops | 0 | 1 | Area bodies detect layer-1 Player; coin credits sibling HUD and XP credits Player. |
| Spider minion | 0 | 0 | Navigation/digging is manual and world-layer based. |

Relevant abilities do not define a reusable projectile collision layer/mask:
stomp, hammer, chain/web and related effects find enemies by group/distance or
direct calls, while Shaman totems are area/effect logic. The magic-orb visual
is created in code at Z 7; its gameplay collision semantics require runtime
characterization. Do not infer a general “ability collision layer” from the
absence of scene values.

## 9. Tile, world-bound, and A* contracts

Every world tile is 64x64. `level.tscn` defines these `TileSet_main` source
IDs: 0 background, 1 easy block, 2 medium block, 3 hard block, 4/5/6 easy/
medium/hard edge atlases, 7/8 damage stages, 9 fog mask, 10/11/12 easy/medium/
hard front walls, 13/14 front damage stages, and 15 rails. The separate block
TileSet also has source 0; gameplay writes blocks with sources 1-3 from the
main set. Atlas coordinates are `(0,0)` for plain blocks, damage, and front
walls.

Edge and fog atlases are assumed to be 4x4. Cardinal-open bits are top=1,
right=2, bottom=4, left=8, mapped to `(mask % 4, mask / 4)`. Rail autotiling
uses the same bit convention and atlas mapping; an isolated rail substitutes
mask 5. Rail source ID 15 is duplicated in `world.gd`, `minecart.gd`, and
`rail_item.gd`. Front-wall sources have a TileSet texture origin `(0,32)` and
are written into the cell below the solid block. Front gem sprites likewise
anchor to the below cell, then add Y +1.

Generation covers X `[-20, 20)` and Y `[-10, 30)`. It initially creates an
A* region `Rect2i(-30,-15,60,60)`, cardinal-only with 64-pixel cells, then the
deferred `MapBounds` contract trims it to exactly `Rect2i(-20,-10,40,40)`.
`MapBounds` builds a two-tile-thick unbreakable ring outside that playable
rectangle with hard source 3 and applies matching camera limits. The base
clearing is X -5..5/Y -4..-1; the entrance clearing is X -2..2/Y 0..1.

A* points are solid when `BlockLayer` has a tile. Dug cells become non-solid.
Weights are 1 when the cell below is solid or out of bounds and 50 otherwise.
Diagonal movement is disabled. Peons and enemies depend on the concrete
world-owned `astar`; Peons additionally reject cells unless BlockLayer source
is `-1`. Terrain changes must update A*, fog, front walls, edge/damage layers,
gem overlays, rail legality, and affected paths together.

## 10. Rendering contracts

The `Level` root is Y-sorted. `BlockLayer`, `FrontWallLayer`, `DamageLayer`,
`FrontDamageLayer`, and the runtime `BoundaryLayer` are also Y-sorted.
Explicit ordering is background -5, rails -1, normal actors/gems 0,
edges/damage 1, front gem indicators 2, magic orb 7, fog 10, and several
ability/UI effects between 12 and 30. HUD and UpgradeMenu are CanvasLayers;
match result UI uses Z 500.

Offsets are part of the 2.5D presentation contract:

- Player root spawns at Y -32; Sprite, collision, camera, and light are at
  local Y -24. The sprite scale is 0.85.
- Peon sprite is at Y -16 and scale 0.5; its path target adds Y +16 so it
  appears grounded.
- Enemy sprite/collision/shadow use Y +8.
- Loose/carried gem sprite uses Y -5 and stays at relative Z 0 so Y-sort,
  rather than a forced foreground Z, orders it.
- Coin and XP drop sprites are moved to Y -24 at runtime.
- Front-wall textures have +32 texture origin; the embedded front-gem texture
  applies an additional sprite offset Y -17 before below-cell positioning.

Fog at Z 10 intentionally overlays world content. Front walls project into
the cell below their block. Changing parentage, Y-sort participation,
`z_as_relative`, sprite roots, or these offsets can change occlusion even when
textures and global positions appear unchanged.

## 11. Peon contract

Base spawns `peon.tscn` as a direct level child at the Base position. Peon
requires its parent to expose `astar` and direct children `BlockLayer` and
`Base`. Its public state is string-valued `IDLE`, `MOVE_TO_GEM`, or
`RETURN_TO_BASE`; `PeonCoordinator` reads and writes `state`, `target_gem`,
`astar_path`, and `velocity`, so those fields and values are cross-script APIs.

Peon scans the global `gems` group, excludes nodes in `rails`, queued nodes,
and nodes tethered to another owner, chooses a reachable nearby walkable cell,
and consumes the target with `queue_free()` inside 24 pixels. It then paths to
Base and directly emits one `gems_deposited` inside 36 pixels. Paths are
cardinal A* ID paths; targets and starts use bounded nearest-walkable fallbacks,
and movement adds the grounding offset described above.

`PeonCoordinator` only operates in recursively discovered non-VS worlds. It
uses metadata to reserve targets and adds status visuals, but Peon's own target
selection does not consult that reservation metadata. Therefore multi-Peon
claim prevention is a periodic reconciliation behavior, not an atomic
selection guarantee. Target disappearance, changed terrain, unreachable
gems, duplicate assignment, and delivery exactly-once behavior remain
runtime-unverified.

## 12. Minecart and rail contract

Base purchase calls `spawn_minecart()`, removes an existing direct child named
`Minecart`, and defers adding a new `minecart.tscn` direct child with that exact
name. The cart initially behaves as a carryable nearby item: it registers with
the direct sibling `Player`, refuses tethering after placement, and has no
physics collision layer/mask.

On drop, placement requires direct sibling `RailLayer` and `BlockLayer` and an
open BlockLayer cell. If that cell has no rail, the cart searches open cells
toward sibling `Base`, writes at most `world.minecart_trail_length` rails
(default 16), and asks `world.update_rail_autotile()` for each cell and
neighbor. Its search is cardinal, capped at 1,200 dequeued cells, and bounded
relative to the start by 40 X/60 Y cells. This is a separate breadth-first
search, not the world's A*.

The cart rebuilds a path over connected open source-15 rail cells, chooses a
farthest reached rail, moves by directly changing `global_position`, and
reverses the path at each end. `world.refresh_minecart_paths()` discovers carts
through group `minecarts`; a dropped `RailItem` calls rail autotiling and then
that refresh hook. The `RailItem` world-name check expects `world.name ==
"World"`, while the active level root is named `Level`; whether that prevents
normal rail-item placement is a known static inconsistency requiring runtime
characterization.

Every five seconds on a valid placed path, the cart directly emits Base
`gems_deposited(max(1, path_length / 10))`; the level scene routes this to
`HUD.add_gems`, so passive “income” is gems, not VS gold. `load_gem(gem,
player)` accepts only a placed cart and a depositable gem, increments
`stored_gems`, and frees the gem. Stored gems emit through Base only when the
cart is within 96 pixels of Base. No current minecart area handler calls
`load_gem`; a separate caller (not found by repository search) would be needed
for automatic loading. Spawn ownership, initial placement, path direction,
extension extent, loading, income cadence, and Base notification are all
priority runtime characterization targets before `MOV-011`.

## 13. Upgrade-menu and HUD contracts

`UpgradeMenu` is a `CanvasLayer` direct child of Level. Its controller requires
sibling `HUD` and `Player`, root child `Panel`, and the following stable Panel
children: `Title`, `Close`, `UnlockHealthbar`, `UnlockBaseHealth`,
`UnlockWaveTimer`, `UnlockXP`, `UnlockStats`, `UnlockMinimap`,
`UpgradeMinimap`, `UpgradeMaxHealth`, `HealPlayer`, `UpgradeStrength`,
`UpgradeAgility`, `UpgradeIntelligence`, `UpgradeSpikes`, `SwapHero`,
`FactionTitle`, `BuyRail`, `BuyMinecart`, `BuyPeon`, `GoldPileIcon4`, and
`BranchTitle6`. Cost labels also use the fragile repeated paths
`Panel/BranchTitle4/BranchTitle4/BranchTitle4/BranchTitle4` and its fifth- and
sixth-level descendants. All 18 purchase/close buttons are scene-connected;
Close is additionally guarded and connected in code. VS runtime UI expects
children `Panel`, `VSPromptPanel`, and `VSSendPanel` when present.

HUD is a `CanvasLayer` direct child of Level. Its required scene paths are
`Label`, `GoldLabel`, `BaseHealthBar`, `PlayerHealthBar`, `Minimap`,
`RespawnLabel`, `WaveLabel`, `WaveBar`, `XPLabel`, `XPBar`,
`StatsContainer/StrLabel`, `AgiLabel`, and `IntLabel`; layout code also uses
`PlayerLabel`, `BaseLabel`, and the full `StatsContainer`. Ability code creates
or expects runtime ability slots with `Root/Icon`, `Root/CooldownOverlay`,
`Root/Timer`, and `Root/Level`. HUD also creates notice, mobile, totem,
stomp/ability, and game-over controls in code. `MatchFlow` expects HUD
properties including totals, last wave, and run start time and may remove
`GameOverOverlay`/hide `RespawnLabel` before adding `MatchResultOverlay`.

The wallet contract is currently UI-owned: HUD's `total_gems`/`total_gold`
and add/spend methods are gameplay state consumed by Base, drops, upgrades,
minecart, world VS income, and match results. A UI move must preserve both node
paths and these callable methods/properties; extracting economy is a separate
task.

## 14. Web export and deployment contracts

`export_presets.cfg` defines one runnable `Web` preset with
`export_filter="all_resources"`, export path `build/web/index.html`, WebGL
desktop texture compression enabled, mobile compression disabled, canvas
resize policy 2, focus-on-start enabled, and no PWA/custom shell.
`project.godot` uses GL Compatibility, pixel texture filtering, 2D pixel snap,
and `canvas_items` stretch with `expand` aspect. Gameplay changes must remain
Web compatible; networking additionally assumes WebSocket/WebRTC support and
the hardcoded signaling endpoint `wss://minewar.onrender.com` plus Google's
public STUN service.

`.github/workflows/deploy.yml` triggers on pushes to `main` except changes
limited by its `paths-ignore` (`.github/**`, `.deploy-trigger`, `README.md`), or
manually. It checks that the triggering SHA is still latest `origin/main`,
downloads standard Godot 4.7 and matching templates through
`firebelley/godot-export@v5.2.1`, exports using the preset path, then publishes
`build/web` with the butler action to the `web` channel. The required secrets
are `BUTLER_API_KEY`, `ITCH_GAME_ID`, and `ITCH_USERNAME`. Preserve the preset
name/path, workflow freshness guard, Godot version pairing, package directory,
channel, and secret names unless deployment is explicitly in scope.

## 15. Known uncertainties requiring runtime characterization

- Router detection and lighting/mobile-controls behavior on real iPhone,
  iPad-like, Android, desktop Web, and native iOS environments.
- Single-player, local split-screen, and two-client online scene flow,
  authority/disconnect handling, and whether the passed online seed produces
  matching worlds (the source does not apply it to generation).
- Repeated runtime input registration in Global and multiple Level instances,
  controller ownership, and missing mobile secondary/ultimate/interact inputs.
- Actual collision/contact timing for player/enemy/base and exact detection by
  default child Area layers; magic-orb and other ability hit behavior.
- BoundaryLayer draw/collision ordering, nested Y-sort, fog/front-wall/gem
  occlusion, actor sprite offsets, and camera limits at supported viewports.
- A* recovery after digging, enemy/Peon path invalidation, Peon reservation
  races, unreachable/removed targets, and exact-once Peon delivery.
- Rail-item placement under the active `Level` root given its `"World"` name
  guard.
- Minecart spawn/carry/drop placement, rail construction and autotile shape,
  farthest-path choice/reversal, live path extension, loading caller/claim
  semantics, five-second passive deposits, stored-gem proximity deposits,
  duplicate carts, and Base/HUD notification exactly once.
- Upgrade/HUD focus, code-created controls, compact VS panels, affordability,
  economy updates, and all fragile repeated cost-label paths.
- Full standard-Godot parse/import scan, interactive gameplay, Web export
  contents/performance, and actual GitHub-to-itch.io deployment were not rerun
  for this documentation-only task. The progress ledger records successful
  baseline validation/deployment before this audit; this task only verified
  their static configuration.

## 16. Preservation rule for the next work

Before moving a scene/script, search this document's paths and the repository
again because runtime-created nodes and string resource paths are not protected
by file moves. In particular, do not begin `MOV-011` from this static contract
alone. The next task must create repeatable minecart characterization for
spawn, rail following, path extension, gem loading, passive income, and Base
notification, including explicit expected ownership and exactly-once results.
