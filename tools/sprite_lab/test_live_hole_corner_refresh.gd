extends Node

const WORKBENCH := preload("res://tools/sprite_lab/dome_material_workbench.gd")

func _ready() -> void:
	var workbench := WORKBENCH.new() as Control
	add_child(workbench)
	await get_tree().process_frame
	await get_tree().process_frame

	workbench.set("current_mode", "corner")
	var corners: Dictionary = workbench.get("corner_images")
	var source := (corners["easy"] as Image).duplicate()
	var test_color := Color(1.0, 0.0, 0.8, 1.0)
	source.set_pixel(0, 0, test_color)
	corners["easy"] = source
	workbench.set("corner_images", corners)
	workbench.call("_refresh_workspace")
	await get_tree().process_frame

	var preview: Control = workbench.get("preview") as Control
	var built: Dictionary = preview.get("inside_corner_images")
	var frames: Array = built["easy"] as Array
	var actual := (frames[0] as Image).get_pixel(0, 0)
	if actual.is_equal_approx(test_color):
		print("PASS_LIVE_HOLE_CORNER_REFRESH")
		get_tree().quit(0)
	else:
		push_error("Live Hole Corner preview did not refresh. Actual=" + str(actual))
		get_tree().quit(1)
