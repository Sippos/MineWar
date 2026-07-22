extends Node

const TARGET := "res://scripts/systems/preparation/in_world_hero_selector.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(TARGET)
	if source.is_empty():
		push_error("Could not read in_world_hero_selector.gd")
		get_tree().quit(1)
		return

	var marker := "func _build_hero_shrines() -> void:\n"
	if not source.contains("func _compact_hero_choices() -> Array[String]:"):
		var helpers := '''func _compact_hero_choices() -> Array[String]:
	var choices: Array[String] = []
	# A fresh stronghold needs no shrine for the hero already equipped. The first
	# real unlock introduces a compact current-vs-alternative choice.
	if Global.unlocked_heroes.size() <= 1:
		return choices
	_add_compact_choice(choices, str(Global.selected_hero_id))
	var newly_unlocked: Array = world.get_meta("newly_unlocked_heroes", []) if world != null else []
	for index in range(newly_unlocked.size() - 1, -1, -1):
		_add_compact_choice(choices, str(newly_unlocked[index]))
	for index in range(Global.unlocked_heroes.size() - 1, -1, -1):
		_add_compact_choice(choices, str(Global.unlocked_heroes[index]))
		if choices.size() >= 2:
			break
	return choices

func _add_compact_choice(choices: Array[String], hero_name: String) -> void:
	if choices.size() >= 2 or hero_name.is_empty() or choices.has(hero_name):
		return
	if not _hero_unlocked(hero_name):
		return
	choices.append(hero_name)

'''
		source = source.replace(marker, helpers + marker)

	var old_loop := '''\tfor hero_name in HERO_ORDER:
\t\tif not _hero_unlocked(hero_name):
\t\t\tcontinue
\t\tvar root := Node2D.new()
\t\troot.name = hero_name.replace(" ", "") + "Shrine"
\t\troot.position = HERO_POSITIONS[hero_name]
\t\tshrine_root.add_child(root)
'''
	var new_loop := '''\tvar visible_choices := _compact_hero_choices()
\tvar compact_positions := [Vector2(-205, -62), Vector2(205, -62)]
\tfor choice_index in range(visible_choices.size()):
\t\tvar hero_name: String = visible_choices[choice_index]
\t\tvar root := Node2D.new()
\t\troot.name = hero_name.replace(" ", "") + "Shrine"
\t\troot.position = compact_positions[choice_index]
\t\tshrine_root.add_child(root)
'''
	if not source.contains(old_loop):
		push_error("Could not find the single-player shrine loop")
		get_tree().quit(1)
		return
	source = source.replace(old_loop, new_loop)

	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not write in_world_hero_selector.gd")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("SINGLE_PLAYER_HERO_SHRINES_COMPACTED")
	get_tree().quit()
