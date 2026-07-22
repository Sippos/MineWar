extends Node

const TARGET := "res://local_coop_mode.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(TARGET)
	if source.is_empty():
		push_error("Could not read local_coop_mode.gd")
		get_tree().quit(1)
		return

	source = source.replace(
		"\texit_button.pressed.connect(_return_to_menu)\n",
		"\texit_button.pressed.connect(_return_to_menu)\n\t_configure_exit_button()\n"
	)

	var distance_block := '''\tdistance_hint = Label.new()
\tdistance_hint.name = "CoopDistanceHint"
\tdistance_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
\tdistance_hint.offset_left = 390.0
\tdistance_hint.offset_top = -37.0
\tdistance_hint.offset_right = -390.0
\tdistance_hint.offset_bottom = -15.0
\tdistance_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tdistance_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
\tdistance_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
\tdistance_hint.add_theme_font_size_override("font_size", 12)
\tdistance_hint.add_theme_color_override("font_color", Color(0.78, 0.86, 0.94, 1.0))
\tdistance_hint.add_theme_color_override("font_outline_color", Color.BLACK)
\tdistance_hint.add_theme_constant_override("outline_size", 4)
\tcoop_hud.add_child(distance_hint)
'''
	source = source.replace(distance_block, "\tdistance_hint = null\n")

	source = source.replace("\tpanel.offset_bottom = 82.0\n", "\tpanel.offset_bottom = 70.0\n")

	var base_name_block := '''\tvar name_label := Label.new()
\tname_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tname_label.add_theme_font_size_override("font_size", 15)
\tname_label.add_theme_color_override("font_color", Color(0.56, 1.0, 0.76, 1.0))
\tname_label.add_theme_color_override("font_outline_color", Color.BLACK)
\tname_label.add_theme_constant_override("outline_size", 4)
\tinfo.add_child(name_label)

'''
	source = source.replace(base_name_block, "")
	source = source.replace("\t\t\"name\": name_label,\n", "")

	source = source.replace(
		'''\tvar hidden_nodes := [
\t\t"PlayerLabel", "PlayerHealthBar", "HeroPortrait", "StatsBackdrop", "StatsContainer",
\t\t"BaseHealthBar", "BaseLabel", "BaseStatus", "HeroRPGSummaryP1", "HeroRPGSummaryP2"
\t]
''',
		'''\tvar hidden_nodes := [
\t\t"PlayerLabel", "PlayerHealthBar", "HeroPortrait", "StatsBackdrop", "StatsContainer",
\t\t"BaseHealthBar", "BaseLabel", "BaseStatus", "HeroRPGSummaryP1", "HeroRPGSummaryP2",
\t\t"ResourcePanel", "GemIcon", "Label", "GoldIcon", "GoldLabel", "NoticeLabel"
\t]
'''
	)

	source = source.replace(
		'''\tfor node_name in hidden_nodes:
\t\tvar item := hud.get_node_or_null(node_name) as CanvasItem
\t\tif item != null:
\t\t\titem.visible = false
''',
		'''\tfor node_name in hidden_nodes:
\t\tvar item := hud.get_node_or_null(node_name) as CanvasItem
\t\tif item != null:
\t\t\titem.visible = false
\tvar exploration_controller := level.get_node_or_null("ExplorationModeController")
\tif exploration_controller != null:
\t\tfor child in exploration_controller.get_children():
\t\t\tif child is CanvasLayer:
\t\t\t\t(child as CanvasLayer).visible = false
'''
	)

	var distance_update := '''\tif distance_hint == null:
\t\treturn
\tvar separation := player_one.global_position.distance_to(player_two.global_position) if is_instance_valid(player_one) and is_instance_valid(player_two) else 0.0
\tif separation > 720.0:
\t\tdistance_hint.text = "REGROUP  •  Camera at maximum zoom"
\telif separation > 460.0:
\t\tdistance_hint.text = "Players are spreading apart"
\telse:
\t\tdistance_hint.text = "SHARED EXPEDITION  •  Stay together, split the work"
'''
	source = source.replace(distance_update, "")

	source = source.replace(
		'''\tvar details := ui["details"] as Label
\tdetails.text = "LEVEL %d   •   GEMS %d" % [level_value, carried]
''',
		'''\tvar details := ui["details"] as Label
\tif player_id == 2:
\t\tvar hud := level.get_node_or_null("HUD")
\t\tvar shared_gems := int(hud.get("total_gems")) if hud != null and hud.get("total_gems") != null else 0
\t\tvar shared_gold := int(hud.get("total_gold")) if hud != null and hud.get("total_gold") != null else 0
\t\tdetails.text = "LEVEL %d   •   GEMS %d   •   GOLD %d" % [level_value, shared_gems, shared_gold]
\telse:
\t\tdetails.text = "LEVEL %d   •   GEMS %d" % [level_value, carried]
'''
	)

	source = source.replace(
		'''\tvar base_entry_value = Global.base_data.get(Global.selected_base_id, {})
\tvar base_entry: Dictionary = base_entry_value if base_entry_value is Dictionary else {}
\tvar display_name := str(base_entry.get("name", "Shared Bastion"))
\tvar icon := base_ui["icon"] as TextureRect
\ticon.texture = base_entry.get("texture") as Texture2D
\tvar name_label := base_ui["name"] as Label
\tname_label.text = "SHARED BASE  •  %s" % display_name.to_upper()
''',
		'''\tvar base_entry_value = Global.base_data.get(Global.selected_base_id, {})
\tvar base_entry: Dictionary = base_entry_value if base_entry_value is Dictionary else {}
\tvar icon := base_ui["icon"] as TextureRect
\ticon.texture = base_entry.get("texture") as Texture2D
'''
	)

	source = source.replace(
		'''\tvar hud := level.get_node_or_null("HUD")
\tvar shared_gems := int(hud.get("total_gems")) if hud != null and hud.get("total_gems") != null else 0
\tvar shared_gold := int(hud.get("total_gold")) if hud != null and hud.get("total_gold") != null else 0
\tvar status := base_ui["status"] as Label
\tstatus.text = "HP %d / %d   •   BANK %d GEMS   •   %d GOLD" % [current_health, maximum_health, shared_gems, shared_gold]
''',
		'''\tvar status := base_ui["status"] as Label
\tstatus.text = "HP %d / %d" % [current_health, maximum_health]
'''
	)

	var insert_point := "func _panel_style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:\n"
	var exit_function := '''func _configure_exit_button() -> void:
\texit_button.text = "RETURN TO MODES"
\texit_button.icon = null
\texit_button.expand_icon = false
\texit_button.offset_left = 18.0
\texit_button.offset_top = 18.0
\texit_button.offset_right = 188.0
\texit_button.offset_bottom = 58.0
\texit_button.add_theme_font_size_override("font_size", 14)
\texit_button.add_theme_color_override("font_color", Color(0.96, 0.86, 0.68, 1.0))
\texit_button.add_theme_color_override("font_hover_color", Color.WHITE)
\texit_button.add_theme_stylebox_override("normal", _panel_style(Color(0.035, 0.025, 0.02, 0.96), Color(0.8, 0.58, 0.22, 0.95), 2, 8))
\texit_button.add_theme_stylebox_override("hover", _panel_style(Color(0.09, 0.055, 0.025, 0.98), Color(1.0, 0.76, 0.3, 1.0), 2, 8))
\texit_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.02, 0.018, 0.015, 1.0), Color(0.72, 0.45, 0.14, 1.0), 2, 8))

'''
	if not source.contains("func _configure_exit_button() -> void:"):
		source = source.replace(insert_point, exit_function + insert_point)

	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not write local_coop_mode.gd")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("LOCAL_COOP_HUD_REFINED")
	get_tree().quit()
