extends Node

func _ready() -> void:
	var ok := true
	ok = _patch_level_scene() and ok
	ok = _patch_map_bounds() and ok
	ok = _patch_world_visual_contract() and ok
	print("Dome material runtime patch applied" if ok else "Dome material runtime patch failed")
	get_tree().quit(0 if ok else 1)

func _patch_level_scene() -> bool:
	var path := "res://scenes/world/mine/level.tscn"
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Could not read level scene")
		return false
	var