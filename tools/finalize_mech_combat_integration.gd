extends Node

var failures: Array[String] = []

func _ready() -> void:
	_patch(
		"res://scripts/systems/world_generation/siege_mode_controller.gd",
		"\t4: \"BURIED HEART\",",
		"\t4: \"GOBLIN WAR MECH\","
	)
	_patch(
		"res://scripts/systems/world_generation/siege_mode_controller.gd",
		"FINAL ASSAULT — the Buried Heart is marching on the bastion!",
		"FINAL ASSAULT — the Goblin War Mech is marching on the bastion!"
	)
	_patch(
		"res://scripts/systems/world_generation/siege_mode_controller.gd",
		"BOSS PHASE II — armor shattered. The Heart releases its spider guard!",
		"MECH PHASE II — armor shattered. The pilot releases its spider guard!"
	)
	_patch(
		"res://scripts/systems/world_generation/siege_mode_controller.gd",
		"CORE OVERLOAD — a second breach tears open in the east!",
		"MECH OVERDRIVE — a second breach tears open in the east!"
	)
	_patch(
		"res://scripts/systems/world_generation/siege_mode_controller.gd",
		"SECONDARY_ENTRANCE_CELL, \"CORE BREACH\"",
		"SECONDARY_ENTRANCE_CELL, \"OVERDRIVE BREACH\""
	)
	_patch(
		"res://scripts/systems/preparation/preparation_world_controller.gd",
		"\"summary\": \"An armored mining platform reserved for a later unlock.\",",
		"\"summary\": \"An armored mining platform with an emergency goblin pilot.\","
	)
	_patch(
		"res://scripts/systems/preparation/preparation_world_controller.gd",
		"\"kit\": \"Weapon modules  •  Utility modules  •  Future unlock\"",
		"\"kit\": \"Heavy frame  •  Pilot ejection  •  Rebuild beside the bastion\""
	)
	_patch(
		"res://enemy_combat_behavior.gd",
		"\tif ratio <= 0.25:\n\t\tnew_phase = 3\n\telif ratio <= 0.60:\n\t\tnew_phase = 2",
		"\tif ratio <= 0.34:\n\t\tnew_phase = 3\n\telif ratio <= 0.68:\n\t\tnew_phase = 2"
	)
	_patch(
		"res://enemy_combat_behavior.gd",
		"\tif world.has_node(\"HUD\"):\n\t\tvar hud := world.get_node(\"HUD\")\n\t\tif hud.has_method(\"show_notice\"):\n\t\t\thud.show_notice(\"MECH OVERDRIVE — attack pattern intensified!\" if boss_phase == 2 else \"MECH CRITICAL — pilot override engaged!\", 3.0)",
		"\t# MineWars has its own phase ceremony and reinforcement announcements.\n\t# Other modes still receive the self-contained boss warning.\n\tif not bool(enemy.get_meta(\"minewars_boss\", false)) and world.has_node(\"HUD\"):\n\t\tvar hud := world.get_node(\"HUD\")\n\t\tif hud.has_method(\"show_notice\"):\n\t\t\thud.show_notice(\"MECH OVERDRIVE — attack pattern intensified!\" if boss_phase == 2 else \"MECH CRITICAL — pilot override engaged!\", 3.0)"
	)

	if failures.is_empty():
		print("FINALIZE_MECH_COMBAT_INTEGRATION_OK")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _patch(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		failures.append("Could not read %s" % path)
		return
	if not source.contains(old_text):
		if source.contains(new_text):
			return
		failures.append("Patch target missing in %s: %s" % [path, old_text.left(80)])
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write %s" % path)
		return
	file.store_string(source.replace(old_text, new_text))
	file.close()
