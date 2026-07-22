extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const RUNTIME_PATH := "res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd"

func _replace_once(text: String, old_value: String, new_value: String, label: String) -> String:
	if not text.contains(old_value):
		push_error("Missing patch anchor: " + label)
		return text
	return text.replace(old_value, new_value)

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + path)
		return false
	file.store_string(text)
	file.close()
	return true

func _ready() -> void:
	var preview := FileAccess.get_file_as_string(PREVIEW_PATH)
	preview = _replace_once(
		preview,
		'''\t\t\tvar left_open := not _is_solid(cell + Vector2i.LEFT)
\t\t\tvar right_open := not _is_solid(cell + Vector2i.RIGHT)''',
		'''\t\t\t# Round only a genuinely free outer tip. A diagonal solid block means this
\t\t\t# face is meeting a tunnel/Hole Corner transition and must stay square.
\t\t\tvar left_open := not _is_solid(cell + Vector2i.LEFT) and not _is_solid(cell + Vector2i.DOWN + Vector2i.LEFT)
\t\t\tvar right_open := not _is_solid(cell + Vector2i.RIGHT) and not _is_solid(cell + Vector2i.DOWN + Vector2i.RIGHT)''',
		"preview outer-tip topology"
	)
	if not _write(PREVIEW_PATH, preview):
		get_tree().quit(1)
		return

	var runtime := FileAccess.get_file_as_string(RUNTIME_PATH)
	runtime = _replace_once(
		runtime,
		'''\tvar image := _build_extrusion_image(source_id, _exposure_mask(cell))''',
		'''\tvar left_round := not _is_solid(cell + Vector2i.LEFT) and not _is_solid(cell + Vector2i.DOWN + Vector2i.LEFT)
\tvar right_round := not _is_solid(cell + Vector2i.RIGHT) and not _is_solid(cell + Vector2i.DOWN + Vector2i.RIGHT)
\tvar image := _build_extrusion_image(source_id, _exposure_mask(cell), left_round, right_round)''',
		"runtime topology flags"
	)
	runtime = _replace_once(
		runtime,
		'''\tvar radius := mini(8, face_height)''',
		'''\tvar radius := mini(6, face_height)''',
		"runtime mask radius"
	)
	runtime = _replace_once(
		runtime,
		'''func _build_extrusion_image(source_id: int, mask: int) -> Image:''',
		'''func _build_extrusion_image(source_id: int, mask: int, round_left: bool = false, round_right: bool = false) -> Image:''',
		"runtime extrusion arguments"
	)
	runtime = _replace_once(
		runtime,
		'''\tvar left_open := (mask & 8) != 0
\tvar right_open := (mask & 2) != 0''',
		'''\t# These flags come from side + lower-diagonal topology, not from the border
\t# atlas. Thus inner tunnel corners remain square while true protruding ends round.
\tvar left_open := round_left
\tvar right_open := round_right''',
		"runtime independent outer-tip flags"
	)
	if not _write(RUNTIME_PATH, runtime):
		get_tree().quit(1)
		return

	print("Front mask now rounds only true free outer tips; tunnel joins remain square.")
	get_tree().quit()
