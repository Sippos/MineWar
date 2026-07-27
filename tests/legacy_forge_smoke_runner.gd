extends Node

# Legacy Ore was earned, shown and saved but had no spend point in the live
# stronghold. The forge is that spend point, so it has to exist exactly when the
# run-1 ceremony promises it, sit inside the room at every hub tier, and move
# real permanent upgrade ranks.

const SINGLE_PLAYER_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")
const SMOKE_SAVE_PATH := "user://legacy_forge_smoke_save.json"

var failures := 0

func _ready() -> void:
	Global.set_save_path_override(SMOKE_SAVE_PATH)
	await _run_smoke_test()
	if failures == 0:
		print("LEGACY_FORGE_SMOKE_PASS")
		get_tree().quit(0)
	else:
		push_error("LEGACY_FORGE_SMOKE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

func _run_smoke_test() -> void:
	await _check_absent_before_the_first_run()
	await _check_fits_every_hub_tier()
	await _check_pads_sell_permanent_ranks()

func _check_absent_before_the_first_run() -> void:
	var hub := await _open_hub(0, 1)
	var world := hub.get_node("Level") as Node2D
	_expect(not Global.is_legacy_workshop_unlocked(), "A fresh save has no legacy workshop")
	_expect(world.get_node_or_null("StrongholdLegacyForge") == null, "The forge should not exist before the first expedition")
	hub.queue_free()
	await _wait_frames(2)

func _check_fits_every_hub_tier() -> void:
	# Hub tiers grow with the unlocked roster; the forge anchors to the room, so
	# it must stay inside the walls and clear of the base, spawn and shrines.
	for hero_count in [1, 3, 6]:
		var hub := await _open_hub(1, hero_count)
		var world := hub.get_node("Level") as Node2D
		var forge := world.get_node_or_null("StrongholdLegacyForge") as Node2D
		_expect(forge != null, "The forge should stand in the stronghold once the workshop is awake (heroes=%d)" % hero_count)
		if forge == null:
			hub.queue_free()
			await _wait_frames(2)
			continue

		var interior: Rect2 = world.get_hub_interior_rect()
		var base_node := world.get_node("Base") as Node2D
		var spawn := (world.get_node("Player") as Node2D).global_position
		var shrines := world.get_node_or_null("PhysicalHeroShrines")
		var spot: Vector2 = forge.global_position
		_expect(interior.grow(-40.0).has_point(spot), "The forge must sit inside the room at heroes=%d (forge %s, room %s)" % [hero_count, str(spot), str(interior)])
		_expect(spot.distance_to(base_node.global_position) > 96.0, "The forge must not sit on the base (heroes=%d)" % hero_count)
		_expect(spot.distance_to(spawn) > forge.INTERACT_RADIUS, "The forge must not open itself at the spawn point (heroes=%d)" % hero_count)
		if shrines != null:
			for shrine in shrines.get_children():
				_expect(spot.distance_to((shrine as Node2D).global_position) > 78.0, "The forge must not overlap the %s shrine (heroes=%d)" % [shrine.name, hero_count])
		hub.queue_free()
		await _wait_frames(2)

func _check_pads_sell_permanent_ranks() -> void:
	var hub := await _open_hub(1, 1)
	var world := hub.get_node("Level") as Node2D
	var forge := world.get_node_or_null("StrongholdLegacyForge") as Node2D
	var hero := world.get_node("Player") as CharacterBody2D
	if forge == null:
		_expect(false, "The purchase check needs a forge")
		hub.queue_free()
		await _wait_frames(2)
		return

	# Out of range the forge is scenery, and it must not open from across the room.
	hero.global_position = forge.global_position + Vector2(0, -400)
	await _wait_frames(3)
	_expect(not bool(forge.get("player_in_range")), "The forge should be out of reach from across the room")
	_expect(not bool(forge.call("is_menu_open")), "The forge must not open by itself")

	# Standing at the forge offers it; opening it locks the hero in place.
	hero.global_position = forge.global_position
	await _wait_frames(3)
	_expect(bool(forge.get("player_in_range")), "Standing at the forge should offer it")
	var menu: CanvasLayer = forge.call("open_menu")
	await _wait_frames(2)
	_expect(menu != null and bool(forge.call("is_menu_open")), "The forge should open its menu")
	_expect(hero.get("can_move") == false, "The hero should be held still while the forge menu is open")
	_expect(menu.get("rows").size() == forge.UPGRADE_ORDER.size(), "The menu should list every permanent upgrade")

	# The menu spends ore on whichever rank is selected.
	menu.set("selected_index", 0)
	menu.call("refresh")
	var upgrade_id: String = menu.call("selected_upgrade_id")
	_expect(upgrade_id == "reinforced_core", "The list should open on the Reinforced Core")

	Global.legacy_ore = 0
	_expect(not bool(menu.call("_purchase_selected")), "An empty ore purse should not buy a rank")
	_expect(Global.get_permanent_upgrade_level(upgrade_id) == 0, "A failed purchase must not grant a rank")

	var cost := Global.get_permanent_upgrade_cost(upgrade_id)
	Global.legacy_ore = cost
	var health_before := Global.get_permanent_base_health_bonus()
	_expect(bool(menu.call("_purchase_selected")), "Enough ore should buy the rank")
	_expect(Global.legacy_ore == 0, "The purchase should spend exactly the listed ore")
	_expect(Global.get_permanent_upgrade_level(upgrade_id) == 1, "The purchase should grant the rank")
	_expect(Global.get_permanent_base_health_bonus() > health_before, "The bought rank should reach the run through the permanent bonus")

	# Ranks are capped, and a maxed rank must refuse further ore.
	Global.permanent_upgrade_levels[upgrade_id] = int(Global.PERMANENT_UPGRADE_MAX_LEVELS[upgrade_id])
	Global.legacy_ore = 9999
	_expect(not bool(menu.call("_purchase_selected")), "A maxed rank should refuse further purchases")
	_expect(Global.legacy_ore == 9999, "A refused purchase must not spend ore")

	# The uncapped rank is reachable from the same list and never refuses.
	var deepening_index: int = forge.UPGRADE_ORDER.find("deepening")
	_expect(deepening_index >= 0, "Deepening should be listed in the forge")
	menu.set("selected_index", deepening_index)
	menu.call("refresh")
	_expect(bool(menu.call("_purchase_selected")), "The uncapped rank should still sell at 9999 ore")
	_expect(Global.get_permanent_upgrade_level("deepening") == 1, "Buying Deepening should grant a rank")

	# Closing gives the hero back.
	forge.call("close_menu")
	await _wait_frames(2)
	_expect(not bool(forge.call("is_menu_open")), "Closing should dismiss the menu")
	_expect(hero.get("can_move") == true, "Closing the forge should give the hero back their legs")

	# Walking away closes it too, and a forge freed mid-menu must not strand the hero.
	forge.call("open_menu")
	await _wait_frames(2)
	hero.global_position = forge.global_position + Vector2(0, -400)
	await _wait_frames(3)
	_expect(not bool(forge.call("is_menu_open")), "Walking away should close the forge")
	_expect(hero.get("can_move") == true, "Walking away should give the hero back their legs")

	hub.queue_free()
	await _wait_frames(2)

func _open_hub(runs_completed: int, hero_count: int) -> Node:
	var roster := ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King", "Mech"]
	Global.unlocked_heroes = roster.slice(0, hero_count)
	Global.first_level_beaten = hero_count > 1
	Global.minewars_runs_completed = runs_completed
	for upgrade_id in Global.PERMANENT_UPGRADE_IDS:
		Global.permanent_upgrade_levels[upgrade_id] = 0
	Global.legacy_ore = 0
	Global.pending_unlock_rewards.clear()
	var hub := SINGLE_PLAYER_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(6)
	return hub

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("LEGACY_FORGE_SMOKE: %s" % message)

func _wait_frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame
