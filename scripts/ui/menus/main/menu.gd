extends Control

const MENU_THEME = preload("res://assets/themes/global/global_theme.tres")
const MENU_FONT: FontFile = preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")
const DECORATIVE_FONT: FontFile = preload("res://assets/fonts/grenze_gotisch/GrenzeGotisch-Variable.ttf")
const HEADER_LOGO: Texture2D = preload("res://HeaderLogo.png")
const MULTIPLAYER_MENU = preload("res://scenes/menus/multiplayer_menu.tscn")
const SETTINGS_MENU = preload("res://scenes/menus/settings_menu.tscn")
const CONTROLS_ICON = preload("res://assets/sprites/ui/common/icon_controls.svg")
const SETTINGS_ICON = preload("res://assets/sprites/ui/common/icon_settings.svg")

@onready var single_player_button: Button = $SinglePlayerButton
@onready var local_multiplayer_button: Button = $LocalMultiplayerButton
@onready var online_multiplayer_button: Button = $OnlineMultiplayerButton
@onready var controls_button: Button = $ControlsButton
@onready var settings_button: Button = $SettingsButton
@onready var lexicon_button: TextureButton = $LexikonButton

func _ready() -> void:
	theme = MENU_THEME
	_configure_release_menu()
	single_player_button.pressed.connect(_on_single_player_pressed)
	local_multiplayer_button.pressed.connect(_on_local_multiplayer_pressed)
	online_multiplayer_button.pressed.connect(_on_online_multiplayer_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	lexicon_button.pressed.connect(_on_lexikon_pressed)
	_configure_focus_navigation()
	_configure_lexicon_action()
	_apply_display_font()
	get_tree().root.size_changed.connect(_layout_for_screen)
	call_deferred("_layout_for_screen")
	single_player_button.call_deferred("grab_focus")

func _configure_release_menu() -> void:
	$Label.visible = false
	_ensure_logo_header()
	single_player_button.text = "START EXPEDITION"
	single_player_button.tooltip_text = "Enter the overworld and choose your expedition."

	local_multiplayer_button.text = "LOCAL MULTIPLAYER"
	local_multiplayer_button.tooltip_text = "Play local co-op Exploration or local Maze Builder VS."
	online_multiplayer_button.text = "ONLINE MULTIPLAYER"
	online_multiplayer_button.tooltip_text = "Host your stronghold with a private password or join a friend online."

	_configure_utility_button(controls_button, CONTROLS_ICON, "CONTROLS")
	_configure_utility_button(settings_button, SETTINGS_ICON, "SETTINGS")

	var tagline := get_node_or_null("ReleaseTagline") as Label
	if tagline == null:
		tagline = Label.new()
		tagline.name = "ReleaseTagline"
		tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tagline.add_theme_font_size_override("font_size", 14)
		tagline.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0, 0.94))
		tagline.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 0.96))
		tagline.add_theme_constant_override("outline_size", 3)
		add_child(tagline)
	tagline.text = ""
	tagline.visible = false

func _apply_display_font() -> void:
	var button_font := _make_font_variation(MENU_FONT, 900.0, 0.85)
	var detail_font := _make_font_variation(MENU_FONT, 650.0, 0.15)
	var decorative_heading := _make_font_variation(DECORATIVE_FONT, 760.0)
	var decorative_detail := _make_font_variation(DECORATIVE_FONT, 600.0)

	for button in [single_player_button, local_multiplayer_button, online_multiplayer_button]:
		button.add_theme_font_override("font", button_font)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.82, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 0.72, 0.32, 1.0))
		button.add_theme_color_override("font_focus_color", Color(0.73, 0.93, 1.0, 1.0))
		button.add_theme_color_override("font_outline_color", Color(0.03, 0.012, 0.006, 0.98))
		button.add_theme_constant_override("outline_size", 3)
		button.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
		button.add_theme_constant_override("shadow_offset_x", 1)
		button.add_theme_constant_override("shadow_offset_y", 2)
		button.add_theme_constant_override("shadow_outline_size", 1)

	var tagline := get_node_or_null("ReleaseTagline") as Label
	if tagline:
		tagline.add_theme_font_override("font", detail_font)

	var lexicon_caption := _ensure_lexicon_caption()
	lexicon_caption.add_theme_font_override("font", decorative_heading)
	var lexicon_hint := _ensure_lexicon_hint()
	lexicon_hint.add_theme_font_override("font", decorative_detail)

func _make_font_variation(base_font: Font, weight: float, embolden: float = 0.0) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = base_font
	font.variation_opentype = {"wght": weight}
	font.variation_embolden = embolden
	return font

func _ensure_logo_header() -> TextureRect:
	var existing := get_node_or_null("LogoHeader") as TextureRect
	if existing != null:
		return existing
	var logo := TextureRect.new()
	logo.name = "LogoHeader"
	logo.texture = HEADER_LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.z_index = 4
	add_child(logo)
	return logo

func _configure_utility_button(button: Button, icon_texture: Texture2D, tooltip: String) -> void:
	button.text = ""
	button.icon = icon_texture
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.z_index = 5
	button.add_theme_constant_override("icon_max_width", 34)
	button.add_theme_constant_override("icon_spacing", 0)
	button.add_theme_stylebox_override("normal", _utility_style(Color(0.075, 0.035, 0.018, 0.94), Color(0.48, 0.34, 0.22, 1.0), 2))
	button.add_theme_stylebox_override("hover", _utility_style(Color(0.13, 0.065, 0.025, 0.98), Color(1.0, 0.64, 0.18, 1.0), 3))
	button.add_theme_stylebox_override("pressed", _utility_style(Color(0.035, 0.018, 0.012, 1.0), Color(0.88, 0.42, 0.1, 1.0), 3))
	button.add_theme_stylebox_override("focus", _utility_style(Color(0.11, 0.055, 0.022, 0.98), Color(0.45, 0.88, 1.0, 1.0), 3))
	button.mouse_entered.connect(_set_utility_emphasis.bind(button, true))
	button.mouse_exited.connect(_set_utility_emphasis.bind(button, false))
	button.focus_entered.connect(_set_utility_emphasis.bind(button, true))
	button.focus_exited.connect(_set_utility_emphasis.bind(button, false))

func _utility_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(9)
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0.0, 3.0)
	return style

func _set_utility_emphasis(button: Button, enabled: bool) -> void:
	if not is_instance_valid(button):
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2(1.08, 1.08) if enabled else Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", Color(1.08, 1.02, 0.82, 1.0) if enabled else Color.WHITE, 0.12)

func _configure_focus_navigation() -> void:
	single_player_button.focus_neighbor_bottom = local_multiplayer_button.get_path()
	local_multiplayer_button.focus_neighbor_top = single_player_button.get_path()
	local_multiplayer_button.focus_neighbor_bottom = online_multiplayer_button.get_path()
	online_multiplayer_button.focus_neighbor_top = local_multiplayer_button.get_path()
	online_multiplayer_button.focus_neighbor_bottom = controls_button.get_path()

	for button in [single_player_button, local_multiplayer_button, online_multiplayer_button]:
		button.focus_neighbor_right = controls_button.get_path()

	controls_button.focus_neighbor_top = online_multiplayer_button.get_path()
	controls_button.focus_neighbor_bottom = settings_button.get_path()
	controls_button.focus_neighbor_left = single_player_button.get_path()
	controls_button.focus_neighbor_right = settings_button.get_path()
	settings_button.focus_neighbor_top = controls_button.get_path()
	settings_button.focus_neighbor_bottom = lexicon_button.get_path()
	settings_button.focus_neighbor_left = controls_button.get_path()
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

	var logo_width := float(layout["logo_width"])
	var logo_height := float(layout["logo_height"])
	var logo := _ensure_logo_header()
	logo.offset_left = center_x - logo_width * 0.5
	logo.offset_top = title_top
	logo.offset_right = center_x + logo_width * 0.5
	logo.offset_bottom = title_top + logo_height

	# Keep the legacy title node as a hidden layout anchor for existing tests/tools.
	$Label.visible = false
	$Label.offset_left = logo.offset_left
	$Label.offset_top = logo.offset_top
	$Label.offset_right = logo.offset_right
	$Label.offset_bottom = logo.offset_bottom
	$Label.add_theme_font_size_override("font_size", title_font_size)

	var tagline := get_node_or_null("ReleaseTagline") as Label
	if tagline:
		tagline.offset_left = center_x - title_width * 0.5
		tagline.offset_top = logo.offset_bottom - 7.0
		tagline.offset_right = center_x + title_width * 0.5
		tagline.offset_bottom = tagline.offset_top + 22.0

	var panel := $MenuPanel as Sprite2D
	panel.position = Vector2(center_x, screen_size.y * 0.55)
	var panel_scale := clampf(minf(screen_size.x / 820.0, screen_size.y / 650.0), 0.42, 0.96)
	var texture_height := maxf(float(panel.texture.get_height()), 1.0) if panel.texture else 314.0
	var desired_panel_height := float(layout["stack_height"]) + 90.0
	var panel_y_scale := maxf(panel_scale * 0.88, desired_panel_height / texture_height)
	var panel_x_scale := panel_scale * (0.82 if bool(layout["compact"]) else 0.86)
	panel.scale = Vector2(panel_x_scale, panel_y_scale)
	var nested_panel := panel.get_node_or_null("MenuPanel")
	if nested_panel != null:
		nested_panel.visible = false

	var game_mode_buttons: Array[Button] = [
		single_player_button,
		local_multiplayer_button,
		online_multiplayer_button,
	]
	for index in game_mode_buttons.size():
		_layout_button(game_mode_buttons[index], center_x, buttons_top + float(index) * (button_height + gap), button_width, button_height)

	_layout_utility_buttons(screen_size, layout)
	_layout_lexicon(screen_size, layout)

func _layout_utility_buttons(screen_size: Vector2, layout: Dictionary) -> void:
	var icon_size := float(layout["utility_icon_size"])
	var icon_gap := float(layout["utility_icon_gap"])
	var margin := float(layout["utility_margin"])
	var compact := bool(layout["compact"])
	var settings_left := screen_size.x - margin - icon_size
	var controls_left := settings_left - icon_size - icon_gap
	var top := margin

	if compact:
		controls_left = settings_left
		_layout_icon_button(controls_button, controls_left, top, icon_size)
		_layout_icon_button(settings_button, settings_left, top + icon_size + icon_gap, icon_size)
	else:
		_layout_icon_button(controls_button, controls_left, top, icon_size)
		_layout_icon_button(settings_button, settings_left, top, icon_size)

func _layout_icon_button(button: Button, left: float, top: float, size: float) -> void:
	button.offset_left = left
	button.offset_top = top
	button.offset_right = left + size
	button.offset_bottom = top + size
	button.custom_minimum_size = Vector2(size, size)
	button.pivot_offset = Vector2(size * 0.5, size * 0.5)
	button.add_theme_constant_override("icon_max_width", maxi(24, int(size * 0.62)))

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
	var title_top := clampf(screen_size.y * (0.032 if compact else 0.035), 10.0, 28.0)
	var logo_width := clampf(screen_size.x * (0.50 if compact else 0.30), 210.0, 340.0)
	var logo_aspect := float(HEADER_LOGO.get_width()) / maxf(float(HEADER_LOGO.get_height()), 1.0)
	var logo_height := logo_width / maxf(logo_aspect, 1.0)
	var title_width := logo_width
	var button_width := clampf(screen_size.x * 0.40, 218.0, 252.0)
	var button_height := 50.0 if compact else 58.0
	var gap := 9.0 if compact else 12.0
	var minimum_top := title_top + logo_height + (8.0 if compact else 12.0)
	var available_height := screen_size.y - minimum_top - 18.0
	var button_count := 3.0
	var stack_height := button_height * button_count + gap * (button_count - 1.0)
	if stack_height > available_height:
		button_height = maxf(36.0, (available_height - gap * (button_count - 1.0)) / button_count)
		stack_height = button_height * button_count + gap * (button_count - 1.0)
	var desired_top := screen_size.y * 0.535 - stack_height * 0.5
	var maximum_top := maxf(minimum_top, screen_size.y - 18.0 - stack_height)
	return {
		"compact": compact,
		"title_font_size": title_font_size,
		"title_top": title_top,
		"title_width": title_width,
		"logo_width": logo_width,
		"logo_height": logo_height,
		"button_width": button_width,
		"button_height": button_height,
		"gap": gap,
		"buttons_top": clampf(desired_top, minimum_top, maximum_top),
		"stack_height": stack_height,
		"utility_icon_size": 46.0 if compact else 56.0,
		"utility_icon_gap": 8.0 if compact else 10.0,
		"utility_margin": 12.0 if compact else 20.0,
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
	# Start Expedition always opens the overworld first. The player chooses the
	# actual expedition destination from there.
	GameMode.set_mode(GameMode.Mode.SIEGE)
	Global.apply_selected_loadout()
	get_tree().change_scene_to_file("res://scenes/world/preparation/preparation_hub.tscn")

func _open_multiplayer_menu(use_online_mode: bool) -> void:
	var multiplayer_menu = MULTIPLAYER_MENU.instantiate()
	multiplayer_menu.setup(use_online_mode)
	add_child(multiplayer_menu)
	multiplayer_menu.tree_exited.connect(func():
		if not is_instance_valid(self) or not is_inside_tree():
			return
		var target := local_multiplayer_button if not use_online_mode else online_multiplayer_button
		if is_instance_valid(target) and target.is_inside_tree():
			target.grab_focus()
	)

func _on_local_multiplayer_pressed() -> void:
	# Local multiplayer begins inside the shared physical stronghold.
	GameMode.set_mode(GameMode.Mode.HUB)
	Global.apply_selected_loadout()
	get_tree().change_scene_to_file("res://scenes/world/preparation/local_multiplayer_hub.tscn")

func _on_online_multiplayer_pressed() -> void:
	# Online multiplayer now begins with a private hosted stronghold instead of
	# choosing a mode in a disconnected menu first.
	GameMode.set_mode(GameMode.Mode.HUB)
	Global.apply_selected_loadout()
	get_tree().change_scene_to_file("res://online_lobby.tscn")

func _on_controls_pressed() -> void:
	var controls = preload("res://scenes/menus/controls/controls_menu.tscn").instantiate()
	add_child(controls)
	controls.tree_exited.connect(func():
		if is_instance_valid(controls_button) and controls_button.is_inside_tree():
			controls_button.grab_focus()
	)

func _on_settings_pressed() -> void:
	var settings = SETTINGS_MENU.instantiate()
	add_child(settings)
	settings.tree_exited.connect(func():
		if is_instance_valid(settings_button) and settings_button.is_inside_tree():
			settings_button.grab_focus()
	)

func _on_lexikon_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/lexicon/lexikon.tscn")
