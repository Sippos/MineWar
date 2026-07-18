extends Node

func _ready() -> void:
	var failures := 0
	failures += _patch_global_test_save_path()
	failures += _patch_boss_reinforcement_race()
	if failures == 0:
		print("MINEWARS_COMPLETE_RUN_RUNTIME_PATCHES_APPLIED")
		get_tree().quit()
	else:
		push_error("MINEWARS_COMPLETE_RUN_RUNTIME_PATCHES_FAILED: %d" % failures)
		get_tree().quit(1)

func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read " + path)
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write " + path)
		return false
	file.store_string(text)
	file.close()
	return true

func _replace_once(source: String, old_text: String, new_text: String, label: String) -> Dictionary:
	if source.contains(new_text):
		return {"text": source, "failed": false}
	var count := source.count(old_text)
	if count != 1:
		push_error("Patch count mismatch for %s: expected 1, found %d" % [label, count])
		return {"text": source, "failed": true}
	return {"text": source.replace(old_text, new_text), "failed": false}

func _patch_global_test_save_path() -> int:
	var path := "res://global.gd"
	var source := _read(path)
	if source.is_empty():
		return 1
	var result := _replace_once(
		source,
		"const DEFAULT_BASE_ID := \"default_base\"\n",
		"const DEFAULT_BASE_ID := \"default_base\"\nconst DEFAULT_SAVE_PATH := \"user://savegame.save\"\nvar save_path_override := \"\"\n\nfunc get_save_path() -> String:\n\treturn save_path_override if not save_path_override.is_empty() else DEFAULT_SAVE_PATH\n\nfunc set_save_path_override(path: String) -> void:\n\tsave_path_override = path\n",
		"global save path declaration"
	)
	if bool(result["failed"]):
		return 1
	source = str(result["text"])
	source = source.replace("FileAccess.open(\"user://savegame.save\", FileAccess.WRITE)", "FileAccess.open(get_save_path(), FileAccess.WRITE)")
	source = source.replace("FileAccess.file_exists(\"user://savegame.save\")", "FileAccess.file_exists(get_save_path())")
	source = source.replace("FileAccess.open(\"user://savegame.save\", FileAccess.READ)", "FileAccess.open(get_save_path(), FileAccess.READ)")
	return 0 if _write(path, source) else 1

func _patch_boss_reinforcement_race() -> int:
	var path := "res://scripts/systems/world_generation/siege_mode_controller.gd"
	var source := _read(path)
	if source.is_empty():
		return 1
	var result := _replace_once(
		source,
		"var boss_phase := 0\n",
		"var boss_phase := 0\nvar pending_reinforcement_batches := 0\n",
		"boss reinforcement state"
	)
	if bool(result["failed"]):
		return 1
	source = str(result["text"])
	result = _replace_once(
		source,
		"\tif not wave_spawning and _count_world_enemies() == 0:\n\t\t_complete_assault()",
		"\tif not wave_spawning and pending_reinforcement_batches == 0 and _count_world_enemies() == 0:\n\t\t_complete_assault()",
		"assault completion guard"
	)
	if bool(result["failed"]):
		return 1
	source = str(result["text"])
	result = _replace_once(
		source,
		"func _spawn_boss_reinforcements(roster: Array, entrance_cell: Vector2i) -> void:\n\tvar entrance_position := _cell_world_position(entrance_cell)",
		"func _spawn_boss_reinforcements(roster: Array, entrance_cell: Vector2i) -> void:\n\tpending_reinforcement_batches += 1\n\tvar entrance_position := _cell_world_position(entrance_cell)",
		"reinforcement batch start"
	)
	if bool(result["failed"]):
		return 1
	source = str(result["text"])
	result = _replace_once(
		source,
		"\t\tif world == null or not is_instance_valid(world):\n\t\t\treturn\n\t\t_spawn_enemy(int(roster[index]), entrance_position + Vector2(0, float(index - 1) * 10.0), false)\n\t\tawait get_tree().create_timer(0.28).timeout\n\nfunc _complete_assault() -> void:",
		"\t\tif world == null or not is_instance_valid(world):\n\t\t\tpending_reinforcement_batches = maxi(0, pending_reinforcement_batches - 1)\n\t\t\treturn\n\t\t_spawn_enemy(int(roster[index]), entrance_position + Vector2(0, float(index - 1) * 10.0), false)\n\t\tawait get_tree().create_timer(0.28).timeout\n\tpending_reinforcement_batches = maxi(0, pending_reinforcement_batches - 1)\n\nfunc _complete_assault() -> void:",
		"reinforcement batch completion"
	)
	if bool(result["failed"]):
		return 1
	source = str(result["text"])
	return 0 if _write(path, source) else 1
