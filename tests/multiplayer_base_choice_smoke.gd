extends Node

# Local multiplayer gives each player their own stronghold: walk up to the dome
# on your side, click an arrow on the little switcher, and only your base
# changes - in realtime, without pausing the hub.

const HUB_SCENE := preload("res://scenes/world/preparation/local_multiplayer_hub.tscn")

var failures: Array[String] = []

func _ready() -> void:
	await _run()
	if failures.is_empty():
		print("MULTIPLAYER_BASE_CHOICE_SMOKE_OK")
		get_tree().quit(0)
	else:
		for message in failures:
			push_error(message)
		get_tree().quit(1)

func _run() -> void:
	var previous_bases: Array = Global.unlocked_bases.duplicate()
	var previous_selected := Global.selected_base_id
	var previous_p1 := Global.base_p1
	var previous_p2 := Global.base_p2
	# Deliberately only the starter fortress is unlocked: the hubs must still
	# offer every hero base regardless of campaign progress.
	Global.unlocked_bases = ["default_base"]
	Global.selected_base_id = "default_base"
	Global.base_p1 = "default_base"
	Global.base_p2 = "default_base"

	var hub := HUB_SCENE.instantiate()
	add_child(hub)
	for _index in range(4):
		await get_tree().process_frame

	var controller := hub.get_node_or_null("LocalMultiplayerHubController")
	_expect(controller != null, "The hub should carry its controller")
	if controller == null:
		return

	var level := hub.get_node_or_null("Level")
	var base_one := level.get_node_or_null("Base") if level else null
	var base_two := level.get_node_or_null("Base2") if level else null
	_expect(base_one != null and base_two != null, "Both strongholds should exist in the hub")
	_expect(base_one != null and int(base_one.get("base_owner_id")) == 1, "The left stronghold belongs to player one")
	_expect(base_two != null and int(base_two.get("base_owner_id")) == 2, "The right stronghold belongs to player two")

	# Player two walks up to their own dome; the switcher pops over it.
	var popups: Dictionary = controller.get("base_popups")
	_expect(popups.has(1) and popups.has(2), "Both strongholds should carry a base switcher")
	var popup_two: Node2D = popups.get(2)
	_expect(popup_two != null and int(popup_two.get("player_id")) == 2, "The right switcher belongs to player two")
	if popup_two == null:
		return

	var choices: Array = popup_two.call("available_bases")
	_expect(choices.size() == 6, "Every hero fortress should be switchable in the hub, got %d" % choices.size())

	# Arrows cycle the fortresses in realtime, no menu and no pause.
	popup_two.call("_cycle", 1)
	await get_tree().process_frame
	_expect(Global.base_p2 == "shaman_base", "Player two should now own the Shaman Lodge, got %s" % Global.base_p2)
	_expect(Global.base_p1 == "default_base", "Player two's choice must not move player one's stronghold, got %s" % Global.base_p1)
	_expect(Global.selected_base_id == "default_base", "Player two's choice must not rewrite the single-player loadout")
	_expect(not get_tree().paused, "Switching a base must not pause the hub")
	var sprite_two := base_two.get_node_or_null("Sprite2D") as Sprite2D if base_two else null
	var sprite_one := base_one.get_node_or_null("Sprite2D") as Sprite2D if base_one else null
	_expect(sprite_two != null and sprite_two.texture == Global.base_data["shaman_base"]["texture"], "The right dome should render the Shaman Lodge")
	_expect(sprite_one != null and sprite_one.texture == Global.base_data["default_base"]["texture"], "The left dome should still render the Dwarf Bastion")

	# Backwards wraps around the same list.
	popup_two.call("_cycle", -1)
	await get_tree().process_frame
	_expect(Global.base_p2 == "default_base", "The left arrow should step back to the Dwarf Bastion, got %s" % Global.base_p2)
	popup_two.call("_cycle", 1)
	await get_tree().process_frame

	# And player one switches independently on their own dome.
	var popup_one: Node2D = popups.get(1)
	if popup_one != null:
		popup_one.call("_cycle", -1)
		await get_tree().process_frame
		_expect(Global.base_p1 == "undead_king_base", "Player one should wrap to the Undead Citadel, got %s" % Global.base_p1)
		_expect(Global.base_p2 == "shaman_base", "Player one's choice must not move player two's stronghold, got %s" % Global.base_p2)

	# The switcher carries a small box listing that fortress' own upgrades.
	var upgrade_rows: Array = popup_two.get("_upgrade_rows")
	_expect(upgrade_rows.size() == 3, "The upgrade box should show three perk rows")
	if upgrade_rows.size() == 3:
		var kinds: Array = []
		for row in upgrade_rows:
			var kind_label: Label = row["kind"]
			var text_label: Label = row["text"]
			kinds.append(kind_label.text)
			_expect(not text_label.text.is_empty(), "%s should describe an upgrade for the current base" % kind_label.text)
		_expect(kinds == ["PASSIVE", "DEFENCE", "WORLD"], "The upgrade box should read PASSIVE / DEFENCE / WORLD, got %s" % str(kinds))
	for base_id in Global.base_data:
		var upgrades: Array = Global.base_data[base_id].get("upgrades", [])
		_expect(upgrades.size() == 3, "%s should declare three upgrades" % base_id)

	# The popup only shows while that player stands at their own stronghold.
	controller.call("_update_base_popups")
	_expect(not popup_two.visible, "The switcher stays hidden until the player walks up to their dome")
	if is_instance_valid(hub.get_node_or_null("Level/Player2")):
		var player_two: Node2D = hub.get_node_or_null("Level/Player2")
		player_two.global_position = base_two.global_position
		controller.call("_update_base_popups")
		_expect(popup_two.visible, "Standing at your own dome should pop the switcher open")

	hub.queue_free()
	Global.unlocked_bases = previous_bases
	Global.selected_base_id = previous_selected
	Global.base_p1 = previous_p1
	Global.base_p2 = previous_p2

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
