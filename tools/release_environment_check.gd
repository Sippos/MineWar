extends Node

const SKIP_DIRS := {".git": true, ".godot": true, "_quarantine": true, "build": true, ".godot-mcp": true}

func _ready() -> void:
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var project_bytes := _directory_size(root)
	var git_output: Array = []
	var git_code := OS.execute("git", PackedStringArray(["-C", root, "ls-files", ".godot/**"]), git_output, true)
	var tracked_text := "\n".join(git_output).strip_edges()
	var tracked_godot := 0 if tracked_text.is_empty() else tracked_text.split("\n", false).size()
	print("RELEASE_CHECK project_bytes=", project_bytes, " tracked_godot=", tracked_godot, " git_code=", git_code)
	get_tree().quit(0)

func _directory_size(path: String) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	var total := 0
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var child := path.path_join(name)
		if dir.current_is_dir():
			if not SKIP_DIRS.has(name):
				total += _directory_size(child)
		else:
			var file := FileAccess.open(child, FileAccess.READ)
			if file:
				total += file.get_length()
		name = dir.get_next()
	dir.list_dir_end()
	return total
