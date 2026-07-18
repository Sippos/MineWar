extends Node

const WORLD_PATH := "res://scripts/systems/world_generation/world.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(WORLD_PATH)
	if text.is_empty():
		push_error("Could not read world.gd")
		get_tree().quit(1)
		return

	text = text.replace(
		"const GEM_TOP_TEXTURE = preload(\"res://Easy_Edge_Atlas-1-Stat-Ressources.png\")\nconst GEM_FRONT_TEXTURE = preload(\"res://Stat_Ressources_Overlay_Front.png\")\nconst GEM_INDICATOR_TEXTURE: Texture2D = preload(\"res://assets/sprites/ui/common/stats/StatRessources.png\")\nconst GEM_INDICATOR_TOP_SCALE := Vector2(0.58, 0.58)\nconst GEM_INDICATOR_FRONT_SCALE := Vector2(0.46, 0.46)",
		"const GEM_TOP_TEXTURE: Texture2D = preload(\"res://assets/sprites/world/terrain/gem_embedded_edge.svg\")\nconst GEM_FRONT_TEXTURE: Texture2D = preload(\"res://assets/sprites/world/terrain/gem_embedded_front.svg\")\nconst GEM_INDICATOR_TEXTURE: Texture2D = GEM_TOP_TEXTURE\nconst GEM_INDICATOR_TOP_SCALE := Vector2.ONE\nconst GEM_INDICATOR_FRONT_SCALE := Vector2.ONE"
	)

	var old_block := """func _normalize_gem_indicator_sprites() -> void:
	for raw_cell: Variant in gem_blocks.keys():
		var cell: Vector2i = raw_cell
		var sprites: Dictionary = gem_blocks[cell]
		var top_sprite: Sprite2D = sprites.get(\"top\") as Sprite2D
		var front_sprite: Sprite2D = sprites.get(\"front\") as Sprite2D
		if is_instance_valid(top_sprite):
			if top_sprite.get_parent() != self:
				top_sprite.reparent(self, true)
			top_sprite.texture = GEM_INDICATOR_TEXTURE
			top_sprite.region_enabled = false
			top_sprite.scale = GEM_INDICATOR_TOP_SCALE
			top_sprite.z_index = FRONT_GEM_Z_INDEX
			top_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if is_instance_valid(front_sprite):
			front_sprite.texture = GEM_INDICATOR_TEXTURE
			front_sprite.region_enabled = false
			front_sprite.offset = Vector2(0.0, -16.0)
			front_sprite.scale = GEM_INDICATOR_FRONT_SCALE
			front_sprite.z_index = FRONT_GEM_Z_INDEX
			front_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_refresh_gem_indicator(cell)

func _refresh_gem_indicator(cell: Vector2i) -> void:
	if not gem_blocks.has(cell):
		return
	var sprites: Dictionary = gem_blocks[cell]
	var top_sprite: Sprite2D = sprites.get(\"top\") as Sprite2D
	var front_sprite: Sprite2D = sprites.get(\"front\") as Sprite2D
	var solid: bool = block_layer.get_cell_source_id(cell) != -1
	var top_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x, cell.y - 1)) == -1
	var right_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x + 1, cell.y)) == -1
	var bottom_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x, cell.y + 1)) == -1
	var left_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x - 1, cell.y)) == -1
	var show_front: bool = bottom_open
	var show_top: bool = solid and not show_front and (top_open or right_open or left_open)

	if is_instance_valid(top_sprite):
		top_sprite.visible = show_top
		if show_top:
			var indicator_offset := Vector2.ZERO
			if top_open:
				indicator_offset = Vector2(0.0, -18.0)
			elif left_open and not right_open:
				indicator_offset = Vector2(-18.0, 0.0)
			elif right_open and not left_open:
				indicator_offset = Vector2(18.0, 0.0)
			top_sprite.global_position = block_layer.to_global(block_layer.map_to_local(cell)) + indicator_offset

	if is_instance_valid(front_sprite):
		_position_front_gem_sprite(front_sprite, cell)
		front_sprite.visible = show_front
"""

	var new_block := """func _normalize_gem_indicator_sprites() -> void:
	for raw_cell: Variant in gem_blocks.keys():
		var cell: Vector2i = raw_cell
		var sprites: Dictionary = gem_blocks[cell]
		var top_sprite: Sprite2D = sprites.get(\"top\") as Sprite2D
		var front_sprite: Sprite2D = sprites.get(\"front\") as Sprite2D
		if is_instance_valid(top_sprite):
			if top_sprite.get_parent() != self:
				top_sprite.reparent(self, true)
			top_sprite.texture = GEM_TOP_TEXTURE
			top_sprite.region_enabled = false
			top_sprite.offset = Vector2.ZERO
			top_sprite.scale = GEM_INDICATOR_TOP_SCALE
			top_sprite.z_index = FRONT_GEM_Z_INDEX
			top_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if is_instance_valid(front_sprite):
			front_sprite.texture = GEM_FRONT_TEXTURE
			front_sprite.region_enabled = false
			front_sprite.offset = Vector2.ZERO
			front_sprite.scale = GEM_INDICATOR_FRONT_SCALE
			front_sprite.z_index = FRONT_GEM_Z_INDEX
			front_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_refresh_gem_indicator(cell)

func _refresh_gem_indicator(cell: Vector2i) -> void:
	if not gem_blocks.has(cell):
		return
	var sprites: Dictionary = gem_blocks[cell]
	var top_sprite: Sprite2D = sprites.get(\"top\") as Sprite2D
	var front_sprite: Sprite2D = sprites.get(\"front\") as Sprite2D
	var solid: bool = block_layer.get_cell_source_id(cell) != -1
	var top_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x, cell.y - 1)) == -1
	var right_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x + 1, cell.y)) == -1
	var bottom_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x, cell.y + 1)) == -1
	var left_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x - 1, cell.y)) == -1
	var show_front: bool = bottom_open
	var show_edge: bool = solid and not show_front and (top_open or right_open or left_open)

	if is_instance_valid(top_sprite):
		top_sprite.visible = show_edge
		if show_edge:
			top_sprite.global_position = block_layer.to_global(block_layer.map_to_local(cell))
			if top_open:
				top_sprite.rotation_degrees = 0.0
			elif left_open and not right_open:
				top_sprite.rotation_degrees = -90.0
			else:
				top_sprite.rotation_degrees = 90.0

	if is_instance_valid(front_sprite):
		_position_front_gem_sprite(front_sprite, cell)
		front_sprite.visible = show_front
"""

	if not text.contains(old_block):
		push_error("Legacy gem-indicator block was not found; no unsafe partial patch was written.")
		get_tree().quit(1)
		return
	text = text.replace(old_block, new_block)

	var file := FileAccess.open(WORLD_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write world.gd")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Replaced the legacy loose-gem indicator with tile-face overlays in world.gd.")
	get_tree().quit(0)
