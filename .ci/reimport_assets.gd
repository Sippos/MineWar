@tool
extends SceneTree

func _initialize() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	fs.scan()
	while fs.is_scanning():
		await process_frame

	var files := PackedStringArray()
	_collect_importable("res://", files)
	fs.reimport_files(files)
	while fs.is_scanning():
		await process_frame
	quit()

func _collect_importable(path: String, files: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var child := path.path_join(name)
		if dir.current_is_dir():
			_collect_importable(child, files)
		elif _is_importable(name):
			files.append(child)
	dir.list_dir_end()

func _is_importable(name: String) -> bool:
	for extension in [".png", ".jpg", ".jpeg", ".webp", ".svg", ".bmp", ".tga", ".hdr", ".exr", ".wav", ".ogg", ".mp3", ".flac", ".ttf", ".otf"]:
		if name.to_lower().ends_with(extension):
			return true
	return false
