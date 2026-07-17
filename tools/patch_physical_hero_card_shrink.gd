extends Node

func _ready() -> void:
	var path := "res://scripts/systems/preparation/in_world_hero_selector.gd"
	var source := FileAccess.get_file_as_string(path)
	var before := "card_ability_list.size_flags_vertical = Control.SIZE_EXPAND_FILL"
	var after := "card_ability_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN"
	if source.contains(before):
		source = source.replace(before, after)
	else:
		push_warning("Ability-list size flag patch target was not found")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(source)
		file.close()
	get_tree().quit()
