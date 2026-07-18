extends Node

func _ready() -> void:
	var path := "res://scripts/systems/world_generation/siege_mode_controller.gd"
	var source := FileAccess.get_file_as_string(path)
	source = source.replace("\t\tvar prospect := world.get_minewars_prospect_hint(stage_number) if world.has_method(\"get_minewars_prospect_hint\") else \"\"", "\t\tvar prospect: String = str(world.get_minewars_prospect_hint(stage_number)) if world.has_method(\"get_minewars_prospect_hint\") else \"\"")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	print("MINEWARS_PROSPECT_TYPES_FIXED")
	get_tree().quit()
