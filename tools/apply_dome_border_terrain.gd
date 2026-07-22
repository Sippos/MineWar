extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	_patch_runtime_textures()
	_patch_level_scene()
	_patch_map_bounds()
	_patch_world_contract()
	_patch_gem_depth()
	if failures.is_empty():
		print("Dome border terrain integration complete")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _read(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		failures.append("Missing or empty file: %s" % path)
	return text

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(text)
	file.close()

func _replace_once(text: String, old: String, replacement: String, label: String) -> String:
	if text.contains(replacement):
		return text
	if not text.contains(old):
		failures.append("Patch anchor not found: %s" % label)
		return text
	return text.replace(old, replacement)

func _patch_runtime_textures() -> void:
	var path := "res://scripts/systems/world_generation/world_terrain_runtime.gd"
	var text := _read(path)
	if text.is_empty():
		return
	text = _replace_once(
		text,
		"\t14: \"res://assets/sprites/world/terrain/front_damage/Next-Hit-Front-Rework.svg\"\n}",
		"\t14: \"res://assets/sprites/world/terrain/front_damage/Next-Hit-Front-Rework.svg\",\n\t16: \"res://assets/sprites/world/terrain/bricks/Bedrock_Border.svg\"\n}",
		"runtime bedrock texture"
	)
	_write(path, text)

func _patch_level_scene() -> void:
	var path := "res://scenes/world/mine/level.tscn"
	var text := _read(path)
	if text.is_empty():
		return
	text = _replace_once(
		text,
		"[ext_resource type=\"Texture2D\" uid=\"uid://05q4s6yyeyv1\" path=\"res://assets/sprites/world/terrain/bricks/Medium_Brick.png\" id=\"tex_med\"]\n",
		"[ext_resource type=\"Texture2D\" uid=\"uid://05q4s6yyeyv1\" path=\"res://assets/sprites/world/terrain/bricks/Medium_Brick.png\" id=\"tex_med\"]\n[ext_resource type=\"Texture2D\" path=\"res://assets/sprites/world/terrain/bricks/Bedrock_Border.svg\" id=\"tex_bedrock\"]\n",
		"level bedrock resource"
	)
	var bedrock_source := "[sub_resource type=\"TileSetAtlasSource\" id=\"Source_bedrock\"]\ntexture = ExtResource(\"tex_bedrock\")\ntexture_region_size = Vector2i(64, 64)\n0:0/0 = 0\n0:0/0/physics_layer_0/polygon_0/points = PackedVector2Array(-32, -32, 32, -32, 32, 32, -32, 32)\n\n"
	text = _replace_once(
		text,
		"[sub_resource type=\"TileSetAtlasSource\" id=\"Source_edge_easy\"]",
		bedrock_source + "[sub_resource type=\"TileSetAtlasSource\" id=\"Source_edge_easy\"]",
		"level bedrock atlas source"
	)
	text = _replace_once(
		text,
		"sources/15 = SubResource(\"Source_rail\")",
		"sources/15 = SubResource(\"Source_rail\")\nsources/16 = SubResource(\"Source_bedrock\")",
		"level bedrock source id"
	)
	text = _replace_once(
		text,
		"[node name=\"FrontWallLayer\" type=\"TileMapLayer\" parent=\".\" unique_id=601881360]\nz_index = 3",
		"[node name=\"FrontWallLayer\" type=\"TileMapLayer\" parent=\".\" unique_id=601881360]\nvisible = false\nz_index = 3",
		"disable projected front wall layer"
	)
	text = _replace_once(
		text,
		"[node name=\"FrontDamageLayer\" type=\"TileMapLayer\" parent=\".\" unique_id=1720352593]\nz_index = 4",
		"[node name=\"FrontDamageLayer\" type=\"TileMapLayer\" parent=\".\" unique_id=1720352593]\nvisible = false\nz_index = 4",
		"disable projected front damage layer"
	)
	_write(path, text)

func _patch_map_bounds() -> void:
	var path := "res://map_bounds.gd"
	var text := _read(path)
	if text.is_empty():
		return
	text = _replace_once(text, "const BOUNDARY_SOURCE_ID := 3", "const BOUNDARY_SOURCE_ID := 16", "boundary source id")
	_write(path, text)

func _patch_world_contract() -> void:
	var path := "res://scripts/systems/world_generation/world.gd"
	var text := _read(path)
	if text.is_empty():
		return
	var old_front := "func update_front_wall(cell: Vector2i) -> void:\n\tvar block_id = block_layer.get_cell_source_id(cell)\n\tvar below_cell = Vector2i(cell.x, cell.y + 1)\n\tvar has_front_wall = false\n\t\n\tif block_id != -1:\n\t\t# If cell is solid, check if below is empty\n\t\tif block_layer.get_cell_source_id(below_cell) == -1:\n\t\t\tvar front_id = 10 # Easy Front\n\t\t\tif block_id == 2: front_id = 11\n\t\t\telif block_id == 3: front_id = 12\n\t\t\t\n\t\t\tfront_layer.set_cell(below_cell, front_id, Vector2i(0, 0))\n\t\t\thas_front_wall = true\n\t\telse:\n\t\t\tfront_layer.erase_cell(below_cell)\n\telse:\n\t\t# If cell is empty, it can't have a front wall projecting down\n\t\tfront_layer.erase_cell(below_cell)\n\t\t\n\tif gem_blocks.has(cell):\n\t\t_refresh_gem_indicator(cell)"
	var new_front := "func update_front_wall(cell: Vector2i) -> void:\n\t# Dome-style terrain uses the bottom bit of the transparent 16-mask edge\n\t# atlas as its front-facing rim. Keep the legacy layer empty so old callers\n\t# remain safe without projecting a second full tile into tunnel space.\n\tvar below_cell := cell + Vector2i.DOWN\n\tfront_layer.erase_cell(below_cell)\n\tif gem_blocks.has(cell):\n\t\t_refresh_gem_indicator(cell)"
	text = _replace_once(text, old_front, new_front, "world front wall contract")
	var old_position := "func _position_front_gem_sprite(sprite: Sprite2D, cell: Vector2i) -> void:\n\tvar below_cell = Vector2i(cell.x, cell.y + 1)\n\tsprite.global_position = front_layer.to_global(front_layer.map_to_local(below_cell))\n\tsprite.global_position.y += 1.0"
	var new_position := "func _position_front_gem_sprite(sprite: Sprite2D, cell: Vector2i) -> void:\n\t# Bottom-facing veins now live on the solid tile's own thicker lower rim.\n\tsprite.global_position = block_layer.to_global(block_layer.map_to_local(cell))\n\tsprite.global_position.y += 8.0"
	text = _replace_once(text, old_position, new_position, "bottom edge gem position")
	_write(path, text)

func _patch_gem_depth() -> void:
	var path := "res://scripts/systems/world_generation/world_gem_visuals.gd"
	var text := _read(path)
	if text.is_empty():
		return
	text = _replace_once(text, "const GEM_FRONT_Z_INDEX := 3", "const GEM_FRONT_Z_INDEX := 2", "bottom edge gem z-index")
	_write(path, text)
