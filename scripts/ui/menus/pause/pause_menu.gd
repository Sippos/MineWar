extends CanvasLayer

const MenuTypography = preload("res://scripts/ui/menus/menu_typography.gd")
const CONTROLS_MENU := preload("res://scenes/menus/controls/controls_menu.tscn")
const SETTINGS_MENU := preload("res://scenes/menus/settings_menu.tscn")
const MENU_PANEL_TEX := preload("res://assets/sprites/ui/common/MenuPanel.png")

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Title
@onready var resume_button: Button = $Panel/VBoxContainer/ButtonResume
@onready var controls_button: Button = $Panel/VBoxContainer/ButtonControls
@onready var settings_button: Button = $Panel/VBoxContainer/ButtonSettings
@onready var main_menu_button: Button = $Panel/VBoxContainer/ButtonMainMenu

var returning_to_main_menu := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_wooden_panel()
	_apply_typography()
	_configure_focus()
	get_tree().root.size_changed.connect(_layout_for_screen)
	call_deferred("_layout_for_screen")
	# Keep keyboard/gamepad focus without a visible "selected" look (focus style == normal)
	resume_button.call_deferred("grab_focus")


func _apply_wooden_panel() -> void:
	var style := StyleBoxTexture.new()
	style.texture = MENU_PANEL_TEX
	style.texture_margin_left = 34.0
	style.texture_margin_top = 34.0
	style.texture_margin_right = 34.0
	style.texture_margin_bottom = 34.0
	style.content_margin_left = 48.0
	style.content_margin_top = 34.0
	style.content_margin_right = 48.0
	style.content_margin_bottom = 34.0
	panel.add_theme_stylebox_override("panel", style)


func _apply_typography() -> void:
	MenuTypography.apply_title_style(title_label, 28)
	for button in [resume_button, controls_button, settings_button, main_menu_button]:
		MenuTypography.apply_primary_button_style(button, 18)
		button.custom_minimum_size.y = 68


func _layout_for_screen() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var compact := screen_size.x < 700.0 or screen_size.y < 540.0
	var panel_width := minf(460.0, maxf(300.0, screen_size.x - 40.0))
	var panel_height := minf(500.0, maxf(340.0, screen_size.y - 40.0))
	panel.offset_left = -panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_bottom = panel_height * 0.5

	var content: VBoxContainer = $Panel/VBoxContainer
	var h_margin := 40.0 if compact else 58.0
	var v_margin := 90.0 if compact else 100.0
	content.offset_left = h_margin
	content.offset_top = v_margin
	content.offset_right = -h_margin
	content.offset_bottom = -46.0
	content.add_theme_constant_override("separation", 10 if compact else 12)

	title_label.offset_left = 38.0
	title_label.offset_top = 36.0 if compact else 42.0
	title_label.offset_right = -38.0
	title_label.offset_bottom = title_label.offset_top + (36.0 if compact else 46.0)
	MenuTypography.apply_title_style(title_label, 22 if compact else 28)

	var btn_height := 56.0 if compact else 68.0
	for button in [resume_button, controls_button, settings_button, main_menu_button]:
		button.custom_minimum_size.y = btn_height
		MenuTypography.apply_primary_button_style(button, 16 if compact else 18)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_on_button_resume_pressed()
		get_viewport().set_input_as_handled()


func _configure_focus() -> void:
	var buttons: Array[Button] = [resume_button, controls_button, settings_button, main_menu_button]
	for index in buttons.size():
		buttons[index].focus_neighbor_top = buttons[index - 1].get_path() if index > 0 else NodePath()
		buttons[index].focus_neighbor_bottom = buttons[index + 1].get_path() if index < buttons.size() - 1 else NodePath()


func _on_button_resume_pressed() -> void:
	get_tree().paused = false
	queue_free()


func _on_button_controls_pressed() -> void:
	var controls = CONTROLS_MENU.instantiate()
	add_child(controls)
	controls.tree_exited.connect(func():
		if is_instance_valid(controls_button) and controls_button.is_inside_tree():
			controls_button.grab_focus()
	)


func _on_button_settings_pressed() -> void:
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "SettingsOverlayLayer"
	overlay_layer.layer = 220
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)
	var settings = SETTINGS_MENU.instantiate()
	overlay_layer.add_child(settings)
	settings.tree_exited.connect(func():
		if is_instance_valid(overlay_layer):
			overlay_layer.queue_free()
		if is_instance_valid(settings_button) and settings_button.is_inside_tree():
			settings_button.grab_focus()
	)


func _on_button_main_menu_pressed() -> void:
	if returning_to_main_menu:
		return
	returning_to_main_menu = true
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	await get_tree().create_timer(0.12, true).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/main/menu.tscn")
	queue_free()
