extends "res://scripts/systems/world_generation/world_terrain_runtime.gd"

# Visual-only specialization used by the base mine scene (local co-op and VS).
# Single Player's continuous world has equivalent lazy creation in
# preparation_fast_world.gd because it stores gem entries without sprites.
const GEM_TEXTURE_FACTORY = preload("res://scripts/systems/preparation/gem_indicator_texture_factory.gd")
const GEM_ATLAS_PATH := "res://assets/sprites/world/terrain/gem_overlays/minewars_gem_overlay_atlas.png"
const GEM_CELL_SIZE := 64
const GEM_TOP_REGIONS := [
	Rect2(0, 0, GEM_CELL_SIZE, GEM_CELL_SIZE),
	Rect2(GEM_CELL_SIZE, 0, GEM_CELL_SIZE, GEM_CELL_SIZE),
	Rect2(GEM_CELL_SIZE * 2, 0, GEM_CELL_SIZE, GEM_CELL_SIZE),
	Rect2(GEM_CELL_SIZE * 3, 0, GEM_CELL_SIZE, GEM_CELL_SIZE),
]
const GEM_FRONT_REGIONS := [
	Rect2(0, GEM_CELL_SIZE, GEM_CELL_SIZE, GEM_CELL_SIZE),
	Rect2(GEM_CELL_SIZE, GEM_CELL_SIZE, GEM_CELL_SIZE, GEM_CELL_SIZE),
	Rect2(GEM_CELL_SIZE * 2, GEM_CELL_SIZE, GEM_CELL_SIZE, GEM_CELL_SIZE),
	Rect2(GEM_CELL_SIZE * 3, GEM_CELL_SIZE, GEM_CELL_SIZE, GEM_CELL_SIZE),
]

var gem_overlay_atlas: Texture2D

func _ensure_gem_textures() -> bool:
	if gem_overlay_atlas == null:
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(GEM_ATLAS_PATH))
		if image != null and not image.is_empty():
			gem_overlay_atlas = ImageTexture.create_from_image(image)
	return gem_overlay_atlas != null

func _gem_variant(cell: Vector2i) -> int:
	return absi(cell.x * 17 + cell.y * 31) & 1

func _gem_cluster_size(cell: Vector2i) -> int:
	var size := 1
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if gem_blocks.has(cell + direction):
			size += 1
	return size

func _apply_gem_regions(cell: Vector2i, top_sprite: Sprite2D, front_sprite: Sprite2D) -> void:
	var variant := _gem_variant(cell)
	# The four connected cells in a motherlode read as one rich seam instead of
	# four unrelated icons. The rich cluster art is the visual anchor.
	var rich_cluster := _gem_cluster_size(cell) >= 3
	top_sprite.region_rect = GEM_TOP_REGIONS[variant]
	front_sprite.region_rect = GEM_FRONT_REGIONS[3 if rich_cluster else variant]

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

	top_sprite.texture = gem_overlay_atlas
	top_sprite.region_enabled = true
	top_sprite.offset = Vector2.ZERO
	top_sprite.scale = Vector2.ONE
	top_sprite.z_index = 5
	top_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	front_sprite.texture = gem_overlay_atlas
	front_sprite.region_enabled = true
	front_sprite.offset = Vector2.ZERO
	front_sprite.scale = Vector2.ONE
	front_sprite.z_index = 5
	front_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_gem_regions(cell, top_sprite, front_sprite)

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
	var variant := _gem_variant(cell)

	var sprites := _ensure_visual_sprites(cell)
	var top_sprite := sprites.get("top") as Sprite2D
	var front_sprite := sprites.get("front") as Sprite2D
	_apply_gem_regions(cell, top_sprite, front_sprite)
	if is_instance_valid(top_sprite):
		top_sprite.visible = show_edge
		if show_edge:
			top_sprite.global_position = block_layer.to_global(block_layer.map_to_local(cell))
			# Directional art is already present in the imported sheet, so avoid
			# rotating the asymmetric crystals and keep their highlights upright.
			top_sprite.region_rect = GEM_TOP_REGIONS[variant if top_open else (2 if left_open and not right_open else 3)]
	if is_instance_valid(front_sprite):
		_position_front_gem_sprite(front_sprite, cell)
		front_sprite.visible = show_front
