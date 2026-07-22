extends CanvasLayer

const CONTROLS_MENU := preload("res://scenes/menus/controls/controls_menu.tscn")
const SETTINGS_MENU := preload("res://scenes/menus/settings_menu.tscn")

@onready var resume_button: Button = $Panel/VBoxContainer/ButtonResume
@onready var controls_button: Button = $Panel/VBoxContainer/ButtonControls
@onready var settings_button: Button = $Panel/VBoxContainer/ButtonSettings
@onready var main_menu_button: Button = $Panel/VBoxContainer/ButtonMainMenu

var returning_to_main_menu := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_focus()
	resume_button.call_deferred("grab_focus")

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
	# Settings is a Control rather than its own CanvasLayer. Place it on a
	# temporary layer so first-run banners and world HUD cannot draw above it.
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
	# Keep the pause panel alive through mouse release before loading the clickable main menu.
	await get_tree().create_timer(0.12, true).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/main/menu.tscn")
	queue_free()
