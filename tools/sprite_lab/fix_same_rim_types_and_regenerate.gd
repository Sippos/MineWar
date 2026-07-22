extends Node

const BUILDER_PATH := "res://tools/sprite_lab/dome_corner_builder.gd"
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const TIERS: Array[String] = ["easy", "medium", "hard"]

func _ready() -> void:
	var text: String = FileAccess.get_file_as_string(BUILDER_PATH)
	var replacements := {
		"\tvar mass := mass_image.duplicate()": "\tvar mass: Image = mass_image.duplicate()",
		"\tvar result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)": "\tvar result: Image = Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)",
		"\t\t\tvar joint_color := joint.get_pixelv(point)": "\t\t\tvar joint_color: Color = joint.get_pixelv(point)",
		"\t\t\tvar mass_color := mass.get_pixelv(point)": "\t\t\tvar mass_color: Color = mass.get_pixelv(point)",
		"\t\t\tvar color_delta := absf(joint_color.r - mass_color.r) + absf(joint_color.g - mass_color.g) + absf(joint_color.b - mass_color.b)": "\t\t\tvar color_delta: float = absf(joint_color.r - mass_color.r) + absf(joint_color.g - mass_color.g) + absf(joint_color.b - mass_color.b)",
		"\t\t\tvar touches_outside := false": "\t\t\tvar touches_outside: bool = false",
	}
	for old_text: String in replacements.keys():
		text = text.replace(old_text, String(replacements[old_text]))
	var file := FileAccess.open(BUILDER_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write typed Hole Corner builder")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()

	var builder: GDScript = load(BUILDER_PATH)
	if builder == null:
		push_error("Could not load typed Hole Corner builder")
		get_tree().quit(1)
		return
	var mass: Image = Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/dark_mass_32.png"))
	if mass == null or mass.is_empty():
		push_error("Could not load dark mass")
		get_tree().quit(1)
		return
	mass.convert(Image.FORMAT_RGBA8)

	for tier: String in TIERS:
		var border: Image = Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/%s_border_top_32.png" % tier))
		var edge: Image = Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % tier))
		if border == null or edge == null or border.is_empty() or edge.is_empty():
			push_error("Missing source art for %s" % tier)
			get_tree().quit(1)
			return
		border.convert(Image.FORMAT_RGBA8)
		edge.convert(Image.FORMAT_RGBA8)
		var hole: Image = builder.make_hole_corner_top_left(mass, border, edge)
		var save_error: Error = hole.save_png(SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier)
		if save_error != OK:
			push_error("Could not save %s Hole Corner" % tier)
			get_tree().quit(1)
			return

	var easy_hole: Image = Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/easy_hole_corner_top_left_32.png"))
	if easy_hole != null and not easy_hole.is_empty():
		easy_hole.save_png(SOURCE_DIR + "/unmineable_hole_corner_top_left_32.png")
	print("Hole Corners regenerated with the exact Edge Joint rim and opposite rock/cave sides")
	get_tree().quit()
