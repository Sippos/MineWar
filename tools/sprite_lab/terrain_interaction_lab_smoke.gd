extends Node

const CANVAS_SCRIPT := preload("res://tools/sprite_lab/terrain_interaction_canvas.gd")

func _ready() -> void:
	var canvas: Control = CANVAS_SCRIPT.new() as Control
	add_child(canvas)
	await get_tree().process_frame
	canvas.call("apply_template", "Motherlode")
	var mask_side: int = int(canvas.call("exposure_mask", Vector2i(2, 4)))
	var mask_front: int = int(canvas.call("exposure_mask", Vector2i(3, 2)))
	var front_state: int = int(canvas.call("front_connection_state", Vector2i(3, 2)))
	var gems: Dictionary = canvas.get("gems")
	if mask_side != 2:
		push_error("Expected side motherlode mask 2, got %d" % mask_side)
		get_tree().quit(1)
		return
	if (mask_front & 4) == 0:
		push_error("Expected top motherlode cell to expose a projected front wall, got mask %d" % mask_front)
		get_tree().quit(1)
		return
	if front_state < 0 or not gems.has(Vector2i(2, 5)) or int(gems[Vector2i(2, 5)]) != 3:
		push_error("Motherlode template did not preserve front/gem state")
		get_tree().quit(1)
		return
	var save_result: Error = canvas.call("save_map")
	if save_result != OK:
		push_error("Terrain lab save failed: %s" % error_string(save_result))
		get_tree().quit(1)
		return
	canvas.call("apply_template", "Solid Mass")
	var load_result: Error = canvas.call("load_map")
	if load_result != OK:
		push_error("Terrain lab load failed: %s" % error_string(load_result))
		get_tree().quit(1)
		return
	gems = canvas.get("gems")
	if not gems.has(Vector2i(2, 5)) or int(gems[Vector2i(2, 5)]) != 3:
		push_error("Terrain lab save/load did not restore motherlode data")
		get_tree().quit(1)
		return
	print("TERRAIN_INTERACTION_LAB_SMOKE_PASS mask_side=", mask_side, " mask_front=", mask_front, " front_state=", front_state, " gems=", gems.size())
	get_tree().quit(0)
