# Refactor Progress Ledger

Status: authoritative restart point

Updated: 2026-07-11

Baseline: `main` at `a2527ac` after the upgrade-menu hierarchy cleanup merge.

## Current repository state

- Local `main` and `origin/main` are synchronized at `a2527ac`.
- Runtime-styler repair: `a35f1a9` on `test/upgrade-menu-runtime`.
- Player 2 ability-input repair: `f750a1e` on `fix/p2-ability-inputs`.
- Integration commit: `73fad96` on `test/upgrade-menu-runtime-integration`.
- Compact unlock-state repair: `27dc424` on `fix/vs-compact-unlock-states`.
- Active focused branch: `fix/vs-compact-button-focus`, based on `27dc424`.
- No branch has been merged into `main` after `a2527ac`.

## Upgrade-menu hierarchy cleanup

The hierarchy cleanup is merged and validated statically:

- 61 nodes total: the CanvasLayer, Panel, and 59 direct panel children.
- No nested decorative descendants remain.
- Stable direct paths are used for stat costs, currency icons, section titles, and wave-timer controls.
- `upgrade_menu.gd` retains 47 functions and `send_enemy`.

## Runtime-styler repair

Commit `a35f1a9` prevents deferred styling from retaining a node object that may be freed before the message queue executes. It defers the instance ID and resolves the node safely.

Isolated validation completed:

- `upgrade_menu_ui_styler.gd` outlines with 13 functions.
- Single-player Dwarf menu opening/closing, Close focus, layout, wave-timer visibility, rail/minecart visibility, stat costs, currency deductions, one-time unlock disabling, and movement restoration passed.
- The stale deferred-node conversion error did not recur after the repair.

## Player 2 ability-input repair

Commit `f750a1e` fixes Local VS initialization order. Both HeroAbilities controllers initially run while their Player still has the default ID 1; the parent VS scene assigns Player 2 afterward. The controller now refreshes secondary and ultimate actions when its owning Player ID changes.

Isolated validation completed:

- `hero_abilities.gd` retains all 81 functions.
- Local VS reached `VSMode`.
- `p1_secondary`, `p1_ultimate`, `p2_secondary`, and `p2_ultimate` all existed.
- Controller configuration matched final player IDs 1 and 2.
- Repeated missing Player 2 action errors did not recur.

## Integration validation

Commit `73fad96` combines `a35f1a9` and `f750a1e` without changing `main`.

Validated:

- Local VS launched with neither prior runtime error class.
- Dwarf Rail/Minecart and Shaman Peon visibility passed.
- Compact VS omitted Wave Timer as intended.
- Stat costs, gold/gem deductions, prompt focus, closing, and movement restoration passed.

## Compact unlock-state repair

Branch `fix/vs-compact-unlock-states` fixes one-time buttons that stayed enabled after purchase.

Validated on both Dwarf and Shaman sides:

- Player HP, Base HP, XP Bar, and Minimap start enabled and disable after unlock.
- See Enemies starts disabled, enables after Minimap unlock, and disables after its one-time upgrade.
- Four unlocks deduct 50 gold total; See Enemies deducts another 50 gold.
- No fresh game errors occurred.

## Compact focus repair

The compact menu rebuilt its grid by queuing old buttons for deletion while leaving them attached until frame end. `show_compact()` then selected the stale first child, so focus disappeared when that child was freed.

The focused repair removes old grid children before queueing them for deletion. Runtime validation confirmed the new `STR +1` button owns focus in both Local VS subviewports, and the game log remained clean.

Do not merge into `main` without explicit confirmation.

## Other refactor work

Existing audit, migration, minecart, Peon, and deployment records remain governed by the earlier sections and commits in repository history. Do not infer completion of pending tasks from this upgrade-menu validation track.
