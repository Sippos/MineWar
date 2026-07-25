extends SceneTree

func get_image_texture(path: String) -> ImageTexture:
	var img = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img:
		return ImageTexture.create_from_image(img)
	print("Failed to load image: ", path)
	return null

func _init():
	var packed = load("res://scenes/world/mine/level.tscn")
	var level = packed.instantiate()
	
	var block_layer = level.get_node("BlockLayer")
	var ts = block_layer.tile_set
	
	# Make 1, 2, 3 transparent
	var trans_tex = get_image_texture("res://assets/sprites/world/terrain/dome/generated/transparent_block.png")
	for id in [1, 2, 3]:
		if ts.has_source(id):
			var s = ts.get_source(id)
			s.texture = trans_tex

	# 1. Update COMPOSITE_ATLAS_PATHS
	var composite = {
		4: "res://assets/sprites/world/terrain/dome/Easy_Border_Atlas.png",
		5: "res://assets/sprites/world/terrain/dome/Medium_Border_Atlas.png",
		6: "res://assets/sprites/world/terrain/dome/Hard_Border_Atlas.png",
		17: "res://assets/sprites/world/terrain/dome/Unmineable_Border_Atlas.png",
		22: "res://assets/sprites/world/terrain/dome/Gems_Border_Atlas_TONED.png", # Added 22
	}
	for id in composite:
		if not ts.has_source(id):
			ts.add_source(TileSetAtlasSource.new(), id)
		var s = ts.get_source(id)
		s.texture = load(composite[id])
		s.texture_region_size = Vector2i(64, 64)
		for y in range(4):
			for x in range(4):
				if not s.has_tile(Vector2i(x,y)):
					s.create_tile(Vector2i(x,y))
		
	# 2. Update INSIDE_CORNER_PATHS
	var inside = {
		25: "res://assets/sprites/world/terrain/dome/Easy_Inside_Corners_CLEAN.png",
		26: "res://assets/sprites/world/terrain/dome/Medium_Inside_Corners.png",
		27: "res://assets/sprites/world/terrain/dome/Hard_Inside_Corners.png",
		28: "res://assets/sprites/world/terrain/dome/Unmineable_Inside_Corners.png",
		29: "res://assets/sprites/world/terrain/dome/Gems_Inside_Corners.png",
	}
	for id in inside:
		if not ts.has_source(id):
			ts.add_source(TileSetAtlasSource.new(), id)
		var s = ts.get_source(id)
		s.texture = load(inside[id])
		s.texture_region_size = Vector2i(64, 64) # FIXED: WAS 128
		for y in range(2):
			for x in range(2):
				if not s.has_tile(Vector2i(x,y)):
					s.create_tile(Vector2i(x,y))
				var t = s.get_tile_data(Vector2i(x,y), 0)
				if t:
					if x == 0 and y == 0: t.texture_origin = Vector2i(32, 32)
					elif x == 1 and y == 0: t.texture_origin = Vector2i(-32, 32)
					elif x == 0 and y == 1: t.texture_origin = Vector2i(-32, -32)
					elif x == 1 and y == 1: t.texture_origin = Vector2i(32, -32)

	# 3. Update OTHER_TEXTURE_PATHS
	var others = {
		0: "res://assets/sprites/world/terrain/cave_floor_tile.svg",
		7: "res://assets/sprites/world/terrain/damage/First_Hitting_Rework.svg",
		8: "res://assets/sprites/world/terrain/damage/Second_Hitting_Rework.svg",
		16: "res://assets/sprites/world/terrain/dome/Dome_Dark_Mass.png"
	}
	for id in others:
		if not ts.has_source(id):
			ts.add_source(TileSetAtlasSource.new(), id)
		var s = ts.get_source(id)
		s.texture = load(others[id])
		s.texture_region_size = Vector2i(64, 64)
		if not s.has_tile(Vector2i(0,0)):
			s.create_tile(Vector2i(0,0))
			
	# Add collisions for 16
	var s16 = ts.get_source(16)
	var t16 = s16.get_tile_data(Vector2i(0,0), 0)
	if t16 and ts.get_physics_layers_count() > 0:
		if t16.get_collision_polygons_count(0) == 0:
			t16.add_collision_polygon(0)
		t16.set_collision_polygon_points(0, 0, [Vector2(-32, -32), Vector2(32, -32), Vector2(32, 32), Vector2(-32, 32)])

	if not ts.has_source(21):
		ts.add_source(TileSetAtlasSource.new(), 21)
	var s21 = ts.get_source(21)
	s21.texture = trans_tex
	s21.texture_region_size = Vector2i(64, 64)
	if not s21.has_tile(Vector2i(0,0)):
		s21.create_tile(Vector2i(0,0))
	var t21 = s21.get_tile_data(Vector2i(0,0), 0)
	if t21 and ts.get_physics_layers_count() > 0:
		if t21.get_collision_polygons_count(0) == 0:
			t21.add_collision_polygon(0)
		t21.set_collision_polygon_points(0, 0, [Vector2(-32, -32), Vector2(32, -32), Vector2(32, 32), Vector2(-32, 32)])

	# 4. Front faces cropped
	var front_cropped = [10, 11, 12, 15, 24, 13, 14]
	for id in front_cropped:
		if not ts.has_source(id):
			ts.add_source(TileSetAtlasSource.new(), id)
		var s = ts.get_source(id)
		s.texture = get_image_texture("res://assets/sprites/world/terrain/dome/generated/front_cropped_%d.png" % id)
		s.texture_region_size = Vector2i(64, 26)
		if not s.has_tile(Vector2i(0,0)):
			s.create_tile(Vector2i(0,0))
		var t = s.get_tile_data(Vector2i(0,0), 0)
		if t:
			t.y_sort_origin = -32
			t.texture_origin = Vector2i(0, 32 - 13)

	# 5. Front variants
	var front_vars = [30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44]
	for id in front_vars:
		if not ts.has_source(id):
			ts.add_source(TileSetAtlasSource.new(), id)
		var s = ts.get_source(id)
		s.texture = get_image_texture("res://assets/sprites/world/terrain/dome/generated/front_variant_%d.png" % id)
		s.texture_region_size = Vector2i(64, 26)
		if not s.has_tile(Vector2i(0,0)):
			s.create_tile(Vector2i(0,0))
		var t = s.get_tile_data(Vector2i(0,0), 0)
		if t:
			t.y_sort_origin = -32
			t.texture_origin = Vector2i(0, 32 - 13)
			
	var ps = PackedScene.new()
	ps.pack(level)
	ResourceSaver.save(ps, "res://scenes/world/mine/level.tscn")
	print("Baked level.tscn successfully (V3).")
	quit()
