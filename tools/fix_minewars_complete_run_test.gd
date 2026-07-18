extends Node

func _ready() -> void:
	var path := "res://tests/minewars_complete_run_runner.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read complete-run test")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	file.close()
	source = source.replace(
		"\tvar ui_children_before := controller.get(\"ui_layer\").get_child_count()",
		"\tvar ui_layer_node: Node = controller.get(\"ui_layer\") as Node\n\tvar ui_children_before: int = ui_layer_node.get_child_count()"
	)
	source = source.replace(
		"\t\tvar hub_hud := controller_node.get(\"hub_hud\")",
		"\t\tvar hub_hud: Node = controller_node.get(\"hub_hud\") as Node"
	)
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write complete-run test")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("MINEWARS_COMPLETE_RUN_TEST_PARSE_FIX_APPLIED")
	get_tree().quit()
