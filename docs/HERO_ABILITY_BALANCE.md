# MineWars Hero Ability and Balance Baseline

## Purpose

This document is the production baseline for hero scale, starting stats, controls, ability behavior, and playtest expectations. It reflects the implementation validated in Godot 4.7 on 2026-07-17.

## Shared controls

- **R / controller X:** starter ability
- **F / controller RB:** secondary ability
- **T / controller LB:** ultimate ability
- Passive abilities appear in the HUD but require no input.
- Every hero receives one usable starter ability at level 1. Ultimates require hero level 6.

## Starting profiles

| Hero | Health | Move speed | Base dig time | Intended role |
|---|---:|---:|---:|---|
| Dwarf | 40 | 190 | 0.36 s | Durable melee miner and burst defender |
| Shaman | 32 | 205 | 0.42 s | Ranged support, area control, and utility |
| Nerubian | 36 | 215 | 0.46 s | Brood commander, control, and autonomous mining |
| Druid | 34 | 210 | 0.39 s | Mobile form-switcher, sustain, and map traversal |
| Undead King | 38 | 195 | 0.43 s | Summoner and army commander |

## Visual scale baseline

- Dwarf and Shaman retain their reviewed animation fit.
- Nerubian now uses a runtime multiplier of **1.70** over the source fit. Its effective normal scale is approximately **0.78**, making the wide spider silhouette readable beside humanoid heroes without clipping.
- Druid humanoid receives a small consistency increase. Mole Form uses an effective scale of approximately **0.84**, visibly larger than the previous form while preserving its ground contact.
- Undead King receives a minor scale increase for silhouette parity.
- Walk and attack states continue using each hero's dedicated reviewed sprite sheets and anchors.

## Dwarf

### Ground Stomp — R
Area damage and stun. Starts at rank 1. Rank increases radius, damage, and control duration.

### Throwing Hammer — F
A directional ranged strike that stuns an enemy and breaks soft blocks. At rank 3 with normal level-six test stats, cooldown is approximately 6.6 seconds. Avatar allows the hammer to cleave up to three targets.

### Dwarven Bash — passive
Every third completed melee attack or mined block is empowered. The empowered hit adds damage, stun, knockback, and nearby splash.

### Avatar of the Mountain — T
Twelve-second transformation with Strength, health, movement, mining, size, and hammer-cleave bonuses. Cooldown: 60 seconds.

## Shaman

### Totemic Invocation — R
Opens the four-way totem wheel: Dig, Heal, Radar, or Gem. Totem lifetime, radius, and cooldown improve with Totemic Invocation and Ancestral Wisdom.

### Chain Lightning — F
Targets a forward enemy and jumps through nearby enemies. Rank 3 chains through a useful pack with decreasing damage per jump. Normal rank-3 cooldown with Wisdom is approximately 5.9 seconds.

### Ancestral Wisdom — passive
Improves totem effectiveness and grants permanent Intelligence when selected.

### Ancestral Ascendance — T
For twelve seconds, grants Intelligence and movement, refreshes Chain Lightning, and creates all four totems around the Shaman. Cooldown: 65 seconds.

## Nerubian

### Spawn Brood — R
Starts at rank 1. Summons mining spiders up to a rank-scaled cap of five. Rank-3 cooldown with Carapace is approximately 3.1 seconds.

Brood spiders now have two complete behaviors:

1. Mine reachable blocks and prioritize gem-bearing targets.
2. Defend the area by pursuing and biting enemies within their aggro radius.

At rank 3 with three Intelligence, a spider deals 26 bite damage at roughly 0.54-second intervals. This gives the brood real wave-defense value without replacing the hero.

### Web Burst — F
A circular damage, root, and slow effect. At rank 3 it reaches 220 pixels, roots for approximately 2.55 seconds, and has a normal cooldown of approximately 6.6 seconds.

### Chitinous Carapace — passive
Adds hero health regeneration and improves spider digging. Nerubian basic attacks also trigger **Venom Bite** every third completed attack, adding magic damage and a slow.

### Broodmother's Call — T
Fourteen-second brood transformation. Summons three spiders, casts a large Web Burst, and empowers the full brood with 45% movement, approximately 55% bite damage, faster attacks, and longer life. Cooldown: 70 seconds.

### Manual claw mining
Nerubian can now mine directly with directional movement against a block. This prevents the hero from becoming trapped or dependent on spider pathfinding. The manual rate remains slower than dedicated Dwarf or Mole Form mining, preserving role identity.

## Druid

### Mole Form — R
Starts at rank 1. Transforms the Druid into the larger reviewed Mole Form, greatly improves digging, and grants a rank-scaled movement burst.

Entering Mole Form triggers **Verdant Burrow**, damaging, rooting, and slowing nearby enemies. While moving underground, the Druid emits a smaller controlled burrow pulse every 0.9 seconds. This makes the form useful during combat without turning it into unlimited burst damage.

At rank 3, Mole Form lasts 12 seconds and grants 58 movement speed.

### Burrow Tunnel — F
Places an entrance and exit, then allows travel between the linked openings. Placement distance and use radius scale with rank. This is the Druid's persistent route-planning tool rather than a direct damage spell.

### Deep Roots — passive
Adds maximum health and meaningful regeneration. At rank 3 it heals every approximately 0.74 seconds, with stronger healing while stationary.

### Worldroot Passage — T
Instantly returns the Druid to the base through the roots. Cooldown: 45 seconds.

## Undead King

### Raise Dead — R
Starts at rank 1. Summons up to three combat minions. Rank and Intelligence improve lifetime, damage, speed, and attack interval.

At rank 3 with three Intelligence, a minion has approximately 43 attack damage, 148 movement speed, and a 0.51-second attack interval.

### Grave Might — F
Grave Might remains a permanent upgrade and is now also a true active command ability. It can automatically raise a minion when none exists, then empowers the army and creates a damaging grave pulse around every minion.

At rank 3, the command lasts eight seconds with an approximately 9.5-second cooldown. Minions gain approximately 49% movement, 52% damage, and substantially faster attacks during the command.

### Soul Harvest — passive
Minion damage heals the Undead King. Rank 3 grants 18% life steal.

### Death March — T
Extends and strengthens the existing army and raises reinforcements up to the minion cap. Cooldown: 60 seconds.

## Validation performed

### Automated scale and functionality smoke test

`res://tests/hero_balance_smoke_runner.tscn`

- Result: **PASS, 5/5 heroes**
- Validates selected hero loading, starting profiles, sprite fit, level-up card connection, starter abilities, summons, Mole Form, and Grave Might.

### Automated combat balance test

`res://tests/hero_combat_balance_runner.tscn`

- Result: **PASS, 5/5 heroes**
- Uses the real mine scene and combat targets.
- Exercises every hero at level 6 with all ability tiers unlocked.
- Validates damage delivery, cooldown windows, crowd control, summons, transformations, regeneration, tunnel travel, return-to-base behavior, and army commands.

Observed scenario totals are not direct DPS rankings because each hero is tested against its intended role and timing window:

| Hero | Scenario damage | Friendly summons |
|---|---:|---:|
| Dwarf | 945 | 0 |
| Shaman | 460 | 4 totems |
| Nerubian | 872 | 4 spiders |
| Druid | 218 | 0 |
| Undead King | 466 | 2 minions |

Druid's lower damage is intentional because its test also validates sustain and two traversal abilities. Dwarf and Nerubian totals include multi-target transformations and should not be read as sustained single-target DPS.

### Interactive input-driven review

`res://tests/hero_live_playtest.tscn`

- Actual mapped actions were used for starter, secondary, and ultimate abilities.
- Dwarf Avatar, Shaman's four-totem Ascendance, Nerubian brood/Web/Broodmother HUD state, Druid Mole Form movement and tunnel placement, and Undead Raise Dead/Grave Might/Death March were visually inspected.
- No runtime script errors were produced during the final interactive review.
