extends Node

const DIR := "res://tools/sprite_lab/diagnostics/exact_hole_candidates"

func _ready() -> void:
	for cut in [10, 11, 12, 13, 14]:
		var path := DIR + "/origin_31_cut_%d.png" % cut
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		image.resize(1024, 1024, Image.INTERPOLATE_NEAREST)
		image.save_png(DIR + "/origin_31_cut_%d_16x.png" % cut)
	print("Enlarged native-origin Hole Corner mask candidates")
	get_tree().quit()
