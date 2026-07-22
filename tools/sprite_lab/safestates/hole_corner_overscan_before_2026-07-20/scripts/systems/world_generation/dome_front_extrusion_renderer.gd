extends Node2D

const TILE_SIZE := 64
const DEFAULT_DEPTH := 10
const ATLAS_PATHS := {
	1: "res://assets/sprites/world/terrain/dome/Easy_Border_Atlas.png",
	2: "res://assets/sprites/world/terrain/dome/Medium_Border_Atlas.png",
	3: "res://assets/sprites/world/terrain/dome/Hard_Border_Atlas.png",
	16: "res://assets/sprites/world/terrain/dome/Unmineable_Border_Atlas.png",
}
const FRONT_PATHS := {
	1: "res://assets/sprites/world/terrain/dome/Easy_Front_Face.png",
	2: "res://assets/sprites/world/terrain/dome/Medium_Front_Face.png",
	3: "res://assets/sprites/world/terrain/dome/Hard_Front_Face.png",
	16: "res://assets/sprites/world/terrain/dome/Unmineable_Front_Face.png",
}

var block_layer: TileMapLayer
var depth := DEFAULT_DEPTH
var atlas_images: Dictionary = {}
var front_images: Dictionary = {}
var sprites: Dictionary = {}

func setup(target_block_layer: TileMapLayer, extrusion_depth: int = DEFAULT_DEPTH) -> void:
	block_layer = target_block_layer
	depth = clampi(extrusion_depth, 2, 32)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_images()
	rebuild_all()

func _load_images() -> void:
	atlas_images.clear()
	front_images.clear()
	for source_id_value: Variant in ATLAS_PATHS.keys():
		var source_id := int(source_id_value)
		var atlas_path := String(ATLAS_PATHS[source_id])
		if FileAccess.file_exists(atlas_path):
			var atlas := Image.load_from_file(ProjectSettings.globalize_path(atlas_path))
			if atlas != null and not atlas.is_empty():
				atlas.convert(Image.FORMAT_RGBA8)
				atlas_images[source_id] = atlas
		var front_path := String(FRONT_PATHS[source_id])
		if FileAccess.file_exists(front_path):
			var front := Image.load_from_file(ProjectSettings.globalize_path(front_path))
			if front != null and not front.is_empty():
				front.convert(Image.FORMAT_RGBA8)
				front.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
				front_images[source_id] = front

func _canonical_source_id(raw_source_id: int) -> int:
	if raw_source_id == 1 or raw_source_id == 2 or raw_source_id == 3:
		return raw_source_id
	return 16

func _is_solid(cell: Vector2i) -> bool:
	return block_layer != null and block_layer.get_cell_source_id(cell) != -1

func _exposure_mask(cell: Vector2i) -> int:
	var mask := 0
	if not _is_solid(cell + Vector2i.UP):
		mask |= 1
	if not _is_solid(cell + Vector2i.RIGHT):
		mask |= 2
	if not _is_solid(cell + Vector2i.DOWN):
		mask |= 4
	if not _is_solid(cell + Vector2i.LEFT):
		mask |= 8
	return mask

func _sprite_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func _remove_cell(cell: Vector2i) -> void:
	var key := _sprite_key(cell)
	var sprite := sprites.get(key) as Sprite2D
	if is_instance_valid(sprite):
		sprite.queue_free()
	sprites.erase(key)

func refresh_around(cell: Vector2i) -> void:
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			_refresh_cell(cell + Vector2i(ox, oy))

func rebuild_all() -> void:
	for sprite_value: Variant in sprites.values():
		var sprite := sprite_value as Sprite2D
		if is_instance_valid(sprite):
			sprite.queue_free()
	sprites.clear()
	if block_layer == null:
		return
	var rect := block_layer.get_used_rect().grow(1)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_refresh_cell(Vector2i(x, y))

func _refresh_cell(cell: Vector2i) -> void:
	if block_layer == null:
		return
	var raw_source_id := block_layer.get_cell_source_id(cell)
	if raw_source_id == -1 or _is_solid(cell + Vector2i.DOWN):
		_remove_cell(cell)
		return
	var source_id := _canonical_source_id(raw_source_id)
	if not atlas_images.has(source_id) or not front_images.has(source_id):
		_remove_cell(cell)
		return
	var image := _build_extrusion_image(source_id, _exposure_mask(cell))
	if image == null or image.is_empty():
		_remove_cell(cell)
		return
	var key := _sprite_key(cell)
	var sprite := sprites.get(key) as Sprite2D
	if not is_instance_valid(sprite):
		sprite = Sprite2D.new()
		sprite.name = "FrontExtrusion_%d_%d" % [cell.x, cell.y]
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		sprites[key] = sprite
	sprite.texture = ImageTexture.create_from_image(image)
	var center_local := block_layer.map_to_local(cell)
	var top_left_global := block_layer.to_global(center_local - Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5))
	sprite.position = to_local(top_left_global)
	sprite.visible = true

func _build_extrusion_image(source_id: int, mask: int) -> Image:
	var atlas := atlas_images[source_id] as Image
	var front := front_images[source_id] as Image
	var atlas_position := Vector2i(mask % 4, mask / 4) * TILE_SIZE
	var tile := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	tile.fill(Color.TRANSPARENT)
	tile.blit_rect(atlas, Rect2i(atlas_position, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i.ZERO)
	var result := Image.create(TILE_SIZE, TILE_SIZE + depth, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(TILE_SIZE + depth):
		for x in range(TILE_SIZE):
			var shifted_y := y - depth
			if shifted_y < 0 or shifted_y >= TILE_SIZE:
				continue
			if tile.get_pixel(x, shifted_y).a <= 0.05:
				continue
			var original_alpha := tile.get_pixel(x, y).a if y < TILE_SIZE else 0.0
			if original_alpha > 0.05:
				continue
			var sample_y := posmod(y - TILE_SIZE, TILE_SIZE)
			var color := front.get_pixel(x, sample_y)
			var depth_ratio := float(y - TILE_SIZE + 1) / float(maxi(depth, 1))
			color = color.darkened(0.10 + depth_ratio * 0.18)
			color.a = 1.0
			result.set_pixel(x, y, color)
	return result
