extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	text = text.replace(
		"_add_mode_button(controls, \"corner\", \"HOLE CORNER • opposite turn\")",
		"_add_mode_button(controls, \"corner\", \"HOLE CORNER • one sprite, rotated 4 ways\")"
	)
	text = text.replace(
		"Each material has one straight border, one EDGE JOINT and one editable HOLE CORNER. Hole Corners start from the exact 14x14 Edge Joint patch rotated 180 degrees, then remain independently editable.",
		"Each material has one straight border, one EDGE JOINT and one HOLE CORNER source. Paint the Hole Corner once; preview and export rotate that same sprite into all four directions automatically."
	)
	text = text.replace(
		"return \"%s HOLE CORNER • AUTHOR TOP-LEFT OPPOSITE TURN\" % current_tier.to_upper()",
		"return \"%s HOLE CORNER • ONE SOURCE, AUTO-ROTATED 4 WAYS\" % current_tier.to_upper()"
	)
	text = text.replace(
		"instruction_label.text = \"Paint the TOP-LEFT opposite HOLE CORNER on the diagonal solid block. It must carve the corner and connect the two neighbouring border endpoints.\"",
		"instruction_label.text = \"Paint this single HOLE CORNER source. The live cave and exported atlas rotate it automatically for top-left, top-right, bottom-right and bottom-left.\""
	)
	var file := FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not update Hole Corner auto-rotation UI")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Hole Corner UI now clearly exposes one source auto-rotated four ways")
	get_tree().quit()
