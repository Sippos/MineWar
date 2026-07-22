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
	super._ready()

func _install_runtime_terrain_textures() -> void:
	pass # TileSet is now statically baked into level.tscn for HTML5 compatibility
	return

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
