extends Node

func _ready() -> void:
	var path := "res://tests/minewars_four_stage_balance_runner.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read MineWars balance runner")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	file.close()
	var replacements := {
		"stage_one_muster > 9.0 and stage_one_muster <= 10.0": "stage_one_muster > 15.0 and stage_one_muster <= 16.0",
		"about ten seconds of return grace": "about sixteen seconds of return grace",
		"float(controller.get(\"assault_muster_timer\")) > 7.0": "float(controller.get(\"assault_muster_timer\")) > 12.0",
		"float(controller.get(\"assault_muster_timer\")) > 5.0": "float(controller.get(\"assault_muster_timer\")) > 9.0",
		"float(controller.get(\"assault_muster_timer\")) > 4.0": "float(controller.get(\"assault_muster_timer\")) > 7.0",
		"int(boss_enemy.get(\"health\")) == 600": "int(boss_enemy.get(\"health\")) == 540",
		"int(boss_enemy.get(\"damage\")) == 12": "int(boss_enemy.get(\"damage\")) == 9",
		"float(boss_enemy.get(\"speed\")) - 50.0": "float(boss_enemy.get(\"speed\")) - 46.0",
	}
	for old_text in replacements:
		source = source.replace(old_text, replacements[old_text])
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write MineWars balance runner")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("MINEWARS_BALANCE_TEST_UPDATED")
	get_tree().quit()
