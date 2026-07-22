extends Node

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(390, 844))
	var level = preload("res://scenes/world/mine/level.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	_print_visible(get_tree().current_scene)
	print("PROBE_DONE")

func _print_visible(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			print("LAYER path=", child.get_path(), " layer=", child.layer, " visible=", child.visible)
		if child is Control and child.visible:
			var text_value := ""
			if child is Label:
				text_value = (child as Label).text
			print("CONTROL path=", child.get_path(), " type=", child.get_class(), " pos=", child.position, " size=", child.size, " text=", text_value)
		_print_visible(child)
