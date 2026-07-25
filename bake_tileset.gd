extends SceneTree

const FRONT_VARIANTS := {
	10: {"L": 30, "R": 31, "B": 32}, # Easy
	11: {"L": 33, "R": 34, "B": 35}, # Medium
	12: {"L": 36, "R": 37, "B": 38}, # Hard
	15: {"L": 39, "R": 40, "B": 41}, # Unmineable
	24: {"L": 42, "R": 43, "B": 44}, # Gem
}

func _init():
	print("Starting bake...")
	var packed = load("res://scenes/world/mine/level.tscn")
	var level = packed.instantiate()
	
	# We will use the existing script logic to modify the TileSet, 
	# but we will attach it to a dummy node.
	var runtime = load("res://scripts/systems/world_generation/world_terrain_runtime.gd").new()
	level.add_child(runtime)
	runtime.block_layer = level.get_node("BlockLayer")
	runtime.edge_layer = level.get_node("EdgeLayer")
	runtime._install_runtime_terrain_textures()
	
	# Now we need to save the dynamically generated textures to disk so they can be imported
	# The generated textures are in the TileSetAtlasSources for 30-44, and also the cropped ones for 10,11,12,15,24,13,14
	var ts = runtime.block_layer.tile_set
	
	# Create output dir
	DirAccess.make_dir_absolute("res://assets/sprites/world/terrain/dome/generated")
	
	# Save textures for cropped front faces
	for source_id in [10, 11, 12, 15, 24, 13, 14]:
		if ts.has_source(source_id):
			var source = ts.get_source(source_id) as TileSetAtlasSource
			if source and source.texture and source.texture is ImageTexture:
				var img = source.texture.get_image()
				var path = "res://assets/sprites/world/terrain/dome/generated/front_cropped_%d.png" % source_id
				img.save_png(path)
				
	# Save textures for variants
	for base_id in FRONT_VARIANTS.keys():
		for variant_key in FRONT_VARIANTS[base_id].keys():
			var source_id = FRONT_VARIANTS[base_id][variant_key]
			if ts.has_source(source_id):
				var source = ts.get_source(source_id) as TileSetAtlasSource
				if source and source.texture and source.texture is ImageTexture:
					var img = source.texture.get_image()
					var path = "res://assets/sprites/world/terrain/dome/generated/front_variant_%d.png" % source_id
					img.save_png(path)
					
	# Also source 21 (transparent gem block)
	if ts.has_source(21):
		var source = ts.get_source(21) as TileSetAtlasSource
		if source and source.texture and source.texture is ImageTexture:
			var img = source.texture.get_image()
			var path = "res://assets/sprites/world/terrain/dome/generated/transparent_block.png"
			img.save_png(path)

	print("Saved images. Now you must import them, assign them to the TileSet, and save the scene!")
	quit()
