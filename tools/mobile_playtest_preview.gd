extends Node

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(390, 844))
	var level = preload("res://scenes/world/mine/level.tscn").instantiate()
	level.name = "Level"
	add_child(level)
	var layer := CanvasLayer.new()
	layer.name = "MobilePreviewLayer"
	layer.layer = 100
	add_child(layer)
	var controls = preload("res://mobile_controls.tscn").instantiate()
	controls.name = "MobileControls"
	controls.player_id = 1
	layer.add_child(controls)
	await get_tree().process_frame
	print("MOBILE_GEOMETRY viewport=", get_viewport().get_visible_rect().size, " viewport_size=", get_viewport().size, " window=", get_window().size, " controls=", controls.joystick_radius, " compact=", min(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y) < 520.0)
