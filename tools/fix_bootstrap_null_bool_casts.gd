extends Node

const PATCHES := {
	"res://siege_mode_bootstrap.gd": {
		"bool(node.get(\"is_vs_mode\"))": "node.get(\"is_vs_mode\") == true",
		"bool(node.get(\"preparation_mode\"))": "node.get(\"preparation_mode\") == true",
	},
	"res://exploration_mode_bootstrap.gd": {
		"bool(node.get(\"is_vs_mode\"))": "node.get(\"is_vs_mode\") == true",
		"bool(node.get(\"preparation_mode\"))": "node.get(\"preparation_mode\") == true",
	},
	"res://enemy_approach_bootstrap.gd": {
		"bool(node.get(\"is_vs_mode\"))": "node.get(\"is_vs_mode\") == true",
	},
	"res://keeper_mode_bootstrap.gd": {
		"bool(node.get(\"is_vs_mode\"))": "node.get(\"is_vs_mode\") == true",
	},
	"res://match_flow.gd": {
		"return not bool(node.get(\"is_vs_mode\"))": "return node.get(\"is_vs_mode\") != true",
	},
	"res://peon_coordinator.gd": {
		"if not bool(node.get(\"is_vs_mode\")):": "if node.get(\"is_vs_mode\") != true:",
	},
}

func _ready() -> void:
	var changed: Array[String] = []
	for path_value in PATCHES.keys():
		var path := str(path_value)
		var source := FileAccess.get_file_as_string(path)
		if source.is_empty():
			push_error("Could not read %s" % path)
			get_tree().quit(1)
			return
		var original := source
		var replacements: Dictionary = PATCHES[path]
		for old_value in replacements.keys():
			var old_text := str(old_value)
			var new_text := str(replacements[old_value])
			if source.contains(old_text):
				source = source.replace(old_text, new_text)
		if source != original:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				push_error("Could not write %s" % path)
				get_tree().quit(1)
				return
			file.store_string(source)
			file.close()
			changed.append(path)
	print("BOOTSTRAP_NULL_BOOL_CASTS_FIXED changed=", changed)
	get_tree().quit(0)
