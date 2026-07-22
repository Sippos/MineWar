extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	if text.is_empty():
		push_error("Could not read Dome workbench")
		get_tree().quit(1)
		return

	text = text.replace(
		"subtitle.text = \"ONE universal dark mass  +  FOUR border tiers: Unmineable / Easy / Medium / Hard\"",
		"subtitle.text = \"NORMAL TILING: one dark mass + straight borders + edge joints + concave connectors\""
	)
	text = text.replace(
		"_add_mode_button(controls, \"convex\", \"CONVEX CORNER • one top-left cutout\")",
		"_add_mode_button(controls, \"convex\", \"EDGE JOINT • one top-left turn\")"
	)
	text = text.replace(
		"Each material has one straight border, one outward CONVEX cutout and one inward CONCAVE connector. UNMINEABLE starts from the exact Easy artwork.",
		"Each material has one straight border, one EDGE JOINT where two borders meet, and one inward CONCAVE connector. UNMINEABLE starts from the exact Easy artwork."
	)
	text = text.replace("rounded_toggle.text = \"Use convex corner sprites\"", "rounded_toggle.text = \"Use edge joints\"")
	text = text.replace("rounded_toggle.text = \"Rounded light corners\"", "rounded_toggle.text = \"Use edge joints\"")

	var lip_block := "\tvar lip_toggle := CheckBox.new()\n\tlip_toggle.text = \"Rock lip outside cell\"\n\tlip_toggle.button_pressed = true\n\tlip_toggle.toggled.connect(func(value: bool) -> void: preview.call(\"set_rock_lip_outside_cell\", value))\n\tcontrols.add_child(lip_toggle)\n"
	text = text.replace(lip_block, "")
	text = text.replace("export_button.text = \"EXPORT BORDERS + CORNERS\"", "export_button.text = \"EXPORT NORMAL TILING\"")

	var old_loader := "func _load_convex_stamp(tier: String, fallback_border: Image) -> Image:\n\tvar editable_path := SOURCE_DIR + \"/%s_convex_top_left_32.png\" % tier\n\tvar convex: Image\n\tif FileAccess.file_exists(editable_path):\n\t\tconvex = Image.load_from_file(ProjectSettings.globalize_path(editable_path))\n\telse:\n\t\tconvex = CORNER_BUILDER.make_convex_corner_top_left(mass_image, fallback_border)\n\tconvex.convert(Image.FORMAT_RGBA8)\n\tconvex.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)\n\treturn convex"
	var new_loader := "func _load_convex_stamp(tier: String, fallback_border: Image) -> Image:\n\t# Internal name kept for scene compatibility; this is the authored EDGE JOINT.\n\tvar editable_path := SOURCE_DIR + \"/%s_edge_joint_top_left_32.png\" % tier\n\tvar joint: Image\n\tif FileAccess.file_exists(editable_path):\n\t\tjoint = Image.load_from_file(ProjectSettings.globalize_path(editable_path))\n\telse:\n\t\tjoint = CORNER_BUILDER.make_edge_joint_top_left(mass_image, fallback_border)\n\tjoint.convert(Image.FORMAT_RGBA8)\n\tjoint.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)\n\treturn joint"
	if text.contains(old_loader):
		text = text.replace(old_loader, new_loader)

	text = text.replace(
		"return \"%s CONVEX CORNER • AUTHOR TOP-LEFT ONLY\" % current_tier.to_upper()",
		"return \"%s EDGE JOINT • AUTHOR TOP-LEFT ONLY\" % current_tier.to_upper()"
	)
	text = text.replace(
		"instruction_label.text = \"Paint the TOP-LEFT outward rounded cutout. Transparent pixels carve the cave; painted pixels contain the complete rock rim and mass for this corner.\"",
		"instruction_label.text = \"Paint one TOP-LEFT EDGE JOINT where the top and left straight borders meet. Transparent pixels shape the cave; painted pixels must connect both border strips cleanly.\""
	)
	text = text.replace(
		"result = (convex_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_convex_top_left_32.png\" % tier)",
		"result = (convex_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_edge_joint_top_left_32.png\" % tier)"
	)
	text = text.replace(
		"Saved one mass, four borders, four convex corners and four concave corners.",
		"Saved one mass, four borders, four edge joints and four concave connectors."
	)
	text = text.replace(
		"Exported normal border atlases with authored convex and concave corner sprites.",
		"Exported normal tiling: dark mass, borders, edge joints and concave connectors."
	)

	var file := FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write edge-joint workbench patch")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Edge-joint workflow installed")
	get_tree().quit()
