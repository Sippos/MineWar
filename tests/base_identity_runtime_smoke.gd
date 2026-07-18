extends Node

const BASE_SCENE := preload("res://base.tscn")
const DUMMY_PLAYER_SCRIPT := preload("res://tests/base_identity_dummy_player.gd")
const AMBIENCE_SCRIPT := preload("res://scripts/systems/stronghold_ambience_controller.gd")

var failed: Array[String] = []

func _ready() -> void:
	await _run()
	if failed.is_empty():
		print("BASE_IDENTITY_RUNTIME_SMOKE_OK")
		get_tree().quit(0)
	else:
		for message in failed:
			push_error(message)
		get_tree().quit(1)

func _run() -> void:
	var previous_base := Global.selected_base_id
	var world := Node2D.new()
	world.name = "Level"
	add_child(world)

	var player := CharacterBody2D.new()
	player.name = "DummyPlayer"
	player.set_script(DUMMY_PLAYER_SCRIPT)
	world.add_child(player)

	var base := BASE_SCENE.instantiate()
	base.name = "Base"
	world.add_child(base)
	await get_tree().process_frame
	await get_tree().process_frame

	# Rename only after all node-added bootstrap scans have completed. The base
	# identity controller needs a child named Player, while this isolated smoke
	# test deliberately avoids attaching the full hero runtime to the dummy.
	player.name = "Player"
	var identity := base.get_node_or_null("BaseIdentityController")
	_expect(identity != null, "Base should attach BaseIdentityController")
	if identity == null:
		Global.selected_base_id = previous_base
		world.queue_free()
		return
	identity.call("_late_setup")
	await get_tree().process_frame

	var ids := ["default_base", "shaman_base", "nerubian_base", "druid_base", "undead_king_base", "mech_base"]
	for id in ids:
		player.name = "Player"
		Global.selected_base_id = id
		await get_tree().process_frame
		await get_tree().process_frame
		var snapshot: Dictionary = identity.call("get_identity_snapshot")
		_expect(str(snapshot.get("base_id", "")) == id, "%s identity should activate" % id)
		_expect(not str(snapshot.get("passive", "")).is_empty(), "%s should expose a gameplay passive" % id)
		if id == "default_base":
			_expect(int(snapshot.get("carry_bonus", 0)) == 1, "Dwarf Bastion should add one free carry slot")
		if id == "mech_base":
			_expect(int(snapshot.get("base_health_bonus", 0)) == 15, "Goblin Workshop should add 15 bastion HP")

		# Hide the dummy from global character bootstraps while ambience nodes are
		# added to the tree. The identity controller retains its direct reference.
		player.name = "DummyPlayer"
		var ambience := Node2D.new()
		ambience.set_script(AMBIENCE_SCRIPT)
		ambience.set("base_id", id)
		ambience.set("dwarf_cart_unlocked", true)
		world.add_child(ambience)
		await get_tree().process_frame
		_expect(ambience.get_child_count() > 0, "%s should create distinct overworld ambience" % id)
		ambience.queue_free()
		await get_tree().process_frame

	Global.selected_base_id = previous_base
	world.queue_free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed.append(message)
