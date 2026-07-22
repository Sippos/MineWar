extends Node

const LOGICAL_SIZE := 32
const TILE_SIZE := 64
const ATLAS_SIZE := 256
const OUTPUT_DIR := "res://assets/sprites/world/terrain/dome"
const MASS_SOURCE := "res://assets/sprites/world/terrain/bricks/Easy_Brick_Rework.svg"
const BEDROCK_SOURCE := "res://assets/sprites/world/terrain/bricks/Bedrock_Border.svg"
const EDGE_SOURCES := {
	"easy": "res://assets/sprites/world/terrain/edges/Easy_Edge_Atlas_Rework.svg",
	"medium": "res://assets/sprites/world/terrain/edges/Medium_Edge_Atlas_Rework.svg",
	"hard": "res://assets/sprites/world/terrain/edges/Hard_Edge_Atlas_Rework.svg"
}

func _ready() -> void:
	var directory_result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if directory_result != OK and directory_result != ERR_ALREADY_EXISTS:
		push_error("Could not create dome terrain directory: %s" % error_string(directory_result))
		get_tree().quit(1)
		return
	var mass := _load_svg(MASS_SOURCE)
	mass.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
	var result: Error = mass.save_png(OUTPUT_DIR + "/Dome_Dark_Mass.png")
	var bedrock := _load_svg(BEDROCK_SOURCE)
	bedrock.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
	if result == OK:
		result = bedrock.save_png(OUTPUT_DIR + "/Bedrock_Border.png")
	for tier_value: Variant in EDGE_SOURCES.keys():
		if result != OK:
			break
		var tier := String(tier_value)
		var atlas_source := _load_svg(String(EDGE_SOURCES[tier]))
		var stamp := _extract_top_stamp(atlas_source)
		var atlas := _build_atlas(stamp)
		result = atlas.save_png(OUTPUT_DIR + "/%s_Border_Atlas.png" % tier.capitalize())
	if result != OK:
		push_error("Could not initialize dome runtime assets: %s" % error_string(result))
		get_tree().quit(1)
		return
	print("Initialized universal mass, bedrock and rotated border atlases")
	get_tree().quit()

func _load_svg(path: String) -> Image:
	var image := Image.new()
	var svg_text := FileAccess.get_file_as_string(path)
	var result: Error = image.load_svg_from_string(svg_text, 1.0) if not svg_text.is_empty() else ERR_FILE_NOT_FOUND
	if result != OK or image.is_empty():
		image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
	image.convert(Image.FORMAT_RGBA8)
	return image

func _extract_top_stamp(atlas: Image) -> Image:
	var stamp := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	stamp.fill(Color.TRANSPARENT)
	stamp.blit_rect(atlas, Rect2i(Vector2i(TILE_SIZE, 0), Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i.ZERO)
	stamp.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return stamp

func _build_atlas(top_stamp: Image) -> Image:
	var directions: Array[Image] = []
	for turn in range(4):
		directions.append(_rotate_quarters(top_stamp, turn))
	var atlas := Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for mask in range(16):
		var tile := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
		tile.fill(Color.TRANSPARENT)
		for direction_index in range(4):
			if (mask & (1 << direction_index)) != 0:
				tile.blend_rect(directions[direction_index], Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE)), Vector2i.ZERO)
		tile.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(tile, Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i(mask % 4, mask / 4) * TILE_SIZE)
	return atlas

func _rotate_quarters(source: Image, turns: int) -> Image:
	var normalized_turns: int = posmod(turns, 4)
	var result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(LOGICAL_SIZE):
		for x in range(LOGICAL_SIZE):
			var destination := Vector2i(x, y)
			match normalized_turns:
				1:
					destination = Vector2i(LOGICAL_SIZE - 1 - y, x)
				2:
					destination = Vector2i(LOGICAL_SIZE - 1 - x, LOGICAL_SIZE - 1 - y)
				3:
					destination = Vector2i(y, LOGICAL_SIZE - 1 - x)
			result.set_pixelv(destination, source.get_pixel(x, y))
	return result
