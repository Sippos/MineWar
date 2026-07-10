# MCT-001 Minecart Characterization

Status: complete for current `main` baseline (`aba8253`)

This note records the current minecart behavior without moving `minecart.tscn`
or `minecart.gd`. It is a characterization artifact for the transport batch
that follows `AUD-002`.

Confidence labels:

- Confirmed: directly visible in source or scene data.
- Inferred: derived from call flow or ownership relationships in source.
- Runtime-unverified: still needs playthrough validation.

## 1. Deployment and spawn path

| Behavior | Status | Evidence |
| --- | --- | --- |
| Minecart purchase exists only in the Dwarf upgrade flow and costs 50 gold. | Confirmed | `upgrade_menu.gd` gates `_on_buy_minecart_pressed()` behind `hud.total_gold >= 50` and calls `Base.spawn_minecart()`. |
| Base is the spawn owner. | Confirmed | `base.gd` preloads `res://minecart.tscn`, removes an existing child named `Minecart`, instantiates a new cart, names it `Minecart`, sets its position to the base, and defers `add_child()`. |
| Cart ownership is sibling-scene based rather than autoload-based. | Confirmed | `minecart.gd` reads `get_parent()` for `RailLayer`, `BlockLayer`, and `Base`. |
| The level scene connects `Base.gems_deposited` to `HUD.add_gems`, so minecart emissions reach HUD indirectly. | Confirmed | `level.tscn` signal wiring. |

## 2. Minecart scene contract

| Node / property | Status | Notes |
| --- | --- | --- |
| Root node | Confirmed | `RigidBody2D` named `Minecart`. |
| Physics defaults | Confirmed | `collision_layer = 0`, `collision_mask = 0`, `gravity_scale = 0.0`, `linear_damp = 3.0`. |
| Sprite | Confirmed | `Sprite2D` uses `character_sprites/minecart_spritesheet_25d.png` with `hframes = 8` and `vframes = 8`. |
| Collision | Confirmed | One rectangular body shape plus a `PickupArea` circle. |
| Runtime group | Confirmed | `_ready()` adds the node to `minecarts`. |

## 3. Rail placement and route construction

- `_try_place_on_rail()` is the gate into transport mode.
- The cart requires an open current cell. If that cell is not already rail,
  `_build_trail_to_base()` attempts to lay rail toward `Base` before the route
  is rebuilt.
- The maximum trail length comes from `world.minecart_trail_length`, defaulting
  to `16`.
- Trail cells are autotiled through `world.update_rail_autotile()` and its four
  orthogonal neighbors.
- `_rebuild_path()` then chooses the connected open-rail path using BFS and
  starts movement from the closest valid rail cell if the current one is no
  longer valid.

This is a manual movement system, not a physics-rail system. The cart is frozen
once placed and then moved by directly changing `global_position` in `_process()`.

## 4. Rail following behavior

- The cart advances along `rail_path` only after placement.
- `_process()` first refreshes the route if it is invalid, then updates passive
  income, then deposits stored gems, then moves along the path.
- `speed` is `100.0`.
- When the cart reaches the end of the path, the path is reversed and the cart
  walks back along the same rail chain.
- `animate_cart()` chooses the sprite row from movement angle and cycles frames
  at `12.0` frame units per second.

## 5. Gem loading and delivery

| Behavior | Status | Evidence |
| --- | --- | --- |
| Player can load carried gems into a nearby minecart with the drop action. | Confirmed | `player.gd` checks nearby bodies for `load_gem()` before dropping the last carried gem back into the world. |
| `Minecart.load_gem()` only accepts valid gem-like bodies while the cart is already on rails. | Confirmed | It returns `false` unless `placed_on_rail` is true, the target is valid, and the target reports `should_deposit_as_gem()`. |
| Loaded gems are untethered first, then consumed into the cart. | Confirmed | `load_gem()` calls `untether()` when present, increments `stored_gems`, and `queue_free()`s the source body. |
| Stored gems are delivered to Base once the cart is close enough. | Confirmed | `_deposit_stored_gems()` emits `Base.gems_deposited(stored_gems)` when within 96 px, then resets `stored_gems` to zero. |
| No repository code besides `player.gd` calls `load_gem()`. | Confirmed by search | Static search found no other caller. This makes player drop the only known load path. |

## 6. Passive income and notification path

- Every 5 seconds in transport mode, `_update_income()` emits
  `Base.gems_deposited(max(1, int(rail_path.size() / 10.0)))`.
- That signal is the same one used by the base deposit path, so HUD accounting
  stays centralized through the level scene wiring.
- The passive-income amount scales with path length, but the exact live gameplay
  effect still needs runtime playthrough confirmation.
- Stored-gem delivery and passive income are separate paths; both use the Base
  signal rather than mutating HUD directly.

## 7. Pickup and node-ownership contract

- `PickupArea` keeps the player's nearby gem list in sync through
  `body_entered` and `body_exited`.
- `_register_nearby_player()` handles the initial overlap case after spawn.
- The cart expects its parent to provide `Player`, `Base`, `RailLayer`, and
  `BlockLayer` nodes.
- `refresh_minecart_paths()` exists on `world.gd`, but current minecart code
  does not call it directly; rail-item placement does.

## 8. Cross-node dependencies

| Source | Target | Contract |
| --- | --- | --- |
| `upgrade_menu.gd` | `Base.spawn_minecart()` | Purchase entry point. |
| `base.gd` | `minecart.tscn` | Spawn owner and replacement policy. |
| `level.tscn` | `HUD.add_gems()` | Minecart/base deposits update HUD indirectly. |
| `player.gd` | `Minecart.load_gem()` | Only known gem-loading caller. |
| `world.gd` | `minecart.gd` | Rail source ID, autotile updates, and trail length contract. |
| `rail_item.gd` | `world.refresh_minecart_paths()` | Path refresh hook after rail placement. |

## 9. Uncertainties that still need runtime characterization

- The exact feel of cart spawn location versus base collision, especially when
  the base is busy or the parent scene layout changes.
- Whether the current rail-trail builder consistently reaches the intended base
  connection in every terrain shape the player can create.
- Whether passive income, stored-gem delivery, and HUD updates remain exactly
  once in all edge cases, including rapid despawn/replacement and rail
  destruction.
- Whether the `rail_item.gd` world-name guard matches the active runtime scene
  name in every launch path. The current code checks `world.name == "World"`,
  while the current level root is `Level`, so this deserves a playthrough check.

## 10. Characterization outcome

The transport contract is now concrete enough to start `MOV-011` with a clear
ownership picture:

- spawn is base-owned,
- route following is rail-cell owned,
- gem loading is player-driven,
- passive income and stored-gem payout both flow through `Base.gems_deposited`,
- HUD remains a downstream listener, not the cart owner.
