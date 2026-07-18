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
	var center := block_layer.to_global(block_layer.map_to_local(mine_entry))
	hero.global_position = center
	hero.set("health", hero.get("max_health"))
	hero.set("invulnerability_timer", 0.0)
	print("GATE_DEBUG_BEFORE health=", hero.get("health"), " pos=", hero.global_position, " center=", center, " ref_same=", hero == line_wars.get("hero"))
	line_wars.call("_trigger_gate_eruption")
	print("GATE_DEBUG_AFTER_IMMEDIATE health=", hero.get("health"), " pos=", hero.global_position, " velocity=", hero.velocity)
	await _wait_frames(3)
	print("GATE_DEBUG_AFTER_FRAMES health=", hero.get("health"), " pos=", hero.global_position, " velocity=", hero.velocity)
	get_tree().quit(0)

func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame
