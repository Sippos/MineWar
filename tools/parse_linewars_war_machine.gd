extends Node

func _ready() -> void:
	var script := load("res://scripts/systems/linewars_war_machine_controller.gd")
	if script == null:
		push_error("LINEWARS_WAR_MACHINE_PARSE_FAIL")
		get_tree().quit(1)
		return
	print("LINEWARS_WAR_MACHINE_PARSE_PASS")
	get_tree().quit(0)
