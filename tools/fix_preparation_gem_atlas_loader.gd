extends Node

const PATH := "res://scripts/systems/preparation/preparation_fast_world.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(PATH)
	var old_text := '''func _ensure_gem_indicator_textures() -> bool:
	if preparation_gem_overlay_atlas == null:
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(PREPARATION_GEM_ATLAS_PATH))
		if image != null and not image.is_empty():
			preparation_gem_overlay_atlas = ImageTexture.create_from_image(image)
	return preparation_gem_overlay_atlas != null
'''
	var new_text := '''func _ensure_gem_indicator_textures() -> bool:
	if preparation_gem_overlay_atlas != null:
		return true
	# Read the PNG bytes directly from res://. This works both in the editor and
	# from an exported PCK without relying on an imported ResourceLoader entry.
	var png_bytes := FileAccess.get_file_as_bytes(PREPARATION_GEM_ATLAS_PATH)
	if png_bytes.is_empty():
		push_warning("MineWars gem-overlay atlas is missing: %s" % PREPARATION_GEM_ATLAS_PATH)
		return false
	var image := Image.new()
	var load_error := image.load_png_from_buffer(png_bytes)
	if load_error != OK or image.is_empty():
		push_warning("MineWars gem-overlay atlas could not be decoded: %s" % error_string(load_error))
		return false
	preparation_gem_overlay_atlas = ImageTexture.create_from_image(image)
	return preparation_gem_overlay_atlas != null
'''
	if source.contains(new_text):
		print("PREPARATION_GEM_ATLAS_LOADER_ALREADY_FIXED")
		get_tree().quit(0)
		return
	if source.is_empty() or not source.contains(old_text):
		push_error("Preparation gem-atlas loader patch target missing")
		get_tree().quit(1)
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write preparation_fast_world.gd")
		get_tree().quit(1)
		return
	file.store_string(source.replace(old_text, new_text))
	file.close()
	print("PREPARATION_GEM_ATLAS_LOADER_FIXED")
	get_tree().quit(0)
