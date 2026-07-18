extends Node

func _ready() -> void:
	_patch_file(
		"res://scripts/systems/world_generation/world_gem_visuals.gd",
		{"extends \"res://scripts/systems/world_generation/world.gd\"": "extends \"res://scripts/systems/world_generation/world_terrain_runtime.gd\""}
	)
	_patch_file(
		"res://scripts/systems/preparation/preparation_fast_world.gd",
		{"extends \"res://scripts/systems/world_generation/world.gd\"": "extends \"res://scripts/systems/world_generation/world_terrain_runtime.gd\""}
	)
	_patch_file("res://scenes/world/mine/level.tscn", {
		"res://assets/sprites/world/terrain/damage/First_Hitting_Rework.svg": "res://assets/sprites/world/terrain/damage/First_Hitting.png",
		"res://assets/sprites/world/terrain/damage/Second_Hitting_Rework.svg": "res://assets/sprites/world/terrain/damage/Second_Hitting.png",
		"res://assets/sprites/world/terrain/bricks/Easy_Brick_Rework.svg": "res://assets/sprites/world/terrain/bricks/Easy_Brick.png",
		"res://assets/sprites/world/terrain/edges/Easy_Edge_Atlas_Rework.svg": "res://assets/sprites/world/terrain/edges/Easy_Edge_Atlas.png",
		"res://assets/sprites/world/terrain/edges/Hard_Edge_Atlas_Rework.svg": "res://assets/sprites/world/terrain/edges/Hard_Edge_Atlas.png",
		"res://assets/sprites/world/terrain/edges/Medium_Edge_Atlas_Rework.svg": "res://assets/sprites/world/terrain/edges/Medium_Edge_Atlas.png",
		"res://assets/sprites/world/terrain/front_damage/First-Hit-Front-Rework.svg": "res://assets/sprites/world/terrain/front_damage/First-Hit-Front.png",
		"res://assets/sprites/world/terrain/front_damage/Next-Hit-Front-Rework.svg": "res://assets/sprites/world/terrain/front_damage/Next-Hit-Front.png",
		"res://assets/sprites/world/terrain/front_walls/Easy_Brick-Front-Rework.svg": "res://assets/sprites/world/terrain/front_walls/Easy_Brick-Front.png",
		"res://assets/sprites/world/terrain/front_walls/Hard-Brick-Front-Rework.svg": "res://assets/sprites/world/terrain/front_walls/Hard-Brick-Front.png",
		"res://assets/sprites/world/terrain/front_walls/Medium-Brick-Front-Rework.svg": "res://assets/sprites/world/terrain/front_walls/Medium-Brick-Front.png",
		"res://assets/sprites/world/terrain/bricks/Hard_Brick_Rework.svg": "res://assets/sprites/world/terrain/bricks/Hard_Brick.png",
		"res://assets/sprites/world/terrain/bricks/Medium_Brick_Rework.svg": "res://assets/sprites/world/terrain/bricks/Medium_Brick.png"
	})
	print("Applied runtime terrain inheritance and restored stable scene resource paths.")
	get_tree().quit(0)

func _patch_file(path: String, replacements: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(path)
	for old_text: String in replacements:
		text = text.replace(old_text, String(replacements[old_text]))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not patch %s" % path)
		return
	file.store_string(text)
	file.close()
