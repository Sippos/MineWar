extends Node

const EXACT_ATLAS_PATH := "res://assets/sprites/world/terrain/gem_overlays/minewars_buried_gem_overlays_exact_256x128.png"
const TARGETS := [
	"res://scripts/systems/world_generation/world_gem_visuals.gd",
	"res://scripts/systems/preparation/preparation_fast_world.gd",
]

func _ready() -> void:
	var changed := 0
	for target in TARGETS:
		var text := FileAccess.get_file_as_string(target)
		if text.is_empty():
			push_error("Could not read %s" % target)
			get_tree().quit(1)
			return
		var updated := text.replace(
			"res://assets/sprites/world/terrain/gem_overlays/minewars_gem_overlay_atlas.png",
			EXACT_ATLAS_PATH
		)
		if updated != text:
			var file := FileAccess.open(target, FileAccess.WRITE)
			if file == null:
				push_error("Could not write %s" % target)
				get_tree().quit(1)
				return
			file.store_string(updated)
			file.close()
			changed += 1
			print("Updated gem atlas path in ", target)
		else:
			print("Exact atlas path already active in ", target)
	print("Exact buried-gem atlas switch complete. Files changed: ", changed)
	get_tree().quit(0)
