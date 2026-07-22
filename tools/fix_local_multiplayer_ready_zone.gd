extends Node

const TARGET := "res://scripts/systems/preparation/local_multiplayer_hub_controller.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(TARGET)
	if source.is_empty():
		push_error("Could not read local multiplayer hub controller")
		get_tree().quit(1)
		return

	var old_constants := '''const LINE_WARS_ENTRY_Y := -6
const MINE_WARS_ENTRY_Y := 7
const ROUTE_X_MIN := -1
const ROUTE_X_MAX := 1
const ADVENTURE_ENTRY_X := 10
const ADVENTURE_MIN_Y := -1
const ADVENTURE_MAX_Y := 1
const READY_COUNTDOWN := 1.35
'''
	var new_constants := '''# Readiness uses generous world-space rectangles that match the visible doorway
# glows. Players should not need to find an invisible exact TileMap cell.
const LINE_WARS_READY_ZONE := Rect2(-150.0, -480.0, 300.0, 220.0)
const MINE_WARS_READY_ZONE := Rect2(-150.0, 270.0, 300.0, 230.0)
const ADVENTURE_READY_ZONE := Rect2(390.0, -130.0, 250.0, 260.0)
const READY_COUNTDOWN := 1.35
'''
	if not source.contains(old_constants):
		push_error("Could not find old local multiplayer readiness constants")
		get_tree().quit(1)
		return
	source = source.replace(old_constants, new_constants)

	var old_function := '''func _mode_zone_for(target: CharacterBody2D) -> String:
	var cell := block_layer.local_to_map(block_layer.to_local(target.global_position))
	var in_vertical_route := cell.x >= ROUTE_X_MIN and cell.x <= ROUTE_X_MAX
	if in_vertical_route and cell.y <= LINE_WARS_ENTRY_Y:
		return "maze_vs"
	if in_vertical_route and cell.y >= MINE_WARS_ENTRY_Y:
		return "coop_mine"
	if cell.x >= ADVENTURE_ENTRY_X and cell.y >= ADVENTURE_MIN_Y and cell.y <= ADVENTURE_MAX_Y:
		return "coop_adventure"
	return ""
'''
	var new_function := '''func _mode_zone_for(target: CharacterBody2D) -> String:
	if target == null or not is_instance_valid(target):
		return ""
	var world_position := target.global_position
	if LINE_WARS_READY_ZONE.has_point(world_position):
		return "maze_vs"
	if MINE_WARS_READY_ZONE.has_point(world_position):
		return "coop_mine"
	if ADVENTURE_READY_ZONE.has_point(world_position):
		return "coop_adventure"
	return ""
'''
	if not source.contains(old_function):
		push_error("Could not find old local multiplayer mode-zone function")
		get_tree().quit(1)
		return
	source = source.replace(old_function, new_function)

	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not write local multiplayer hub controller")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("LOCAL_MULTIPLAYER_READY_ZONE_FIXED")
	get_tree().quit()
