extends Node

const BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const TIERS: Array[String] = ["unmineable", "easy", "medium", "hard"]
const SIZE := 32

func _load_image(path: String) -> Image:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return Image.new()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
	return image

func _ready() -> void:
	var mass: Image = _load_image(SOURCE_DIR + "/dark_mass_32.png")
	if mass.is_empty():
		push_error("Could not load dark mass source")
		get_tree().quit(1)
		return
	for tier: String in TIERS:
		var border: Image = _load_image(SOURCE_DIR + "/%s_border_top_32.png" % tier)
		var joint: Image = _load_image(SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % tier)
		if border.is_empty() or joint.is_empty():
			push_error("Missing border or Edge Joint source for %s" % tier)
			get_tree().quit(1)
			return
		var hole: Image = BUILDER.make_hole_corner_top_left(mass, border, joint)
		var result: Error = hole.save_png(SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier)
		if result != OK:
			push_error("Could not save clean Hole Corner for %s: %s" % [tier, error_string(result)])
			get_tree().quit(1)
			return
	print("Regenerated four clean Hole Corners from their exact Edge Joint boundaries")
	get_tree().quit()
