extends Node

var failures: Array[String] = []
var changed: Array[String] = []

func _ready() -> void:
	_patch_project_clear_color()
	_patch_global_theme_disabled_button()
	_patch_main_menu_layout()
	_patch_panel_container_scenes()
	_patch_online_lobby()
	_patch_bestiary_layout()
	_patch_controls_copy()
	_patch_loadout_selector()
	_patch_hero_card_safe_area()
	if failures.is_empty():
		print("MENU_UI_CONSISTENCY_PATCH_OK changed=", changed)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _patch_project_clear_color() -> void:
	_replace_once(
		"res://project.godot",
		"[rendering]\n\ntextures/canvas_textures/default_texture_filter=0",
		"[rendering]\n\nenvironment/defaults/default_clear_color=Color(0.004, 0.006, 0.01, 1)\ntextures/canvas_textures/default_texture_filter=0"
	)

func _patch_global_theme_disabled_button() -> void:
	var path := "res://assets/themes/global/global_theme.tres"
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		_fail("Could not read %s" % path)
		return
	if source.contains("Button/styles/disabled"):
		return
	var anchor := "[sub_resource type=\"StyleBoxTexture\" id=\"StyleBoxTexture_0lf1r\"]\ntexture = ExtResource(\"2_ap137\")"
	var disabled := "[sub_resource type=\"StyleBoxTexture\" id=\"StyleBoxTexture_disabled\"]\ntexture = ExtResource(\"1_l7yju\")\ntexture_margin_left = 16.0\ntexture_margin_top = 16.0\ntexture_margin_right = 16.0\ntexture_margin_bottom = 16.0\nmodulate_color = Color(0.32, 0.32, 0.32, 0.78)\n\n" + anchor
	if not source.contains(anchor):
		_fail("Theme panel anchor missing")
		return
	source = source.replace(anchor, disabled)
	source = source.replace("Button/styles/focus = SubResource(\"StyleBoxTexture_icku4\")", "Button/styles/disabled = SubResource(\"StyleBoxTexture_disabled\")\nButton/styles/focus = SubResource(\"StyleBoxTexture_icku4\")")
	_write(path, source)

func _patch_main_menu_layout() -> void:
	_replace_once(
		"res://scripts/ui/menus/main/menu.gd",
		"\tvar button_height := 52.0\n\tvar gap := 4.0 if compact else 8.0",
		"\t# Seven destinations must remain inside the wooden frame at 16:9.\n\tvar button_height := 40.0 if compact else 44.0\n\tvar gap := 2.0 if compact else 3.0"
	)

func _panel_style_resource(texture_id: String, style_id: String) -> String:
	return "[sub_resource type=\"StyleBoxTexture\" id=\"%s\"]\ntexture = ExtResource(\"%s\")\ntexture_margin_left = 32.0\ntexture_margin_top = 32.0\ntexture_margin_right = 32.0\ntexture_margin_bottom = 32.0\ncontent_margin_left = 38.0\ncontent_margin_top = 32.0\ncontent_margin_right = 38.0\ncontent_margin_bottom = 32.0\n" % [style_id, texture_id]

func _patch_panel_container_scenes() -> void:
	_patch_panel_scene("res://scenes/menus/settings_menu.tscn", "2_theme", "3_panel", "StyleBox_settings", "custom_minimum_size = Vector2(560, 390)", "custom_minimum_size = Vector2(620, 430)")
	_patch_panel_scene("res://scenes/menus/multiplayer_menu.tscn", "2_theme", "3_panel", "StyleBox_multiplayer", "custom_minimum_size = Vector2(600, 390)", "custom_minimum_size = Vector2(650, 430)")
	_patch_panel_scene("res://scenes/menus/multiplayer_hero_select.tscn", "2_theme", "3_panel", "StyleBox_hero_select", "custom_minimum_size = Vector2(680, 360)", "custom_minimum_size = Vector2(730, 410)")

func _patch_panel_scene(path: String, theme_id: String, texture_id: String, style_id: String, old_size: String, new_size: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		_fail("Could not read %s" % path)
		return
	if not source.contains("id=\"%s\"" % texture_id):
		var theme_line := "[ext_resource type=\"Theme\" path=\"res://assets/themes/global/global_theme.tres\" id=\"%s\"]" % theme_id
		if not source.contains(theme_line):
			_fail("Theme anchor missing in %s" % path)
			return
		source = source.replace(theme_line, theme_line + "\n[ext_resource type=\"Texture2D\" path=\"res://assets/sprites/ui/common/MenuPanel.png\" id=\"%s\"]\n\n%s" % [texture_id, _panel_style_resource(texture_id, style_id)])
	if source.contains(old_size):
		source = source.replace(old_size, new_size)
	var panel_anchor := "[node name=\"Panel\" type=\"PanelContainer\" parent=\"Dimmer/Center\"]\n"
	if not source.contains("theme_override_styles/panel = SubResource(\"%s\")" % style_id):
		if not source.contains(panel_anchor):
			_fail("Panel anchor missing in %s" % path)
			return
		source = source.replace(panel_anchor, panel_anchor + "theme_override_styles/panel = SubResource(\"%s\")\n" % style_id)
	_write(path, source)

func _patch_online_lobby() -> void:
	var scene := '''[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://online_lobby.gd" id="1_script"]
[ext_resource type="Theme" path="res://assets/themes/global/global_theme.tres" id="2_theme"]
[ext_resource type="Texture2D" path="res://assets/sprites/ui/common/MenuPanel.png" id="3_panel"]

[sub_resource type="StyleBoxTexture" id="StyleBox_lobby"]
texture = ExtResource("3_panel")
texture_margin_left = 32.0
texture_margin_top = 32.0
texture_margin_right = 32.0
texture_margin_bottom = 32.0
content_margin_left = 46.0
content_margin_top = 38.0
content_margin_right = 46.0
content_margin_bottom = 38.0

[sub_resource type="StyleBoxFlat" id="StyleBox_input"]
bg_color = Color(0.035, 0.025, 0.02, 0.96)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.62, 0.42, 0.18, 0.92)
corner_radius_top_left = 7
corner_radius_top_right = 7
corner_radius_bottom_right = 7
corner_radius_bottom_left = 7
content_margin_left = 14.0
content_margin_right = 14.0

[sub_resource type="StyleBoxFlat" id="StyleBox_input_focus"]
bg_color = Color(0.045, 0.032, 0.022, 0.98)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(1, 0.72, 0.22, 1)
corner_radius_top_left = 7
corner_radius_top_right = 7
corner_radius_bottom_right = 7
corner_radius_bottom_left = 7
content_margin_left = 14.0
content_margin_right = 14.0

[node name="OnlineLobby" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme = ExtResource("2_theme")
script = ExtResource("1_script")

[node name="Dimmer" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.004, 0.006, 0.01, 1)

[node name="Center" type="CenterContainer" parent="Dimmer"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Panel" type="PanelContainer" parent="Dimmer/Center"]
custom_minimum_size = Vector2(680, 440)
layout_mode = 2
theme_override_styles/panel = SubResource("StyleBox_lobby")

[node name="VBoxContainer" type="VBoxContainer" parent="Dimmer/Center/Panel"]
layout_mode = 2
theme_override_constants/separation = 18
alignment = 1

[node name="Label" type="Label" parent="Dimmer/Center/Panel/VBoxContainer"]
custom_minimum_size = Vector2(0, 58)
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.84, 0.32, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 4
theme_override_font_sizes/font_size = 30
text = "ONLINE EXPLORATION VS"
horizontal_alignment = 1
vertical_alignment = 1

[node name="StatusLabel" type="Label" parent="Dimmer/Center/Panel/VBoxContainer"]
custom_minimum_size = Vector2(0, 54)
layout_mode = 2
theme_override_colors/font_color = Color(0.88, 0.8, 0.66, 1)
theme_override_font_sizes/font_size = 16
text = "Enter the same room code on both devices."
horizontal_alignment = 1
vertical_alignment = 1
autowrap_mode = 2

[node name="RoomInput" type="LineEdit" parent="Dimmer/Center/Panel/VBoxContainer"]
custom_minimum_size = Vector2(460, 54)
layout_mode = 2
theme_override_font_sizes/font_size = 18
theme_override_styles/normal = SubResource("StyleBox_input")
theme_override_styles/focus = SubResource("StyleBox_input_focus")
placeholder_text = "ROOM CODE  •  e.g. APPLE"
alignment = 1
max_length = 18

[node name="ConnectBtn" type="Button" parent="Dimmer/Center/Panel/VBoxContainer"]
custom_minimum_size = Vector2(460, 56)
layout_mode = 2
text = "CONNECT"

[node name="Hint" type="Label" parent="Dimmer/Center/Panel/VBoxContainer"]
layout_mode = 2
theme_override_colors/font_color = Color(0.62, 0.68, 0.74, 1)
theme_override_font_sizes/font_size = 12
text = "WebRTC • One player hosts automatically • Both players need internet access"
horizontal_alignment = 1
autowrap_mode = 2

[node name="BackBtn" type="Button" parent="Dimmer/Center/Panel/VBoxContainer"]
custom_minimum_size = Vector2(460, 52)
layout_mode = 2
text = "BACK TO MAIN MENU"
'''
	_write("res://online_lobby.tscn", scene)
	var script_path := "res://online_lobby.gd"
	var source := FileAccess.get_file_as_string(script_path)
	if source.is_empty():
		_fail("Could not read online_lobby.gd")
		return
	source = source.replace("@onready var connect_btn = $VBoxContainer/ConnectBtn\n@onready var room_input = $VBoxContainer/RoomInput\n@onready var status_label = $VBoxContainer/StatusLabel\n@onready var back_btn = $VBoxContainer/BackBtn", "@onready var connect_btn: Button = $Dimmer/Center/Panel/VBoxContainer/ConnectBtn\n@onready var room_input: LineEdit = $Dimmer/Center/Panel/VBoxContainer/RoomInput\n@onready var status_label: Label = $Dimmer/Center/Panel/VBoxContainer/StatusLabel\n@onready var back_btn: Button = $Dimmer/Center/Panel/VBoxContainer/BackBtn")
	if not source.contains("func _unhandled_input(event: InputEvent)"):
		source = source.replace("\tws = WebSocketPeer.new()\n", "\tws = WebSocketPeer.new()\n\troom_input.call_deferred(\"grab_focus\")\n\nfunc _unhandled_input(event: InputEvent) -> void:\n\tif event.is_action_pressed(\"ui_cancel\"):\n\t\t_on_back_pressed()\n\t\tget_viewport().set_input_as_handled()\n")
	_write(script_path, source)

func _patch_bestiary_layout() -> void:
	var path := "res://scenes/menus/lexicon/lexikon.tscn"
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		_fail("Could not read Bestiary scene")
		return
	var anchor := "[node name=\"VBoxContainer\" type=\"VBoxContainer\" parent=\".\" unique_id=784171436]\nlayout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2"
	var replacement := anchor + "\noffset_left = 48.0\noffset_top = 12.0\noffset_right = -48.0\noffset_bottom = -24.0"
	if not source.contains("offset_left = 48.0"):
		if not source.contains(anchor):
			_fail("Bestiary layout anchor missing")
			return
		source = source.replace(anchor, replacement)
	_write(path, source)

func _patch_controls_copy() -> void:
	_replace_once("res://scenes/menus/controls/controls_menu.tscn", "text = \"Controls & Settings\"", "text = \"CONTROLS\"")
	_replace_once("res://scenes/ui/overlays/pause/pause_menu.tscn", "text = \"Controls & Settings\"", "text = \"Controls\"")

func _patch_loadout_selector() -> void:
	var path := "res://scripts/ui/menus/loadout_selection_menu.gd"
	_replace_once(path, "\t\tbutton.custom_minimum_size = Vector2(92, 66)\n\t\tbutton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART", "\t\tbutton.custom_minimum_size = Vector2(220, 60)\n\t\tbutton.autowrap_mode = TextServer.AUTOWRAP_OFF\n\t\tbutton.add_theme_font_size_override(\"font_size\", 15)")
	_replace_once(path, "\tvar height := clampf(view_size.y - 24.0, 520.0, 680.0)", "\tvar height := clampf(view_size.y - 40.0, 520.0, 620.0)")
	_replace_once(path, "\t\tbutton.visible = unlocked\n\t\tbutton.text = short_name", "\t\t# The arrows own cycling; show one readable fortress name instead of a cramped strip.\n\t\tbutton.visible = unlocked and is_selected\n\t\tbutton.text = short_name")

func _patch_hero_card_safe_area() -> void:
	var path := "res://scripts/systems/preparation/in_world_hero_selector.gd"
	var old := "\tvar target_y := screen_position.y - CARD_SIZE.y * 0.45\n\ttarget_x = clampf(target_x, 12.0, maxf(12.0, viewport_size.x - CARD_SIZE.x - 12.0))\n\ttarget_y = clampf(target_y, CARD_TOP_SAFE, maxf(CARD_TOP_SAFE, viewport_size.y - CARD_SIZE.y - CARD_BOTTOM_SAFE))"
	var new := "\tvar target_y := screen_position.y - CARD_SIZE.y * 0.45\n\tvar top_safe := CARD_TOP_SAFE\n\tvar first_run_guide := get_parent().get_node_or_null(\"SinglePlayerWorldController/FirstRunStrongholdGuide\")\n\tif first_run_guide != null and is_instance_valid(first_run_guide):\n\t\ttop_safe = 174.0\n\ttarget_x = clampf(target_x, 12.0, maxf(12.0, viewport_size.x - CARD_SIZE.x - 12.0))\n\ttarget_y = clampf(target_y, top_safe, maxf(top_safe, viewport_size.y - CARD_SIZE.y - CARD_BOTTOM_SAFE))"
	_replace_once(path, old, new)

func _replace_once(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		_fail("Could not read %s" % path)
		return
	if source.contains(new_text):
		return
	if not source.contains(old_text):
		_fail("Patch target missing in %s: %s" % [path, old_text.left(100)])
		return
	_write(path, source.replace(old_text, new_text))

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write %s" % path)
		return
	file.store_string(content)
	file.close()
	if not changed.has(path):
		changed.append(path)

func _fail(message: String) -> void:
	failures.append(message)
