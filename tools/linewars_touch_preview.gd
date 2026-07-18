extends Node

const HUB_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")

func _ready() -> void:
	Global.first_level_beaten = true
	var hub := HUB_SCENE.instantiate()
	add_child(hub)
	for _index in 6:
		await get_tree().process_frame
	var world := hub.get_node("Level") as Node2D
	var selector := hub.get_node("SinglePlayerWorldController")
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var hero := world.get_node("Player") as CharacterBody2D
	world.set_meta("force_touch_commands", true)
	hero.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(0, -7)))
	selector.call("_activate_line_wars")
	for _index in 8:
		await get_tree().process_frame
	var controller := world.get_node("ContinuousLineWarsController")
	var exit_cell: Vector2i = controller.get("tunnel_exit_cell")
	for step in range(1, 6):
		var cell := exit_cell + Vector2i.UP * step
		block_layer.set_cell(cell, 1, Vector2i.ZERO)
		if world.get("astar") != null and world.astar.is_in_bounds(cell.x, cell.y):
			world.astar.set_point_solid(cell, true)
		world.call("on_cell_dug", cell)
	for _index in 8:
		await get_tree().process_frame
	var target := exit_cell + Vector2i.UP * 6
	block_layer.set_cell(target, 1, Vector2i.ZERO)
	if world.get("astar") != null and world.astar.is_in_bounds(target.x, target.y):
		world.astar.set_point_solid(target, true)
	controller.call("_begin_command_view", "DIG")
	controller.call("_select_touch_command_cell", target)
