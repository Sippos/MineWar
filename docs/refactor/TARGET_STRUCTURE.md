# MineWars Target Structure and Migration Strategy

Status: active migration; authoritative execution state is recorded in
`docs/refactor/REFACTOR_PROGRESS.md`

Backlog task: `STR-001` (corresponds to audit task `AUD-004`)

Repository inspected: 2026-07-10

## 1. Purpose

This document defines the destination structure for MineWars and a safe sequence for reaching it. The reorganization is intended to make ownership obvious, shorten navigation time, reduce accidental cross-system edits, and separate source assets, scenes, scripts, data, tests, tools, generated output, and documentation. It also creates stable boundaries for later gameplay and UI refactors without performing those refactors during file moves.

The target is a scalable Godot project, not merely a tidier root. Every runtime file should have one clear owner, shared content should be visibly shared, and each move should preserve the runnable game.

## 2. Current structure summary

MineWars is a Godot 4.7 project whose first-party runtime content is mostly flat at the repository root. The root currently mixes 24 scenes, first-party scripts and their `.uid` sidecars, 76 PNG source images, 85 tracked `.import` sidecars, a theme, project/export configuration, roughly 74 one-off Python maintenance utilities, GDScript probes, networking support, and deployment files. `character_sprites/` is the only substantial first-party asset grouping. `addons/godot_ai/` is a large third-party plugin, while `.godot/` and `build/` are local generated directories and are not tracked.

The main problems are unclear ownership, scene/script pairs that are separated only by naming convention, production and test/tool artifacts sharing the root, inconsistent asset names and casing, and extensive `res://` coupling. `level.tscn`, `world.gd`, `player.gd`, HUD/upgrades, and the entity scenes form a particularly dense dependency cluster. This summary intentionally does not repeat the full inventory in `PROJECT_AUDIT.md`.

No first-party audio streams, fonts, shader files, or standalone gameplay data resources currently exist. Their target directories are nevertheless reserved so future content does not return to the root.

## 3. Organization principles

### Naming and casing

- Use lowercase `snake_case` for directories and source filenames on all platforms: `hero_selection_menu.tscn`, `dwarf_walk.png`, `enemy_definition.tres`.
- Preserve existing names during a pure move. Case cleanup and spelling fixes such as `Strenght`, `Ressources`, `Healthbar`, or hyphen/underscore variants require separate rename batches after reference and visual-use verification.
- Name scenes for the concrete thing they instantiate. Use `PascalCase` for scene root nodes and `snake_case.tscn` for scene files.
- Give a scene-owned script the same basename as its scene where practical. Shared scripts are named for their role, not for the first scene that used them.
- Name assets by owner, purpose, and optional state or variant; avoid generic names such as `bg.png`, `edge.png`, or `Button.png` in new work.
- Treat path case as exact even on case-insensitive development machines. Every move and rename must be verified on a case-sensitive filesystem.

### Ownership and placement

- Keep `project.godot`, `export_presets.cfg`, repository metadata, and deployment entry files at the root. The root is configuration and orientation space, not a content folder.
- Store executable scenes under `scenes/`, GDScript behavior under `scripts/`, source media under `assets/`, and reusable `Resource` data under `data/`.
- A file used by one scene belongs to that scene's feature directory; a file used by multiple features belongs in the narrowest honest shared directory.
- Prefer feature ownership below the type boundary: for example, player scenes remain under `scenes/entities/characters/`, player scripts under `scripts/gameplay/characters/`, and player-only art under `assets/sprites/characters/dwarf/`.
- Reusable UI widgets belong in `scenes/ui/components/` and `scripts/ui/components/`; menu-specific panels and images stay with the owning menu category.
- Global systems and autoloads belong in `scripts/core/` only when they genuinely provide project-wide lifecycle/state. A script does not become “core” merely because many files currently reach into it.
- Put tests under `tests/` and developer diagnostics under `scripts/debug/` or `tools/`. Test fixtures go below `tests/fixtures/`; never mix probes into production scene folders.
- Put reproducible repository tooling under `tools/` by purpose. Historical fix/generation scripts must first be classified as active, archival, or obsolete; moving them does not prove they are supported.
- Keep third-party packages self-contained under `addons/<package>/`. Do not redistribute their internal files into first-party directories.
- Keep documentation under `docs/`; refactor planning remains under `docs/refactor/`.
- Never hand-move `.godot/` contents. `.godot/`, `build/`, caches, logs, and export output are regenerated and remain ignored. Source-adjacent `.import` and `.gd.uid` sidecars must travel with their source file when Godot/editor behavior requires it; they do not belong in a central generated directory.

## 4. Proposed target directory tree

```text
MineWars/
├── .github/
│   └── workflows/
├── addons/
│   └── godot_ai/
├── assets/
│   ├── audio/
│   │   ├── music/
│   │   ├── sfx/
│   │   └── ui/
│   ├── fonts/
│   ├── materials/
│   ├── shaders/
│   ├── sprites/
│   │   ├── characters/
│   │   │   ├── dwarf/
│   │   │   ├── mech/
│   │   │   └── shaman/
│   │   ├── enemies/
│   │   │   ├── bat/
│   │   │   ├── orc/
│   │   │   ├── rat/
│   │   │   ├── spider/
│   │   │   └── trogg/
│   │   ├── workers/
│   │   ├── transport/
│   │   ├── collectibles/
│   │   ├── base/
│   │   ├── effects/
│   │   ├── world/
│   │   │   ├── terrain/
│   │   │   ├── fog/
│   │   │   └── rails/
│   │   └── ui/
│   │       ├── common/
│   │       ├── hud/
│   │       ├── menus/
│   │       └── upgrades/
│   └── textures/
│       ├── backgrounds/
│       ├── icons/
│       └── masks/
├── data/
│   ├── balance/
│   ├── characters/
│   ├── enemies/
│   ├── progression/
│   ├── upgrades/
│   └── world/
├── docs/
│   └── refactor/
├── scenes/
│   ├── boot/
│   ├── gameplay/
│   │   ├── single_player/
│   │   └── versus/
│   ├── menus/
│   │   ├── main/
│   │   ├── hero_selection/
│   │   ├── controls/
│   │   ├── lexicon/
│   │   └── online_lobby/
│   ├── ui/
│   │   ├── components/
│   │   ├── hud/
│   │   ├── overlays/
│   │   └── upgrades/
│   ├── world/
│   └── entities/
│       ├── characters/
│       ├── enemies/
│       ├── workers/
│       ├── collectibles/
│       ├── base/
│       ├── transport/
│       └── abilities/
├── scripts/
│   ├── core/
│   │   └── autoloads/
│   ├── gameplay/
│   │   ├── characters/
│   │   ├── enemies/
│   │   ├── workers/
│   │   ├── collectibles/
│   │   ├── base/
│   │   ├── transport/
│   │   ├── abilities/
│   │   └── versus/
│   ├── systems/
│   │   ├── economy/
│   │   ├── input/
│   │   ├── navigation/
│   │   ├── networking/
│   │   ├── persistence/
│   │   ├── progression/
│   │   ├── spawning/
│   │   └── world_generation/
│   ├── ui/
│   │   ├── components/
│   │   ├── hud/
│   │   ├── menus/
│   │   └── upgrades/
│   ├── utilities/
│   └── debug/
├── tests/
│   ├── fixtures/
│   ├── integration/
│   ├── unit/
│   └── visual/
├── tools/
│   ├── asset_pipeline/
│   ├── content_checks/
│   ├── migration/
│   ├── networking/
│   └── archive/
├── project.godot
├── export_presets.cfg
├── icon.svg
└── README.md
```

### Major-directory rules and current examples

| Directory | Purpose and allowed content | Must not contain | Current examples with eventual destination |
| --- | --- | --- | --- |
| `assets/` | Source media imported by Godot: sprites, textures, future audio/fonts, materials, and shaders. Owner subfolders are authoritative. | Scenes, behavior scripts, balance data, generated `.godot` cache. | `character_sprites/*` → character/enemy/worker/transport sprite owners; `GoldCoin.png` → `sprites/collectibles/`; `MainMenuBackground.png` → `textures/backgrounds/`; world atlases → `sprites/world/terrain/`. |
| `data/` | Stable `.tres`/`.res` definitions for balance, content catalogs, progression, upgrades, and world rules once those resources exist. | UI layout, executable nodes, arbitrary dictionaries moved out of scripts without an architecture task. | Future destinations for hero/enemy/totem metadata now duplicated in `global.gd`, `enemy.gd`, and `shaman_totem.gd`; none should move here during file-only batches. |
| `scenes/` | Instantiable `.tscn`/`.scn`, grouped by runtime owner. | Standalone scripts, raw media, caches. | `menu.tscn` → `menus/main/`; `hud.tscn` → `ui/hud/`; `level.tscn` → `world/`; entity scenes → matching `entities/*`; `main.tscn` → `boot/`. |
| `scripts/` | First-party GDScript grouped by responsibility and ownership. | Third-party addon code, scene files, source art, ad hoc Python patchers. | `global.gd` → `core/autoloads/`; `world.gd` → initially `systems/world_generation/`; UI controllers → `ui/`; actor behavior → `gameplay/*`; `debug_weights.gd` → `debug/`. |
| `tests/` | Maintained test suites, integration/visual probes, and fixtures with a documented runner. | Shipping gameplay scripts and unclassified experiments. | `test_*.gd`, `run_test*.gd`, and `run_test_node.tscn` after classification; Python image tests belong under tools unless they are formal test runners. |
| `tools/` | Non-runtime build, validation, content-generation, migration, networking, and archival utilities. | Godot runtime content and undocumented scripts presented as supported tools. | `generate_*`, `resize_*`, `check_*`, `fix_*`, `patch_*`, `signaling_server.js`, `package.json`, and `export_web.sh`, classified before movement. |
| `docs/` | Product, architecture, validation, and refactor documentation. | Runtime resources and generated reports that are not meant for version control. | Existing `docs/*.md` and `docs/refactor/*.md` remain here. |
| `addons/` | Self-contained third-party Godot plugins with their licenses/readmes. | First-party gameplay code. | `addons/godot_ai/` remains intact; its plugin and runtime-autoload paths make it a separately managed dependency. |
| Root/config | Godot entry configuration, export configuration, repository policy, deployment, licensing, and orientation. | Normal scenes/scripts/assets/tests. | Keep `project.godot`, `export_presets.cfg`, `.github/`, `AGENTS.md`, `README.md`; keep `icon.svg` at root initially because project configuration references it. |
| Generated/ignored | `.godot/`, `build/`, `__pycache__/`, logs, export artifacts. | Authored source or manually maintained resources. | Regenerate; never migrate their contents. Tracked source-adjacent `.import` and `.gd.uid` are handled with their owners, not placed here. |

`assets/audio/`, `assets/fonts/`, `assets/materials/`, and `assets/shaders/` are reserved and should be created only when the first owned file exists. The audit and repository scan found no first-party files in those categories. `global_theme.tres` is currently the only first-party standalone resource; its eventual destination is `assets/materials/themes/global_theme.tres` (or a future `assets/themes/` if theme volume warrants it), not `data/`.

## 5. Scene and script ownership

- A script used by exactly one scene remains logically owned by that scene, but type separation is retained: `scenes/entities/base/base.tscn` pairs with `scripts/gameplay/base/base.gd`. Matching relative feature names make the pair discoverable.
- A script used by several scenes moves to the narrowest shared `scripts/` subsystem. Consumers must reference that shared path; do not duplicate it beside each scene.
- Inherited scenes remain near the parent scene under the same feature. Their base scripts/resources belong in a clearly named `shared/` or `components/` directory only after actual reuse exists.
- Reusable node components have a scene in `scenes/ui/components/` or the relevant entity component folder and a paired controller in `scripts/.../components/`. Reuse must be intentional and documented; deeply coupled fragments should stay with their owner.
- Data-only `Resource` objects live in `data/<domain>/`. They must not depend on scene-tree node paths. Media referenced only by one definition still belongs to the definition's domain asset folder.
- `Global` is the first-party autoload and eventually belongs at `scripts/core/autoloads/global.gd`, but only after its mixed persistence/input/network/content responsibilities are characterized. `_mcp_game_helper` remains owned by `addons/godot_ai/`.
- Project-wide services belong under `scripts/systems/`; autoload status is a lifecycle decision, not a folder convention. A move must not silently add or remove an autoload.
- Menu controllers belong in `scripts/ui/menus/<menu>/`; HUD and upgrade controllers belong in their respective UI directories even though they currently own gameplay state. Moving them must not be combined with extracting that state.
- Entity scenes own entity-specific collision shapes, animations, and embedded resources. Entity-specific external art belongs to `assets/sprites/<entity-family>/<entity>/`; shared art belongs one level above at the family or shared domain.
- `rail_item.gd` inherits by path from `res://gem.gd`. The parent and child must either move together in a dedicated inheritance batch or the child reference must be updated and validated immediately.

## 6. Asset ownership

| Asset situation | Target ownership rule | Current examples |
| --- | --- | --- |
| One character only | `assets/sprites/characters/<character>/` | Dwarf walk/attack, Shaman walk and totem art. |
| Several playable characters | `assets/sprites/characters/shared/` | Only after confirmed reuse; do not infer reuse from similar dimensions. |
| One enemy type | `assets/sprites/enemies/<enemy>/` | Rat, bat, spider, trogg, orc sprite sheets. |
| Worker or transport | `assets/sprites/workers/` or `assets/sprites/transport/` | Peon and minecart sheets/placeholders. |
| One menu | `assets/sprites/ui/menus/<menu>/` or `textures/backgrounds/<menu>/` | `MainMenuBackground.png`, `Beastary.png`. |
| Shared UI | `assets/sprites/ui/common/` | `Button.png`, `MenuPanel.png`, only because the theme/menu/upgrades demonstrate reuse. |
| HUD/upgrades | `assets/sprites/ui/hud/` or `ui/upgrades/`; shared stat icons may use `ui/common/stats/` | Health bars, `StatRessources.png`, stat icons, coin art. Confirm whether `GoldCoin` and `GoldCoinPile` are semantically shared before combining. |
| Tileset-related | `assets/sprites/world/terrain/` with subfolders by tileset/difficulty if needed | Brick, edge, front, damage, fog-mask, and background atlases referenced by `level.tscn`. Keep complete atlas families together. |
| Level-specific | `assets/sprites/world/levels/<level>/` | Create only when multiple levels exist; the current mine is the shared world owner. |
| Collectible drops | `assets/sprites/collectibles/<drop>/` | `assets/sprites/collectibles/xp/xp_orb.png`. |
| Gameplay effects | `assets/sprites/effects/<effect>/` | Potential stomp art after usage is confirmed. |
| Temporary/debug | `tests/fixtures/`, `assets/debug/`, or `tools/archive/`, depending on runtime role | Placeholders and suspected-unused `MineTrails.png`/`StompSprite.png` remain unmoved until provenance classification (`AUD-003`). |

An asset that appears duplicated is not deletion-ready. The similarly named brick/front/gradient variants, root import-only files, placeholder imports, and multiple resolutions may encode distinct TileSet regions or historical outputs. Compare hashes, import source paths, references, dimensions, and editor use before classifying them.

## 7. Godot-specific risks

- Text scenes store `ExtResource` paths. Moving a `.tscn`, script, texture, or theme requires updating every affected `.tscn`; `level.tscn` alone references the player/world scripts, base/HUD/upgrade scenes, character art, and terrain atlases.
- `.tres` and text `.res` files may reference scripts, textures, shaders, or other resources. Binary `.res` cannot be safely updated by blind text replacement and should be moved through Godot with load validation.
- `preload()` paths are parse-time dependencies; broken paths can prevent scripts from parsing. Runtime `load()` paths may be dictionary values or dynamically composed and need explicit searches and flow checks.
- `.import` sidecars describe source import settings and remap to `.godot/imported/`. Move source plus sidecar through a controlled Godot-aware workflow, then allow `.godot/` to regenerate. Never commit `.godot/imported/` merely to repair a move.
- `project.godot` directly references `res://menu.tscn`, `res://icon.svg`, `res://global.gd`, `res://global_theme.tres`, the addon autoload, and plugin configuration. Those paths are release-critical.
- The main scene is `menu.tscn`, while runtime flow also depends on the thin `main.tscn` wrapper and direct scene changes from menu/pause/game-over/lexicon code. Entry-scene moves require all transition references and export startup checks.
- No first-party `.gdshader` was found. Future shader moves must check material resources, inline ShaderMaterials, and code loads; shader include paths are also path-sensitive.
- `level.tscn` embeds TileSet data, source IDs, atlas coordinates, collision data, layers, and texture dependencies. Terrain atlas moves can load successfully yet still render or collide incorrectly.
- Animation libraries may store external texture/resource references and track node paths. Current animations embedded in scenes must be checked for both after moving an entity scene or art.
- `rail_item.gd` uses path-based script inheritance (`extends "res://gem.gd"`). Search all `extends` declarations and update parent paths before parsing child scripts.
- Some scene resources include both `uid://` and `path="res://..."`, while many have paths only. UIDs reduce some editor relinking risk but are not a substitute for correct paths, and hand-written/custom IDs such as scene UIDs must not be assumed valid. Keep `.gd.uid` sidecars with scripts and verify Godot's UID cache after each move.
- Case-only renames can be lost on Windows/macOS filesystems and fail on Linux/web deployment. Use an explicit intermediate rename when eventually authorized and validate exact casing with `git ls-files` and path searches.
- Export preset `all_resources` behavior can ship root tests/archive content. Moving a file may change inclusion only if export filters later change; filter changes are a separate task.

## 8. Files that must not be moved initially

| File/category | Why it is high risk | Prerequisite before movement |
| --- | --- | --- |
| `project.godot`, `export_presets.cfg`, `icon.svg` | Entry scene, icon, autoload, theme, plugin, renderer, and export contracts. | Complete earlier low-risk batches; record project contracts (`AUD-002`); obtain reliable editor/export validation. Root retention is the default target. |
| `menu.tscn`, `menu.gd`, `main.tscn` | Startup and direct transitions; `main.tscn` wraps `level.tscn`. | Move a non-entry menu first, validate transition protocol, then update main-scene and all direct loads in one dedicated batch. |
| `level.tscn`, `world.gd`, and terrain/fog/edge/front/damage textures | Central scene, embedded TileSet, numerical tile contracts, navigation, rendering layers, most gameplay instances. | `AUD-002`; reliable scene load; manual mining/render/collision/navigation smoke test; complete independent asset/UI/entity batches first. |
| `player.gd` and player resources | 718-line core loop with hero, dig, combat, HUD, and hardcoded preloads. | Characterization checks and hero metadata consolidation (`AUD-006`); move script and required references in isolation. |
| `global.gd` | Active `Global` autoload mixing save, input, selection, content, networking, with project-config path. | `AUD-002`, `AUD-005`, `AUD-006`, and autoload startup/save/network checks. |
| `hud.tscn`/`hud.gd`, `upgrade_menu.tscn`/`.gd`, shared UI art, `global_theme.tres` | UI currently owns economy/progression state; scenes have deep node-path and shared-theme dependencies. | Economy separation (`AUD-007`), HUD widget task (`AUD-008`) where applicable, reusable UI ownership decision, and manual layout/focus checks. |
| `base.*`, `peon.*`, `minecart.*`, rails | Cross-linked spawning, economy, navigation, A*, TileMap node names, gem pickup/deposit and base signals. | Peon characterization (`AUD-009`), relevant defect task (`AUD-010`) if confirmed, documented node contracts, and worker/transport gameplay checks. |
| `gem.*` and `rail_item.*` | Path-based inheritance plus player/base/cart/worker pickup coupling. | Collectible behavior characterization/standardization (`AUD-012`); move parent/child with explicit inheritance validation. |
| `enemy.*`, drop scenes, enemy art | Dynamic texture dictionaries, hardcoded spawn/drop preloads, world A*, encyclopedia data. | Central metadata/reference manifest and wave/combat/drop checks; do one enemy family at a time. |
| `vs_mode.*`, `vs_online.*`, `online_lobby.*`, networking tools | Level internals, peer state, RPC authority, external signaling, multi-client validation. | Deterministic/network test plan and two-client environment; decide ownership of `signaling_server.js`. |
| `addons/godot_ai/` | Enabled plugin and runtime autoload with extensive internal paths. | Decide production/export necessity and use the addon's supported upgrade/reinstall mechanism; never piecemeal-move it. |
| `.import`, `.gd.uid`, import-only files and placeholders | Some are tracked metadata, some lack visible source counterparts, and UID/import behavior is version-sensitive. | `AUD-003` classification; Godot-aware move trial; clean reimport and reference verification. |
| `.godot/`, `build/`, `__pycache__/` | Generated/cache/export output, not source. | Never move. Confirm ignore rules and regenerate as needed. |
| `menu_free.tscn.txt`, `upgrade_menu_free.tscn.txt`, `MineTrails.png`, `StompSprite.png`, root probes/tools | Potential archive, unused, debug, or provenance-unknown content. | `AUD-003` classification and explicit keep/archive/delete decision; this plan authorizes none. |

## 9. Migration principles

Every future movement task must follow this protocol:

1. Select one batch and freeze its exact source/target manifest. Move only one related category.
2. Record `git status --short`, preserve unrelated work, and establish the strongest available baseline from `VALIDATION_CHECKLIST.md`.
3. Search the entire tracked repository for exact filenames, `res://` strings, UIDs, `ExtResource`, `preload`, `load`, inheritance, project settings, tool scripts, and documentation references.
4. Use Godot-aware moves where practical. Move the source and required sidecars together; do not edit generated `.godot/` content.
5. Update every affected path without changing behavior, node names, resource values, import settings, names/casing, or architecture.
6. Validate immediately: path existence, diff checks, project/scene load where available, and the batch-specific manual flow. Leave the game runnable.
7. Keep the result reviewable as one small commit. If unexpected coupling expands scope, roll back the batch rather than absorbing another category.
8. Roll back by reverting only the batch commit (or reversing its explicit move/path edits before commit), restore source paths and sidecars, clear only regenerated ignored cache if necessary, reimport, and repeat the baseline. Never use a destructive whole-worktree reset.

Each implementation PR/commit should include its reference manifest, automated command results, manual checks, remaining limitations, and exact rollback command appropriate to that commit.

## 10. Migration batches

The batches below are independently executable units, not one continuous mega-migration. Later IDs express a recommended ordering; each batch still requires its named prerequisites and a clean baseline. Common validation for every batch is `git status --short`, `git diff --check`, review of `git diff --summary` and `git diff`, and an exact old/new path search with `rg`. Godot commands are attempted only when the environment supports them; known Mono/display limitations in `VALIDATION_CHECKLIST.md` must be reported rather than hidden.

### MOV-001 — Classify and relocate one content-check tool group

- **Status:** Pending; intentionally not backfilled during the 2026-07-10 move sequence.

- **Objective:** Establish `tools/content_checks/` with a small, non-runtime group after confirming their role.
- **Files/category:** `check_content.py`, `check_grid.py`, `check_img.py`, `check_img2.py` only; do not include tests, generators, patchers, or export tools.
- **Source → target:** root → `tools/content_checks/`.
- **Known references:** no `res://` use established; search shell, workflow, Markdown, Python imports, and developer instructions. These may be manually invoked despite no inbound reference.
- **Prerequisites:** `AUD-003` must classify all four as retained tools and document invocation/provenance.
- **Risk/scope:** Low; four Python files plus path-reference updates only.
- **Validation commands:** `rg -n 'check_(content|grid|img2?)\.py|from check_|import check_' . --glob '!\.git/**'`; `python3 -m py_compile tools/content_checks/*.py` if Python is available; common checks.
- **Manual checks:** Run only each script's documented non-mutating/help mode; confirm docs/workflows still point to it. Do not let validation rewrite assets.
- **Rollback:** Reverse the four moves and any path-only documentation/caller edits, then rerun the searches.

### MOV-002 — Move debug weight scripts

- **Status:** Pending; intentionally not backfilled during the 2026-07-10 move sequence.

- **Objective:** Separate Godot debugging probes from runtime scripts.
- **Files/category:** `debug_weights.gd` and its `.uid` only.
- **Source → target:** root → `scripts/debug/`.
- **Known references:** search scenes, scripts, editor metadata, CLI notes, and exact UID; no active first-party `res://` consumer was found in the planning scan.
- **Prerequisites:** `AUD-003` classification as retained debug tooling.
- **Risk/scope:** Low; one script pair.
- **Validation commands:** `rg -n 'debug_weights|<recorded-uid>' . --glob '!\.git/**' --glob '!\.godot/**'`; Godot script load if available; common checks.
- **Manual checks:** Invoke its documented probe flow if one exists; otherwise confirm it remains discoverable and explicitly note it is unexecuted.
- **Rollback:** Move the script and UID back and revert path-only references.

### MOV-003 — Move Controls menu pair

- **Status:** Implemented 2026-07-10 in `2ab5d36`.

- **Objective:** Prove the menu move protocol on a non-entry overlay.
- **Files/category:** `controls_menu.tscn`, `controls_menu.gd`, `controls_menu.gd.uid`.
- **Source → target:** `scenes/menus/controls/controls_menu.tscn`; `scripts/ui/menus/controls/controls_menu.gd` and sidecar.
- **Known references:** `menu.gd` preloads the scene; the scene references its script.
- **Prerequisites:** `AUD-002`; working static path validator; baseline menu checks.
- **Risk/scope:** Low; one overlay pair and two known path edits.
- **Validation commands:** `rg -n 'res://controls_menu\.(tscn|gd)|controls_menu' --glob '!\.godot/**'`; verify all extracted `res://` targets exist; load the moved scene with the checklist command if available; common checks.
- **Manual checks:** Main menu opens Controls once; keyboard/mouse close returns correctly; focus/input does not leak.
- **Rollback:** Restore the three files and the two original paths; reload menu.

### MOV-004 — Move Pause menu pair

- **Status:** Implemented 2026-07-10 in `1b41aea`.

- **Objective:** Place the pause overlay under UI without touching gameplay pause behavior.
- **Files/category:** `pause_menu.tscn`, `pause_menu.gd`, `.uid`.
- **Source → target:** `scenes/ui/overlays/pause/`; `scripts/ui/menus/pause/`.
- **Known references:** dynamic/preloaded use from `world.gd` and menu-return paths inside the controller must be searched.
- **Prerequisites:** `MOV-003` protocol proven; pause node/tree ownership recorded by `AUD-002`.
- **Risk/scope:** Low–medium; one overlay pair.
- **Validation commands:** exact `pause_menu`/UID and `change_scene_to_file` searches; affected scene load; common checks.
- **Manual checks:** Pause, resume, and return-to-menu in single player; no duplicate overlay.
- **Rollback:** Restore paths/files and re-run pause flow.

### MOV-005 — Move Level-up overlay pair

- **Status:** Implemented 2026-07-10 in `8e577f5`.

- **Objective:** Isolate the player-spawned level-up UI.
- **Files/category:** `level_up_menu.tscn`, `level_up_menu.gd`, `.uid`.
- **Source → target:** `scenes/ui/overlays/level_up/`; `scripts/ui/menus/level_up/`.
- **Known references:** `player.gd` preloads the scene; scene references script.
- **Prerequisites:** `MOV-003`; XP/level-up manual baseline.
- **Risk/scope:** Low–medium; one overlay pair and preload update.
- **Validation commands:** exact filename/UID/path searches; moved scene load; common checks.
- **Manual checks:** Gain a level, choose an upgrade once, return to gameplay, inspect focus and pause state.
- **Rollback:** Restore pair/UID and `player.gd` preload path.

### MOV-006 — Move main-menu shared UI images

- **Status:** Implemented 2026-07-10 in `61cd22e`.

- **Objective:** Establish shared UI asset ownership without moving scenes or theme.
- **Files/category:** `Button.png`, `MenuPanel.png` and their `.import` sidecars only.
- **Source → target:** `assets/sprites/ui/common/`.
- **Known references:** `global_theme.tres`; `menu.tscn`; `upgrade_menu.tscn` for `MenuPanel.png`; UID/path references and `.godot` import cache.
- **Prerequisites:** successful asset-sidecar move trial; main menu, HUD/upgrade visual baseline; `AUD-003` import classification.
- **Risk/scope:** Medium; two shared images and all direct references.
- **Validation commands:** exact filenames, UIDs, and paths across tracked files; Godot reimport and scene loads when available; common checks.
- **Manual checks:** menu buttons/panels, menu overlay, and upgrade panel render identically at checklist resolutions.
- **Rollback:** Restore images/sidecars and old resource paths; reimport without committing `.godot/`.

### MOV-007 — Move collectible drop group

- **Status:** Implemented 2026-07-10 in `757cb50`.

- **Objective:** Group coin and XP drop scenes/scripts/art without including gems or rails.
- **Files/category:** `coin_drop.*`, `xp_drop.*`, `xp_orb.png` and sidecar.
- **Source → target:** scenes → `scenes/entities/collectibles/drops/`; scripts → `scripts/gameplay/collectibles/drops/`; art → `assets/sprites/collectibles/xp/`.
- **Known references:** enemy preloads coin/XP scenes; XP scene references script and texture; HUD/player methods receive drops.
- **Prerequisites:** drop pickup baseline; reference manifest; do not combine with `AUD-012` behavior changes.
- **Risk/scope:** Medium; two scene/script pairs and one texture.
- **Validation commands:** exact `coin_drop`, `xp_drop`, `xp_orb`, UIDs, and all `res://` searches; load both scenes and enemy scene if possible; common checks.
- **Manual checks:** Kill an enemy; coin and XP spawn, animate, collect, and credit exactly once.
- **Rollback:** Reverse group moves and restore enemy/scene resource paths.

### MOV-008 — Move one character family: Dwarf art

- **Status:** Implemented 2026-07-10.
- **Objective:** Place only Dwarf art under explicit character ownership.
- **Files/category:** `character_sprites/dwarf_walk_highres_spritesheet.png`, `character_sprites/dwarf_attack_pixelart_spritesheet.png`, and their valid sidecars. `DwarfBase.png` and its sidecar are explicitly excluded because they are base-system art; the orphan root `dwarf_attack_spritesheet.png.import` is also excluded.
- **Source → target:** `assets/sprites/characters/dwarf/`.
- **Known references:** string paths in `global.gd`, `level.tscn`, `.import` metadata, and UIDs where present. Base resources remain unchanged because `DwarfBase.png` is outside this batch.
- **Prerequisites:** `AUD-003`, `AUD-006`, character animation visual baseline; freeze the optional base-file decision before execution.
- **Risk/scope:** Medium; one actor family, no scene/script moves.
- **Validation commands:** exact Dwarf filenames/path/UID search; load `level.tscn`/`base.tscn`; common checks.
- **Manual checks:** Dwarf idle/walk/attack/dig/death/respawn and Dwarf base rendering.
- **Follow-up:** Investigate the observed UI/itch.io visual mismatch in a separate UI/deployment task; it was not addressed by this asset-only batch.
- **Rollback:** Restore the selected images/sidecars and all old paths; reimport.

### MOV-009 — Move one enemy art family: Rat

- **Status:** Implemented 2026-07-10 in `ad6d6de`.

- **Objective:** Prove dynamic enemy texture relocation with one enemy only.
- **Files/category:** `assets/sprites/enemies/rat/rat_walk_pixelart_spritesheet.png` and sidecar; root import-only `rat_walk_spritesheet.png.import` is excluded pending classification.
- **Source → target:** `assets/sprites/enemies/rat/`.
- **Known references:** `enemy.gd`, `enemy.tscn`, `global.gd` encyclopedia mapping, import metadata.
- **Prerequisites:** enemy spawn/animation/lexicon baseline; `AUD-006` if metadata paths have not otherwise been centralized; `AUD-003` decision on import-only duplicate.
- **Risk/scope:** Medium; one image and path updates.
- **Validation commands:** exact rat filenames/path/UID search; enemy scene load; common checks.
- **Manual checks:** Spawn Rat, verify animation/combat/drop, and verify its lexicon image/discovery.
- **Rollback:** Restore image/sidecar and three known consumer paths; reimport.

### MOV-010 — Move non-entry menu: Lexicon

- **Status:** Implemented 2026-07-10.
- **Objective:** Group the lexicon scene/controller without moving its enemy art.
- **Files/category:** `lexikon.tscn`, `lexikon.gd`, `.uid`.
- **Source → target:** `scenes/menus/lexicon/`; `scripts/ui/menus/lexicon/`.
- **Known references:** direct change from `menu.gd`, test probes, lexicon controller's return path and `Global` content data.
- **Prerequisites:** `MOV-003`; menu and lexicon baseline.
- **Risk/scope:** Medium; one menu pair and test path updates.
- **Validation commands:** exact `lexikon`/UID/change-scene searches; moved scene load and relevant probe if maintained; common checks.
- **Manual checks:** Open lexicon, inspect locked/seen entries, return to menu.
- **Rollback:** Restore pair/UID and direct transition/test paths.

### MOV-011 — Move transport scene group

- **Status:** Pending; the focused minecart characterization is now recorded in `REFACTOR_PROGRESS.md` and the `AUD-002` contract baseline is complete.

- **Objective:** Group minecart scene/script only; leave rails and art for their own batch if references are not fully characterized.
- **Files/category:** `minecart.tscn`, `minecart.gd`, `.uid`.
- **Source → target:** `scenes/entities/transport/minecart/`; `scripts/gameplay/transport/minecart/`.
- **Known references:** `base.gd` preload, minecart sprite paths, world/rail/base node paths and signals.
- **Prerequisites:** `AUD-002`; minecart income/path/pickup baseline; transport art manifest.
- **Risk/scope:** High; one scene pair, behavior unchanged.
- **Validation commands:** exact minecart filename/UID/path searches; scene and `level.tscn` loads; common checks.
- **Manual checks:** Purchase/spawn cart, path creation/extension, movement, gem storage, passive income, base notification.
- **Rollback:** Restore pair/UID and base preload/scene paths.

### MOV-012 — Move worker scene group

- **Objective:** Group Peon scene/script only, separately from character art and navigation changes.
- **Files/category:** `peon.tscn`, `peon.gd`, `.uid`.
- **Source → target:** `scenes/entities/workers/peon/`; `scripts/gameplay/workers/peon/`.
- **Known references:** `base.gd` preload; scene script/art references; parent A*, `BlockLayer`, sibling `Base`, global `gems` group.
- **Prerequisites:** `AUD-009` and any required `AUD-010` fix completed separately; worker baseline.
- **Risk/scope:** High; one scene pair.
- **Validation commands:** exact peon filename/UID/path/node-contract searches; scene and level loads; common checks.
- **Manual checks:** Spawn, reachable/unreachable target selection, pickup, return, deposit once, recovery, multiple workers.
- **Rollback:** Restore pair/UID and base/scene references.

### MOV-013 — Move gem and rail-item inheritance group

- **Objective:** Relocate the inheritance-coupled collectible pair while preserving behavior.
- **Files/category:** `gem.*`, `rail_item.*`, their UIDs; rail item placeholder art only if classified as active and owned by the item.
- **Source → target:** scenes → `scenes/entities/collectibles/{gems,rail_items}/`; scripts → `scripts/gameplay/collectibles/{gems,rail_items}/`; active art → matching asset owner.
- **Known references:** `player.gd`, `base.gd`, `rail_item.gd extends res://gem.gd`, level/world/cart/worker groups and signals.
- **Prerequisites:** `AUD-012`; exact inheritance/reference manifest; collectible gameplay baseline.
- **Risk/scope:** High but bounded; two inseparable scene/script pairs.
- **Validation commands:** exact gem/rail filenames/UIDs, `extends`, group names, and all load/preload searches; load both scenes and level; common checks.
- **Manual checks:** Mine/pick up/tether/deposit gem; purchase/carry/place rail item; cart/Peon interactions unchanged.
- **Rollback:** Restore all selected files and original inheritance/preload/scene paths together.

### MOV-014 — Move HUD stat/health assets

- **Objective:** Separate HUD-owned images from root while leaving HUD scenes/scripts in place.
- **Files/category:** health bar variants, stat icons, `StatRessources.png`, coin HUD art and matching sidecars, using a frozen manifest; exclude upgrade-only assets if ownership differs.
- **Source → target:** `assets/sprites/ui/hud/` and `assets/sprites/ui/common/stats/` for confirmed cross-HUD/upgrade reuse.
- **Known references:** `hud.tscn`, `upgrade_menu.tscn`, theme/other scenes if found; inconsistent spelling/case must be preserved.
- **Prerequisites:** asset ownership matrix; HUD/upgrade visual baseline; `AUD-003`; no renames in this batch.
- **Risk/scope:** Medium–high; one UI asset category, potentially multiple consumers.
- **Validation commands:** exact manifest filenames/UIDs and old/new path search; HUD/upgrade scene loads and reimport; common checks.
- **Manual checks:** Health, stats, XP/resources, upgrade rows, affordability states, and layout at checklist resolutions.
- **Rollback:** Restore the manifest and all resource paths; reimport.

### MOV-015 — Move global theme resource

- **Objective:** Place the shared theme after its dependent images have stable paths.
- **Files/category:** `global_theme.tres` only.
- **Source → target:** `assets/materials/themes/global_theme.tres`.
- **Known references:** `project.godot` custom theme; internal Button/MenuPanel paths; UID references.
- **Prerequisites:** `MOV-006`; reliable project load and menu/UI visual baseline.
- **Risk/scope:** Medium; one globally shared resource and project setting.
- **Validation commands:** exact theme path/UID and internal resources search; project/editor load; affected menu/HUD/upgrade loads; common checks.
- **Manual checks:** All menus, overlays, HUD, and upgrade UI retain styles/focus visuals.
- **Rollback:** Restore resource and `project.godot` theme path.

### MOV-016 — Move boot and main-menu group

- **Objective:** Relocate startup scenes/controllers only after the protocol is proven.
- **Files/category:** `menu.tscn`, `menu.gd`, `.uid`, `main.tscn`; main-menu-only background/lexicon button art may be a separate follow-up, not part of this batch.
- **Source → target:** `scenes/menus/main/menu.tscn`; `scripts/ui/menus/main/menu.gd`; `scenes/boot/main.tscn`.
- **Known references:** `project.godot` main scene; direct returns from pause/HUD/lexicon; hero/controls preloads; `main.tscn` level instance; tests.
- **Prerequisites:** `MOV-003`, `MOV-004`, `MOV-010`; `AUD-002`; successful launch/menu baseline.
- **Risk/scope:** High; entry flow only, no behavior changes.
- **Validation commands:** all exact menu/main paths, `run/main_scene`, change-scene/preload, UID, and test searches; project and both scene loads; common checks.
- **Manual checks:** Cold launch, all menu routes, start single-player, and every return-to-menu route.
- **Rollback:** Restore scenes/script/UID and every original project/transition path as one atomic reversal.

### MOV-017 — Move world/terrain cluster

- **Objective:** Final-stage relocation of the mine scene, world script, and one frozen terrain atlas family per implementation sub-batch.
- **Files/category:** First sub-batch: `level.tscn` plus `world.gd`/UID only. Subsequent separately committed sub-batches: one of brick, edge, front/damage, fog, background, or rail atlas families; never all at once.
- **Source → target:** level → `scenes/world/mine/`; world script → `scripts/systems/world_generation/`; atlases → `assets/sprites/world/{terrain,fog,rails}/`.
- **Known references:** `main.tscn`, VS scenes/scripts, player/base/HUD/upgrades/entities, embedded TileSet sources/atlas coordinates/collision layers, navigation, animation/render order.
- **Prerequisites:** all relevant prior moves; `AUD-002`; repeatable project/scene loading and full core gameplay/render/collision/navigation baseline.
- **Risk/scope:** Very high; despite the single heading, execute each stated sub-batch as its own commit and validation cycle.
- **Validation commands:** repository-wide `res://`, UID, TileSet, source-ID, atlas, layer, node-path, load/preload search; project and all level/VS scene loads; common checks.
- **Manual checks:** Full core gameplay, visual/rendering, collision/navigation, local VS, and web-export smoke checks from `VALIDATION_CHECKLIST.md`.
- **Rollback:** Revert only the current sub-batch commit, regenerate imports/cache, and repeat the complete baseline before attempting another family.

### MOV-018 — Move Global autoload script

- **Objective:** Relocate only the existing autoload script after its responsibilities are stabilized; do not redesign it.
- **Files/category:** `global.gd` and `.uid`.
- **Source → target:** `scripts/core/autoloads/global.gd` and sidecar.
- **Known references:** `project.godot` autoload path, `Global` consumers, hero/enemy asset strings, save path, input and networking state.
- **Prerequisites:** `AUD-002`, `AUD-005`, `AUD-006`; startup, save, input, hero-selection, lexicon, and network-state baselines.
- **Risk/scope:** High; one script pair and project setting.
- **Validation commands:** exact global path/UID, autoload, `Global`, load/preload, and inheritance searches; project/editor load; common checks.
- **Manual checks:** Cold launch, hero selection, input, unlock save/load, lexicon, local VS, and online lobby initialization.
- **Rollback:** Restore script/UID and the original autoload path atomically.

### MOV-019 — Move Base scene group

- **Objective:** Group Base scene/controller without moving faction art, workers, transport, rails, or upgrade behavior.
- **Files/category:** `base.tscn`, `base.gd`, `.uid`.
- **Source → target:** `scenes/entities/base/`; `scripts/gameplay/base/`.
- **Known references:** `level.tscn`; faction texture preloads; rail/Peon/cart preloads; player/gem deposit, HUD, upgrade and game-over signals.
- **Prerequisites:** `AUD-002`, `AUD-007`; base heal/deposit/upgrade/spawn/damage baseline.
- **Risk/scope:** High; one scene pair.
- **Validation commands:** exact base filename/path/UID/node/signal searches; base and level scene loads; common checks.
- **Manual checks:** Heal, deposit once, open upgrades, purchase each spawned category, receive damage/spikes, game over.
- **Rollback:** Restore pair/UID and all scene/preload paths.

### MOV-020 — Move Player script ownership

- **Objective:** Place the level-embedded player controller under character gameplay ownership without extracting components.
- **Files/category:** `player.gd` and `.uid`; `level.tscn` remains in place.
- **Source → target:** `scripts/gameplay/characters/player.gd` and sidecar.
- **Known references:** `level.tscn`, gem/totem/level-up preloads, Global metadata paths, fixed world/HUD/Base sibling paths.
- **Prerequisites:** `AUD-002`, `AUD-006`, `AUD-012`; full Dwarf and Shaman gameplay baseline.
- **Risk/scope:** Very high; one central script pair and one scene reference.
- **Validation commands:** exact player path/UID and all preload/load/node-path searches; level scene load and script parse; common checks.
- **Manual checks:** Full player section of the validation checklist for every available hero, including digging, combat, carrying, abilities, death/respawn, and level-up.
- **Rollback:** Restore script/UID and `level.tscn` script path.

### MOV-021 — Move Enemy scene group

- **Objective:** Group the generic enemy scene/controller without combining enemy art or balance extraction.
- **Files/category:** `enemy.tscn`, `enemy.gd`, `.uid`.
- **Source → target:** `scenes/entities/enemies/common/`; `scripts/gameplay/enemies/`.
- **Known references:** `world.gd` enemy scene constant/spawning, dynamic art paths, coin/XP preloads, Global encyclopedia data, level A* and target node paths.
- **Prerequisites:** `AUD-002`, `AUD-006`, `AUD-011`; enemy wave/combat/drop/lexicon baseline.
- **Risk/scope:** High; one scene pair.
- **Validation commands:** exact enemy filename/path/UID, scene constant, load/preload, group and node-path searches; enemy and level scene loads; common checks.
- **Manual checks:** Spawn each type, animate/path/attack/die/drop, wave scaling, boss unlock, lexicon discovery.
- **Rollback:** Restore pair/UID and every spawn/scene path.

### MOV-022 — Move remaining actor art one family at a time

- **Objective:** Complete art ownership after Dwarf and Rat trials, with one independently committed family per execution.
- **Files/category:** Exactly one family per run: Shaman, Mech, Bat, Orc, Spider, Trogg, Peon, Minecart, or unambiguous shared character art; source plus `.import` only.
- **Source → target:** the matching `assets/sprites/{characters,enemies,workers,transport}/<family>/` directory.
- **Known references:** `global.gd`, `enemy.gd`, entity scenes/scripts, import sidecars, and possible duplicated/import-only root names.
- **Prerequisites:** `MOV-008` or `MOV-009` proven; `AUD-003`, `AUD-006`; family-specific animation/gameplay baseline.
- **Risk/scope:** Medium per family; never execute multiple families in one commit.
- **Validation commands:** frozen-family filename/path/UID search; owning scene and level load; reimport; common checks.
- **Manual checks:** Spawn/use only the selected family and verify every animation/state plus its selection/lexicon representation where applicable.
- **Rollback:** Reverse only the selected family manifest and consumer paths, then reimport.

### MOV-023 — Move Shaman totem ability group

- **Objective:** Group the totem scene/controller separately from its four ability images.
- **Files/category:** `shaman_totem.tscn`, `shaman_totem.gd`, `.uid`; art is a following per-family asset execution, not mixed into the scene move.
- **Source → target:** `scenes/entities/abilities/shaman_totem/`; `scripts/gameplay/abilities/shaman_totem/`; later art → `assets/sprites/characters/shaman/abilities/totems/`.
- **Known references:** player preload; four string-loaded texture paths; HUD totem wheel/status; world/player effects.
- **Prerequisites:** `AUD-006`; Shaman ability baseline. Art execution additionally requires successful scene-group validation.
- **Risk/scope:** High for the scene pair; medium for the later art-only commit.
- **Validation commands:** exact totem filenames/path/UID/type keys and texture searches; scene and level loads; common checks.
- **Manual checks:** Cast each totem, verify sprite, duration/effect, wheel/status, and cleanup.
- **Rollback:** Restore only the current scene or art sub-batch and all corresponding paths.

### MOV-024 — Move HUD scene group

- **Objective:** Group HUD scene/controller after gameplay state is no longer accidentally re-owned by movement.
- **Files/category:** `hud.tscn`, `hud.gd`, `.uid`; no images.
- **Source → target:** `scenes/ui/hud/`; `scripts/ui/hud/`.
- **Known references:** `level.tscn`, player/base/world/enemy/drops/upgrades, code-created widgets, fixed child paths and signals.
- **Prerequisites:** `AUD-007`, `AUD-008`, `AUD-002`; `MOV-014`; full HUD baseline.
- **Risk/scope:** Very high; one scene pair.
- **Validation commands:** exact HUD path/UID, instance, signal, `$`/`get_node`, and load/preload searches; HUD/level/VS scene loads; common checks.
- **Manual checks:** Every HUD display/update, minimap, notices, mobile controls, ability status, respawn/game-over, single-player and split-screen layouts.
- **Rollback:** Restore pair/UID and every scene/controller reference.

### MOV-025 — Move Upgrade menu scene group

- **Objective:** Group the large upgrade UI without changing economy, prices, node hierarchy, or art.
- **Files/category:** `upgrade_menu.tscn`, `upgrade_menu.gd`, `.uid`.
- **Source → target:** `scenes/ui/upgrades/`; `scripts/ui/upgrades/`.
- **Known references:** `level.tscn`, Base/player/HUD/world/VS direct mutations, repeated deep control paths, shared UI/stat images.
- **Prerequisites:** `AUD-007`, `AUD-002`; `MOV-014`, `MOV-015`; purchase-flow baseline.
- **Risk/scope:** Very high; one 732-line scene pair.
- **Validation commands:** exact upgrade path/UID, instance, signal, node-path and resource searches; upgrade/level/VS scene loads; common checks.
- **Manual checks:** Open/close, every purchase category, insufficient funds, faction/VS purchases, focus and layout at checklist resolutions.
- **Rollback:** Restore pair/UID and all level/Base/VS references.

### MOV-026 — Move remaining menu groups individually

- **Objective:** Complete menu ownership with one independently committed menu per execution.
- **Files/category:** Exactly one pair per run: `hero_selection_menu.*` or `online_lobby.*`; entry menu and Controls/Lexicon are covered elsewhere.
- **Source → target:** corresponding `scenes/menus/<menu>/` and `scripts/ui/menus/<menu>/`.
- **Known references:** menu preloads/overlays, Global hero/peer state, online transition/RPC paths, tests, scene-internal script paths.
- **Prerequisites:** `MOV-003`; menu-specific baseline. Online lobby also requires network contract/two-client plan.
- **Risk/scope:** Medium for hero selection; high for online lobby; never combine them.
- **Validation commands:** frozen-menu filename/path/UID, preload/change-scene/RPC searches; moved scene load; common checks.
- **Manual checks:** Complete only the selected menu's checklist flow, including back/focus/double-activation; online requires two clients.
- **Rollback:** Reverse only the selected pair/UID and its callers.

### MOV-027 — Move versus controllers individually

- **Objective:** Separate local and online VS orchestration without altering networking or level APIs.
- **Files/category:** One scene/script/UID pair per execution: `vs_mode.*` or `vs_online.*`.
- **Source → target:** `scenes/gameplay/versus/<mode>/`; `scripts/gameplay/versus/<mode>/`.
- **Known references:** menu/hero-selection/lobby transitions, `level.tscn`, level internals, enemy sending, tests, RPC/peer state.
- **Prerequisites:** `AUD-002`; local split-screen baseline for local VS; deterministic/two-client test plan for online VS.
- **Risk/scope:** High per mode; never combine local and online.
- **Validation commands:** selected mode filename/path/UID, level, signal, RPC, load/preload and test searches; selected scene load; common checks.
- **Manual checks:** Full selected VS flow; online additionally requires host/join, synchronized start, enemy send, disconnect/return.
- **Rollback:** Restore only the selected pair/UID and transition/test references.

### MOV-028 — Move maintained test probes by suite

- **Objective:** Establish `tests/` without asserting that every root `test_*` file is maintained.
- **Files/category:** One `AUD-003`-classified suite per execution: navigation/A*, menus/UI, tilesets/world, VS/network, or runner harness; GDScript plus UIDs and required scene fixture.
- **Source → target:** `tests/unit/`, `tests/integration/`, or `tests/visual/`; fixtures → `tests/fixtures/`.
- **Known references:** CLI invocations, hardcoded `res://` paths in probes, `run_test_node.tscn`, addon test discovery under `res://tests/`.
- **Prerequisites:** `AUD-003`; documented command and expected result for the selected suite.
- **Risk/scope:** Low–medium per suite; no production files unless path-only test references require updates.
- **Validation commands:** exact selected filenames/UIDs/paths; run the documented selected suite; common checks.
- **Manual checks:** Confirm discovery and expected pass/fail baseline; ensure export behavior is unchanged unless separately authorized.
- **Rollback:** Restore only the selected suite and its path references.

### MOV-029 — Move remaining repository tools by purpose

- **Objective:** Complete tool separation without mixing unrelated utility categories.
- **Files/category:** One classified category per execution: asset generators, resizers/processors, migration patch/fix/update scripts, export tooling, or networking server files (`signaling_server.js` with `package.json`).
- **Source → target:** one matching `tools/{asset_pipeline,migration,networking,archive}/` directory; keep `export_web.sh` at root until workflow/cwd assumptions are documented, or move it alone.
- **Known references:** Python/Node imports, relative asset paths, shell working-directory assumptions, workflows, docs, package scripts, manual invocations.
- **Prerequisites:** `AUD-003`; documented owner, inputs, outputs, working directory, and mutation behavior for the selected category.
- **Risk/scope:** Low–medium per category; never combine generators, migration scripts, export, and networking.
- **Validation commands:** exact selected filename/import/reference search; syntax/help or documented dry-run validation; common checks.
- **Manual checks:** Confirm invocation from the documented working directory and that no asset/source mutation occurred during validation.
- **Rollback:** Reverse only the selected category and reference edits.

No batch above authorizes deletion, cleanup, spelling correction, behavior refactoring, import-setting changes, or export-filter changes.

## 11. Recommended first migration batch

Recommend exactly **`MOV-003 — Move Controls menu pair`** as the first implementation batch after its documented prerequisites are met. It is a small three-file scene/controller group, is outside central gameplay, has one clear caller (`menu.gd`) and one internal script reference, offers immediate separation of menu content from the root, can be loaded independently, and is straightforward to reverse. `MOV-001` and `MOV-002` are lower runtime risk but depend on the still-uncompleted artifact-classification task and provide less proof that the Godot path-migration protocol works.

This recommendation is planning only; no files are moved by `STR-001`.

## 12. Deferred architectural changes

These findings affect eventual ownership but must not be mixed with folder moves:

- Record scene/node/input/collision/tile/render contracts (`AUD-002`) and classify generated/test/archive/suspected-unused artifacts (`AUD-003`).
- Consolidate runtime input registration (`AUD-005`); moving `Global` or `world.gd` must not also change bindings.
- Centralize hero, enemy, and Shaman totem metadata (`AUD-006`); do not manufacture data resources as part of an asset move.
- Move economy/progression state out of HUD and upgrades (`AUD-007`) before treating those controllers as presentation-only.
- Move code-created HUD widgets into inspectable UI scenes (`AUD-008`) separately from HUD file relocation.
- Characterize and, only when confirmed, repair Peon pathfinding (`AUD-009`, `AUD-010`) before moving worker/navigation ownership.
- Extract wave scheduling from `world.gd` (`AUD-011`) only after world movement and validation contracts are stable.
- Standardize collectible pickup behavior (`AUD-012`) independently from the gem/rail/drop path changes.
- Define and implement settings persistence (`AUD-015`, `AUD-016`) as product architecture work, not directory scaffolding.
- Decisions about `main.tscn` removal, online determinism, networking boundaries, addon production necessity, save schema, audio, settings, and export filters remain architectural/product tasks. This document creates no new implementation task for them.

## Structural coverage check

The proposed tree covers every current major category: project/export/deployment configuration stays at root or `.github`; scenes and scripts have boot/gameplay/menu/UI/world/entity destinations; sprites/textures have character, enemy, worker, transport, collectible, base, world, effect, and UI owners; future audio/fonts/shaders/materials are reserved; the theme and future data resources have destinations; tests/debug/tools/docs/addons are separated; and generated/import metadata has explicit handling. Central world, player, autoload, UI/economy, workers/transport, collectibles/inheritance, enemies, networking, plugin, tracked metadata, and archive/unused candidates are explicitly marked high risk.

## Unresolved structural questions

- Should the checked-in `.import` and `.gd.uid` policy remain as-is for Godot 4.7, or should a later repository-policy task standardize which source-adjacent metadata is versioned?
- Are root import-only sidecars (`dwarf_attack_spritesheet.png.import`, `mech_walk_spritesheet.png.import`, `rat_walk_spritesheet.png.import`) remnants, intentional remaps, or evidence of missing sources?
- Which Python utilities are reproducible supported tooling, historical migrations, or archive candidates? `AUD-003` must answer this before `tools/` movement.
- Are `menu_free.tscn.txt` and `upgrade_menu_free.tscn.txt` intentional source templates, archived alternatives, or generated snapshots?
- Should faction base art be owned by `assets/sprites/base/factions/` or by each playable character? Actual future reuse should decide.
- Should `global_theme.tres` ultimately live under `assets/materials/themes/` or a dedicated `assets/themes/` once theme/resource volume grows?
- Is `addons/godot_ai` required in production and Web exports, or only during development? Its enabled plugin and runtime autoload currently make the answer operationally significant.
- Will `signaling_server.js` remain part of this repository's deployable system (`tools/networking/`) or move to a separately deployed service repository?
