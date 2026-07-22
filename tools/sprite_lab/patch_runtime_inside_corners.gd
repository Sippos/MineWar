extends Node

func _ready() -> void:
	var path := "res://scripts/systems/world_generation/world.gd"
	var text := FileAccess.get_file_as_string(path)
	var variable_marker := "@onready var front_layer: TileMapLayer = $FrontWallLayer\n@onready var canvas_modulate: CanvasModulate = $CanvasModulate\n"
	var variable_replacement := "@onready var front_layer: TileMapLayer = $FrontWallLayer\n@onready var canvas_modulate: CanvasModulate = $CanvasModulate\n\nconst INSIDE_CORNER_ATLAS_PATHS := {\n\t1: \"res://assets/sprites/world/terrain/dome/Easy_Inside_Corners.png\",\n\t2: \"res://assets/sprites/world/terrain/dome/Medium_Inside_Corners.png\",\n\t3: \"res://assets/sprites/world/terrain/dome/Hard_Inside_Corners.png\",\n}\nconst INSIDE_CORNER_FRAME_SIZE := 64\nconst INSIDE_CORNER_Z_INDEX := 2\nvar inside_corner_textures: Dictionary = {}\nvar inside_corner_sprites: Dictionary = {}\nvar inside_corner_layer: Node2D\n"
	if not text.contains(variable_marker):
		push_error("Could not find world inside-corner variable marker")
		get_tree().quit(1)
		return
	text = text.replace(variable_marker, variable_replacement)

	var ready_marker := "\t_ensure_base_gem_indicator_textures()\n\t_configure_mine_lighting()\n"
	var ready_replacement := "\t_ensure_base_gem_indicator_textures()\n\t_setup_inside_corner_renderer()\n\t_configure_mine_lighting()\n"
	if not text.contains(ready_marker):
		push_error("Could not find world ready setup marker")
		get_tree().quit(1)
		return
	text = text.replace(ready_marker, ready_replacement)

	var generation_marker := "\tgenerate_initial_world()\n\t_normalize_gem_indicator_sprites()\n"
	var generation_replacement := "\tgenerate_initial_world()\n\t_rebuild_inside_corners()\n\t_normalize_gem_indicator_sprites()\n"
	if not text.contains(generation_marker):
		push_error("Could not find world generation marker")
		get_tree().quit(1)
		return
	text = text.replace(generation_marker, generation_replacement)

	var empty_marker := "\tif block_layer.get_cell_source_id(cell) == -1:\n\t\tfog_layer.erase_cell(cell)\n\t\treturn\n"
	var empty_replacement := "\tif block_layer.get_cell_source_id(cell) == -1:\n\t\tfog_layer.erase_cell(cell)\n\t\t_refresh_inside_corners_around(cell)\n\t\treturn\n"
	if not text.contains(empty_marker):
		push_error("Could not find empty fog-mask marker")
		get_tree().quit(1)
		return
	text = text.replace(empty_marker, empty_replacement)

	var end_marker := "\tif gem_blocks.has(cell):\n\t\t_refresh_gem_indicator(cell)\n\nfunc _add_wasd_input() -> void:\n"
	var end_replacement := "\tif gem_blocks.has(cell):\n\t\t_refresh_gem_indicator(cell)\n\t_refresh_inside_corners_around(cell)\n\nfunc _add_wasd_input() -> void:\n"
	if not text.contains(end_marker):
		push_error("Could not find fog-mask end marker")
		get_tree().quit(1)
		return
	text = text.replace(end_marker, end_replacement)

	var insertion_marker := "func _configure_mine_lighting() -> void:\n"
	var functions := """func _setup_inside_corner_renderer() -> void:
	inside_corner_layer = get_node_or_null("InsideCornerLayer") as Node2D
	if inside_corner_layer == null:
		inside_corner_layer = Node2D.new()
		inside_corner_layer.name = "InsideCornerLayer"
		inside_corner_layer.z_index = INSIDE_CORNER_Z_INDEX
		add_child(inside_corner_layer)
	inside_corner_textures.clear()
	for block_id_value: Variant in INSIDE_CORNER_ATLAS_PATHS.keys():
		var block_id := int(block_id_value)
		var atlas_path := String(INSIDE_CORNER_ATLAS_PATHS[block_id])
		if not FileAccess.file_exists(atlas_path):
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(atlas_path))
		if image == null or image.is_empty():
			continue
		image.convert(Image.FORMAT_RGBA8)
		inside_corner_textures[block_id] = ImageTexture.create_from_image(image)

func _inside_corner_key(cell: Vector2i, frame: int) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, frame]

func _remove_inside_corner(cell: Vector2i, frame: int) -> void:
	var key := _inside_corner_key(cell, frame)
	var sprite := inside_corner_sprites.get(key) as Sprite2D
	if is_instance_valid(sprite):
		sprite.queue_free()
	inside_corner_sprites.erase(key)

func _refresh_inside_corners_for_empty_cell(cell: Vector2i) -> void:
	if inside_corner_layer == null:
		return
	if block_layer.get_cell_source_id(cell) != -1:
		for frame in range(4):
			_remove_inside_corner(cell, frame)
		return
	var rules := [
		[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],
		[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],
		[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],
		[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],
	]
	for rule_value: Variant in rules:
		var rule: Array = rule_value
		var first: Vector2i = rule[0]
		var second: Vector2i = rule[1]
		var diagonal: Vector2i = rule[2]
		var frame: int = rule[3]
		var first_solid := block_layer.get_cell_source_id(cell + first) != -1
		var second_solid := block_layer.get_cell_source_id(cell + second) != -1
		var owner_id := block_layer.get_cell_source_id(cell + diagonal)
		if not first_solid or not second_solid or not inside_corner_textures.has(owner_id):
			_remove_inside_corner(cell, frame)
			continue
		var key := _inside_corner_key(cell, frame)
		var sprite := inside_corner_sprites.get(key) as Sprite2D
		if not is_instance_valid(sprite):
			sprite = Sprite2D.new()
			sprite.name = "InsideCorner_%d_%d_%d" % [cell.x, cell.y, frame]
			sprite.centered = true
			sprite.region_enabled = true
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			inside_corner_layer.add_child(sprite)
			inside_corner_sprites[key] = sprite
		sprite.texture = inside_corner_textures[owner_id]
		sprite.region_rect = Rect2(Vector2(frame % 2, frame / 2) * INSIDE_CORNER_FRAME_SIZE, Vector2(INSIDE_CORNER_FRAME_SIZE, INSIDE_CORNER_FRAME_SIZE))
		sprite.position = inside_corner_layer.to_local(block_layer.to_global(block_layer.map_to_local(cell)))
		sprite.visible = true

func _refresh_inside_corners_around(cell: Vector2i) -> void:
	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			_refresh_inside_corners_for_empty_cell(cell + Vector2i(x_offset, y_offset))

func _rebuild_inside_corners() -> void:
	for sprite_value: Variant in inside_corner_sprites.values():
		var sprite := sprite_value as Sprite2D
		if is_instance_valid(sprite):
			sprite.queue_free()
	inside_corner_sprites.clear()
	var used_rect := block_layer.get_used_rect().grow(1)
	for y in range(used_rect.position.y, used_rect.end.y):
		for x in range(used_rect.position.x, used_rect.end.x):
			var cell := Vector2i(x, y)
			if block_layer.get_cell_source_id(cell) == -1:
				_refresh_inside_corners_for_empty_cell(cell)

"""
	if not text.contains(insertion_marker):
		push_error("Could not find world corner function insertion marker")
		get_tree().quit(1)
		return
	text = text.replace(insertion_marker, functions + insertion_marker)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write runtime inside-corner patch")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Runtime inside-corner renderer installed")
	get_tree().quit()
