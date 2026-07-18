extends Node

func _ready() -> void:
	_patch("res://match_flow.gd", {
		"const FINAL_WAVE := 10": "const FINAL_WAVE := 4",
		"hud.show_notice(\"Survive 10 waves. Defeat the boss to win.\", 3.2)": "hud.show_notice(\"Complete three expeditions, then defeat the final boss assault.\", 3.8)",
		"subtitle.text = \"The wave boss has fallen.\" if victory else \"The base has fallen. Your legacy remains.\"": "subtitle.text = \"The final assault has been broken.\" if victory else \"The bastion fell, but your legacy remains.\"",
		"status.text = \"BOSS DEFEATED\" if victory else \"HERO FALLEN\"": "status.text = \"EXPEDITION COMPLETE\" if victory else \"EXPEDITION LOST\"",
		"_add_result_row(stats, null, \"WAVE\", \"Wave reached\", \"%d / %d\" % [wave_reached, FINAL_WAVE])": "_add_result_row(stats, null, \"STAGE\", \"Stage reached\", \"%d / %d\" % [wave_reached, FINAL_WAVE])"
	})
	_patch("res://hud.gd", {
		"wave_label.text = \"BOSS WAVE %d - COMBAT!\" % wave": "wave_label.text = \"FINAL ASSAULT - COMBAT!\"",
		"wave_label.text = \"BOSS WAVE %d!\" % wave": "wave_label.text = \"FINAL ASSAULT\"",
		"wave_label.text = \"Wave %d - Combat Phase\" % wave": "wave_label.text = \"STAGE %d - DEFEND\" % wave",
		"wave_label.text = \"Wave %d\" % wave": "wave_label.text = \"STAGE %d - EXPLORE\" % wave"
	})
	print("FOUR_STAGE_EXPEDITION_FLOW_APPLIED")
	get_tree().quit()

func _patch(path: String, replacements: Dictionary) -> void:
	var source := FileAccess.get_file_as_string(path)
	for old_text in replacements:
		if not source.contains(old_text):
			push_error("Missing patch target in %s: %s" % [path, str(old_text).left(100)])
			continue
		source = source.replace(old_text, str(replacements[old_text]))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
