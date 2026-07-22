with open('scripts/systems/world_generation/world_terrain_runtime.gd', 'r') as f:
    content = f.read()

content = content.replace(
"""	for source_id_value: Variant in OTHER_TEXTURE_PATHS.keys():
		var source_id := int(source_id_value)
		if not tile_set_resource.has_source(source_id):
			continue
		var source := tile_set_resource.get_source(source_id) as TileSetAtlasSource
		if source == null:
			continue
		var texture := _load_runtime_texture(String(OTHER_TEXTURE_PATHS[source_id]))
		if texture != null:
			source.texture = texture""",
"""	for source_id_value: Variant in OTHER_TEXTURE_PATHS.keys():
		var source_id := int(source_id_value)
		var texture := _load_runtime_texture(String(OTHER_TEXTURE_PATHS[source_id]))
		if texture == null:
			continue
		var source: TileSetAtlasSource
		if tile_set_resource.has_source(source_id):
			source = tile_set_resource.get_source(source_id) as TileSetAtlasSource
		else:
			source = TileSetAtlasSource.new()
			tile_set_resource.add_source(source, source_id)
		
		if source != null:
			source.texture = texture
			source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
			var atlas_coords := Vector2i(0, 0)
			if not source.has_tile(atlas_coords):
				source.create_tile(atlas_coords)"""
)

with open('scripts/systems/world_generation/world_terrain_runtime.gd', 'w') as f:
    f.write(content)
