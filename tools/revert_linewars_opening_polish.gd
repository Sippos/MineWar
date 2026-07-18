extends Node

const CONTROLLER_PATH := "res://scripts/systems/continuous_line_wars_controller.gd"

func _ready() -> void:
	var file := FileAccess.open(CONTROLLER_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open LineWars controller")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	var replacements: Array[Dictionary] = [
		{"from": "var switch_button: Button\nvar radar_button: Button\nvar opening_progress: ProgressBar\nvar alert_banner: PanelContainer\nvar alert_label: Label\n", "to": "var switch_button: Button\nvar radar_button: Button\n"},
		{"from": "var last_spawn_cell := Vector2i.ZERO\nvar current