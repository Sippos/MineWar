# MineWars Hero RPG System

## Resource decision: cooldowns, no mana

MineWars currently uses cooldowns as the active-ability resource. A separate mana pool is intentionally **not** required.

Using mana and cooldowns together would double-gate abilities: the player could wait for a cooldown and still be unable to cast. That would slow the mining-and-wave loop without adding a meaningful decision unless the game also introduced mana potions, mana regeneration builds, drains, silences, and resource-denial enemies.

Intelligence therefore improves cooldown recovery, spell power, summon power, and effect duration. Mana can be reconsidered later only if resource-management gameplay becomes a major pillar.

## Primary attributes

| Hero | Primary attribute | Level-1 attributes | Level-6 attributes | RPG identity |
|---|---|---:|---:|---|
| Dwarf | Strength | 4 / 2 / 1 | 8 / 3 / 2 | Durable physical bruiser and miner |
| Shaman | Intelligence | 1 / 2 / 4 | 2 / 3 / 8 | Spell and totem specialist |
| Nerubian | Agility | 2 / 4 / 1 | 4 / 8 / 2 | Fast attacker and brood commander |
| Druid | Intelligence | 2 / 2 / 4 | 4 / 4 / 7 | Mobile spellcaster and sustain hero |
| Undead King | Intelligence | 2 / 1 / 4 | 4 / 2 / 8 | Summoner and army commander |

Attribute order in the table is Strength / Agility / Intelligence.

The primary attribute adds basic-attack damage in addition to its ordinary derived benefits. This gives every hero a preferred build direction without making the other attributes useless.

## Strength

Each Strength point provides:

- 1.25 basic-attack damage.
- 6 maximum health for points above the hero's authored starting Strength.
- 0.08 health regeneration per second for points above the starting value.
- Existing carrying-capacity thresholds.
- Additional physical-ability scaling, especially for a Strength-primary hero.

Dwarf is the Strength-primary hero. Its level-six natural Strength is 8 before purchased upgrades or temporary Avatar bonuses.

## Agility

Each Agility point provides:

- 3.5% attack-speed scaling.
- 3 movement speed.
- 0.18 armor.
- Approximately 2.5% mining-speed contribution.

Agility no longer grants 20 movement speed and 10% attack/mining speed per point. The old formula made it universally optimal. Its benefits are now broad but individually controlled.

Attack interval is calculated from a hero-specific base interval:

```text
attack interval = hero base interval / (1 + 0.035 × (Agility - 1))
```

Nerubian is the Agility-primary hero. At level 6 it naturally reaches 8 Agility and approximately 2.08 basic attacks per second before purchased upgrades.

## Intelligence

Each Intelligence point provides:

- 3.5% spell-power scaling.
- 3% summon-power scaling.
- 1.25% cooldown reduction, capped at 25%.
- 1.5% duration scaling for forms, summons, totems, and other timed effects.

Cooldowns remain the only casting resource. Intelligence makes caster builds cast more frequently without requiring a mana bar.

## Armor

Armor is derived from a hero-specific base value plus Agility:

```text
armor = hero base armor + Agility × 0.18
reduction = armor / (10 + armor)
```

Damage reduction is capped at 65%. Avatar of the Mountain grants an additional 2.5 armor while active.

## Basic attacks

Each hero has an authored base damage and base attack interval. Basic damage combines:

```text
hero base damage + Strength × 1.25 + primary attribute
```

This creates the intended distinctions:

- Dwarf attacks more slowly and hits harder.
- Nerubian has the fastest natural attack cadence.
- Shaman, Druid, and Undead King have lower basic damage but stronger Intelligence-driven ability or summon output.

## Mining

Mining speed now receives smaller contributions from both physical execution stats:

```text
mining multiplier = 1 / (1 + 0.025 × (Agility - 1) + 0.015 × (Strength - 1))
```

The multiplier has a lower bound of 0.62. Hero abilities such as Mole Form, Totems, Avatar, and brood miners remain the main way to specialize heavily into mining.

## Hero level growth

Attribute growth is fractional internally and converted to whole points at each level. This supports recognizable hero growth without granting every attribute every level.

- Dwarf: 0.80 Strength, 0.35 Agility, 0.20 Intelligence per level.
- Shaman: 0.20 Strength, 0.35 Agility, 0.85 Intelligence per level.
- Nerubian: 0.40 Strength, 0.85 Agility, 0.20 Intelligence per level.
- Druid: 0.45 Strength, 0.45 Agility, 0.75 Intelligence per level.
- Undead King: 0.55 Strength, 0.20 Agility, 0.80 Intelligence per level.

Purchased stat points remain permanent and are preserved when the current hero changes. Temporary Avatar and Ascendance bonuses are excluded from permanent progression tracking.

## Ability integration

The RPG controller now scales:

- Dwarf physical ability damage and cooldowns.
- Shaman Chain Lightning, Totem duration, cooldowns, and Ascendance duration.
- Nerubian Web Burst, Venom Bite, spider damage, spider lifetime, and brood cooldowns.
- Druid Mole Form duration, Burrow Tunnel cooldowns, Worldroot cooldown, and burrow spell damage.
- Undead minion damage and lifetime, Raise Dead cooldown, Grave Might damage/duration/cooldown, and Death March cooldown.

## HUD communication

When the stat HUD is unlocked, it now shows a compact derived-stat line containing:

- Primary attribute.
- Basic attack damage.
- Attacks per second.
- Armor.
- Spell-power percentage.
- Summon-power percentage.

Strength, Agility, and Intelligence icons and values also have detailed tooltips explaining their exact derived benefits and identifying the hero's primary attribute.

## Validation

### `res://tests/hero_rpg_system_runner.tscn`

Result: **PASS — 5/5 heroes**

Validates:

- Hero-specific level-one attributes.
- Primary attributes.
- Level-six natural growth.
- Strength health and damage benefits.
- Agility attack-speed, movement, and armor benefits.
- Intelligence spell, summon, and cooldown benefits.
- Armor damage reduction.
- Permanent purchased-stat routing.

Observed natural level-six profiles:

| Hero | Basic damage | Attacks/sec | Armor |
|---|---:|---:|---:|
| Dwarf | 23 | 1.37 | 1.74 |
| Shaman | 15 | 1.22 | 0.74 |
| Nerubian | 17 | 2.08 | 2.04 |
| Druid | 16 | 1.42 | 1.22 |
| Undead King | 17 | 1.15 | 1.16 |

### Regression tests

- Hero scale/function smoke test: **PASS — 5/5 heroes**.
- Full combat balance test: **PASS — 5/5 heroes**.
