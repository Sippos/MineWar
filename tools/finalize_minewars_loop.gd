extends Node

func _ready() -> void:
	_patch_world_objective_forwarding()
	_patch_controller_objective_event()
	_patch_siege_bootstrap_casts()
	_patch_input_autoload()
	print("MINEWARS_LOOP_FINALIZED")
	get_tree().quit()

func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read " + path)
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write " + path)
		return
	file.store_string(text)
	file.close()

func _replace_required(source: String, old_text: String, new_text: String, label: String) -> String:
	if source.contains(new_text):
		return source
	if not source.contains(old_text):
		push_error("Missing patch anchor: " + label)
		return source
	return source.replace(old_text, new_text)

func _patch_world_objective_forwarding() -> void:
	var path := "res://scripts/systems/world_generation/world.gd"
	var source := _read(path)
	var old_text := "func notify_tutorial_cell_dug(_cell: Vector2i, contained_gem: bool