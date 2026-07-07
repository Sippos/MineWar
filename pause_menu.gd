extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/VBoxContainer/ButtonResume.call_deferred("grab_focus")

func _on_button_resume_pressed() -> void:
	get_tree().paused = false
	queue_free()


func _on_button_controls_pressed() -> void:
	var controls = preload("res://controls_menu.tscn").instantiate()
	add_child(controls)
	controls.tree_exited.connect(func(): $Panel/VBoxContainer/ButtonControls.grab_focus())

func _on_button_main_menu_pressed() -> void:
	get_tree().paused = false
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	hide()
	queue_free()
	get_tree().change_scene_to_file("res://menu.tscn")
