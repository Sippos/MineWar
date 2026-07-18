extends Node

const ATLAS_PATH := "res://assets/sprites/world/terrain/gem_overlays/minewars_buried_gem_overlays_256x128.png"

func _ready() -> void:
	var absolute_path := ProjectSettings.globalize_path(ATLAS_PATH)
	var image := Image.new()
	var err := image.load(absolute_path)
	if err != OK:
		push_error("GEM_ATLAS_LOAD_FAILED error=%d path=%s" % [err, absolute_path])
		get_tree().quit(1)
		return
	print("GEM_ATLAS_OK size=", image.get_size(), " format=", image.get_format(), " alpha=", image.detect_alpha())
	if image.get_size() != Vector2i(256, 128):
		push_error("GEM_ATLAS_BAD_SIZE %s" % image.get_size())
		get_tree().quit(2)
		return
	get_tree().quit(0)
