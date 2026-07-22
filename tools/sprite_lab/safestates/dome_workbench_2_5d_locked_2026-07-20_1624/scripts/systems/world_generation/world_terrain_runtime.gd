extends "res://scripts/systems/world_generation/world.gd"

## Runtime terrain contract:
## - BlockLayer keeps source IDs 1/2/3 for hardness and collision, but its art is
##   transparent.
## - EdgeLayer renders the complete visual cell: universal mass + tier border +
##   genuine transparent quarter-circle cutouts.
## - Source 16 is the same composite system for the unmineable boundary.

const TEXTURE_FACTORY = preload("res://scripts/systems/preparation/gem_indicator_texture_factory.gd")
const TILE_SIZE := 64
const COMPOSITE_ATLAS_PATHS := {
	4: "res://assets/sprites/world/terrain/dome/Easy_Border_Atlas.png",
	5: "res://assets/sprites/world/terrain/dome/Medium_Border_Atlas.png",
	6: "res://assets/sprites/world/terrain/dome/Hard_Border_Atlas.png",
	16: "res://assets/sprites/world/terrain/dome/Unmineable_Border_Atlas.png",
}
const OTHER_TEXTURE_PATHS := {
	0: "res://assets/sprites/world/terrain/cave_floor_tile.svg",
	7: "res://assets/sprites/world/terrain/damage/First_Hitting_Rework.svg",
	8: "res://assets/sprites/world/terrain/damage/Second_Hitting_Rework.svg",
	10: "res://assets/sprites/world/terrain/front_walls/Easy_Brick-Front-Rework.svg",
	11: "res://assets/sprites/world/terrain/front_walls/Medium-Brick-Front-Rework.svg",
	12: "res://assets/sprites/world/terrain/front_walls/Hard-Brick-Front-Rework.svg",
	13: "res://assets/sprites/world/terrain/front_damage/First-Hit-Front-Rework.svg",
	14: "res://assets/sprites/world/terrain/front_damage/Next-Hit-Front-Rework.svg",
}
const GROUND_BACKDROP_PATH := "res://assets/environment/ground/blue_mine_ground.svg"

func _ready() -> void:
	_install_runtime_terrain_textures()
	super._ready()

func _install_runtime_terrain_textures() -> void:
	var tile_set_resource := block_layer.tile_set
	if tile_set_resource == null:
		push_error("Mine terrain TileSet is missing.")
		return

	# Collision/hardness cells must not remain visible below the transparent
	# rounded composite tiles, otherwise every cutout reveals a square block.
	var transparent_image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	transparent_image.fill(Color.TRANSPARENT)
	var transparent_texture := ImageTexture.create_from_image(transparent_image)
	for source_id in [1, 2, 3]:
		if tile_set_resource.has_source(source_id):
			var collision_source := tile_set_resource.get_source(source_id) as TileSetAtlasSource
			if collision_source != null:
				collision_source.texture = transparent_texture

	for source_id_value: Variant in COMPOSITE_ATLAS_PATHS.keys():
		var source_id := int(source_id_value)
		var texture := _load_runtime_texture(String(COMPOSITE_ATLAS_PATHS[source_id]))
		if texture == null:
			continue
		var source := _ensure_composite_source(tile_set_resource, source_id)
		source.texture = texture
		source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		for atlas_y in range(4):
			for atlas_x in range(4):
				var atlas_coords := Vector2i(atlas_x, atlas_y)
				if not source.has_tile(atlas_coords):
					source.create_tile(atlas_coords)
				if source_id == 16:
					_add_full_collision(source, atlas_coords)

	for source_id_value: Variant in OTHER_TEXTURE_PATHS.keys():
		var source_id := int(source_id_value)
		if not tile_set_resource.has_source(source_id):
			continue
		var source := tile_set_resource.get_source(source_id) as TileSetAtlasSource
		if source == null:
			continue
		var texture := _load_runtime_texture(String(OTHER_TEXTURE_PATHS[source_id]))
		if texture != null:
			source.texture = texture

	var ground_backdrop := get_node_or_null("GroundBackdrop") as TextureRect
	if ground_backdrop:
		var backdrop_texture := _load_runtime_texture(GROUND_BACKDROP_PATH)
		if backdrop_texture != null:
			ground_backdrop.texture = backdrop_texture

func _ensure_composite_source(tile_set_resource: TileSet, source_id: int) -> TileSetAtlasSource:
	if tile_set_resource.has_source(source_id):
		var existing := tile_set_resource.get_source(source_id) as TileSetAtlasSource
		if existing != null:
			return existing
	var source := TileSetAtlasSource.new()
	tile_set_resource.add_source(source, source_id)
	return source

func _add_full_collision(source: TileSetAtlasSource, atlas_coords: Vector2i) -> void:
	var tile_data := source.get_tile_data(atlas_coords, 0)
	if tile_data == null:
		return
	tile_data.set_collision_polygons_count(0, 1)
	tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-32, -32), Vector2(32, -32), Vector2(32, 32), Vector2(-32, 32)
	]))

func _load_runtime_texture(path: String) -> Texture2D:
	if path.get_extension().to_lower() == "svg":
		return TEXTURE_FACTORY.load_svg_texture(path)
	if not FileAccess.file_exists(path):
		push_warning("Runtime terrain texture is missing: %s" % path)
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		push_warning("Runtime terrain texture could not be decoded: %s" % path)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(image)
