extends "res://scripts/systems/world_generation/world.gd"

## Runtime terrain contract:
## - BlockLayer keeps source IDs 1/2/3 for hardness and collision, but its art is
##   transparent.
## - EdgeLayer renders the complete visual cell: universal mass + tier border +
##   genuine transparent quarter-circle cutouts.
## - Source 16 is the same composite system for the unmineable boundary.

const TEXTURE_FACTORY = preload("res://scripts/systems/preparation/gem_indicator_texture_factory.gd")
const TILE_SIZE := 64
## Height of the shallow front-wall strip. The full 64px face art is SCALED (not
## cropped) down into this height, and sat flush to the top of the below-cell. Raise
## it to make the front face read taller/less pill-like; keep it even for clean math.
## Keep in sync with FRONT_FACE_HEIGHT in crack_overlay_manager.gd.
const FRONT_FACE_HEIGHT := 34
const COMPOSITE_ATLAS_PATHS := {
	4: "res://assets/sprites/world/terrain/dome/Easy_Border_Atlas.png",
	5: "res://assets/sprites/world/terrain/dome/Medium_Border_Atlas.png",
	6: "res://assets/sprites/world/terrain/dome/Hard_Border_Atlas.png",
	17: "res://assets/sprites/world/terrain/dome/Unmineable_Border_Atlas.png",
	# Gem border = rock (Easy) mass+rim base with muted crystals INSET in the interior
	# (off the edges, so no overshoot) - reads as an embedded inclusion like Dome
	# Keeper resources, not neon blobs. Regenerate from Gems_Border_Atlas.png +
	# Easy_Border_Atlas.png if art changes. Swap back to Gems_Border_Atlas.png to undo.
	22: "res://assets/sprites/world/terrain/dome/Gems_Border_Atlas_TONED.png",
}
const OTHER_TEXTURE_PATHS := {
	0: "res://assets/sprites/world/terrain/cave_floor_tile.svg",
	7: "res://assets/sprites/world/terrain/damage/First_Hitting_Rework.svg",
	8: "res://assets/sprites/world/terrain/damage/Second_Hitting_Rework.svg",
	10: "res://assets/sprites/world/terrain/dome/Easy_Front_Face.png",
	11: "res://assets/sprites/world/terrain/dome/Medium_Front_Face.png",
	12: "res://assets/sprites/world/terrain/dome/Hard_Front_Face.png",
	15: "res://assets/sprites/world/terrain/dome/Unmineable_Front_Face.png",
	13: "res://assets/sprites/world/terrain/front_damage/First-Hit-Front-Rework.svg",
	14: "res://assets/sprites/world/terrain/front_damage/Next-Hit-Front-Rework.svg",
	24: "res://assets/sprites/world/terrain/dome/Gems_Front_Face_TONED.png",  # muted inset gem, rock-face base
}
const INSIDE_CORNER_PATHS := {
	# Source 25 is the SHARED rock corner (Easy/Medium/Hard all map here). This CLEAN
	# sheet is RIM-ONLY: just the rounded light rim arc on a TRANSPARENT centre, no
	# dark mass and no decorative speckle. The mass/fill comes from the EdgeLayer
	# border frames underneath; the corner only adds the rounded rim on top (z=3).
	# This avoids both the 50/50 speckle seam AND the dark-mass filling/overlapping
	# tunnel-end caps. Do NOT re-add mass here - it made caps read wrong.
	25: "res://assets/sprites/world/terrain/dome/Easy_Inside_Corners_CLEAN.png",
	26: "res://assets/sprites/world/terrain/dome/Medium_Inside_Corners.png",
	27: "res://assets/sprites/world/terrain/dome/Hard_Inside_Corners.png",
	28: "res://assets/sprites/world/terrain/dome/Unmineable_Inside_Corners.png",
	29: "res://assets/sprites/world/terrain/dome/Gems_Inside_Corners.png",
}
const GROUND_BACKDROP_PATH := "res://assets/sprites/world/terrain/cave_floor_tile.svg"

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
	
	if not tile_set_resource.has_source(21):
		var gem_block_source := TileSetAtlasSource.new()
		tile_set_resource.add_source(gem_block_source, 21)
		gem_block_source.texture = transparent_texture
		gem_block_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		gem_block_source.create_tile(Vector2i(0, 0))
		_add_full_collision(gem_block_source, Vector2i(0, 0))

	for source_id in [1, 2, 3, 16, 21]:
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

	for source_id_value: Variant in INSIDE_CORNER_PATHS.keys():
		var source_id := int(source_id_value)
		var texture := _load_runtime_texture(String(INSIDE_CORNER_PATHS[source_id]))
		if texture == null:
			continue
		# An inside-corner sheet must be at least a 2x2 grid of double-size tiles.
		# A mis-exported/cropped atlas (e.g. a manual crop to 194x188) leaves the
		# lower/right tiles off the texture, so create_tile() silently fails and
		# get_tile_data() returns null. Validate up front and skip loudly instead
		# of crashing the whole level on a null texture_origin assignment.
		var required_size := Vector2i(TILE_SIZE * 2 * 2, TILE_SIZE * 2 * 2)
		if texture.get_width() < required_size.x or texture.get_height() < required_size.y:
			push_warning("Inside-corner atlas %d is %dx%d; needs %dx%d (2x2 of %dpx). Skipping." % [
				source_id, texture.get_width(), texture.get_height(),
				required_size.x, required_size.y, TILE_SIZE * 2])
			continue
		var source := _ensure_composite_source(tile_set_resource, source_id)
		source.texture = texture
		source.texture_region_size = Vector2i(TILE_SIZE * 2, TILE_SIZE * 2)
		for atlas_y in range(2):
			for atlas_x in range(2):
				var atlas_coords := Vector2i(atlas_x, atlas_y)
				if not source.has_tile(atlas_coords):
					source.create_tile(atlas_coords)
				var tile_data = source.get_tile_data(atlas_coords, 0)
				if tile_data == null:
					continue
				if atlas_coords == Vector2i(0, 0): tile_data.texture_origin = Vector2i(32, 32)
				elif atlas_coords == Vector2i(1, 0): tile_data.texture_origin = Vector2i(-32, 32)
				elif atlas_coords == Vector2i(0, 1): tile_data.texture_origin = Vector2i(-32, -32)
				elif atlas_coords == Vector2i(1, 1): tile_data.texture_origin = Vector2i(32, -32)

	for source_id_value: Variant in OTHER_TEXTURE_PATHS.keys():
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
			var atlas_coords := Vector2i(0, 0)
			# Front-face tiles (10/11/12/15 tiers + 24 gems) and the front-damage
			# cracks (13/14) are the shallow wall strip. SCALE the whole 64px face
			# down into FRONT_FACE_HEIGHT (not crop, so the full designed face shows),
			# then sit it flush to the top of the below-cell (origin.y = 32 - h/2).
			if source_id in [10, 11, 12, 15, 24, 13, 14]:
				var face_img := texture.get_image()
				face_img.resize(TILE_SIZE, FRONT_FACE_HEIGHT, Image.INTERPOLATE_NEAREST)
				source.texture = ImageTexture.create_from_image(face_img)
				source.texture_region_size = Vector2i(TILE_SIZE, FRONT_FACE_HEIGHT)
				if not source.has_tile(atlas_coords):
					source.create_tile(atlas_coords)
				var tile_data = source.get_tile_data(atlas_coords, 0)
				tile_data.y_sort_origin = -32
				tile_data.texture_origin = Vector2i(0, 32 - FRONT_FACE_HEIGHT / 2)
			else:
				source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
				if not source.has_tile(atlas_coords):
					source.create_tile(atlas_coords)

	_install_front_wall_variants(tile_set_resource)

	var ground_backdrop := get_node_or_null("GroundBackdrop") as TextureRect
	if ground_backdrop:
		var backdrop_texture := _load_runtime_texture(GROUND_BACKDROP_PATH)
		if backdrop_texture != null:
			ground_backdrop.texture = backdrop_texture

# Build the rounded-end front-wall variants from each base front face. A ledge END
# rounds its bottom corner (L/R/both) so it meets the tunnel rim instead of leaving
# a square notch; straight runs keep the base square strip. See FRONT_VARIANTS.
const FRONT_CORNER_RADIUS := 13

func _install_front_wall_variants(tile_set_resource: TileSet) -> void:
	for base_id_value: Variant in FRONT_VARIANTS.keys():
		var base_id := int(base_id_value)
		if not tile_set_resource.has_source(base_id):
			continue
		var base_source := tile_set_resource.get_source(base_id) as TileSetAtlasSource
		if base_source == null or base_source.texture == null:
			continue
		var base_image := base_source.texture.get_image()
		if base_image == null:
			continue
		var variants: Dictionary = FRONT_VARIANTS[base_id]
		_make_front_variant_source(tile_set_resource, int(variants["L"]), base_image, true, false)
		_make_front_variant_source(tile_set_resource, int(variants["R"]), base_image, false, true)
		_make_front_variant_source(tile_set_resource, int(variants["B"]), base_image, true, true)

func _make_front_variant_source(tile_set_resource: TileSet, source_id: int, base_image: Image, round_left: bool, round_right: bool) -> void:
	# base_image is already the scaled FRONT_FACE_HEIGHT strip. Carve only the
	# requested BOTTOM corner(s) into a quarter-circle so a ledge END curves up to the
	# tunnel rim; the top is never touched (so it never looks like a rounded square).
	var strip: Image = base_image.duplicate()
	strip.convert(Image.FORMAT_RGBA8)
	var radius := FRONT_CORNER_RADIUS
	var strip_height := strip.get_height()
	for y in range(strip_height):
		for x in range(TILE_SIZE):
			var carve := false
			if round_left and x < radius and y > strip_height - radius:
				if (x - radius) * (x - radius) + (y - (strip_height - radius)) * (y - (strip_height - radius)) > radius * radius:
					carve = true
			if round_right and x >= TILE_SIZE - radius and y > strip_height - radius:
				var rx := x - (TILE_SIZE - radius)
				if rx * rx + (y - (strip_height - radius)) * (y - (strip_height - radius)) > radius * radius:
					carve = true
			if carve:
				strip.set_pixel(x, y, Color(0, 0, 0, 0))
	var texture := ImageTexture.create_from_image(strip)
	var source: TileSetAtlasSource
	if tile_set_resource.has_source(source_id):
		source = tile_set_resource.get_source(source_id) as TileSetAtlasSource
	else:
		source = TileSetAtlasSource.new()
		tile_set_resource.add_source(source, source_id)
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, strip_height)
	if not source.has_tile(Vector2i(0, 0)):
		source.create_tile(Vector2i(0, 0))
	var tile_data := source.get_tile_data(Vector2i(0, 0), 0)
	if tile_data != null:
		tile_data.y_sort_origin = -32
		tile_data.texture_origin = Vector2i(0, 32 - strip_height / 2)

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
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		push_warning("Runtime terrain texture is missing: %s" % path)
		return null
	var tex = load(path)
	if tex == null:
		push_warning("Runtime terrain texture could not be loaded: %s" % path)
		return null
	var image: Image
	if tex is Texture2D:
		image = tex.get_image()
	if image == null or image.is_empty():
		push_warning("Runtime terrain texture could not be decoded: %s" % path)
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(image)
