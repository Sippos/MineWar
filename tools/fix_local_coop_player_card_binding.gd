extends Node

const TARGET := "res://local_coop_mode.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(TARGET)
	var old_block := '''\treturn {
\t\t"panel": panel,
\t\t"portrait": portrait,
\t\t"hp": hp_label,
\t\t"health": health_bar,
\t\t"details": details,
\t}

func _create_base_panel() -> Dictionary:
'''
	var new_block := '''\treturn {
\t\t"panel": panel,
\t\t"portrait": portrait,
\t\t"name": name_label,
\t\t"hp": hp_label,
\t\t"health": health_bar,
\t\t"details": details,
\t}

func _create_base_panel() -> Dictionary:
'''
	if not source.contains(old_block):
		push_error("Player card return block not found")
		get_tree().quit(1)
		return
	source = source.replace(old_block, new_block)
	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not write local_coop_mode.gd")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("LOCAL_COOP_PLAYER_CARD_BINDING_FIXED")
	get_tree().quit()
