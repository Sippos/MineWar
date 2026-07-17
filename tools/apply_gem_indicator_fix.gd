extends Node

const WORLD_PATH := "res://scripts/systems/world_generation/world.gd"
const BACKUP_PATH := "res://tools/world_before_gem_indicator_fix_20260717.gd.bak"

func _ready() -> void:
	var file := FileAccess.open(WORLD_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open world.gd for reading")
		get_tree().quit(1)
		return
	var source: String = file.get_as_text()
	file.close()

	var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
	if backup == null:
		push_error("Could not create world.gd backup")
		get_tree().quit(1)
		return
	backup.store_string(source)
	backup.close()

	source = _replace_once(
		source,
		"const GEM_FRONT_TEXTURE = preload(\"res://Stat_Ressources_Overlay_Front.png\")\n",
		"const GEM_FRONT_TEXTURE = preload(\"res://Stat_Ressources_Overlay_Front.png\")\nconst GEM_INDICATOR_TEXTURE: Texture2D = preload(\"res://assets/sprites/ui/common/stats/StatRessources.png\")\nconst GEM_INDICATOR_TOP_SCALE := Vector2(0.58, 0.58)\nconst GEM_INDICATOR_FRONT_SCALE := Vector2(0.46, 0.46)\n"
	)

	source = _replace_once(
		source,
		"\tworld_generation_in_progress = true\n\tgenerate_initial_world()\n\tworld_generation_in_progress = false\n",
		"\tworld_generation_in_progress = true\n\tgenerate_initial_world()\n\t_normalize_gem_indicator_sprites()\n\tworld_generation_in_progress = false\n"
	)

	source = _replace_once(
		source,
		"\tif gem_blocks.has(cell):\n\t\tvar sprites = gem_blocks[cell]\n\t\tif is_instance_valid(sprites.top):\n\t\t\tsprites.top.visible = (index != 0)\n\t\t\tif index != 0:\n\t\t\t\tsprites.top.region_enabled = true\n\t\t\t\tsprites.top.region_rect = Rect2(atlas_x * 64, atlas_y * 64, 64, 64)\n",
		"\tif gem_blocks.has(cell):\n\t\t_refresh_gem_indicator(cell)\n"
	)

	source = _replace_once(
		source,
		"func has_gem(cell: Vector2i) -> bool:\n\tif gem_blocks.has(cell):\n\t\tvar sprites = gem_blocks[cell]\n\t\tif is_instance_valid(sprites.top):\n\t\t\tsprites.top.queue_free()\n\t\tif is_instance_valid(sprites.front):\n\t\t\tsprites.front.queue_free()\n\t\tgem_blocks.erase(cell)\n\t\treturn true\n\treturn false\n",
		"func has_gem(cell: Vector2i) -> bool:\n\tif gem_blocks.has(cell):\n\t\tvar sprites: Dictionary = gem_blocks[cell]\n\t\tvar top_sprite: Sprite2D = sprites.get(\"top\") as Sprite2D\n\t\tvar front_sprite: Sprite2D = sprites.get(\"front\") as Sprite2D\n\t\tif is_instance_valid(top_sprite):\n\t\t\ttop_sprite.visible = false\n\t\t\ttop_sprite.queue_free()\n\t\tif is_instance_valid(front_sprite):\n\t\t\tfront_sprite.visible = false\n\t\t\tfront_sprite.queue_free()\n\t\tgem_blocks.erase(cell)\n\t\treturn true\n\treturn false\n"
	)

	source = _replace_once(
		source,
		"\tif gem_blocks.has(cell):\n\t\tvar sprites = gem_blocks[cell]\n\t\tif is_instance_valid(sprites.front):\n\t\t\t_position_front_gem_sprite(sprites.front, cell)\n\t\t\tsprites.front.visible = has_front_wall\n\nfunc _position_front_gem_sprite(sprite: Sprite2D, cell: Vector2i) -> void:\n",
		"\tif gem_blocks.has(cell):\n\t\t_refresh_gem_indicator(cell)\n\nfunc _normalize_gem_indicator_sprites() -> void:\n\tfor raw_cell: Variant in gem_blocks.keys():\n\t\tvar cell: Vector2i = raw_cell\n\t\tvar sprites: Dictionary = gem_blocks[cell]\n\t\tvar top_sprite: Sprite2D = sprites.get(\"top\") as Sprite2D\n\t\tvar front_sprite: Sprite2D = sprites.get(\"front\") as Sprite2D\n\t\tif is_instance_valid(top_sprite):\n\t\t\tif top_sprite.get_parent() != self:\n\t\t\t\ttop_sprite.reparent(self, true)\n\t\t\ttop_sprite.texture = GEM_INDICATOR_TEXTURE\n\t\t\ttop_sprite.region_enabled = false\n\t\t\ttop_sprite.scale = GEM_INDICATOR_TOP_SCALE\n\t\t\ttop_sprite.z_index = FRONT_GEM_Z_INDEX\n\t\t\ttop_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST\n\t\tif is_instance_valid(front_sprite):\n\t\t\tfront_sprite.texture = GEM_INDICATOR_TEXTURE\n\t\t\tfront_sprite.region_enabled = false\n\t\t\tfront_sprite.offset = Vector2(0.0, -16.0)\n\t\t\tfront_sprite.scale = GEM_INDICATOR_FRONT_SCALE\n\t\t\tfront_sprite.z_index = FRONT_GEM_Z_INDEX\n\t\t\tfront_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST\n\t\t_refresh_gem_indicator(cell)\n\nfunc _refresh_gem_indicator(cell: Vector2i) -> void:\n\tif not gem_blocks.has(cell):\n\t\treturn\n\tvar sprites: Dictionary = gem_blocks[cell]\n\tvar top_sprite: Sprite2D = sprites.get(\"top\") as Sprite2D\n\tvar front_sprite: Sprite2D = sprites.get(\"front\") as Sprite2D\n\tvar solid: bool = block_layer.get_cell_source_id(cell) != -1\n\tvar top_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x, cell.y - 1)) == -1\n\tvar right_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x + 1, cell.y)) == -1\n\tvar bottom_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x, cell.y + 1)) == -1\n\tvar left_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x - 1, cell.y)) == -1\n\tvar show_front: bool = bottom_open\n\tvar show_top: bool = solid and not show_front and (top_open or right_open or left_open)\n\n\tif is_instance_valid(top_sprite):\n\t\ttop_sprite.visible = show_top\n\t\tif show_top:\n\t\t\tvar indicator_offset := Vector2.ZERO\n\t\t\tif top_open:\n\t\t\t\tindicator_offset = Vector2(0.0, -18.0)\n\t\t\telif left_open and not right_open:\n\t\t\t\tindicator_offset = Vector2(-18.0, 0.0)\n\t\t\telif right_open and not left_open:\n\t\t\t\tindicator_offset = Vector2(18.0, 0.0)\n\t\t\ttop_sprite.global_position = block_layer.to_global(block_layer.map_to_local(cell)) + indicator_offset\n\n\tif is_instance_valid(front_sprite):\n\t\t_position_front_gem_sprite(front_sprite, cell)\n\t\tfront_sprite.visible = show_front\n\nfunc _position_front_gem_sprite(sprite: Sprite2D, cell: Vector2i) -> void:\n"
	)

	var output := FileAccess.open(WORLD_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Could not open world.gd for writing")
		get_tree().quit(1)
		return
	output.store_string(source)
	output.close()
	print("Applied stable gem-indicator rendering fix to world.gd")
	get_tree().quit()

func _replace_once(source: String, old_text: String, new_text: String) -> String:
	var matches: int = source.count(old_text)
	if matches != 1:
		push_error("Expected exactly one patch match, got %d" % matches)
		get_tree().quit(1)
		return source
	return source.replace(old_text, new_text)
