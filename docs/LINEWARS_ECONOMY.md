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

## VS opening phase

Both sides start on the peon, not the hero. The peon stands on the mine roof
and the player digs it upward through the LineWars field, the mirror image of
the hero digging down into the mine. Five new tiles complete the side's opening
route and mark it READY; waves stay paused until both sides are ready and the
match is started.

Control can move between the two units at any time during that phase:

- Player one: `Tab` or right shoulder on pad 0, or the `A → HERO` button.
- Player two: `/` or right shoulder on pad 1, or the `B → HERO` button.
- Each side's own HUD also carries the same `SWITCH TO HERO` / `SWITCH TO PEON`
  button inside its viewport.

Only tiles removed while the peon holds the controls count toward the opening
route, so mining down with the hero never finishes the peon's job. `AUTO
OPENING` remains as a playtest shortcut that carves both routes.

The mirrored VS scene starts each side with 50 gold and one gem. Once both
opening routes are complete, each side receives the current passive income
(10 gold every five seconds, increasing by two gold every three minutes).
The in-world Goblin War Machine emits a payload immediately; the mirrored
controller routes it to the opponent's farthest tunnel endpoint.
