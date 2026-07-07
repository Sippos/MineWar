extends Control

func _ready() -> void:
	$VSOnlineButton.pressed.connect(_on_vs_online_pressed)
	$VSModeButton.pressed.connect(_on_vs_mode_pressed)
	$SinglePlayerButton.pressed.connect(_on_single_player_pressed)
	$LexikonButton.pressed.connect(_on_lexikon_pressed)
	$ControlsButton.pressed.connect(_on_controls_pressed)
	$SinglePlayerButton.call_deferred("grab_focus")

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
	var controls = preload("res://controls_menu.tscn").instantiate()
	add_child(controls)
	controls.tree_exited.connect(func(): $ControlsButton.grab_focus())
