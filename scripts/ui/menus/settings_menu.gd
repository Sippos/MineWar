extends Control

const MenuTypography = preload("res://scripts/ui/menus/menu_typography.gd")
const MENU_THEME: Theme = preload("res://assets/themes/global/global_theme.tres")
const SETTINGS_PATH := "user://minewars_settings.cfg"

const MODE_WINDOWED := 0
const MODE_BORDERLESS := 1
const MODE_FULLSCREEN := 2

const COMMON_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const FPS_LIMITS: Array[int] = [60, 120, 144, 0]

@onready var panel: PanelContainer = $Dimmer/Center/Panel
@onready var vbox: VBoxContainer = $Dimmer/Center/Panel/VBox
@onready var header: HBoxContainer = $Dimmer/Center/Panel/VBox/Header
@onready var header_spacer: Control = $Dimmer/Center/Panel/VBox/Header/HeaderSpacerLeft
@onready var title_label: Label = $Dimmer/Center/Panel/VBox/Header/Title
@onready var header_icon: TextureRect = $Dimmer/Center/Panel/VBox/Header/HeaderIcon

@onready var window_mode_row: PanelContainer = $Dimmer/Center/Panel/VBox/WindowModeRow
@onready var resolution_row: PanelContainer = $Dimmer/Center/Panel/VBox/ResolutionRow
@onready var vsync_row: PanelContainer = $Dimmer/Center/Panel/VBox/VSyncRow
@onready var fps_row: PanelContainer = $Dimmer/Center/Panel/VBox/FPSRow
@onready var volume_row: PanelContainer = $Dimmer/Center/Panel/VBox/VolumeRow

@onready var window_mode_option: OptionButton = $Dimmer/Center/Panel/VBox/WindowModeRow/Content/WindowModeOption
@onready var resolution_option: OptionButton = $Dimmer/Center/Panel/VBox/ResolutionRow/Content/ResolutionOption
@onready var vsync_toggle: Button = $Dimmer/Center/Panel/VBox/VSyncRow/Content/VSyncToggle
@onready var fps_option: OptionButton = $Dimmer/Center/Panel/VBox/FPSRow/Content/FPSOption
@onready var volume_slider: HSlider = $Dimmer/Center/Panel/VBox/VolumeRow/Content/VolumeSlider
@onready var volume_value: Label = $Dimmer/Center/Panel/VBox/VolumeRow/Content/VolumeValue
@onready var hint_label: Label = $Dimmer/Center/Panel/VBox/Hint
@onready var back_button: Button = $Dimmer/Center/Panel/VBox/BackButton

var _loading := false
var _closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_menu_typography()
	z_index = 100
	theme = MENU_THEME
	_configure_window_modes()
	_configure_resolutions()
	_configure_fps_limits()
	_configure_toggle_style()
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	vsync_toggle.toggled.connect(_on_vsync_toggled)
	fps_option.item_selected.connect(_on_fps_selected)
	volume_slider.value_changed.connect(_on_volume_changed)
	back_button.pressed.connect(_on_back_pressed)
	get_tree().root.size_changed.connect(_layout_for_screen)
	_load_settings()
	_layout_for_screen()
	window_mode_option.call_deferred("grab_focus")


func _apply_menu_typography() -> void:
	MenuTypography.apply_title_style(title_label, 28)
	MenuTypography.apply_detail_style(hint_label, 14)
	MenuTypography.apply_primary_button_style(back_button, 18)
	back_button.custom_minimum_size.y = 68


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _configure_window_modes() -> void:
	window_mode_option.clear()
	window_mode_option.add_item("WINDOWED", MODE_WINDOWED)
	window_mode_option.add_item("BROWSER FULLSCREEN" if OS.has_feature("web") else "BORDERLESS", MODE_BORDERLESS)
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		window_mode_option.add_item("FULLSCREEN", MODE_FULLSCREEN)
	window_mode_option.tooltip_text = "Choose how MineWars uses your display."


func _configure_resolutions() -> void:
	resolution_option.clear()
	var current_size: Vector2i = DisplayServer.window_get_size()
	var screen_index: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_index)
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = Vector2i(get_viewport().get_visible_rect().size)

	var added: Dictionary = {}
	for resolution: Vector2i in COMMON_RESOLUTIONS:
		if resolution.x <= screen_size.x and resolution.y <= screen_size.y:
			_add_resolution_option(resolution)
			added[resolution] = true
	if not added.has(current_size):
		_add_resolution_option(current_size)
	resolution_option.tooltip_text = "Window size used in Windowed mode."


func _add_resolution_option(resolution: Vector2i) -> void:
	var label := "%d × %d" % [resolution.x, resolution.y]
	resolution_option.add_item(label)
	resolution_option.set_item_metadata(resolution_option.item_count - 1, resolution)


func _configure_fps_limits() -> void:
	fps_option.clear()
	for limit: int in FPS_LIMITS:
		fps_option.add_item("UNLIMITED" if limit == 0 else "%d FPS" % limit)
		fps_option.set_item_metadata(fps_option.item_count - 1, limit)
	fps_option.tooltip_text = "Limits rendering speed to reduce heat and power use."


func _configure_toggle_style() -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.12, 0.055, 0.025, 0.98)
	normal_style.border_color = Color(0.65, 0.35, 0.14, 1.0)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(7)
	normal_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	normal_style.shadow_size = 3

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.border_color = Color(1.0, 0.72, 0.28, 1.0)
	hover_style.bg_color = Color(0.18, 0.08, 0.03, 1.0)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.055, 0.2, 0.24, 0.98)
	pressed_style.border_color = Color(0.42, 0.9, 1.0, 1.0)

	vsync_toggle.add_theme_stylebox_override("normal", normal_style)
	vsync_toggle.add_theme_stylebox_override("hover", hover_style)
	vsync_toggle.add_theme_stylebox_override("focus", hover_style)
	vsync_toggle.add_theme_stylebox_override("pressed", pressed_style)
	vsync_toggle.add_theme_stylebox_override("hover_pressed", pressed_style)
	vsync_toggle.add_theme_font_override("font", MenuTypography.primary_button_font())
	vsync_toggle.add_theme_font_size_override("font_size", 15)
	vsync_toggle.add_theme_color_override("font_color", Color(0.92, 0.68, 0.4, 1.0))
	vsync_toggle.add_theme_color_override("font_pressed_color", Color(0.62, 0.94, 1.0, 1.0))
	vsync_toggle.add_theme_color_override("font_hover_pressed_color", Color(0.75, 0.97, 1.0, 1.0))
	vsync_toggle.add_theme_color_override("font_outline_color", Color(0.03, 0.012, 0.006, 0.98))
	vsync_toggle.add_theme_constant_override("outline_size", 2)


func _layout_for_screen() -> void:
	if panel == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var compact: bool = viewport_size.x < 700.0 or viewport_size.y < 540.0
	var panel_width: float = minf(660.0, maxf(300.0, viewport_size.x - 24.0))
	var panel_height: float = minf(550.0, maxf(300.0, viewport_size.y - 24.0))
	panel.custom_minimum_size = Vector2(panel_width, panel_height)

	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxTexture
	if panel_style != null:
		panel_style.content_margin_left = 26.0 if compact else 48.0
		panel_style.content_margin_right = 26.0 if compact else 48.0
		panel_style.content_margin_top = 22.0 if compact else 34.0
		panel_style.content_margin_bottom = 22.0 if compact else 34.0

	vbox.add_theme_constant_override("separation", 4 if compact else 8)
	header.custom_minimum_size.y = 34.0 if compact else 48.0
	MenuTypography.apply_title_style(title_label, 22 if compact else 28)
	var icon_size: float = 26.0 if compact else 32.0
	header_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	header_spacer.custom_minimum_size = Vector2(icon_size, 0.0)

	var rows: Array[PanelContainer] = [window_mode_row, resolution_row, vsync_row, fps_row, volume_row]
	var row_height: float = 44.0 if compact else 56.0
	for row: PanelContainer in rows:
		row.custom_minimum_size.y = row_height
		var row_content := row.get_node("Content") as HBoxContainer
		row_content.add_theme_constant_override("separation", 6 if compact else 10)
		var row_icon := row_content.get_node("Icon") as Control
		row_icon.custom_minimum_size = Vector2(24.0 if compact else 32.0, 24.0 if compact else 32.0)
		var row_label := row_content.get_node("Label") as Label
		row_label.custom_minimum_size.x = 102.0 if compact else 165.0
		# Same heavy Cinzel as Main Menu buttons so labels stay readable
		row_label.add_theme_font_override("font", MenuTypography.primary_button_font())
		row_label.add_theme_font_size_override("font_size", 13 if compact else 16)
		row_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72, 1.0))
		row_label.add_theme_color_override("font_outline_color", Color(0.03, 0.012, 0.006, 0.98))
		row_label.add_theme_constant_override("outline_size", 3)

	var opt_h := 40.0 if compact else 48.0
	window_mode_option.custom_minimum_size = Vector2(132.0 if compact else 240.0, opt_h)
	resolution_option.custom_minimum_size = window_mode_option.custom_minimum_size
	fps_option.custom_minimum_size = window_mode_option.custom_minimum_size
	vsync_toggle.custom_minimum_size = Vector2(68.0 if compact else 88.0, opt_h)
	var opt_font := 13 if compact else 15
	for opt in [window_mode_option, resolution_option, fps_option]:
		MenuTypography.apply_option_style(opt, opt_font)
	volume_slider.custom_minimum_size = Vector2(92.0 if compact else 150.0, 28.0 if compact else 34.0)
	volume_value.custom_minimum_size.x = 42.0 if compact else 54.0
	volume_value.add_theme_font_override("font", MenuTypography.primary_button_font())
	volume_value.add_theme_font_size_override("font_size", 13 if compact else 16)
	volume_value.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8, 1.0))
	volume_value.add_theme_color_override("font_outline_color", Color(0.03, 0.012, 0.006, 0.98))
	volume_value.add_theme_constant_override("outline_size", 2)
	hint_label.visible = not compact or viewport_size.y >= 430.0
	hint_label.custom_minimum_size.y = 18.0 if compact else 22.0
	MenuTypography.apply_detail_style(hint_label, 11 if compact else 14)
	back_button.custom_minimum_size = Vector2(minf(340.0, panel_width - 90.0), 56.0 if compact else 68.0)
	MenuTypography.apply_primary_button_style(back_button, 16 if compact else 18)


func _load_settings() -> void:
	_loading = true
	var config := ConfigFile.new()
	var load_result: Error = config.load(SETTINGS_PATH)
	var mode_value: int = _current_window_mode_id()
	var resolution_value: Vector2i = DisplayServer.window_get_size()
	var vsync_value: bool = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	var fps_value: int = Engine.max_fps if Engine.max_fps > 0 else 0
	var volume_default: float = 100.0

	if load_result == OK:
		if config.has_section_key("display", "window_mode"):
			mode_value = int(config.get_value("display", "window_mode", mode_value))
		elif config.has_section_key("display", "fullscreen"):
			mode_value = MODE_BORDERLESS if bool(config.get_value("display", "fullscreen", false)) else MODE_WINDOWED
		var saved_resolution: Variant = config.get_value("display", "resolution", resolution_value)
		if saved_resolution is Vector2i:
			resolution_value = saved_resolution as Vector2i
		vsync_value = bool(config.get_value("display", "vsync", vsync_value))
		fps_value = int(config.get_value("display", "fps_limit", fps_value))
		volume_default = float(config.get_value("audio", "master_volume", volume_default))

	_select_window_mode(mode_value)
	_select_resolution(resolution_value)
	_select_fps_limit(fps_value)
	vsync_toggle.button_pressed = vsync_value
	volume_slider.value = volume_default
	_loading = false

	_apply_window_mode(_selected_window_mode())
	_apply_vsync(vsync_toggle.button_pressed)
	_apply_fps_limit(_selected_fps_limit())
	_apply_volume(volume_slider.value)
	_refresh_vsync_toggle()
	_refresh_mode_dependent_controls()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "window_mode", _selected_window_mode())
	config.set_value("display", "resolution", _selected_resolution())
	config.set_value("display", "vsync", vsync_toggle.button_pressed)
	config.set_value("display", "fps_limit", _selected_fps_limit())
	config.set_value("audio", "master_volume", volume_slider.value)
	config.save(SETTINGS_PATH)


func _current_window_mode_id() -> int:
	var current_mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return MODE_FULLSCREEN
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return MODE_BORDERLESS
	return MODE_WINDOWED


func _selected_window_mode() -> int:
	if window_mode_option.selected < 0:
		return MODE_WINDOWED
	return window_mode_option.get_item_id(window_mode_option.selected)


func _selected_resolution() -> Vector2i:
	if resolution_option.selected < 0:
		return DisplayServer.window_get_size()
	var metadata: Variant = resolution_option.get_item_metadata(resolution_option.selected)
	return metadata as Vector2i if metadata is Vector2i else DisplayServer.window_get_size()


func _selected_fps_limit() -> int:
	if fps_option.selected < 0:
		return 60
	var metadata: Variant = fps_option.get_item_metadata(fps_option.selected)
	return int(metadata)


func _select_window_mode(mode_id: int) -> void:
	for index: int in range(window_mode_option.item_count):
		if window_mode_option.get_item_id(index) == mode_id:
			window_mode_option.select(index)
			return
	window_mode_option.select(0)


func _select_resolution(resolution: Vector2i) -> void:
	for index: int in range(resolution_option.item_count):
		var metadata: Variant = resolution_option.get_item_metadata(index)
		if metadata is Vector2i and metadata == resolution:
			resolution_option.select(index)
			return
	_add_resolution_option(resolution)
	resolution_option.select(resolution_option.item_count - 1)


func _select_fps_limit(limit: int) -> void:
	for index: int in range(fps_option.item_count):
		if int(fps_option.get_item_metadata(index)) == limit:
			fps_option.select(index)
			return
	fps_option.select(0)


func _apply_window_mode(mode_id: int) -> void:
	match mode_id:
		MODE_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if OS.has_feature("web") else DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			call_deferred("_apply_selected_resolution")


func _apply_selected_resolution() -> void:
	_apply_resolution(_selected_resolution())


func _apply_resolution(resolution: Vector2i) -> void:
	if OS.has_feature("web") or _selected_window_mode() != MODE_WINDOWED:
		return
	if resolution.x <= 0 or resolution.y <= 0:
		return
	DisplayServer.window_set_size(resolution)
	var screen_index: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_index)
	var screen_position: Vector2i = DisplayServer.screen_get_position(screen_index)
	if screen_size.x > 0 and screen_size.y > 0:
		DisplayServer.window_set_position(screen_position + (screen_size - resolution) / 2)


func _apply_vsync(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)


func _apply_fps_limit(limit: int) -> void:
	Engine.max_fps = maxi(0, limit)


func _apply_volume(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		var normalized: float = clampf(value / 100.0, 0.0, 1.0)
		AudioServer.set_bus_mute(bus_index, normalized <= 0.001)
		if normalized > 0.001:
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(normalized))
	volume_value.text = "%d%%" % int(round(value))


func _refresh_vsync_toggle() -> void:
	vsync_toggle.text = "ON" if vsync_toggle.button_pressed else "OFF"
	vsync_toggle.tooltip_text = "Vertical Sync is %s." % ("enabled" if vsync_toggle.button_pressed else "disabled")


func _refresh_mode_dependent_controls() -> void:
	var windowed: bool = _selected_window_mode() == MODE_WINDOWED
	resolution_option.disabled = not windowed or OS.has_feature("web")
	resolution_row.modulate = Color.WHITE if not resolution_option.disabled else Color(0.62, 0.62, 0.62, 1.0)
	if OS.has_feature("web"):
		hint_label.text = "Browser fullscreen may require permission. Resolution follows the browser window."
	elif OS.has_feature("editor") and not windowed:
		hint_label.text = "Fullscreen is applied to standalone builds; the embedded editor preview may stay windowed."
	elif not windowed:
		hint_label.text = "Resolution follows your display while fullscreen."
	else:
		hint_label.text = "Changes are saved automatically."


func _on_window_mode_selected(_index: int) -> void:
	if _loading:
		return
	_apply_window_mode(_selected_window_mode())
	_refresh_mode_dependent_controls()
	_save_settings()


func _on_resolution_selected(_index: int) -> void:
	if _loading:
		return
	_apply_selected_resolution()
	_save_settings()


func _on_vsync_toggled(_enabled: bool) -> void:
	if _loading:
		return
	_apply_vsync(vsync_toggle.button_pressed)
	_refresh_vsync_toggle()
	_save_settings()


func _on_fps_selected(_index: int) -> void:
	if _loading:
		return
	_apply_fps_limit(_selected_fps_limit())
	_save_settings()


func _on_volume_changed(value: float) -> void:
	_apply_volume(value)
	if not _loading:
		_save_settings()


func _on_back_pressed() -> void:
	if _closing:
		return
	_closing = true
	get_tree().create_timer(0.12, true).timeout.connect(queue_free)
