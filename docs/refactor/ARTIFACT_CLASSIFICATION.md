# MineWars Artifact Classification

Backlog task: `AUD-003`
Evidence reviewed: repository state and history on 2026-07-10

## 1. Purpose

This document defines how ambiguous repository artifacts must be handled before any MineWars migration or cleanup begins. It is a classification and protection policy, not authorization to move, rename, untrack, regenerate, or delete anything. Unusual files are treated as evidence until their ownership and use are proved.

The initial worktree contained one unrelated modification, `AGENTS.md`. It was inspected as required and was not changed by this task. The audit used `AGENTS.md`, `PROJECT_AUDIT.md`, `VALIDATION_CHECKLIST.md`, `TARGET_STRUCTURE.md`, the tracked tree, project/export/addon configuration, references, file contents, and relevant Git history.

## 2. Classification terminology

- **Authored source:** Human-maintained code, scenes, resources, documents, or configuration that defines the project.
- **Authored asset:** Human- or tool-created source media intentionally used as project content, such as PNG or SVG files. A tool-created image can still be authoritative authored content.
- **Runtime dependency:** Loaded directly or indirectly while the game runs. Breaking it can prevent parsing, loading, or correct behavior.
- **Editor-only dependency:** Needed by the Godot editor or a development workflow, but not by normal game behavior.
- **Export or deployment dependency:** Needed to produce or deploy a build, or operated separately to support a deployed feature.
- **Generated and reproducible:** Output that can be recreated from identified authoritative inputs by a known tool and command.
- **Generated but intentionally tracked:** Tool output kept in Git because it is authoritative, collaboration-relevant, or not reliably reproduced by the normal toolchain.
- **Import sidecar:** Godot metadata adjacent to an imported source, normally `<source>.import`, containing importer settings, a source path, UID, and cache destinations.
- **Configuration:** Project, export, addon, repository, CI, or service settings whose values are maintained intentionally.
- **Third-party addon:** A self-contained external package under `addons/`, including its code, metadata, documentation, and license.
- **Development tooling:** Checks, probes, generators, patchers, migration scripts, debug scripts, and local export helpers not loaded by normal gameplay.
- **Historical archive:** A retained prior implementation, snapshot, or record that is not the active implementation.
- **Backup or duplicate candidate:** Content that may repeat or precede active content but is not deletion-safe until semantic and provenance checks are complete.
- **Unknown or investigation required:** Purpose, authority, or dependency cannot be established from current repository evidence.

Confidence labels are **confirmed**, **strongly indicated**, **probable**, **unclear**, and **unknown**. “Currently unreferenced” means no relevant repository reference was found; it does not mean unused or safe to delete.

## 3. Repository-wide artifact policy

Track authored source, authoritative authored assets, project/export/deployment configuration, third-party packages with their licenses, and any generated material intentionally serving as the authoritative collaborative form. Track source-adjacent metadata only under an explicit Godot-version policy; the current repository already tracks it, so preserve that state until a dedicated policy task changes it.

Normally ignore reproducible caches and outputs such as `.godot/`, `.godot/imported/`, `build/`, `__pycache__/`, logs, OS metadata, and local export products. The current `.gitignore` covers `.godot/`, `*.translation`, `.DS_Store`, and `__pycache__/`; `build/` is currently untracked but is not explicitly ignored. This audit does not change that policy.

“Generated-looking” is not a deletion criterion. In particular:

- do not remove tracked `.import` or `.gd.uid` files merely because Godot can generate related metadata;
- do not regenerate or overwrite PNGs merely because a Python generator exists;
- do not assume an absent text reference excludes editor use, CLI use, UID use, dynamic paths, export inclusion, or historical value;
- keep a source asset, its valid `.import` sidecar, and any required move-time UID relationship together during migration;
- keep an addon intact and use its supported install/upgrade mechanism rather than redistributing its internals;
- keep archives outside active runtime ownership only after a dedicated archive batch records provenance and recovery instructions;
- protect unknown artifacts in place until a named investigation resolves their status.

The Web preset uses `export_filter="all_resources"`. Therefore root probes, archives, and addon resources may be export candidates even when gameplay does not load them. Export inclusion and runtime necessity are different questions and must be tested separately before changing filters or files.

## 4. Tracked Godot metadata

The repository contains 85 tracked `.import` files and 161 tracked `.gd.uid` files. Of the UID files, 47 are at the root and most of the remainder belong to `addons/godot_ai/`. `.godot/` is ignored and not tracked.

### `.import` sidecars

Godot writes these for imported sources. They record importer type and parameters, source path, resource UID, and derived cache files under `.godot/imported/`. The cache products are reproducible and not runtime source; the sidecars preserve current import choices and UIDs and can affect collaboration consistency. Most tracked sidecars have a matching tracked PNG or SVG.

Policy: retain the current tracked sidecars and move a valid sidecar atomically with its source during future Godot-aware asset batches. Do not migrate or commit `.godot/imported/`. A later repository-policy task may decide whether standard Godot-generated sidecars should remain tracked, but that decision must follow a clean reimport comparison on Godot 4.7 and cross-check UIDs and visual/import behavior. Confidence: **confirmed**.

### `.gd.uid` sidecars

Godot 4 associates these UID files with GDScript source. They are editor-generated and reproducible in a broad sense, but regeneration can assign a different UID and invalidate UID consumers or editor cache relationships. They are not executable runtime code by themselves and are not normally an export payload requirement when paths resolve, but they are collaboration- and migration-relevant.

Policy: retain and move each `.gd.uid` with its `.gd` owner. Verify exact UID references and a clean Godot resource scan after movement. Do not centralize, hand-edit, or bulk-regenerate them. Confidence: **strongly indicated** because runtime validation is blocked in the current environment.

`nest.gd.uid` is exceptional: its corresponding `nest.gd` is absent, no UID or filename consumer was found, and history shows the UID only in the initial commit. Classify it as an orphan metadata/deletion candidate requiring proof, not as an ordinary script sidecar. Confidence: **strongly indicated**.

### `.godot/` metadata and import cache

`.godot/` is editor-generated, reproducible local state and is ignored. It can contain resource UID and imported-cache information needed by a local editor session, but it is not collaborative source and must never be moved into the target tree or committed as a repair. Policy: regenerate locally as needed and inspect task-caused changes only. Confidence: **confirmed**.

## 5. Import-only sidecars

Nine tracked source-adjacent metadata files lack the source named in their own contents:

- `Easy_Brick_Gradient.png.import`, `Middle_Brick_Gradient.png.import`, `Hard_Brick_Gradient.png.import`;
- `character_sprites/minecart_placeholder.png.import`, `character_sprites/peon_placeholder.png.import`;
- `dwarf_attack_spritesheet.png.import`, `mech_walk_spritesheet.png.import`, `rat_walk_spritesheet.png.import`;
- `nest.gd.uid` (a script UID sidecar rather than an import sidecar).

The three gradient sidecars point to missing root PNGs used by older `fix_*`, `resize_*`, and `update_*` utilities. Active scene paths now use other brick/front assets. The two placeholder sidecars point into `character_sprites/`, while `generate_faction_assets.py` generates similarly named files at the repository root and `build_base_features.py` embeds root placeholder paths. The three character/enemy sidecars point to missing root sprites while active, differently named pixel-art assets exist under `character_sprites/`. All eight `.import` files map their missing source to `.godot/imported/*.ctex`; none is an authored asset itself.

These files are **probable historical import residue**, not usable atomic companions in their present state. Their sidecar contents are reproducible only if the missing source and same importer settings are restored. They are not confirmed runtime-loaded, and an `all_resources` export cannot make a missing source usable. Nevertheless, do not delete or move them with similarly named active assets: first inspect the initial commit/tree, compare any recoverable source hashes and image dimensions with current assets, perform a clean Godot 4.7 reimport in a disposable worktree, and confirm no UID consumer depends on them.

For normal source-plus-sidecar pairs, migration batches must treat `<asset>` and `<asset>.import` as one atomic group. For these import-only exceptions, freeze them in place until the prerequisite investigation decides whether to restore the source, archive the metadata as history, or authorize removal in a cleanup task.

## 6. Historical and development-tool files

All 74 root Python files are tracked, first-party development artifacts; none is referenced by `project.godot`, an active `.gd`/`.tscn` runtime path, CI, `export_web.sh`, or documented supported invocation. Many execute immediately and overwrite active scenes, scripts, or images with hardcoded root paths. They must not be run casually.

Recommended categories:

- **Read-only content/image checks:** `check_content.py`, `check_grid.py`, `check_img.py`, `check_img2.py`, `dump_globals.py`, `test_mask.py`, `test_ocr.py`. Retain in place temporarily; after dependencies, inputs, exit semantics, and non-mutating behavior are documented, move supported checks to `tools/content_checks/`. `dump_globals.py` reads the no-longer-present `upgrade_menu_free.tscn` path rather than the tracked `.txt`, so it is presently stale. The four `check_*` scripts are useful diagnostics but have no help mode, assertions, or documented expected output. Classification: development tooling, **strongly indicated**.
- **Asset generators/processors:** `generate_*`, `resize_*`, `process_icons.py`, `make_drops.py`, and image-mutating `fix_bg*.py`/`fix_everything.py`. Retain in place temporarily. Move only a proven, reproducible family later to `tools/asset_pipeline/`, with exact inputs, outputs, dependencies (mostly Pillow, sometimes pytesseract), working directory, and nondestructive/dry-run procedure. Multiple “final”, “fixed”, “perfect”, and “ultimate” variants are historical alternatives, not one supported pipeline. Classification: development tooling plus historical experiments, **strongly indicated**.
- **Scene/script builders and patchers:** `build_*`, `fix_*`, `patch_*`, `update_*`, `add_*`, `remove_ysort.py`, `rebuild_*`, `parse_menu.py`. They directly rewrite current or former `.gd`/`.tscn` files, often by brittle textual replacement. Git history and current outputs indicate they captured rapid prototype migrations. Retain in place temporarily, then archive outside the runtime tree in a dedicated `tools/archive/prototype_migrations/` batch only after inputs/outputs and the commit they produced are mapped. Do not present them as supported refactor tools without idempotence and current-path tests. Classification: historical development tooling, **strongly indicated**.
- **Godot probes:** 19 `test_*.gd` scripts, `run_test.gd`, `run_test_node.gd`, `run_test_node.tscn`, their UIDs, and `debug_weights.gd`/UID. They are ad hoc `SceneTree` or scene-load probes, print results rather than forming a unified asserting suite, and have hardcoded current paths. `debug_weights.gd` immediately quits and contains only a comment, so it has no current diagnostic effect. Retain in place temporarily; move only a selected, documented probe family to `tests/`, or `debug_weights.gd` to `scripts/debug/`, after recording a command and expected result. Classification: development/debug tooling, **confirmed** from contents.
- **Local export helper:** `export_web.sh` refuses Mono/.NET Godot, creates `build/web`, and invokes the Web preset. It is deployment tooling, although CI uses `firebelley/godot-export` rather than this script. Retain as export/deployment infrastructure; a later tools batch may move it only with CI/docs reference checks. Confidence: **confirmed**.

No normal runtime imports these tools. Because the export preset selects all resources, their actual Web package inclusion should be measured before claiming they are excluded; regardless, they are not required for game execution.

## 7. Archived `.tscn.txt` files

### `menu_free.tscn.txt`

This tracked 92-line text scene has a `MenuFree` root, no controller script, editor `unique_id` fields, and slightly older absolute positions than active `menu.tscn`. The active scene is 94 lines, has the `menu.gd` script, and is the configured main scene. No runtime, tool, shell, documentation, or addon configuration references the `.txt` file. Git history shows it was introduced during the 2026-07-07 absolute-layout refactor and touched by the 2026-07-08 UID-cache fix.

Classification: historical scene snapshot/alternative, **strongly indicated**. It contains layout provenance but no unique active behavior. Retain temporarily; later archive it with the associated commits or convert its relevant rationale to documentation. It is a deletion candidate only after opening/comparing both scenes in a compatible editor and confirming no recovery workflow uses it.

### `upgrade_menu_free.tscn.txt`

This tracked 538-line `UpgradeMenuFree` Control scene is structurally older than the active 732-line `UpgradeMenu` CanvasLayer: it has no active controller, lacks the current panel hierarchy and faction UI, and uses older unique IDs/resource IDs. No current file references the `.txt` name. Several Python scripts instead refer to `upgrade_menu_free.tscn` without `.txt`, which is absent; that strongly suggests the `.txt` file preserved an intermediate input after those scripts ceased to be directly runnable. History links it to the 2026-07-07 menu/upgrade refactors and the 2026-07-08 UID-cache fix.

Classification: historical intermediate/template snapshot, **strongly indicated**. It contains substantial old layout content but is not the active scene. Retain temporarily; archive later with the builder/patcher family and commit provenance. Consider deletion only after a semantic scene comparison and confirmation that no intended reconstruction process needs it.

The `.txt` suffix prevents normal Godot scene loading and the `all_resources` preset does not make these active `.tscn` resources. Both files should remain outside future active `scenes/` ownership.

## 8. Base-art ownership

`DwarfBase.png` and `ShamanBase.png`, with matching tracked `.import` files, are runtime-authored assets owned by the **base gameplay system**, specifically faction variants of one base structure:

- `base.gd` preloads both in `BASE_TEXTURES` and selects by the player/hero faction;
- `base.tscn` defaults to `DwarfBase.png`;
- the same base node owns healing, deposits, upgrades, health, and faction-specific spawns;
- Git history describes replacement/restoration of “Dwarf and Shaman base sprites” and faction-specific base behavior;
- image checks and `fix_base.py` also treat them as a pair.

They are not character animation art, world terrain, or UI. Recommended future target: `assets/sprites/base/factions/dwarf/DwarfBase.png` and `assets/sprites/base/factions/shaman/ShamanBase.png` (preserving names initially), moved with sidecars and all base references in a dedicated base-art batch. If more structures later reuse them, ownership may be widened to `assets/sprites/structures/base/factions/`, but current evidence does not justify character ownership. Confidence: **confirmed**.

`MineTrails.png` was added in the faction-feature commit but has no non-import reference; its name suggests minecart/rail or base-faction presentation, not enough to assign ownership. `StompSprite.png` was added only in the baseline commit and has no non-import reference; the current stomp effect is code-driven. Both remain **unknown/investigation required**, protected from base or character moves.

## 9. Theme placement

`global_theme.tres` is authored Godot configuration/resource content and an active runtime UI dependency. `project.godot` assigns it as the global custom theme. It defines reusable Button states from `Button.png` and a Panel style from `MenuPanel.png`. `menu.tscn` and `upgrade_menu.tscn` also reference `MenuPanel.png` directly, so that texture is shared rather than menu-exclusive.

Classification and eventual placement:

- `global_theme.tres`, `Button.png`, and their sidecars: reusable global UI styling; target `assets/themes/global/` (theme) and `assets/sprites/ui/common/` (texture), or keep both under a cohesive `assets/themes/global/` bundle if the project adopts theme-owned textures.
- `MenuPanel.png` and sidecar: shared UI panel artwork used by the global Panel style, main menu, and upgrade menu; target `assets/sprites/ui/common/`, not a menu-only folder.
- `MainMenuBackground.png` and `Beastary.png`: menu-specific art; target the main-menu asset area.
- health bars, stat icons, `GoldCoinPile.png`, and similar explicit `hud.tscn`/`upgrade_menu.tscn` resources: HUD/upgrade-specific unless a reference manifest proves wider reuse.
- no first-party font file or custom font resource was found; labels use engine/default fonts with per-scene overrides.

Use a dedicated `assets/themes/` destination now rather than `assets/materials/themes/`: a Godot `Theme` is a UI style resource, not a material, and one active global theme is sufficient to establish clear ownership. Theme dependencies must migrate in ordered atomic batches: first shared textures plus sidecars and all direct consumers, then the `.tres` and `project.godot` path. Scenes contain hardcoded `res://MenuPanel.png` paths; `global_theme.tres` contains hardcoded paths to both shared textures; `project.godot` contains the theme path. Confidence: **confirmed**.

## 10. Addon classification and exports

The only repository addon is `addons/godot_ai/` (231 tracked files), identified by its README, MIT `LICENSE`, and `plugin.cfg` as the third-party Godot AI MCP plugin version 2.9.1.

- **Enabled:** yes, via `project.godot` `editor_plugins/enabled`.
- **Development role:** confirmed. It connects AI/MCP clients to the editor and includes editor docks, handlers, client configuration, tests, and utilities. It requires Godot 4.5+ and external `uv` for its Python server workflow.
- **Runtime component:** `project.godot` currently registers `_mcp_game_helper` from `addons/godot_ai/runtime/game_helper.gd` as an autoload. That helper runs in a launched game process to service debugger screenshot/evaluation/log messages. It returns early in editor context and is idle without an active debugger, including a release export according to its code comments.
- **Export status:** operationally export-related under the present configuration. The autoload path must parse and its preloaded addon runtime files must exist when the game starts; the `all_resources` preset may include further addon resources. The editor plugin itself is not required for normal player gameplay, but the package cannot be classified as wholly editor-only while this autoload remains configured.
- **Licensing:** `addons/godot_ai/LICENSE` and `README.md` must remain with the addon in source distributions and during any upgrade/reinstall. Attribution/export obligations should be checked against the MIT license and distribution policy; do not strip them.

Policy: retain the addon intact under `addons/godot_ai/`; do not move individual files. Before any production/export exclusion, a dedicated addon/export audit must determine how the autoload was installed, whether disabling the plugin removes it, compare release exports with and without it, and verify startup plus editor MCP behavior. If retained only for development, remove its runtime/export coupling in a separately authorized configuration task, not during reorganization. Confidence: **confirmed** for configuration and code role; **unclear** whether the team intentionally requires MCP runtime support in production exports.

## 11. Signaling-server ownership

`signaling_server.js` is a first-party Node.js service using the `ws` package. `package.json` names it `minewar-signaling-server`, declares `ws ^8.16.0`, and starts it with `node signaling_server.js`. The server assigns two WebSocket clients to a room and relays WebRTC SDP/ICE messages; it is not a Godot script and is not loaded into the game client.

The Godot client in `online_lobby.gd` connects to `wss://minewar.onrender.com`, exchanges the same join/peer/SDP/ICE message shapes, then closes signaling after the WebRTC peer connects. This directly links the service contract to Online VS. Git history introduced the server as “signaling server files for Render deployment.” The repository contains no Render manifest, lockfile, tests, health check, deployment documentation, or CI deployment for this service, so its current deployment automation and exact production revision are unconfirmed.

Classification: separate export/deployment dependency for Online VS, not a single-player/local-VS runtime dependency and not ordinary development tooling. Language/runtime: Node.js with npm and `ws`; deployed separately from the Godot Web client. Activity is **strongly indicated** by the hardcoded production URL and matching protocol, but live availability was not tested.

Recommended ownership: keep it in this repository for now under a future top-level `services/signaling/` project, with its own `package.json`, lockfile policy, README, protocol/version notes, deployment configuration, and tests. Do not place it under generic `tools/`; it is operated infrastructure. Consider a separate repository only after deployment ownership, release cadence, observability/secrets, and compatibility versioning are documented. The small service and tightly coupled protocol currently favor a monorepo top-level service. Confidence: **strongly indicated**.

## 12. Artifact classification table

| Artifact or pattern | Representative paths | Classification | Runtime relevance | Tracked status | Recommended action | Confidence | Prerequisite before changing it |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Valid import pairs | `Button.png` + `.import`, `character_sprites/*.png` + `.import` | Authored asset + import sidecar | Runtime where referenced; editor import | Both tracked | Retain and move with owner atomically | Confirmed | Godot-aware move, reference/UID manifest, clean reimport |
| Import cache | `.godot/`, `.godot/imported/` | Generated and reproducible | Local editor/runtime cache only | Ignored/untracked | Retain locally; never migrate or commit | Confirmed | None; regenerate from source |
| Script UID pairs | `base.gd.uid`, `global.gd.uid`, addon UIDs | Generated but intentionally tracked metadata | Migration/editor relevant; not executable | Tracked | Retain and move with script | Strongly indicated | UID search and Godot resource scan |
| Orphan import sidecars | Eight missing-source `.png.import` files listed in section 5 | Historical import residue / unknown | No current runtime load confirmed | Tracked | Investigate further; freeze in place | Probable | Recover initial sources, compare hashes, disposable clean reimport |
| Orphan script UID | `nest.gd.uid` | Orphan generated metadata | None confirmed | Tracked | Deletion candidate requiring proof | Strongly indicated | Recover/search history and validate clean project without it |
| Global theme bundle | `global_theme.tres`, `Button.png`, `MenuPanel.png` | Authored UI resource/assets; runtime dependency | Global runtime UI | Tracked | Retain; move in ordered dedicated batches | Confirmed | Update project/theme/scene paths and visual baseline |
| Base faction art | `DwarfBase.png`, `ShamanBase.png` + sidecars | Authored runtime assets owned by base system | Active base visuals | Tracked | Retain and move with base-art owner | Confirmed | Base scene/load and both-faction visual validation |
| Scene snapshots | `menu_free.tscn.txt`, `upgrade_menu_free.tscn.txt` | Historical archive | Not runtime-loaded | Tracked | Archive later; deletion candidate only with proof | Strongly indicated | Semantic editor comparison and reconstruction-use check |
| Read-only Python checks | `check_content.py`, `check_grid.py`, `check_img*.py` | Development tooling | None | Tracked | Retain; later move to `tools/content_checks/` if documented | Strongly indicated | Dependencies, inputs, invocation, expected output, mutation review |
| Prototype patch/build scripts | `fix_*.py`, `patch_*.py`, `build_*.py`, `update_*.py` | Historical development tooling | None; can overwrite runtime source | Tracked | Retain temporarily; archive later by family | Strongly indicated | Map each to producing commit/input/output; test only in disposable tree |
| Asset generator variants | `generate_mask_*`, `generate_edge_atlases_*`, `resize_*` | Tooling plus historical experiments | Outputs may be runtime assets | Tracked | Split supported pipeline from archive later | Strongly indicated | Establish authoritative variant and reproducibility/hash test |
| Godot probes | `test_*.gd`, `run_test*.gd/.tscn` | Development/test probes | CLI/editor only; load runtime scenes in tests | Tracked | Move later one documented suite at a time | Confirmed | Runner command, assertions/expected result, path and export review |
| Empty debug probe | `debug_weights.gd` + UID | Development tooling, currently inert | None | Tracked | Retain; move only after purpose is documented | Confirmed | Decide whether to implement, archive, or preserve as history |
| Web export helper | `export_web.sh` | Export/deployment tooling | Build-time only | Tracked | Retain; later move as deployment infrastructure | Confirmed | Update docs/callers and prove same export behavior |
| Godot AI addon | `addons/godot_ai/**` | Third-party addon; editor plus debugger-runtime helper | Autoload parses/runs; otherwise gameplay-independent | Tracked | Retain intact; investigate export policy | Confirmed/unclear intent | Dedicated addon/export audit and license retention |
| Signaling service | `signaling_server.js`, `package.json` | Separate deployment dependency | Required only for Online VS connection setup | Tracked | Later move to `services/signaling/` | Strongly indicated | Deployment owner/docs, protocol tests, lockfile policy, two-client validation |
| Suspected unused art | `MineTrails.png`, `StompSprite.png` + sidecars | Unknown authored assets | No current reference found | Tracked | Investigate further; protect | Unclear | Visual/provenance review, history/source comparison, runtime/editor search |
| Build/export output | `build/web/` | Generated and reproducible | Deployed product, not source | Untracked | Ignore only after policy change; never migrate | Confirmed | Dedicated repository-policy task may add ignore rule |

All representative files in this table are tracked unless the tracked-status column states otherwise.

## 13. Protected artifacts

Future migration and cleanup tasks must not alter these until the stated prerequisite is complete:

- **Eight orphan `.import` files and `nest.gd.uid`:** protect until source recovery, UID/reference checks, and a disposable clean reimport determine whether they are residue. Risk: destroying the only remaining UID/import provenance.
- **All valid asset/`.import` and script/`.gd.uid` pairs:** protect from partial movement until the batch includes both sides and validates reimport/resource loading. Risk: broken paths, changed import behavior, or UID churn.
- **`menu_free.tscn.txt` and `upgrade_menu_free.tscn.txt`:** protect until semantic comparison and historical reconstruction needs are documented. Risk: loss of older layout/prototype evidence.
- **`DwarfBase.png` and `ShamanBase.png`:** protect until a dedicated base-art move includes both factions, sidecars, `base.gd`, and `base.tscn` references. Risk: missing or wrong faction base at runtime.
- **`global_theme.tres`, `Button.png`, and `MenuPanel.png`:** protect until shared texture migration succeeds and UI visual checks are available. Risk: project-wide invisible/broken Button and Panel styling.
- **`addons/godot_ai/**`, its license, configured plugin, and autoload:** protect until an addon/export audit proves intended development and release behavior. Risk: editor integration failure, startup parse failure, or unintended export change.
- **`signaling_server.js`, `package.json`, `online_lobby.gd` protocol and endpoint:** protect until deployment ownership and protocol compatibility are documented and tested. Risk: breaking Online VS independently deployed infrastructure.
- **Root Python builders/patchers:** protect and do not execute against the working tree until a per-family provenance audit establishes inputs and mutation behavior. Risk: silent destructive rewrites of current game files.
- **`MineTrails.png` and `StompSprite.png`:** protect until visual/history inspection establishes purpose. Risk: deleting unique authored content based only on absent text references.

## 14. Cleanup candidates

This list does not authorize deletion.

| Candidate | Evidence suggesting obsolescence | Missing evidence | Required validation | Suggested future task |
| --- | --- | --- | --- | --- |
| Eight import-only `.png.import` files | Named sources absent; no active consumer; most relate to older names/placeholder stages | Initial source contents, UID consumers, clean-import effect | Recover initial tree, hash/image comparison, disposable Godot 4.7 reimport/export scan | `CLN-001 — Audit orphan Godot sidecars` |
| `nest.gd.uid` | `nest.gd` absent; no filename/UID consumer; initial-commit-only history | Whether source was intentionally omitted or externally restored | Inspect initial tree/history and clean resource scan without sidecar | `CLN-001 — Audit orphan Godot sidecars` |
| `menu_free.tscn.txt` | Older scriptless layout; active main scene supersedes it; no reference | Whether it is a recovery template or preserves intentional layout | Open/compare semantically; map producing commits and documentation value | `CLN-002 — Review archived scene snapshots` |
| `upgrade_menu_free.tscn.txt` | Older hierarchy; active scene supersedes it; stale tools expect different filename | Whether builders require it and whether unique design content matters | Semantic comparison plus disposable reconstruction attempt | `CLN-002 — Review archived scene snapshots` |
| Superseded Python variants | Sequences named `fixed`, `final`, `perfect`, `ultimate`; many hardcode former paths and overwrite files | Which variant, if any, is authoritative/reproducible | Map outputs to commits/current hashes; run only in disposable tree | `CLN-003 — Audit prototype maintenance scripts` |
| `debug_weights.gd` + UID | Script immediately quits and performs no check | Whether it is a placeholder for planned debugging | Search developer history/notes; decide supported probe intent | `CLN-004 — Rationalize ad hoc Godot probes` |
| `MineTrails.png` | No non-import reference; only added with faction features | Visual identity, intended rail/cart use, editor-only/manual use | Inspect image, related commit patch, current rail visuals, exported package | `CLN-005 — Audit unreferenced authored art` |
| `StompSprite.png` | No non-import reference; current stomp appears code-driven | Intended future effect, asset provenance, dynamic/editor use | Inspect image and baseline commit; exercise Shaman/player effects manually | `CLN-005 — Audit unreferenced authored art` |

## 15. Impact on migration batches

Recommendations against `TARGET_STRUCTURE.md` (the plan itself is unchanged):

- **MOV-001 should be clarified and delayed.** The four checks are retained tools, but lack documented help modes, expected results, and dependency declarations. Add those prerequisites; do not run their default modes during movement validation if inputs are absent. It may proceed after a small invocation contract is written.
- **MOV-002 should be clarified or folded into a probe audit.** `debug_weights.gd` is confirmed inert, so moving it proves path mechanics but preserves no useful debug behavior. Require an explicit keep-versus-archive decision before spending a migration batch on it.
- **Every PNG asset batch (MOV-006, MOV-007, MOV-008, MOV-009, MOV-014, MOV-020, MOV-021) must explicitly include each valid `.import` sidecar as an atomic unit.** Orphan similarly named sidecars are excluded and remain blocked by `CLN-001`.
- **MOV-006 remains ordered before the theme, but its ownership should be explicit:** `Button.png` and `MenuPanel.png` are shared global UI assets, not main-menu assets.
- **MOV-007 should exclude `DwarfBase.png`.** Base art is confirmed base-system/faction-owned; create a separate low-to-medium-risk base-art batch before the base scene move, or include both `DwarfBase.png` and `ShamanBase.png` together with base references. Never move one under character art.
- **MOV-015 target should be clarified to `assets/themes/global/global_theme.tres` rather than `assets/materials/themes/`.** Keep its ordering after MOV-006 and require project-wide Button/Panel visual validation.
- **MOV-023 must be split by artifact family.** Test probes, destructive prototype patchers, asset generators, export tooling, and networking infrastructure have different owners and validation. The signaling pair belongs in a dedicated top-level service batch, not generic `tools/`.
- **Addon movement remains blocked.** No batch should relocate or trim `addons/godot_ai`; first complete a dedicated addon/export audit and decide the `_mcp_game_helper` production policy.
- **Networking scene/controller batches (MOV-010/MOV-022 as applicable) should precede neither service-contract documentation nor two-client planning.** The signaling service may move independently only after its deployment path is updated; client protocol changes are a separate behavior task.
- **Archive and cleanup candidates must not be included opportunistically in any move.** Use dedicated `CLN-*` audits after low-risk movement protocols are proven.

These findings do not block `MOV-003 — Move Controls menu pair`: it has a clear owner, valid script/UID pair, one known scene caller, and no classified ambiguous asset dependency. It remains the lowest-risk first Godot migration batch once its existing `AUD-002` and validation prerequisites are accepted.

## 16. Recommended next task

Recommend exactly **`MOV-003 — Move Controls menu pair`**. Artifact classification is sufficiently clear for this isolated scene/controller/UID batch, it avoids all protected metadata exceptions, archives, addons, themes, base art, tools, and networking infrastructure, and it exercises the intended Godot path-migration protocol with a small reversible scope. Do not start it as part of `AUD-003`.

## Audit limitations and unresolved questions

Static inspection and Git history resolved ownership or policy for every unresolved `STR-001` category, but these questions remain intentionally open:

- whether the repository should continue tracking normal `.import` and `.gd.uid` files after a Godot 4.7 clean-reimport policy comparison;
- whether any of the nine orphan sidecars preserve UIDs or missing source content worth restoration;
- which one, if any, of each generator/patcher family is a supported reproducible tool rather than historical evidence;
- whether `addons/godot_ai` runtime helper support is intentionally shipped in Web releases;
- who owns and deploys the live Render signaling service, and whether the repository version matches production;
- the intended purpose of `MineTrails.png` and `StompSprite.png`.

No Godot editor import, Web export, external service, or destructive utility was run. The known Mono/.NET and display limitations in `VALIDATION_CHECKLIST.md` remain. These uncertainties are protected by prerequisites above rather than represented as facts.
