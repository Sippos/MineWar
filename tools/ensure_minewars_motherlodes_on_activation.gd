extends Node

func _replace(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if not source.contains(old_text):
		push_error("Missing patch target in %s" % path)
		return
	source = source.replace(old_text, new_text)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()

func _ready() -> void:
	var world_path := "res://scripts/systems/world_generation/world.gd"
	_replace(world_path,
		"func get_minewars_prospect_hint(stage: int) -> String:\n",
		"func ensure_minewars_motherlodes() -> void:\n\tif minewars_motherlodes.is_empty():\n\t\t_seed_expedition_motherlodes()\n\nfunc get_minewars_prospect_hint(stage: int) -> String:\n")
	_replace(world_path,
		"\t\t\t_create_gem_block(cell)\n\tminewars_motherlodes = motherlodes",
		"\t\t\t_create_gem_block(cell)\n\t\t\tfor refresh_cell in [cell, cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]:\n\t\t\t\tupdate_fog_mask(refresh_cell)\n\t\t\t\tupdate_front_wall(refresh_cell)\n\tminewars_motherlodes = motherlodes")

	var controller_path := "res://scripts/systems/world_generation/siege_mode_controller.gd"
	_replace(controller_path,
		"\tworld.set_meta(\"wave_spawning\", false)\n\tworld.current_wave_number = stage_number",
		"\tworld.set_meta(\"wave_spawning\", false)\n\tif world.has_method(\"ensure_minewars_motherlodes\"):\n\t\tworld.ensure_minewars_motherlodes()\n\tworld.current_wave_number = stage_number")
	print("MINEWARS_MOTHERLODES_ACTIVATION_ENSURED")
	get_tree().quit()
