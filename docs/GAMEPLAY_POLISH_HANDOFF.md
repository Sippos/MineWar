# MineWars Gameplay Polish — New Chat / Scheduled Work Handoff

Use this handoff for the Godot project at:

`/home/sebastian-berger/mining`

## Product direction

MineWars is a fantasy mining-defense game inspired by Warcraft III Hero Line Wars and Dome Keeper.

The intended emotional loop is:

> Leave safety, dig for value, become greedy, decide when to return, improve the hero/base, then defend the route created by the mine.

The project already has many systems. Do not expand scope casually. The current goal is to make the existing single-player loop readable, rewarding, and physically satisfying.

## Decisions already made with the developer

### Keep the unlockable HUD

Do not automatically reveal the player health bar, base health bar, wave timer, minimap, or enemy locations. The developer likes the Dome Keeper-style decision to spend resources on information.

Design boundary:

> Upgrades may hide precision and prediction, but the game must not hide that an important event is happening.

Before the relevant HUD upgrade, use immersive nonnumeric communication:

- Strong wave-spawn announcement.
- Base emblem or portrait flashing when the base is hit.
- Directional screen-edge warning toward the base.
- Nonnumeric base conditions such as stable, damaged, and critical.
- Increasing visual urgency when repeated hits occur.
- Later, distinct audio cues.

The player may fail from greed or inexperience, but the failure must be understandable.

### Do not add a repeated run tutorial

Do not make every run say “dig this block” or force a tutorial sequence.

Permitted approaches:

- Natural starting-room composition.
- Nearby visible mineral hints.
- First-ever contextual prompts saved after being seen.
- Strong world reactions that teach through failure.

The current base prompt says “Press E (or Y) to Upgrade” while the player begins with no resources. Consider hiding or reducing this prompt until an upgrade is affordable or the player returns with resources.

### Keep Strength, Agility, and Intelligence

These Warcraft-style stats are part of the game identity. Improve their clarity and balance rather than replacing them.

Desired responsibilities:

- Strength: attack damage, physical abilities, free carrying allowance, possibly health thresholds.
- Agility: movement, attack cadence, digging cadence.
- Intelligence: ability damage, cooldowns, summons, totems, hero utility.

Important current behavior:

- Each carried gem currently adds 15% movement penalty.
- Penalty is capped at 75%.
- Agility increases movement speed before the penalty.
- Strength currently does not improve carrying.
- Agility currently improves movement, attacks, and digging, so it risks becoming the universally best stat.

Preferred carrying model:

- Base free-carry allowance.
- Additional free carry from Strength thresholds.
- Bag items increase free carry.
- Boots reduce overload slowdown.
- Allow overloading instead of a hard inventory limit.

### Small caves and run items are approved

Future examples:

- Miner’s Bag: more free carrying allowance.
- Iron-Toed Boots: reduced carrying slowdown.
- Reinforced Pick: less hard-rock penalty.
- Magnetic Belt: larger pickup radius.
- Surveyor’s Lens: nearby mineral hints.
- Recall Stone: one emergency return.
- Powder Charge: opens rock but creates a dangerous route.

Do not implement a broad item system before the higher-priority polish work is stable.

### Enemy health bars are approved

Preferred behavior:

- Hidden on untouched enemies.
- Appear when damaged, targeted, or near the player.
- Fade after combat inactivity.
- Boss bar remains visible during the boss fight.
- Health loss should animate instead of snapping.

### Base physical footprint is approved

The current base is an Area2D with a 128x64 interaction shape. Area2D does not physically block the player.

Preferred implementation:

- Preserve the larger Area2D for healing, depositing, and upgrade interaction.
- Add a smaller StaticBody2D collision footprint covering only the solid lower/central foundation.
- Do not block the full base image; allow the hero to visually pass behind upper portions.

## Current implementation priorities

Work in this order unless the developer explicitly changes it:

1. Keep HUD unlocks and add nonnumeric wave/base danger warnings.
2. Improve mining impact, block destruction, gem reveal, pickup, and deposit feedback.
3. Add conditional enemy health bars and stronger combat hit reactions.
4. Connect Strength to carrying and clarify/rebalance STR/AGI/INT identities.
5. Add a smaller physical base footprint.
6. Add one small cave reward such as a bag or boots only after the above is stable.
7. Later: tunnel manipulation, route prediction, traps, and deeper line-wars strategy.

## Current gameplay-polish restart point

`POLISH-001` is complete. Do not reimplement it. Treat `docs/GAMEPLAY_POLISH_PROGRESS.md` as authoritative: `POLISH-002` is currently in progress and must be audited and acceptance-tested before any later queue item begins.

The scope and criteria below are retained as the completed `POLISH-001` reference.

Suggested scope:

- On wave spawn, show a short high-priority notice such as “Enemies have entered the mine.”
- When the base takes damage, notify the HUD through an explicit method or signal.
- Add a compact base-danger indicator that is always available but does not show exact health.
- Use three states based on current base health: stable, damaged, critical.
- Flash/pulse the indicator on each hit.
- Add a directional screen-edge cue toward the base when the player is sufficiently far away.
- Do not reveal exact health, timer, minimap, or enemy locations.
- Avoid repeated text spam on every base hit.
- Ensure the warnings work with different hero choices and screen sizes.

Acceptance criteria:

- A player digging far from the base can tell when a wave has started.
- A player can tell when the base is being damaged off-screen.
- A player can distinguish normal damage from a critical emergency without exact numbers.
- Buying the Base HP and Wave Timer upgrades still provides meaningful new information.
- No repeated tutorial flow is added.
- No unrelated gameplay or visual assets are changed.

## Required workflow

1. Read `AGENTS.md`, `docs/PROJECT_VISION.md`, and this handoff.
2. Inspect Git status before editing.
3. The working tree is currently extremely dirty with many unrelated image/import/animation changes. Preserve all existing work.
4. Do not reset, clean, checkout, overwrite, or commit unrelated changes.
5. Inspect the active Godot session and current runtime errors.
6. Make one focused gameplay-polish change at a time.
7. Prefer editable scene nodes for lasting UI, but a small runtime warning overlay may be acceptable if documented and contained.
8. Run a Godot project check after edits.
9. Run the real game through hero selection into single player.
10. Test while far from the base and confirm wave-start, base-hit, and critical warnings.
11. Inspect fresh editor and game errors after testing.
12. Review the exact Git diff before stopping.
13. Do not commit or push unless explicitly requested.

## Current technical warnings

At the time this handoff was written:

- The live Godot session is connected to `/home/sebastian-berger/mining/`.
- The active branch was `fix/hero-selection-facing-down`.
- The working tree contained a very large number of modified and untracked files.
- Do not assume all existing modifications belong to the current task.
- `upgrade_tree_lab.gd` and `upgrade_tree_lab.tscn` contain parse errors and are untracked experiments.
- Duplicate UID warnings exist because backup sprite folders remain inside the Godot project tree.
- Historical editor logs also showed errors in `hero_abilities.gd`, `undead_minion.gd`, and upgrade-tree experiments; verify current fresh errors rather than trusting stale logs.
- There were no audio streams found in the project during inspection.

## Useful files

- `scripts/systems/world_generation/world.gd`: waves and spawning.
- `base.gd`: base health, damage, deposit, healing, interaction.
- `hud.gd` and `hud.tscn`: unlockable information and notices.
- `upgrade_menu.gd`: HUD unlock purchases and stat upgrades.
- `player.gd`: carrying penalty and core stat behavior.
- `enemy.gd` and `enemy.tscn`: combat and future enemy health bars.
- `base.tscn`: base interaction shape and future physical footprint.

## Product standard

> The player is allowed to be ignorant, greedy, and wrong, but the world must react clearly enough that the failure teaches them something.
