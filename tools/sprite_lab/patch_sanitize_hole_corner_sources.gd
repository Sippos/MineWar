extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	var old_function := "func _load_corner_stamp(tier: String, runtime_path: String, fallback_border: Image) -> Image:\n\t# Opposite HOLE CORNER: replacement patch on the diagonal solid block.\n\tvar editable_path := SOURCE_DIR + \"/%s_hole_corner_top_left_32.png\" % tier\n\tvar corner: Image\n\tif FileAccess.file_exists(editable_path):\n\t\tcorner = Image.load_from_file(ProjectSettings.globalize_path(editable_path))\n\telse:\n\t\tcorner = CORNER_BUILDER.make_hole_corner_top_left(mass_image, fallback_border)\n\tcorner.convert(Image.FORMAT_RGBA8)\n\tcorner.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)\n\treturn corner"
	var new_function := "func _load_corner_stamp(tier: String, runtime_path: String, fallback_border: Image) -> Image:\n\t# Hole Corner is authored only inside the canonical top-left 14x14 patch.\n\t# Clearing everything outside that patch prevents floating fragments in preview/runtime.\n\tvar editable_path := SOURCE_DIR + \"/%s_hole_corner_top_left_32.png\" % tier\n\tvar source: Image\n\tif FileAccess.file_exists(editable_path):\n\t\tsource = Image.load_from_file(ProjectSettings.globalize_path(editable_path))\n\telse:\n\t\tvar joint := _load_convex_stamp(tier, fallback_border)\n\t\tsource = _make_hole_corner_from_joint(joint)\n\tsource.convert(Image.FORMAT_RGBA8)\n\tsource.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)\n\tvar clean := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)\n\tclean.fill(Color.TRANSPARENT)\n\tfor y in range(14):\n\t\tfor x in range(14):\n\t\t\tclean.set_pixel(x, y, source.get_pixel(x, y))\n\treturn clean\n\nfunc _make_hole_corner_from_joint(joint: Image) -> Image:\n\tvar result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)\n\tresult.fill(Color.TRANSPARENT)\n\tfor y in range(14):\n\t\tfor x in range(14):\n\t\t\tresult.set_pixel(13 - x, 13 - y, joint.get_pixel(x, y))\n\treturn result"
	if not text.contains(old_function):
		push_error("Could not find Hole Corner loader to sanitize")
		get_tree().quit(1)
		return
	text = text.replace(old_function, new_function)
	text = text.replace(
		"New Hole Corners start as the Edge Joint rotated 180 degrees.",
		"Hole Corners start from the exact 14x14 Edge Joint patch rotated 180 degrees, then remain independently editable."
	)
	var file := FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write sanitized Hole Corner workflow")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Hole Corner sources sanitized to one canonical 14x14 patch")
	get_tree().quit()
