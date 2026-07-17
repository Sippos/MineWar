extends Control

const MENU_THEME = preload("res://assets/themes/global/global_theme.tres")
const SETTINGS_PATH := "user://minewars_settings.cfg"

@onready var fullscreen_check: CheckButton = $Dimmer/Center/Panel/VBox/FullscreenCheck
@onready var vsync_check: CheckButton = $Dimmer/Center/Panel/VBox/VSyncCheck
@onready var volume_slider: HSlider = $Dimmer/Center/Panel/VBox/VolumeRow/VolumeSlider
@onready var volume_value: Label = $Dimmer/Center/Panel/VBox/VolumeRow/VolumeValue
@onready var back_button: Button = $Dimmer/Center/Panel/VBox/BackButton

var _loading := false

func _ready() -> void:
	theme = MENU_THEME
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	back_button.pressed.connect(_on_back_pressed)
	_load_settings()
	fullscreen_check.grab_focus()

func _load_settings() -> void:
	_loading = true
	var config := ConfigFile.new()
	var load_result := config.load(SETTINGS_PATH)
	var fullscreen_default := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	var vsync_default := DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	var volume_default := 100.0
	if load_result == OK:
		fullscreen_check.button_pressed = bool(config.get_value("display", "fullscreen", fullscreen_default))
		vsync_check.button_pressed = bool(config.get_value("display", "vsync", vsync_default))
		volume_slider.value = float(config.get_value("audio", "master_volume", volume_default))
	else:
		fullscreen_check.button_pressed = fullscreen_default
		vsync_check.button_pressed = vsync_default
		volume_slider.value = volume_default
	_loading = false
	_apply_fullscreen(fullscreen_check.button_pressed)
	_apply_vsync(vsync_check.button_pressed)
	_apply_volume(volume_slider.value)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen_check.button_pressed)
	config.set_value("display", "vsync", vsync_check.button_pressed)
	config.set_value("audio", "master_volume", volume_slider.value)
	config.save(SETTINGS_PATH)

func _apply_fullscreen(enabled: bool) -> void:
	if OS.has_feature("web") or OS.has_feature("ios"):
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_vsync(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)

func _apply_volume(value: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index < 0:
		return
	var normalized := clampf(value / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, normalized <= 0.001)
	if normalized > 0.001:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(normalized))
	volume_value.text = "%d%%" % int(round(value))

func _on_fullscreen_toggled(enabled: bool) -> void:
	if _loading:
		return
	_apply_fullscreen(enabled)
	_save_settings()

func _on_vsync_toggled(enabled: bool) -> void:
	if _loading:
		return
	_apply_vsync(enabled)
	_save_settings()

func _on_volume_changed(value: float) -> void:
	_apply_volume(value)
	if not _loading:
		_save_settings()

func _on_back_pressed() -> void:
	queue_free()
