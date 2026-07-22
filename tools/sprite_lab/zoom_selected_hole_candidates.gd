extends Node

const DIR := "res://tools/sprite_lab/diagnostics/exact_hole_candidates"

func _ready() -> void:
	var choices: Array[String] = [
		"origin_30_cut_10", "origin_30_cut_11", "origin_30_cut_12",
		"origin_31_cut_10", "origin_31_cut_11", "origin_31_cut_12",
		"origin_32_cut_10", "origin_32_cut_11", "origin_32_cut_12",
	]
	for stem: String in choices:
		var path := DIR + "/" + stem + ".png"
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			continue
		image.resize(1024, 1024, Image.INTERPOLATE_NEAREST)
		image.save_png(DIR + "/" + stem + "_16x.png")
	print("Enlarged selected Hole Corner candidates")
	get_tree().quit()
