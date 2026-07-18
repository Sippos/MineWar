# LineWars economy

LineWars has two currencies with deliberately different jobs:

- Gold is predictable war currency. It arrives passively every five seconds
  and pays for reliable pressure: Rat Raid (50), Trogg Push (120), and Elite
  Push (250).
- Gems are rare hero currency. Hero stats, pick power, and hero sustain use
  gems. The Goblin War Machine also offers a one-gem gamble.

The gamble is intentionally volatile. It can create a large Rat attack, a
prototype Orc, a 100-gold cache, or a malfunction that consumes the gem with
no attack. The outcome table and all send prices live in
`scripts/systems/linewars_economy.gd`; gameplay code should read that table
instead of duplicating costs.

The mirrored VS scene starts each side with 50 gold and one gem. Once both
opening routes are complete, each side receives the current passive income
(10 gold every five seconds, increasing by two gold every three minutes).
The in-world Goblin War Machine emits a payload immediately; the mirrored
controller routes it to the opponent's farthest tunnel endpoint.
