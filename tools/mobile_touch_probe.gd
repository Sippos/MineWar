extends Node

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(390, 844))
	var level = preload("res://scenes/world/mine/level.tscn").instantiate()
	level.name = "Level"
	add_child(level)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var controls = preload("res://mobile_controls.tscn").instantiate()
	controls.name = "MobileControls"
	controls.player_id = 1
	layer.add_child(controls)
	await get_tree().process_frame
	await get_tree().process_frame
	print("MOBILE_TOUCH_GEOMETRY grab=", controls.buttons[0].pos, " radius=", controls.button_radius)
	var grab_down := InputEventScreenTouch.new()
	grab_down.index = 2
	grab_down.position = Vector2(281, 624)
	grab_down.pressed = true
	controls.call("_input", grab_down)
	print("MOBILE_TOUCH_PICK direct=", Input.is_action_pressed("p1_grab"))
	var menu_down := InputEventScreenTouch.new()
	menu_down.index = 3
	menu_down.position = Vector2(195, 44)
	menu_down.pressed = true
	controls.call("_input", menu_down)
	print("MOBILE_TOUCH_MENU direct=", get_tree().root.get_node_or_null("PauseMenu") != null, " paused=", get_tree().paused)
	get_tree().quit()
