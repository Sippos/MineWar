extends Node

const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const KINDS: Array[String] = ["border_top_32", "edge_joint_top_left_32", "hole_corner_top_left_32"]
const TARGETS: Array[String] = ["medium", "hard", "unmineable"]

func _ready() -> void:
	var easy_colors: Dictionary = {}
	for kind in KINDS:
		_collect_colors(_path("easy", kind), easy_colors)
	if easy_colors.is_empty():
		push_error("Easy palette is empty")
		get_tree().quit(1)
		return
	for tier in TARGETS:
		for kind in KINDS:
			var foreign := _foreign_colors(_path(tier, kind), easy_colors)
			if not foreign.is_empty():
				push_error("%s %s has colors outside Easy palette: %s" % [tier, kind, foreign])
				get_tree().quit(1)
				return
	print("Verified: Medium, Hard and Unmineable use only the Easy palette")
	get_tree().quit()

func _path(tier: String, kind: String) -> String:
	return SOURCE_DIR + "/%s_%s.png" % [tier, kind]

func _load(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image

func _collect_colors(path: String, output: Dictionary) -> void:
	var image := _load(path)
	if image == null:
		return
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a > 0.05:
				output[_key(color)] = true

func _foreign_colors(path: String, allowed: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}
	var image := _load(path)
	if image == null:
		result.append("missing")
		return result
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.05:
				continue
			var key := _key(color)
			if not allowed.has(key) and not seen.has(key):
				seen[key] = true
				result.append(key)
	return result

func _key(color: Color) -> String:
	return "%02x%02x%02x%02x" % [
		clampi(roundi(color.r * 255.0), 0, 255),
		clampi(roundi(color.g * 255.0), 0, 255),
		clampi(roundi(color.b * 255.0), 0, 255),
		clampi(roundi(color.a * 255.0), 0, 255),
	]
