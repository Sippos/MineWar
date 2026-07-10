extends Control

const MENU_THEME = preload("res://global_theme.tres")

func _ready() -> void:
	theme = MENU_THEME
	$VSOnlineButton.pressed.connect(_on_vs_online_pressed)
	$VSModeButton.pressed.connect(_on_vs_mode_pressed)
	$SinglePlayerButton.pressed.connect(_on_single_player_pressed)
	$LexikonButton.pressed.connect(_on_lexikon_pressed)
	$ControlsButton.pressed.connect(_on_controls_pressed)
	get_tree().root.size_changed.connect(_layout_for_screen)
	call_deferred("_layout_for_screen")
	$SinglePlayerButton.call_deferred("grab_focus")

func _layout_for_screen() -> void:
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var compact = screen_size.x < 700.0 or screen_size.y < 520.0
	var center_x = screen_size.x * 0.5
	var title_font_size = int(clamp(min(screen_size.x * 0.13, screen_size.y * 0.14), 34.0, 60.0))
	var button_w = clamp(screen_size.x * 0.72, 210.0, 280.0)
	var button_h = 46.0 if compact else 60.0
	var gap = 8.0 if compact else 12.0
	var title_top = clamp(screen_size.y * 0.08, 18.0, 70.0)
	var buttons_top = title_top + title_font_size + (18.0 if compact else 34.0)
	if buttons_top + button_h * 4.0 + gap * 3.0 > screen_size.y - 24.0:
		button_h = max(38.0, (screen_size.y - buttons_top - 24.0 - gap * 3.0) / 4.0)
	
	$Label.offset_left = 12.0
	$Label.offset_top = title_top
	$Label.offset_right = screen_size.x - 12.0
	$Label.offset_bottom = title_top + title_font_size + 12.0
	$Label.add_theme_font_size_override("font_size", title_font_size)
	
	var panel = $MenuPanel
	panel.position = Vector2(center_x, screen_size.y * 0.5)
	var panel_scale = clamp(min(screen_size.x / 820.0, screen_size.y / 650.0), 0.42, 0.96)
	panel.scale = Vector2(panel_scale, panel_scale * 1.18)
	var nested_panel = panel.get_node_or_null("MenuPanel")
	if nested_panel:
		nested_panel.visible = false
	
	_layout_button($SinglePlayerButton, center_x, buttons_top, button_w, button_h)
	_layout_button($VSModeButton, center_x, buttons_top + (button_h + gap), button_w, button_h)
	_layout_button($VSOnlineButton, center_x, buttons_top + (button_h + gap) * 2.0, button_w, button_h)
	_layout_button($ControlsButton, center_x, buttons_top + (button_h + gap) * 3.0, button_w, button_h)
	
	var lex_size = clamp(min(screen_size.x, screen_size.y) * 0.12, 48.0, 96.0)
	$LexikonButton.offset_left = screen_size.x - lex_size - 18.0
	$LexikonButton.offset_top = screen_size.y - lex_size - 18.0
	$LexikonButton.offset_right = screen_size.x - 18.0
	$LexikonButton.offset_bottom = screen_size.y - 18.0

func _layout_button(button: Control, center_x: float, top: float, width: float, height: float) -> void:
	button.offset_left = center_x - width * 0.5
	button.offset_top = top
	button.offset_right = center_x + width * 0.5
	button.offset_bottom = top + height
	button.custom_minimum_size = Vector2(width, height)

func _on_single_player_pressed() -> void:
	var h = preload("res://hero_selection_menu.tscn").instantiate()
	h.setup(0) # Mode.SINGLE_PLAYER
	add_child(h)

func _on_lexikon_pressed() -> void:
	get_tree().change_scene_to_file("res://lexikon.tscn")

func _on_vs_mode_pressed() -> void:
	var h = preload("res://hero_selection_menu.tscn").instantiate()
	h.setup(1) # Mode.VS_LOCAL
	add_child(h)

func _on_vs_online_pressed() -> void:
	var h = preload("res://hero_selection_menu.tscn").instantiate()
	h.setup(2) # Mode.VS_ONLINE
	add_child(h)

func _on_controls_pressed() -> void:
	var controls = preload("res://scenes/menus/controls/controls_menu.tscn").instantiate()
	add_child(controls)
	controls.tree_exited.connect(func(): $ControlsButton.grab_focus())
