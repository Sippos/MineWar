extends Node

const SOURCE_PATH := "res://tools/install_gem_overlay_atlas.gd"
const OUTPUT_PATH := "res://assets/sprites/world/terrain/gem_overlays/minewars_buried_gem_overlays_256x128.png"
const PREFIX := "const PNG_BASE64 := \""

func _ready() -> void:
	var source := FileAccess.get_file_as_string(SOURCE_PATH)
	var start := source.find(PREFIX)
	if start < 0:
		push_error("Could not find embedded PNG data")
		get_tree().quit(1)
		return
	start += PREFIX.length()
	var finish := source.find("\"", start)
	if finish < 0:
		push_error("Embedded PNG data is malformed")
		get_tree().quit(1)
		return
	var png_bytes := Marshalls.base64_to_raw(source.substr(start, finish - start))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not create %s" % OUTPUT_PATH)
		get_tree().quit(1)
		return
	file.store_buffer(png_bytes)
	file.close()
	print("Installed exact 256x128 buried-gem atlas: ", OUTPUT_PATH, " (", png_bytes.size(), " bytes)")
	get_tree().quit(0)
