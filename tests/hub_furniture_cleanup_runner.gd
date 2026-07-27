extends Node

# The stronghold and the expedition share one room. Anything the hub adds to the
# world has to be taken back out when a run starts, and the LineWars shaft has to
# be bricked up again — otherwise the forge pads sit on the expedition arena and
# the peon's tunnel stays a hole in the ceiling.

const HUB_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")
const SMOKE_SAVE_PATH := "user://hub_furniture_cleanup_smoke.save"

var failures := 0

func _ready() -> void:
	Global.set_save_path_override(SMOKE_SAVE_PATH)
	call_deferred("_run")

func _run() -> void:
	await _check_run_start_clears_the_stronghold()
	if failures == 0:
		print("HUB_FURNITURE_CLEANUP_PASS")
		get_tree().quit(0)
	else:
		push_error("HUB_FURNITURE_CLEANUP_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

func _check_run_start_clears_the_stronghold() -> void:
	# Two completed runs: the forge exists and the upper shaft is open.
	Global.unlocked_heroes = ["Dwarf", "Shaman"]
	Global.first_level_beaten = true
	Global.minewars_runs_completed = Global.LINE_WARS_UNLOCK_RUNS
	Global.prototype_onboarding_completed = true
	Global.pending_unlock_rewards.clear()
	var hub := HUB_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(8)

	var world := hub.get_node_or_null("Level") as Node2D
	var controller := hub.get_node_or_null("SinglePlayerWorldController")
	if controller == null:
		for child in hub.get_children():
			if child.has_method("_prepare_world_for_run"):
				controller = child
	if world == null or controller == null:
		_expect(false, "The cleanup check needs the hub world and its controller")
		hub.queue_free()
		return

	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var shaft: Vector2i = world.get_top_tunnel_entrance()
	_expect(world.is_top_tunnel_unlocked(), "Two completed runs should open the upper shaft")
	_expect(world.get_node_or_null("StrongholdLegacyForge") != null, "The stronghold should hold a forge before the run")
	_expect(block_layer.get_cell_source_id(shaft) != 16, "The upper shaft should be open in the stronghold")

	# Start the expedition the way walking into the lower entrance does.
	world.activate_minewars_tunnel()
	controller.call("_prepare_world_for_run", "test")
	await _wait_frames(4)

	_expect(world.get_node_or_null("StrongholdLegacyForge") == null, "The forge must not survive into the expedition")
	_expect(world.get_node_or_null("StrongholdAmbience") == null, "Stronghold ambience must not survive into the expedition")
	for y in range(shaft.y - 3, shaft.y + 1):
		_expect(block_layer.get_cell_source_id(Vector2i(shaft.x, y)) == 16, "The upper shaft must be sealed during the expedition (cell %d)" % y)

	hub.queue_free()
	await _wait_frames(2)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("HUB_FURNITURE_CLEANUP: %s" % message)

func _wait_frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame
