extends Node

func _ready() -> void:
	for path in [
		"res://scripts/systems/world_generation/siege_mode_controller.gd",
		"res://scripts/systems/single_player_world_controller.gd",
		"res://scripts/systems/world_generation/world.gd",
		"res://hud.gd",
		"res://sound_fx.gd",
		"res://base.gd",
		"res://scripts/gameplay/collectibles/gems/gem.gd",
	]:
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string(path)
		var result := script.reload()
		print("COMPILE ", path, " => ", result)
	get_tree().quit(0)
