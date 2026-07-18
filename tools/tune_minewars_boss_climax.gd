extends Node

func _replace_once(source: String, old_text: String, new_text: String, label: String) -> String:
	if not source.contains(old_text):
		push_error("Missing MineWars boss patch target: %s" % label)
		return source
	return source.replace(old_text, new_text)

func _ready() -> void:
	var path := "res://scripts/systems/world_generation/siege_mode_controller.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read %s" % path)
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	file.close()

	source = _replace_once(
		source,
		"const NEXT_EXPEDITION_DISTANCE := 180.0\n",
		"const NEXT_EXPEDITION_DISTANCE := 180.0\nconst MINEWARS_BOSS_HEALTH := 600\nconst MINEWARS_BOSS_DAMAGE := 12\nconst MINEWARS_BOSS_SPEED := 50.0\n",
		"boss tuning constants"
	)

	source = _replace_once(
		source,
		"\t\t\tvar power_level := int(STAGE_ENEMY_POWER_LEVELS.get(stage_number, stage_number))\n\t\t\tenemy.initialize(power_level, is_boss, enemy_type)\n\t\tif enemy.has_method(\"begin_breach_emergence\"):\n",
		"\t\t\tvar power_level := int(STAGE_ENEMY_POWER_LEVELS.get(stage_number, stage_number))\n\t\t\tenemy.initialize(power_level, is_boss, enemy_type)\n\t\t\tif is_boss:\n\t\t\t\tenemy.set(\"health\", MINEWARS_BOSS_HEALTH)\n\t\t\t\tenemy.set(\"max_health\", MINEWARS_BOSS_HEALTH)\n\t\t\t\tenemy.set(\"damage\", MINEWARS_BOSS_DAMAGE)\n\t\t\t\tenemy.set(\"speed\", MINEWARS_BOSS_SPEED)\n\t\t\t\tif enemy.has_method(\"_set_health_bar_values\"):\n\t\t\t\t\tenemy.call(\"_set_health_bar_values\", true)\n\t\tif enemy.has_method(\"begin_breach_emergence\"):\n",
		"MineWars boss override"
	)

	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		push_error("Could not write %s" % path)
		get_tree().quit(1)
		return
	output.store_string(source)
	output.close()
	print("MINEWARS_BOSS_CLIMAX_TUNED")
	get_tree().quit()
