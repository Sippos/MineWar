extends Node

const HUB_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")

func _ready() -> void:
	_register_minimum_input()
	var hub := HUB_SCENE.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	var world := hub.get_node_or_null("Level")
	if world == null:
		push_error("DIAG: Level missing")
		get_tree().quit(1)
		return
	var script := world.get_script() as Script
	print("DIAG_SCRIPT=", script.resource_path if script else "<none>")
	print("DIAG_HAS_BEGIN=", world.has_method("begin_run_from_preparation"))
	print("DIAG_HAS_ASTAR=", world.get("astar") != null)
	print("DIAG_HAS_P1=", InputMap.has_action("p1_left"))
	print("DIAG_CHILD_SCRIPT=", world.get_class())
	get_tree().quit(0)

func _register_minimum_input() -> void:
	for action in ["p1_left", "p1_right", "p1_up", "p1_down", "p1_interact", "p1_grab", "p1_drop", "p1_stomp", "pause"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
