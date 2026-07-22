extends Node

const TARGET := "res://local_coop_mode.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(TARGET)
	if source.is_empty():
		push_error("Could not read local_coop_mode.gd")
		get_tree().quit(1)
		return

	var preload_anchor := 'const MAIN_MENU_PATH := "res://scenes/menus/main/menu.tscn"\n'
	var preload_block := '''const MAIN_MENU_PATH := "res://scenes/menus/main/menu.tscn"
const HOME_ICON := preload("res://assets/sprites/ui/common/icon_home.svg")
const GEM_ICON := preload("res://assets/sprites/ui/common/stats/StatRessources.png")
const GOLD_ICON := preload("res://GoldCoin.png")
'''
	if source.contains(preload_anchor) and not source.contains("const HOME_ICON"):
		source = source.replace(preload_anchor, preload_block)

	source = _replace_function(source, "func _create_player_panel", "func _create_base_panel", _player_panel_function())
	source = _replace_function(source, "func _create_base_panel", "func _hide_single_player_hud", _base_panel_function())
	source = _replace_function(source, "func _update_player_panel", "func _update_base_panel", _update_player_function())
	source = _replace_function(source, "func _configure_exit_button", "func _panel_style", _exit_button_function())

	source = source.replace("p1_bar.offset_top = -184.0", "p1_bar.offset_top = -168.0")
	source = source.replace("p1_bar.offset_bottom = -116.0", "p1_bar.offset_bottom = -100.0")
	source = source.replace("p2_bar.offset_top = -184.0", "p2_bar.offset_top = -168.0")
	source = source.replace("p2_bar.offset_bottom = -116.0", "p2_bar.offset_bottom = -100.0")

	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not write local_coop_mode.gd")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("LOCAL_COOP_COMPACT_HUD_REFINED")
	get_tree().quit()

func _replace_function(source: String, start_name: String, end_name: String, replacement: String) -> String:
	var start_index := source.find(start_name)
	var end_index := source.find(end_name, start_index + start_name.length())
	if start_index < 0 or end_index < 0:
		push_error("Could not replace %s" % start_name)
		get_tree().quit(1)
		return source
	return source.substr(0, start_index) + replacement + "\n\n" + source.substr(end_index)

func _player_panel_function() -> String:
	return '''func _create_player_panel(player_id: int, left_side: bool, accent: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "Player%dHeroPanel" % player_id
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 35
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if left_side else Control.PRESET_BOTTOM_RIGHT)
	if left_side:
		panel.offset_left = 18.0
		panel.offset_top = -92.0
		panel.offset_right = 410.0
		panel.offset_bottom = -14.0
	else:
		panel.offset_left = -410.0
		panel.offset_top = -92.0
		panel.offset_right = -18.0
		panel.offset_bottom = -14.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.02, 0.032, 0.95), accent, 2, 10))
	coop_hud.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)

	var portrait_stack := Control.new()
	portrait_stack.custom_minimum_size = Vector2(66, 66)
	row.add_child(portrait_stack)

	var portrait_frame := PanelContainer.new()
	portrait_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.035, 0.05, 1.0), accent, 2, 8))
	portrait_stack.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_frame.add_child(portrait)

	var level_badge := PanelContainer.new()
	level_badge.name = "LevelBadge"
	level_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	level_badge.offset_left = -25.0
	level_badge.offset_top = -25.0
	level_badge.offset_right = 1.0
	level_badge.offset_bottom = 1.0
	level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_badge.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.025, 0.015, 0.98), accent, 2, 13))
	portrait_stack.add_child(level_badge)
	var level_label := Label.new()
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_label.add_theme_color_override("font_outline_color", Color.BLACK)
	level_label.add_theme_constant_override("outline_size", 3)
	level_badge.add_child(level_label)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var header := HBoxContainer.new()
	info.add_child(header)
	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", accent)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 4)
	header.add_child(name_label)
	var hp_label := Label.new()
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.94, 0.9, 0.8, 1.0))
	header.add_child(hp_label)

	var health_bar := ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(0, 14)
	health_bar.show_percentage = false
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.add_theme_stylebox_override("background", _panel_style(Color(0.06, 0.025, 0.025, 0.95), Color(0.2, 0.12, 0.12, 1.0), 1, 4))
	health_bar.add_theme_stylebox_override("fill", _panel_style(Color(0.64, 0.12, 0.10, 1.0), Color(1.0, 0.4, 0.24, 1.0), 1, 4))
	info.add_child(health_bar)

	var resources := HBoxContainer.new()
	resources.add_theme_constant_override("separation", 6)
	info.add_child(resources)
	var gem_icon := TextureRect.new()
	gem_icon.custom_minimum_size = Vector2(20, 20)
	gem_icon.texture = GEM_ICON
	gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resources.add_child(gem_icon)
	var gem_value := Label.new()
	gem_value.add_theme_font_size_override("font_size", 12)
	gem_value.add_theme_color_override("font_color", Color(0.82, 0.72, 1.0, 1.0))
	resources.add_child(gem_value)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 10.0
	resources.add_child(spacer)
	var gold_icon := TextureRect.new()
	gold_icon.custom_minimum_size = Vector2(20, 20)
	gold_icon.texture = GOLD_ICON
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resources.add_child(gold_icon)
	var gold_value := Label.new()
	gold_value.add_theme_font_size_override("font_size", 12)
	gold_value.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32, 1.0))
	resources.add_child(gold_value)

	return {
		"panel": panel,
		"portrait": portrait,
		"level": level_label,
		"name": name_label,
		"hp": hp_label,
		"health": health_bar,
		"gems": gem_value,
		"gold": gold_value,
	}
'''

func _base_panel_function() -> String:
	return '''func _create_base_panel() -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "SharedBasePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 34
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -190.0
	panel.offset_top = 10.0
	panel.offset_right = 190.0
	panel.offset_bottom = 56.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.025, 0.035, 0.96), Color(0.38, 0.88, 0.68, 1.0), 2, 9))
	coop_hud.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	var health_bar := ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(0, 12)
	health_bar.show_percentage = false
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.add_theme_stylebox_override("background", _panel_style(Color(0.025, 0.06, 0.045, 0.95), Color(0.1, 0.26, 0.18, 1.0), 1, 4))
	health_bar.add_theme_stylebox_override("fill", _panel_style(Color(0.12, 0.62, 0.34, 1.0), Color(0.42, 1.0, 0.66, 1.0), 1, 4))
	info.add_child(health_bar)
	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", Color(0.88, 0.92, 0.86, 1.0))
	info.add_child(status)

	return {
		"panel": panel,
		"icon": icon,
		"health": health_bar,
		"status": status,
	}
'''

func _update_player_function() -> String:
	return '''func _update_player_panel(ui: Dictionary, target: CharacterBody2D, player_id: int, hero_name: String) -> void:
	if ui.is_empty() or target == null or not is_instance_valid(target):
		return
	var health := int(target.get("health"))
	var max_health := maxi(1, int(target.get("max_health")))
	var carried := int(target.call("get_carry_load")) if target.has_method("get_carry_load") else 0
	var level_value := int(target.get("level")) if target.get("level") != null else 1
	var hud := level.get_node_or_null("HUD")
	var shared_gold := int(hud.get("total_gold")) if hud != null and hud.get("total_gold") != null else 0
	var portrait := ui["portrait"] as TextureRect
	portrait.texture = HERO_PORTRAITS.get(hero_name, HERO_PORTRAITS["Dwarf"]) as Texture2D
	var level_label := ui["level"] as Label
	level_label.text = str(level_value)
	var name_label := ui["name"] as Label
	name_label.text = "PLAYER %d  •  %s" % [player_id, hero_name.to_upper()]
	var hp_label := ui["hp"] as Label
	hp_label.text = "HP %d / %d" % [health, max_health]
	var health_bar := ui["health"] as ProgressBar
	health_bar.max_value = float(max_health)
	health_bar.value = float(health)
	var gem_value := ui["gems"] as Label
	gem_value.text = str(carried)
	var gold_value := ui["gold"] as Label
	gold_value.text = str(shared_gold)
'''

func _exit_button_function() -> String:
	return '''func _configure_exit_button() -> void:
	exit_button.text = ""
	exit_button.tooltip_text = "Return to Modes"
	exit_button.icon = HOME_ICON
	exit_button.expand_icon = true
	exit_button.offset_left = 18.0
	exit_button.offset_top = 16.0
	exit_button.offset_right = 66.0
	exit_button.offset_bottom = 64.0
	exit_button.add_theme_stylebox_override("normal", _panel_style(Color(0.035, 0.025, 0.02, 0.96), Color(0.8, 0.58, 0.22, 0.95), 2, 9))
	exit_button.add_theme_stylebox_override("hover", _panel_style(Color(0.09, 0.055, 0.025, 0.98), Color(1.0, 0.76, 0.3, 1.0), 2, 9))
	exit_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.02, 0.018, 0.015, 1.0), Color(0.72, 0.45, 0.14, 1.0), 2, 9))
'''
