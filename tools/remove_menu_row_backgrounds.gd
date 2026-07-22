extends Node

const CONTROLS_PATH := "res://scripts/ui/menus/controls/controls_menu.gd"
const SETTINGS_PATH := "res://scenes/menus/settings_menu.tscn"

func _ready() -> void:
	_patch_controls()
	_patch_settings()
	print("MENU_ROW_BACKGROUNDS_REMOVED")
	get_tree().quit()

func _patch_controls() -> void:
	var file := FileAccess.open(CONTROLS_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not read controls menu script")
		return
	var text := file.get_as_text()
	file.close()
	var old := "\trow_style.bg_color = Color(0.07, 0.035, 0.018, 0.58)\n\trow_style.border_color = Color(0.37, 0.2, 0.09, 0.82)\n\trow_style.set_border_width_all(1)\n\trow_style.set_corner_radius_all(6)"
	var replacement := "\t# Let the wood panel act as the background; rows only provide spacing.\n\trow_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)\n\trow_style.border_color = Color(0.0, 0.0, 0.0, 0.0)\n\trow_style.set_border_width_all(0)\n\trow_style.set_corner_radius_all(0)"
	if not text.contains(old):
		push_error("Controls row style snippet not found")
		return
	text = text.replace(old, replacement)
	file = FileAccess.open(CONTROLS_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _patch_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not read settings menu scene")
		return
	var text := file.get_as_text()
	file.close()
	var old := "[sub_resource type=\"StyleBoxFlat\" id=\"RowStyle\"]\nbg_color = Color(0.07, 0.035, 0.018, 0.72)\nborder_width_left = 1\nborder_width_top = 1\nborder_width_right = 1\nborder_width_bottom = 1\nborder_color = Color(0.42, 0.24, 0.1, 0.9)\ncorner_radius_top_left = 6\ncorner_radius_top_right = 6\ncorner_radius_bottom_right = 6\ncorner_radius_bottom_left = 6"
	var replacement := "[sub_resource type=\"StyleBoxFlat\" id=\"RowStyle\"]\nbg_color = Color(0, 0, 0, 0)\nborder_width_left = 0\nborder_width_top = 0\nborder_width_right = 0\nborder_width_bottom = 0\nborder_color = Color(0, 0, 0, 0)\ncorner_radius_top_left = 0\ncorner_radius_top_right = 0\ncorner_radius_bottom_right = 0\ncorner_radius_bottom_left = 0"
	if not text.contains(old):
		push_error("Settings row style snippet not found")
		return
	text = text.replace(old, replacement)
	file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
