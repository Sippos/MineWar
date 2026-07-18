extends Node

func _ready() -> void:
	var script := load("res://scripts/systems/continuous_line_wars_controller.gd")
	if script == null:
		push_error("LINEWARS_CONTROLLER_PARSE_FAIL")
		get_tree().quit(1)
		return
	print("LINEWARS_CONTROLLER_PARSE_PASS")
	get_tree().quit(0)
