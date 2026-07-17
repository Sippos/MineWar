extends Node

const LEVEL_SCENE := preload("res://scenes/world/mine/level.tscn")
const NEST_CELL := Vector2i(-9, 6)
const ARTIFACT_CELLS := [Vector2i(14, 13), Vector2i(-15, 20), Vector2i(5, 27)]
const BOSS_GATE_CELL := Vector2i(0, 28)

func _ready() -> void:
	GameMode.set_mode(GameMode.Mode.EXPLORATION)
	var level := LEVEL_SCENE.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var controller := level.get_node_or_null("ExplorationModeController")
	assert(controller != null, "Exploration controller should attach to a solo Level")
	assert(not level.is_processing(), "Scheduled wave processing should be disabled in Exploration")
	assert(not level.has_node("EnemyApproachPrototype"), "Breach prototype must not attach in Exploration")

	level.on_cell_dug(NEST_CELL)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(bool(controller.nests[0]["discovered"]), "Mining a fixed nest cell should reveal the nest")
	while not bool(controller.nests[0]["destroyed"]):
		controller._damage_nest(0)
	assert(int(controller.nests_destroyed) == 1, "Discovered nests should be destructible")

	for cell in ARTIFACT_CELLS:
		level.on_cell_dug(cell)
		await get_tree().process_frame
		var player := level.get_node("Player") as CharacterBody2D
		var block_layer := level.get_node("BlockLayer") as TileMapLayer
		player.global_position = block_layer.to_global(block_layer.map_to_local(cell))
		await get_tree().process_frame
		await get_tree().process_frame
	assert(int(controller.artifacts_collected) == 3, "All three artifacts should be collectible")

	level.on_cell_dug(BOSS_GATE_CELL)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(bool(controller.boss_spawned), "The bottom gate should summon the boss after all artifacts")
	assert(controller.boss_node != null and is_instance_valid(controller.boss_node), "Boss instance should exist")

	print("EXPLORATION_SMOKE_OK nests=1 artifacts=3 boss=true")
	get_tree().quit()
