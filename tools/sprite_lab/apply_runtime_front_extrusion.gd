extends Node

const WORLD_PATH := "res://scripts/systems/world_generation/world.gd"

func _replace_once(text: String, old_value: String, new_value: String, label: String) -> String:
	if not text.contains(old_value):
		push_error("Missing runtime extrusion anchor: " + label)
		return text
	return text.replace(old_value, new_value)

func _replace_function(text: String, function_name: String, replacement: String) -> String:
	var start := text.find("func %s(" % function_name)
	if start < 0:
		push_error("Missing function: " + function_name)
		return text
	var next := text.find("\nfunc ", start + 1)
	if next < 0:
		next = text.length()
	return text.substr(0, start) + replacement + "\n" + text.substr(next + 1)

func _ready() -> void:
	var text := FileAccess.get_file_as_string(WORLD_PATH)
	if text.is_empty():
		push_error("Could not read world.gd")
		get_tree().quit(1)
		return
	text = _replace_once(
		text,
		"const INSIDE_CORNER_Z_INDEX := 2\nvar inside_corner_textures: Dictionary = {}",
		"const INSIDE_CORNER_Z_INDEX := 2\nconst FRONT_EXTRUSION_RENDERER := preload(\"res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd\")\nconst FRONT_EXTRUSION_DEPTH := 10\nvar front_extrusion_renderer: Node2D\nvar inside_corner_textures: Dictionary = {}",
		"renderer declarations"
	)
	text = _replace_once(
		text,
		"\t_setup_inside_corner_renderer()\n\t_configure_mine_lighting()",
		"\t_setup_inside_corner_renderer()\n\t_setup_front_extrusion_renderer()\n\t_configure_mine_lighting()",
		"ready setup"
	)
	var setup_function := "func _setup_front_extrusion_renderer() -> void:\n\tfront_layer.clear()\n\tfront_layer.visible = false\n\tfront_extrusion_renderer = get_node_or_null(\"DomeFrontExtrusionRenderer\") as Node2D\n\tif front_extrusion_renderer == null:\n\t\tfront_extrusion_renderer = FRONT_EXTRUSION_RENDERER.new() as Node2D\n\t\tfront_extrusion_renderer.name = \"DomeFrontExtrusionRenderer\"\n\t\tfront_extrusion_renderer.z_index = 2\n\t\tadd_child(front_extrusion_renderer)\n\tfront_extrusion_renderer.call(\"setup\", block_layer, FRONT_EXTRUSION_DEPTH)\n\n"
	var inside_anchor := text.find("func _setup_inside_corner_renderer()")
	if inside_anchor < 0:
		push_error("Missing inside corner setup anchor")
	else:
		text = text.substr(0, inside_anchor) + setup_function + text.substr(inside_anchor)
	text = _replace_once(
		text,
		"\t_rebuild_inside_corners()\n\t_normalize_gem_indicator_sprites()",
		"\t_rebuild_inside_corners()\n\tif front_extrusion_renderer != null:\n\t\tfront_extrusion_renderer.call(\"rebuild_all\")\n\t_normalize_gem_indicator_sprites()",
		"initial rebuild"
	)
	var update_function := "func update_front_wall(cell: Vector2i) -> void:\n\t# The legacy square FrontWallLayer is intentionally disabled. The generated\n\t# renderer derives a shallow wall from the exact rounded edge-atlas alpha,\n\t# so convex ends and neighbouring materials share the terrain silhouette.\n\tfront_layer.erase_cell(cell + Vector2i.DOWN)\n\tif front_extrusion_renderer != null:\n\t\tfront_extrusion_renderer.call(\"refresh_around\", cell)\n\tif gem_blocks.has(cell):\n\t\t_refresh_gem_indicator(cell)\n"
	text = _replace_function(text, "update_front_wall", update_function)
	var file := FileAccess.open(WORLD_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write world.gd")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Installed generated rounded front extrusion in the live mine")
	get_tree().quit()
