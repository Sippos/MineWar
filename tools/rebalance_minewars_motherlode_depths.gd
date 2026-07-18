extends Node

func _ready() -> void:
	var path := "res://scripts/systems/world_generation/world.gd"
	var source := FileAccess.get_file_as_string(path)
	source = source.replace("{\"stage\": 1, \"depth\": 6, \"count\": 3, \"rock\": 2}", "{\"stage\": 1, \"depth\": 12, \"count\": 3, \"rock\": 2}")
	source = source.replace("{\"stage\": 2, \"depth\": 13, \"count\": 4, \"rock\": 2}", "{\"stage\": 2, \"depth\": 18, \"count\": 4, \"rock\": 2}")
	source = source.replace("{\"stage\": 3, \"depth\": 20, \"count\": 6, \"rock\": 3}", "{\"stage\": 3, \"depth\": 24, \"count\": 6, \"rock\": 3}")
	source = source.replace("{\"stage\": 4, \"depth\": 27, \"count\": 8, \"rock\": 3}", "{\"stage\": 4, \"depth\": 28, \"count\": 8, \"rock\": 3}")
	source = source.replace("var fallback_depths := {1: 6, 2: 13, 3: 20, 4: 27}", "var fallback_depths := {1: 12, 2: 18, 3: 24, 4: 28}")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	print("MINEWARS_MOTHERLODE_DEPTHS_REBALANCED")
	get_tree().quit()
