extends Node

var failures: Array[String] = []

func _ready() -> void:
	_patch("res://base.gd", "\t\t$Sprite2D.modulate = Color(1, 1, 1, 1)", "\t\t$Sprite2D.modulate = Color(1.16, 0.82, 0.46, 1.0) if base_id == \"mech_base\" else Color(1, 1, 1, 1)")
	_patch("res://mech_unlock_persistence.gd", "\t\"description\": \"The defeated goblin pilot has surrendered the Mech. Its emergency pilot form can rebuild the frame at the bastion.\"", "\t\"description\": \"The defeated goblin pilot has surrendered the Mech and opened the Goblin Mech Workshop. Its emergency pilot can rebuild the frame faster there.\"")
	_patch("res://goblin_pilot.gd", "\t\t\thud.show_notice(\"GOBLIN PILOT DEFEATED — MECH HERO UNLOCKED!\", 5.0)", "\t\t\thud.show_notice(\"GOBLIN PILOT DEFEATED — MECH HERO + WORKSHOP UNLOCKED!\", 5.0)")
	_patch("res://tests/minewars_complete_run_runner.gd", "\t_expect(Global.unlocked_heroes.has(\"Mech\"), \"Defeating the escaping pilot should unlock the Mech hero\")", "\t_expect(Global.unlocked_heroes.has(\"Mech\"), \"Defeating the escaping pilot should unlock the Mech hero\")\n\t_expect(Global.unlocked_bases.has(\"mech_base\"), \"Defeating the escaping pilot should unlock the Goblin Mech Workshop\")")
	_patch("res://tests/minewars_complete_run_runner.gd", "\t_expect(Global.unlocked_bases == [\"default_base\"], \"Save reload should keep later fortresses hidden after one victory\")", "\t_expect(Global.unlocked_bases.has(\"default_base\") and Global.unlocked_bases.has(\"mech_base\") and Global.unlocked_bases.size() == 2, \"Save reload should restore only the Bastion and captured Mech Workshop after one victory\")")
	if failures.is_empty():
		print("FINALIZE_BASE_IDENTITY_POLISH_OK")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _patch(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.contains(new_text):
		return
	if source.is_empty() or not source.contains(old_text):
		failures.append("Missing patch target in %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write %s" % path)
		return
	file.store_string(source.replace(old_text, new_text))
	file.close()
