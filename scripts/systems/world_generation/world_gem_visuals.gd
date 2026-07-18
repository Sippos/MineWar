extends "res://scripts/systems/world_generation/world_terrain_runtime.gd"

# Visual-only specialization used by the base mine scene (local co-op and VS).
# Single Player's continuous world has equivalent lazy creation in
# preparation_fast_world.gd because it stores gem entries without sprites.
const GEM_TEXTURE_FACTORY = preload("res://scripts/systems/preparation/gem_indicator_texture_factory.gd")
const GEM_EDGE_PATH := "res://assets/sprites/world/terrain/gem_embedded_edge.svg"
const GEM_FRONT_PATH := "res://assets/sprites/world/terrain/gem_embedded_front.svg"

var gem_edge_texture: Texture2D
var gem_front_texture: Texture2D

func _ensure_gem_textures() -> bool:
	if gem_edge_texture == null:
		gem_edge_texture = GEM_TEXTURE_FACTORY.load_svg_texture(GEM_EDGE_PATH)
	if gem_front_texture == null:
		gem_front_texture = GEM_TEXTURE_FACTORY.load_svg_texture(GEM_FRONT_PATH)
	return gem_edge_texture != null and gem_front_texture != null

func _ensure_visual_sprites(cell: Vector2i) -> Dictionary:
	var sprites: Dictionary = gem_blocks.get(cell, {"top": null, "front": null})
	if not _ensure_gem_textures():
		return sprites
	var top_sprite := sprites.get("top") as Sprite2D
	var front_sprite := sprites.get("front") as Sprite2D
	if not is_instance_valid(top_sprite):
		top_sprite = Sprite2D.new()
		top_sprite.name = "GemTop_%d_%d" % [cell.x, cell.y]
		add_child(top_sprite)
		sprites["top"] = top_sprite
	if not is_instance_valid(front_sprite):
		front_sprite = Sprite2D.new()
		front_sprite.name = "GemFront_%d_%d" % [cell.x, cell.y]
		add_child(front_sprite)
		sprites["front"] = front_sprite

	top_sprite.texture = gem_edge_texture
	top_sprite.region_enabled = false
	top_sprite.offset = Vector2.ZERO
	top_sprite.scale = Vector2.ONE
	top_sprite.z_index = FRONT_GEM_Z_INDEX
	top_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	front_sprite.texture = gem_front_texture
	front_sprite.region_enabled = false
	front_sprite.offset = Vector2.ZERO
	front_sprite.scale = Vector2.ONE
	front_sprite.z_index = FRONT_GEM_Z_INDEX
	front_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	gem_blocks[cell] = sprites
	return sprites

func _normalize_gem_indicator_sprites() -> void:
	for raw_cell: Variant in gem_blocks.keys():
		var cell := Vector2i(raw_cell)
		_ensure_visual_sprites(cell)
		_refresh_gem_indicator(cell)

func _refresh_gem_indicator(cell: Vector2i) -> void:
	if not gem_blocks.has(cell):
		return
	var solid := block_layer.get_cell_source_id(cell) != -1
	var top_open := solid and block_layer.get_cell_source_id(Vector2i(cell.x, cell.y - 1)) == -1
	var right_open := solid and block_layer.get_cell_source_id(Vector2i(cell.x + 1, cell.y)) == -1
	var bottom_open := solid and block_layer.get_cell_source_id(Vector2i(cell.x, cell.y + 1)) == -1
	var left_open := solid and block_layer.get_cell_source_id(Vector2i(cell.x - 1, cell.y)) == -1
	var show_front := bottom_open
	var show_edge := solid and not show_front and (top_open or right_open or left_open)

	var sprites := _ensure_visual_sprites(cell)
	var top_sprite := sprites.get("top") as Sprite2D
	var front_sprite := sprites.get("front") as Sprite2D
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
