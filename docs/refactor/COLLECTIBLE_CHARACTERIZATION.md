# Collectible Characterization

Status: AUD-012 baseline complete

Updated: 2026-07-12

## Scope

This baseline characterizes the current `gem.gd` and `rail_item.gd` contracts before MOV-013. It changes no production behavior.

## Current contracts

- Gems register in the `gems` group and expose pickup through `PickupArea`.
- `tether_to(player)` is exclusive: a gem already owned by another valid carrier rejects pickup.
- The carrier's `carried_gems` order defines each gem's follow slot.
- `untether()` clears ownership and restores frozen, zero-velocity world state.
- Player deposit consumes normal gems, counts each valid gem once, and removes them from `carried_gems`.
- Items whose `should_deposit_as_gem()` returns `false` remain carried during base deposit.
- `rail_item.gd` inherits directly from `res://gem.gd`.
- Rail items return `false` from `should_deposit_as_gem()`.
- Dropping a rail item in an open, empty world cell writes RailLayer source ID `15`, refreshes autotiling for the cell and four neighbors, refreshes minecart paths, and queues the carried item for deletion.
- Minecarts likewise reject rail items in `load_gem()` and consume only depositable gems.

## Characterization suite

`tests/test_collectible_characterization.gd` covers:

- exclusive gem ownership and untether reset,
- carry-slot ordering,
- player deposit filtering,
- rail-item tile placement and cleanup.

## Known coupling and risks

- Rail-item inheritance is path-based (`extends "res://gem.gd"`), so gem and rail-item scripts must move together.
- Production paths are referenced by player, base, spider-minion, minecart, and both scenes.
- Rail placement depends on parent name `World`, child node names `RailLayer` and `BlockLayer`, RailLayer source ID `15`, and world methods `update_rail_autotile()` and `refresh_minecart_paths()`.
- `deposit_gems()` queues normal gems for deletion before the end of the frame; callers must rely on the returned count and updated carried list rather than immediate object destruction.

## MOV-013 gate

MOV-013 may proceed only as one inheritance-coupled move containing `gem.*`, `rail_item.*`, their UID sidecars, and all exact path updates. No pickup, deposit, rail-placement, or minecart behavior changes belong in that move.
