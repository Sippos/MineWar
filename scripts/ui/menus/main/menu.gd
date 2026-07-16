extends Control

const MENU_THEME = preload("res://assets/themes/global/global_theme.tres")

func _ready() -> void:
	theme = MENU_THEME
	$VSOnlineButton.pressed.connect(_on_vs_online_pressed)
	$VSModeButton.pressed.connect(_on_vs_mode_pressed)
	$SinglePlayerButton.pressed.connect(_on_single_player_pressed)
	$LexikonButton.pressed.connect(_on_lexikon_pressed)
	$ControlsButton.pressed.connect(_on_controls_pressed)
	_configure_lexicon_action()
	get_tree().root.size_changed.connect(_layout_for_screen)
	call_deferred("_layout_for_screen")
	$SinglePlayerButton.call_deferred("grab_focus")

func _configure_lexicon_action() -> void:
	_ensure_lexicon_backdrop()
	_ensure_lexicon_caption()
	_ensure_lexicon_hint()
	$LexikonButton.tooltip_text = "Bestiary — Heroes, Bases, and Monsters"
	$LexikonButton.focus_mode = Control.FOCUS_ALL
	$LexikonButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	$LexikonButton.z_index = 2
	$ControlsButton.focus_neighbor_bottom = $LexikonButton.get_path()
	$LexikonButton.focus_neighbor_top = $ControlsButton.get_path()
	$LexikonButton.mouse_entered.connect(_set_lexicon_emphasis.bind(true))
	$LexikonButton.mouse_exited.connect(_set_lexicon_emphasis.bind(false))
	$LexikonButton.focus_entered.connect(_set_lexicon_emphasis.bind(true))
	$LexikonButton.focus_exited.connect(_set_lexicon_emphasis.bind(false))

func _ensure_lexicon_backdrop() -> Panel:
	var existing := get_node_or_null("LexikonBackdrop") as Panel
	if existing != null:
		return existing
	var backdrop := Panel.new()
	backdrop.name = "LexikonBackdrop"
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = 1
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.025, 0.012, 0.94)
	style.border_color = Color(1.0, 0.63, 0.16, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(1.0, 0.34, 0.06, 0.34)
	style.shadow_size = 9
	backdrop.add_theme_stylebox_override("panel", style)
	add_child(backdrop)
	return backdrop

func _ensure_lexicon_caption() -> Label:
	var existing := get_node_or_null("LexikonCaption") as Label
	if existing != null:
		return existing
	var caption := Label.new()
	caption.name = "LexikonCaption"
	caption.text = "BESTIARY"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.z_index = 3
	caption.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46, 1.0))
	caption.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01, 0.98))
	caption.add_theme_constant_override("outline_size", 4)
	add_child(caption)
	return caption

func _ensure_lexicon_hint() -> Label:
	var existing := get_node_or_null("LexikonHint") as Label
	if existing != null:
		return existing
	var hint := Label.new()
	hint.name = "LexikonHint"
	hint.text = "HEROES • BASES • FOES"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.z_index = 3
	hint.add_theme_color_override("font_color", Color(0.86, 0.76, 0.58, 1.0))
	hint.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01, 0.96))
	hint.add_theme_constant_override("outline_size", 2)
	add_child(hint)
	return hint

func _set_lexicon_emphasis(enabled: bool) -> void:
	var button := $LexikonButton as TextureButton
	var backdrop := _ensure_lexicon_backdrop()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2(1.1, 1.1) if enabled else Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(backdrop, "modulate", Color(1.0, 0.9, 0.72, 1.0) if enabled else Color.WHITE, 0.14)

func _layout_for_screen(screen_size_override: Vector2 = Vector2.ZERO) -> void:
	var screen_size: Vector2 = screen_size_override
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var layout: Dictionary = _main_button_layout(screen_size)
	var center_x: float = screen_size.x * 0.5
	var title_font_size := int(layout["title_font_size"])
	var title_top := float(layout["title_top"])
	var title_width := float(layout["title_width"])
	var button_w := float(layout["button_width"])
	var button_h := float(layout["button_height"])
	var gap := float(layout["gap"])
	var buttons_top := float(layout["buttons_top"])

	$Label.offset_left = center_x - title_width * 0.5
	$Label.offset_top = title_top
	$Label.offset_right = center_x + title_width * 0.5
	$Label.offset_bottom = title_top + float(title_font_size) + 8.0
	$Label.add_theme_font_size_override("font_size", title_font_size)
	$Label.add_theme_constant_override("outline_size", 4)

	var panel: Sprite2D = $MenuPanel
	panel.position = Vector2(center_x, screen_size.y * 0.5)
	var panel_scale: float = clampf(minf(screen_size.x / 820.0, screen_size.y / 650.0), 0.42, 0.96)
	panel.scale = Vector2(panel_scale, panel_scale * 1.18)
	var nested_panel = panel.get_node_or_null("MenuPanel")
	if nested_panel:
		nested_panel.visible = false

	_layout_button($SinglePlayerButton, center_x, buttons_top, button_w, button_h)
	_layout_button($VSModeButton, center_x, buttons_top + (button_h + gap), button_w, button_h)
	_layout_button($VSOnlineButton, center_x, buttons_top + (button_h + gap) * 2.0, button_w, button_h)
	_layout_button($ControlsButton, center_x, buttons_top + (button_h + gap) * 3.0, button_w, button_h)

	var lex_size := float(layout["lexicon_size"])
	var lex_margin := float(layout["lexicon_margin"])
	var callout_width := float(layout["lexicon_callout_width"])
	var callout_right := screen_size.x - lex_margin
	var callout_left := maxf(8.0, callout_right - callout_width)
	var callout_center := (callout_left + callout_right) * 0.5
	var callout_bottom := screen_size.y - lex_margin
	var lex_bottom := callout_bottom - 8.0
	var lex_top := lex_bottom - lex_size
	var lex_left := callout_center - lex_size * 0.5
	var lex_right := callout_center + lex_size * 0.5
	$LexikonButton.offset_left = lex_left
	$LexikonButton.offset_top = lex_top
	$LexikonButton.offset_right = lex_right
	$LexikonButton.offset_bottom = lex_bottom
	$LexikonButton.custom_minimum_size = Vector2(lex_size, lex_size)
	$LexikonButton.pivot_offset = Vector2(lex_size * 0.5, lex_size * 0.5)

	var caption := _ensure_lexicon_caption()
	var hint := _ensure_lexicon_hint()
	var caption_height := 22.0
	var hint_height := 15.0
	var caption_top := maxf(8.0, lex_top - caption_height - hint_height - 5.0)
	caption.offset_left = callout_left + 5.0
	caption.offset_top = caption_top
	caption.offset_right = callout_right - 5.0
	caption.offset_bottom = caption_top + caption_height
	caption.add_theme_font_size_override("font_size", int(layout["lexicon_caption_size"]))
	hint.offset_left = callout_left + 4.0
	hint.offset_top = caption.offset_bottom - 1.0
	hint.offset_right = callout_right - 4.0
	hint.offset_bottom = hint.offset_top + hint_height
	hint.add_theme_font_size_override("font_size", int(layout["lexicon_hint_size"]))

	var backdrop := _ensure_lexicon_backdrop()
	backdrop.offset_left = callout_left
	backdrop.offset_top = caption_top - 6.0
	backdrop.offset_right = callout_right
	backdrop.offset_bottom = callout_bottom

func _main_button_layout(screen_size: Vector2) -> Dictionary:
	var compact: bool = screen_size.x < 700.0 or screen_size.y < 520.0
	var title_font_size: int = int(clampf(minf(screen_size.x * 0.09, screen_size.y * 0.095), 30.0, 48.0))
	var title_top: float = clampf(screen_size.y * (0.075 if compact else 0.095), 18.0, 64.0)
	var title_width: float = clampf(screen_size.x * 0.52, 220.0, 520.0)
	var button_width: float = clampf(screen_size.x * 0.42, 190.0, 232.0)
	var button_height: float = 55.0
	var gap: float = 5.0 if compact else 10.0
	var title_clearance: float = 20.0 if compact else 28.0
	var minimum_top: float = title_top + float(title_font_size) + title_clearance
	var bottom_margin: float = 18.0
	var available_height: float = screen_size.y - minimum_top - bottom_margin
	var stack_height: float = button_height * 4.0 + gap * 3.0
	if stack_height > available_height:
		button_height = maxf(36.0, (available_height - gap * 3.0) / 4.0)
		stack_height = button_height * 4.0 + gap * 3.0
	var desired_top: float = screen_size.y * 0.51 - stack_height * 0.5
	var maximum_top: float = maxf(minimum_top, screen_size.y - bottom_margin - stack_height)
	var buttons_top: float = clampf(desired_top, minimum_top, maximum_top)
	var lexicon_size: float
	if compact:
		lexicon_size = clampf(minf(screen_size.x, screen_size.y) * 0.145, 52.0, 68.0)
	else:
		lexicon_size = clampf(minf(screen_size.x, screen_size.y) * 0.135, 72.0, 96.0)
	var lexicon_margin: float = 12.0 if compact else 20.0
	return {
		"title_font_size": title_font_size,
		"title_top": title_top,
		"title_width": title_width,
		"button_width": button_width,
		"button_height": button_height,
		"gap": gap,
		"buttons_top": buttons_top,
		"stack_height": stack_height,
		"lexicon_size": lexicon_size,
		"lexicon_margin": lexicon_margin,
		"lexicon_callout_width": 124.0 if compact else 144.0,
		"lexicon_caption_size": 12 if compact else 15,
		"lexicon_hint_size": 8 if compact else 10
	}

func _layout_button(button: Control, center_x: float, top: float, width: float, height: float) -> void:
	button.offset_left = center_x - width * 0.5
	button.offset_top = top
	button.offset_right = center_x + width * 0.5
	button.offset_bottom = top + height
	button.custom_minimum_size = Vector2(width, height)

func _on_single_player_pressed() -> void:
	Global.apply_selected_loadout()
	get_tree().change_scene_to_file("res://scenes/world/preparation/preparation_hub.tscn")

func _on_lexikon_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/lexicon/lexikon.tscn")

func _on_vs_mode_pressed() -> void:
	var h = preload("res://hero_selection_menu.tscn").instantiate()
	h.setup(1)
	add_child(h)

func _on_vs_online_pressed() -> void:
	var h = preload("res://hero_selection_menu.tscn").instantiate()
	h.setup(2)
	add_child(h)

func _on_controls_pressed() -> void:
	var controls = preload("res://scenes/menus/controls/controls_menu.tscn").instantiate()
	add_child(controls)
	controls.tree_exited.connect(func(): $ControlsButton.grab_focus())
