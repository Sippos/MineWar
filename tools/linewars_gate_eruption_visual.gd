extends Node

const SINGLE_PLAYER_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")

func _ready() -> void:
	var hub := SINGLE_PLAYER_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(6)
	var world := hub.get_node("Level") as Node2D
	var selector := hub.get_node("SinglePlayerWorldController")
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var hero := world.get_node("Player") as CharacterBody2D
	hero.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(0, -7)))
	selector.call("_activate_line_wars")
	await _wait_frames(8)
	var line_wars := world.get_node("ContinuousLineWarsController")
	var peon := world.get_node("BuilderPeon") as CharacterBody2D
	var tunnel_exit: Vector2i = line_wars.get("tunnel_exit_cell")
	for step in range(1, 6):
		var previous_cell := tunnel_exit + Vector2i.UP * (step - 1)
		var target_cell := tunnel_exit + Vector2i.UP * step
		block_layer.set_cell(target_cell, 1, Vector2i.ZERO)
		if world.get("astar") != null and world.astar.is_in_bounds(target_cell.x, target_cell.y):
			world.astar.set_point_solid(target_cell, true)
		peon.global_position = block_layer.to_global(block_layer.map_to_local(previous_cell))
		peon.call("_process_surface_dig", Vector2.UP, 0.6)
		await _wait_frames(3)
	await _wait_frames(6)
	var mine_entry := Vector2i(0, 8)
	hero.global_position = block_layer.to_global(block_layer.map_to_local(mine_entry))
	hero.set("health", hero.get("max_health"))
	hero.set("invulnerability_timer", 0.0)
	var spawn_cell := tunnel_exit + Vector2i.UP * 5
	var spawn_position := block_layer.to_global(block_layer.map_to_local(spawn_cell))
	line_wars.call("_spawn_enemy_at_endpoint", 1, false, 0, 1, spawn_position)
	await _wait_frames(3)
	var enemy: CharacterBody2D
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(candidate) and world.is_ancestor_of(candidate):
			enemy = candidate as CharacterBody2D
			break
	if enemy:
		enemy.global_position = block_layer.to_global(block_layer.map_to_local(tunnel_exit))
		line_wars.call("_process_layer_transfers")
	await _wait_frames(2)
	print("LINEWARS_GATE_ERUPTION_VISUAL_READY")

func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame
