extends Control

func _ready() -> void:
	$VBoxContainer/VSOnlineButton.pressed.connect(_on_vs_online_pressed)
	$VBoxContainer/VSModeButton.pressed.connect(_on_vs_mode_pressed)
	$VBoxContainer/SinglePlayerButton.pressed.connect(_on_single_player_pressed)
	$LexikonButton.pressed.connect(_on_lexikon_pressed)
	$VBoxContainer/ControlsButton.pressed.connect(_on_controls_pressed)
	$VBoxContainer/SinglePlayerButton.call_deferred("grab_focus")

func _on_single_player_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _on_lexikon_pressed() -> void:
	get_tree().change_scene_to_file("res://lexikon.tscn")

func _on_vs_mode_pressed() -> void:
	get_tree().change_scene_to_file("res://vs_mode.tscn")

func _on_vs_online_pressed() -> void:
	get_tree().change_scene_to_file("res://online_lobby.tscn")

func _on_controls_pressed() -> void:
	var controls = preload("res://controls_menu.tscn").instantiate()
	add_child(controls)
	controls.tree_exited.connect(func(): $VBoxContainer/ControlsButton.grab_focus())
