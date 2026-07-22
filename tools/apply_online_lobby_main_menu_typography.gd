extends Node

const SCRIPT_PATH := "res://online_lobby.gd"
const SCENE_PATH := "res://online_lobby.tscn"

func _ready() -> void:
	var script_source := FileAccess.get_file_as_string(SCRIPT_PATH)
	var scene_source := FileAccess.get_file_as_string(SCENE_PATH)
	if script_source.is_empty() or scene_source.is_empty():
		push_error("Could not read online lobby files")
		get_tree().quit(1)
		return

	if not script_source.contains("const MENU_FONT"):
		script_source = script_source.replace(
			'const ONLINE_HUB_SCENE := preload("res://scenes/world/preparation/online_multiplayer_hub.tscn")\n',
			'const ONLINE_HUB_SCENE := preload("res://scenes/world/preparation/online_multiplayer_hub.tscn")\nconst MENU_FONT: FontFile = preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")\n'
		)

	if not script_source.contains("func _apply_main_menu_typography()"):
		script_source = script_source.replace(
			"func _unhandled_input(event: InputEvent) -> void:\n",
			'''func _make_font_variation(weight: float, embolden: float = 0.0) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = MENU_FONT
	font.variation_opentype = {"wght": weight}
	font.variation_embolden = embolden
	return font

func _apply_main_menu_typography() -> void:
	var button_font := _make_font_variation(900.0, 0.85)
	var input_font := _make_font_variation(760.0, 0.3)
	var detail_font := _make_font_variation(650.0, 0.15)

	title_label.add_theme_font_override("font", button_font)
	title_label.add_theme_font_size_override("font_size", 27)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.03, 0.012, 0.006, 0.98))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 2)

	for button in [host_btn, join_btn, back_btn]:
		button.add_theme_font_override("font", button_font)
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.82, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 0.72, 0.32, 1.0))
		button.add_theme_color_override("font_focus_color", Color(0.73, 0.93, 1.0, 1.0))
		button.add_theme_color_override("font_outline_color", Color(0.03, 0.012, 0.006, 0.98))
		button.add_theme_constant_override("outline_size", 3)
		button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
		button.add_theme_constant_override("shadow_offset_x", 1)
		button.add_theme_constant_override("shadow_offset_y", 2)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	room_input.add_theme_font_override("font", input_font)
	room_input.add_theme_font_size_override("font_size", 15)
	room_input.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8, 1.0))
	room_input.add_theme_color_override("font_placeholder_color", Color(0.68, 0.66, 0.62, 0.9))
	room_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	for label in [status_label, helper_label]:
		label.add_theme_font_override("font", detail_font)
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.005, 0.92))
		label.add_theme_constant_override("outline_size", 2)

func _unhandled_input(event: InputEvent) -> void:
'''
		)

	if not script_source.contains("\t_apply_main_menu_typography()\n"):
		script_source = script_source.replace(
			"\tprocess_mode = Node.PROCESS_MODE_ALWAYS\n",
			"\tprocess_mode = Node.PROCESS_MODE_ALWAYS\n\t_apply_main_menu_typography()\n"
		)

	var old_layout := '''	var compact := size.x < 720.0 or size.y < 580.0
	panel.custom_minimum_size = Vector2(
		minf(680.0, maxf(310.0, size.x - 24.0)),
		minf(500.0, maxf(360.0, size.y - 24.0))
	)
	vbox.add_theme_constant_override("separation", 7 if compact else 14)
	title_label.custom_minimum_size.y = 34.0 if compact else 54.0
	title_label.add_theme_font_size_override("font_size", 23 if compact else 30)
	status_label.custom_minimum_size.y = 46.0 if compact else 62.0
	status_label.add_theme_font_size_override("font_size", 12 if compact else 16)
	helper_label.add_theme_font_size_override("font_size", 10 if compact else 12)
	var control_width := minf(460.0, maxf(250.0, size.x - 120.0))
	room_input.custom_minimum_size = Vector2(control_width, 44.0 if compact else 54.0)
	host_btn.custom_minimum_size = Vector2(control_width, 44.0 if compact else 56.0)
	join_btn.custom_minimum_size = Vector2(control_width, 44.0 if compact else 56.0)
	back_btn.custom_minimum_size = Vector2(control_width, 42.0 if compact else 52.0)
'''
	var new_layout := '''	var compact := size.x < 700.0 or size.y < 520.0
	var panel_width := clampf(size.x * 0.46, 330.0, 520.0)
	var panel_height := clampf(size.y * 0.66, 350.0, 420.0)
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	vbox.add_theme_constant_override("separation", 8 if compact else 11)
	title_label.custom_minimum_size.y = 38.0 if compact else 44.0
	title_label.add_theme_font_size_override("font_size", 23 if compact else 27)
	status_label.custom_minimum_size.y = 42.0 if compact else 48.0
	status_label.add_theme_font_size_override("font_size", 11 if compact else 13)
	helper_label.add_theme_font_size_override("font_size", 9 if compact else 10)
	var control_width := clampf(size.x * 0.22, 218.0, 252.0)
	var button_height := 46.0 if compact else 52.0
	room_input.custom_minimum_size = Vector2(control_width, 44.0 if compact else 48.0)
	host_btn.custom_minimum_size = Vector2(control_width, button_height)
	join_btn.custom_minimum_size = Vector2(control_width, button_height)
	back_btn.custom_minimum_size = Vector2(control_width, 44.0 if compact else 48.0)
	room_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	host_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	join_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
'''
	if not script_source.contains(old_layout):
		push_error("Could not find online lobby layout block")
		get_tree().quit(1)
		return
	script_source = script_source.replace(old_layout, new_layout)

	scene_source = scene_source.replace("custom_minimum_size = Vector2(620, 430)", "custom_minimum_size = Vector2(520, 420)")
	scene_source = scene_source.replace("custom_minimum_size = Vector2(430, 44)", "custom_minimum_size = Vector2(252, 48)")
	scene_source = scene_source.replace("custom_minimum_size = Vector2(430, 46)", "custom_minimum_size = Vector2(252, 52)")
	scene_source = scene_source.replace("theme_override_constants/separation = 8", "theme_override_constants/separation = 11")

	# Prevent VBoxContainer from stretching these controls across the wooden frame.
	for node_header in [
		'[node name="RoomInput" type="LineEdit" parent="Dimmer/Center/Panel/VBoxContainer"]',
		'[node name="ConnectBtn" type="Button" parent="Dimmer/Center/Panel/VBoxContainer"]',
		'[node name="JoinBtn" type="Button" parent="Dimmer/Center/Panel/VBoxContainer"]',
		'[node name="BackBtn" type="Button" parent="Dimmer/Center/Panel/VBoxContainer"]',
	]:
		var insertion: String = str(node_header) + "\n"
		if scene_source.contains(insertion) and not scene_source.contains(insertion + "size_flags_horizontal = 4\n"):
			scene_source = scene_source.replace(insertion, insertion + "size_flags_horizontal = 4\n")

	var script_file := FileAccess.open(SCRIPT_PATH, FileAccess.WRITE)
	var scene_file := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	if script_file == null or scene_file == null:
		push_error("Could not write online lobby files")
		get_tree().quit(1)
		return
	script_file.store_string(script_source)
	script_file.close()
	scene_file.store_string(scene_source)
	scene_file.close()
	print("ONLINE_LOBBY_MAIN_MENU_TYPOGRAPHY_APPLIED")
	get_tree().quit()
