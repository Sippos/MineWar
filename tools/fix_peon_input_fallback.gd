extends Node

const TARGET_PATH := "res://scripts/systems/builder_peon_player.gd"

func _ready() -> void:
	var file := FileAccess.open(TARGET_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open builder peon script")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	var from_text := "\tvar input_vector := Input.get_vector(\"p1_left\", \"p1_right\", \"p1_up\", \"p1_down\")\n\tif input_vector.length_squared() < 0.01:\n\t\tinput_vector = Input.get_vector(\"ui_left\", \"ui_right\", \"ui_up\", \"ui_down\")\n"
	var to_text := "\tvar input_vector := Vector2.ZERO\n\tif InputMap.has_action(\"p1_left\") and InputMap.has_action(\"p1_right\") and InputMap.has_action(\"p1_up\") and InputMap.has_action(\"p1_down\"):\n\t\tinput_vector = Input.get_vector(\"p1_left\", \"p1_right\", \"p1_up\", \"p1_down\")\n\tif input_vector.length_squared() < 0.01:\n\t\tinput_vector = Input.get_vector(\"ui_left\", \"ui_right\", \"ui_up\", \"ui_down\")\n"
	if source.count(from_text) != 1:
		push_error("Expected one peon input block")
		get_tree().quit(1)
		return
	source = source.replace(from_text, to_text)
	var output := FileAccess.open(TARGET_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Could not write builder peon script")
		get_tree().quit(1)
		return
	output.store_string(source)
	print("PEON_INPUT_FALLBACK_PATCH_PASS")
	get_tree().quit(0)
