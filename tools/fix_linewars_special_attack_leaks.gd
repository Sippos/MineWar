extends Node

const PATH := "res://enemy_combat_behavior.gd"

func _ready() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Could not read enemy combat behavior")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	var from_base := "func _base_if_in_range(maximum_range: float) -> Node2D:\n\tvar base := world.get_node_or_null(\"Base\") as Node2D\n"
	var to_base := "func _base_if_in_range(maximum_range: float) -> Node2D:\n\t# LineWars resolves a survivor as one discrete leak when it physically reaches\n\t# the base. Special attacks must not repeatedly chip the base beforehand.\n\tif bool(enemy.get_meta(\"linewars_single_leak\", false)):\n\t\treturn null\n\tvar base := world.get_node_or_null(\"Base\") as Node2D\n"
	var from_targets := "\t\t\tif str(candidate.name).begins_with(\"Player\") or str(candidate.name) == \"Base\":\n\t\t\t\ttargets.append(candidate)\n"
	var to_targets := "\t\t\tvar is_player := str(candidate.name).begins_with(\"Player\")\n\t\t\tvar is_base := str(candidate.name) == \"Base\" and not bool(enemy.get_meta(\"linewars_single_leak\", false))\n\t\t\tif is_player or is_base:\n\t\t\t\ttargets.append(candidate)\n"
	if source.count(from_base) != 1 or source.count(from_targets) != 1:
		push_error("LineWars special leak patch anchors did not match")
		get_tree().quit(1)
		return
	source = source.replace(from_base, to_base)
	source = source.replace(from_targets, to_targets)
	var out := FileAccess.open(PATH, FileAccess.WRITE)
	if out == null:
		push_error("Could not write enemy combat behavior")
		get_tree().quit(1)
		return
	out.store_string(source)
	print("LINEWARS_SPECIAL_ATTACK_LEAK_FIX_PASS")
	get_tree().quit(0)
