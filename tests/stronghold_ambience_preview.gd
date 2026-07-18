extends Node

func _ready() -> void:
	Global.selected_base_id = Global.DEFAULT_BASE_ID
	Global.selected_hero_id = Global.DEFAULT_HERO_ID
	Global.current_hero = Global.DEFAULT_HERO_ID
	if not Global.unlocked_stronghold_ambience.has("dwarf_minecart"):
		Global.unlocked_stronghold_ambience.append("dwarf_minecart")
	get_tree().change_scene_to_file("res://scenes/world/preparation/preparation_hub.tscn")
