extends Control

const MENU_THEME = preload("res://assets/themes/global/global_theme.tres")
const MULTIPLAYER_MENU = preload("res://scenes/menus/multiplayer_menu.tscn")
const SETTINGS_MENU = preload("res://scenes/menus/settings_menu.tscn")

@onready var single_player_button: Button = $SinglePlayerButton
@onready var local_multiplayer_button: Button = $LocalMultiplayerButton
@onready var online_multiplayer_button: Button = $OnlineMultiplayerButton
@onready var controls_button: Button = $ControlsButton
@onready var settings_button: Button = $SettingsButton
@onready var lexicon_button: TextureButton = $LexikonButton

func _ready() -> void:
	theme = MENU_THEME
	single_player_button.pressed.connect(_on_single_player_pressed)
	local_multiplayer_button.pressed.connect(_on_local_multiplayer_pressed)
	online_multiplayer_button.pressed.connect(_on_online_multiplayer_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	lexicon_button.pressed.connect(_on_lexikon_pressed)
	_configure_focus_navigation()
	_configure_lexicon_action()
	get_tree().root.size_changed.connect(_layout_for_screen)
	call_deferred("_layout_for_screen")
	single_player_button.call_deferred("grab_focus")

func _configure_focus_navigation() -> void:
	var buttons: Array[Button] = [
		single_player_button,
		local_multiplayer_button,
		online_multiplayer_button,
		controls_button,
		settings_button,
	]
	for index in buttons.size():
		if index > 0:
			buttons[index].focus_neighbor_top = buttons[index - 1].get_path()
		if index < buttons.size() - 1:
			buttons[index].focus_neighbor_bottom = buttons[index + 1].get_path()
	settings_button.focus_neighbor_bottom = lexicon_button.get_path()
	lexicon_button.focus_neighbor_top = settings_button.get_path()

func _configure_lexicon_action() -> void:
	_ensure_lexicon_backdrop()
	_ensure_lexicon_caption()
	_ensure_lexicon_hint()
	lexicon_button.tooltip_text = "Bestiary — Heroes, Bases, and Monsters"
	lexicon_button.focus_mode = Control.FOCUS_ALL
	lexicon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	lexicon_button.z_index = 2
	lexicon_button.mouse_entered.connect(_set_lexicon_emphasis.bind(true))
	lexicon_button.mouse_exited.connect(_set_lexicon_emphasis.bind(false))
	lexicon_button.focus_entered.connect(_set_lexicon_emphasis.bind(true))
	lexicon_button.focus_exited.connect(_set_lexicon_emphasis.bind(false))

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
	var backdrop := _ensure_lexicon_backdrop()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(lexicon_button, "scale", Vector2(1.1, 1.1) if enabled else Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(backdrop, "modulate", Color(1.0, 0.9, 0.72, 1.0) if enabled else Color.WHITE, 0.14)

func _layout_for_screen(screen_size_override: Vector2 = Vector2.ZERO) -> void:
	var screen_size := screen_size_override
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var layout := _main_button_layout(screen_size)
	var center_x := screen_size.x * 0.5
	var title_font_size := int(layout["title_font_size"])
	var title_top := float(layout["title_top"])
	var title_width := float(layout["title_width"])
	var button_width := float(layout["button_width"])
	var button_height := float(layout["button_height"])
	var gap := float(layout["gap"])
	var buttons_top := float(layout["buttons_top"])

	$Label.offset_left = center_x - title_width * 0.5
	$Label.offset_top = title_top
	$Label.offset_right = center_x + title_width * 0.5
	$Label.offset_bottom = title_top + float(title_font_size) + 8.0
	$Label.add_theme_font_size_override("font_size", title_font_size)
	$Label.add_theme_constant_override("outline_size", 4)

	var panel := $MenuPanel as Sprite2D
	panel.position = Vector2(center_x, screen_size.y * 0.5)
	var panel_scale := clampf(minf(screen_size.x / 820.0, screen_size.y / 650.0), 0.42, 0.96)
	panel.scale = Vector2(panel_scale, panel_scale * 1.18)
	var nested_panel := panel.get_node_or_null("MenuPanel")
	if nested_panel != null:
		nested_panel.visible = false

	var buttons: Array[Button] = [single_player_button, local_multiplayer_button, online_multiplayer_button, controls_button, settings_button]
	for index in buttons.size():
		_layout_button(buttons[index], center_x, buttons_top + float(index) * (button_height + gap), button_width, button_height)

	_layout_lexicon(screen_size, layout)

func _layout_lexicon(screen_size: Vector2, layout: Dictionary) -> void:
	var lex_size := float(layout["lexicon_size"])
	var lex_margin := float(layout["lexicon_margin"])
	var callout_width := float(layout["lexicon_callout_width"])
	var callout_right := screen_size.x - lex_margin
	var callout_left := maxf(8.0, callout_right - callout_width)
	var callout_center := (callout_left + callout_right) * 0.5
	var callout_bottom := screen_size.y - lex_margin
	var lex_bottom := callout_bottom - 8.0
	var lex_top := lex_bottom - lex_size
	lexicon_button.offset_left = callout_center - lex_size * 0.5
	lexicon_button.offset_top = lex_top
	lexicon_button.offset_right = callout_center + lex_size * 0.5
	lexicon_button.offset_bottom = lex_bottom
	lexicon_button.custom_minimum_size = Vector2(lex_size, lex_size)
	lexicon_button.pivot_offset = Vector2(lex_size * 0.5, lex_size * 0.5)

	var caption := _ensure_lexicon_caption()
	var hint := _ensure_lexicon_hint()
	var caption_top := maxf(8.0, lex_top - 42.0)
	caption.offset_left = callout_left + 5.0
	caption.offset_top = caption_top
	caption.offset_right = callout_right - 5.0
	caption.offset_bottom = caption_top + 22.0
	caption.add_theme_font_size_override("font_size", int(layout["lexicon_caption_size"]))
	hint.offset_left = callout_left + 4.0
	hint.offset_top = caption.offset_bottom - 1.0
	hint.offset_right = callout_right - 4.0
	hint.offset_bottom = hint.offset_top + 15.0
	hint.add_theme_font_size_override("font_size", int(layout["lexicon_hint_size"]))
	var backdrop := _ensure_lexicon_backdrop()
	backdrop.offset_left = callout_left
	backdrop.offset_top = caption_top - 6.0
	backdrop.offset_right = callout_right
	backdrop.offset_bottom = callout_bottom

func _main_button_layout(screen_size: Vector2) -> Dictionary:
	var compact := screen_size.x < 700.0 or screen_size.y < 520.0
	var title_font_size := int(clampf(minf(screen_size.x * 0.09, screen_size.y * 0.095), 30.0, 48.0))
	var title_top := clampf(screen_size.y * (0.075 if compact else 0.095), 18.0, 64.0)
	var title_width := clampf(screen_size.x * 0.52, 220.0, 520.0)
	var button_width := clampf(screen_size.x * 0.42, 190.0, 245.0)
	var button_height := 52.0
	var gap := 4.0 if compact else 8.0
	var minimum_top := title_top + float(title_font_size) + (18.0 if compact else 25.0)
	var available_height := screen_size.y - minimum_top - 18.0
	var stack_height := button_height * 5.0 + gap * 4.0
	if stack_height > available_height:
		button_height = maxf(34.0, (available_height - gap * 4.0) / 5.0)
		stack_height = button_height * 5.0 + gap * 4.0
	var desired_top := screen_size.y * 0.51 - stack_height * 0.5
	var maximum_top := maxf(minimum_top, screen_size.y - 18.0 - stack_height)
	return {
		"title_font_size": title_font_size,
		"title_top": title_top,
		"title_width": title_width,
		"button_width": button_width,
		"button_height": button_height,
		"gap": gap,
		"buttons_top": clampf(desired_top, minimum_top, maximum_top),
		"stack_height": stack_height,
		"lexicon_size": clampf(minf(screen_size.x, screen_size.y) * 0.145, 52.0, 68.0) if compact else clampf(minf(screen_size.x, screen_size.y) * 0.135, 72.0, 96.0),
		"lexicon_margin": 12.0 if compact else 20.0,
		"lexicon_callout_width": 124.0 if compact else 144.0,
		"lexicon_caption_size": 12 if compact else 15,
		"lexicon_hint_size": 8 if compact else 10,
	}

func _layout_button(button: Control, center_x: float, top: float, width: float, height: float) -> void:
	button.offset_left = center_x - width * 0.5
	button.offset_top = top
	button.offset_right = center_x + width * 0.5
	button.offset_bottom = top + height
	button.custom_minimum_size = Vector2(width, height)

func _on_single_player_pressed() -> void:
	# Single Player always enters the shared overworld. The player chooses the
	# actual destination physically from there.
	GameMode.set_mode(GameMode.Mode.SIEGE)
	Global.apply_selected_loadout()
	get_tree().change_scene_to_file("res://scenes/world/preparation/preparation_hub.tscn")

func _open_multiplayer_menu(use_online_mode: bool) -> void:
	var multiplayer_menu = MULTIPLAYER_MENU.instantiate()
	multiplayer_menu.setup(use_online_mode)
	add_child(multiplayer_menu)
	multiplayer_menu.tree_exited.connect(func():
		if is_instance_valid(self):
			(local_multiplayer_button if not use_online_mode else online_multiplayer_button).grab_focus()
	)

func _on_local_multiplayer_pressed() -> void:
	_open_multiplayer_menu(false)

func _on_online_multiplayer_pressed() -> void:
	_open_multiplayer_menu(true)

func _on_controls_pressed() -> void:
	var controls = preload("res://scenes/menus/controls/controls_menu.tscn").instantiate()
	add_child(controls)
	controls.tree_exited.connect(func(): controls_button.grab_focus())

func _on_settings_pressed() -> void:
	var settings = SETTINGS_MENU.instantiate()
	add_child(settings)
	settings.tree_exited.connect(func(): settings_button.grab_focus())

func _on_lexikon_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/lexicon/lexikon.tscn")
