extends Node

const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const CORNER_BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")
const SIZE := 14

func _sample_shifted(image: Image, x: int, y: int, dx: int, dy: int) -> Color:
	var sx := x - dx
	var sy := y - dy
	if sx < 0 or sy < 0 or sx >= SIZE or sy >= SIZE:
		return Color.TRANSPARENT
	return image.get_pixel(sx, sy)

func _ready() -> void:
	for tier in ["easy", "medium", "hard"]:
		var mass := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/dark_mass_32.png"))
		var border := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/%s_border_top_32.png" % tier))
		var edge := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % tier))
		var saved := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier))
		if mass == null or border == null or edge == null or saved == null:
			push_error("Missing source image for %s" % tier)
			continue
		for image in [mass, border, edge, saved]:
			image.convert(Image.FORMAT_RGBA8)
		var derived := CORNER_BUILDER.make_hole_corner_top_left(mass, border, edge)
		print("=== %s ===" % tier.to_upper())
		var best_score := 1e20
		var best_shift := Vector2i.ZERO
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var alpha_mismatch := 0
				var color_error := 0.0
				for y in range(SIZE):
					for x in range(SIZE):
						var a := derived.get_pixel(x, y)
						var b := _sample_shifted(saved, x, y, dx, dy)
						var a_solid := a.a > 0.05
						var b_solid := b.a > 0.05
						if a_solid != b_solid:
							alpha_mismatch += 1
						elif a_solid:
							color_error += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
				var score := float(alpha_mismatch) * 10.0 + color_error
				if score < best_score:
					best_score = score
					best_shift = Vector2i(dx, dy)
		print("best saved->derived shift=%s score=%.3f" % [str(best_shift), best_score])
		print("derived alpha mask")
		for y in range(SIZE):
			var row := ""
			for x in range(SIZE):
				row += "#" if derived.get_pixel(x, y).a > 0.05 else "."
			print("%02d %s" % [y, row])
		print("saved alpha mask")
		for y in range(SIZE):
			var row := ""
			for x in range(SIZE):
				row += "#" if saved.get_pixel(x, y).a > 0.05 else "."
			print("%02d %s" % [y, row])
	get_tree().quit()
