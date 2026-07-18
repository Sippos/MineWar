extends Node

func _replace(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if not source.contains(old_text):
		push_error("Missing patch target in %s" % path)
		return
	source = source.replace(old_text, new_text)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()

func _ready() -> void:
	var path := "res://scripts/systems/world_generation/world.gd"
	_replace(path, "var gem_blocks = {}\nvar cave_reward_spawned := false", "var gem_blocks = {}\nvar minewars_motherlodes: Dictionary = {}\nvar cave_reward_spawned := false")
	_replace(path, "\tset_meta(\"minewars_motherlodes\", motherlodes)\n\nfunc get_minewars_prospect_hint(stage: int) -> String:\n\tvar motherlodes: Dictionary = get_meta(\"minewars_motherlodes\", {})\n\tif not motherlodes.has(stage):\n\t\treturn \"\"\n\tvar cell: Vector2i = motherlodes[stage]", "\tminewars_motherlodes = motherlodes\n\nfunc get_minewars_prospect_hint(stage: int) -> String:\n\tif not minewars_motherlodes.has(stage):\n\t\tvar fallback_depths := {1: 6, 2: 13, 3: 20, 4: 27}\n\t\treturn \"A rich seam should lie near depth %d.\" % int(fallback_depths.get(stage, 8))\n\tvar cell: Vector2i = minewars_motherlodes[stage]")
	print("MINEWARS_MOTHERLODE_STATE_FIXED")
	get_tree().quit()
