extends Node

const CONTROLLER := "res://scripts/systems/single_player_world_controller.gd"
const AMBIENCE := "res://scripts/systems/stronghold_ambience_controller.gd"

func _ready() -> void:
	var controller := FileAccess.get_file_as_string(CONTROLLER)
	if controller.is_empty():
		push_error("Could not read single-player controller")
		get_tree().quit(1)
		return

	controller = controller.replace(
		"\t_refresh_stronghold_ambience()\n\tif Global.minewars_runs_completed > 0:\n\t\t_create_practice_gem_station()\n",
		"\t_refresh_stronghold_ambience()\n"
	)
	controller = controller.replace(
		'''\tvar line_wars := signs.get_node_or_null("LineWars") as Label
\tvar mine_wars := signs.get_node_or_null("MineWars") as Label
\tvar adventure := signs.get_node_or_null("Adventure") as Label
\tif line_wars:
\t\tline_wars.visible = false
\tif adventure:
\t\tadventure.visible = false
\tif mine_wars:
\t\tmine_wars.visible = true
\t\tmine_wars.text = "EXPEDITION SHAFT
DESCEND TO MINEWARS"
\t\tmine_wars.position = Vector2(-125, 276)
\t\tmine_wars.size = Vector2(250, 62)
\t\tmine_wars.modulate = Color.WHITE
''',
		'''\tvar line_wars := signs.get_node_or_null("LineWars") as Label
\tvar mine_wars := signs.get_node_or_null("MineWars") as Label
\tvar adventure := signs.get_node_or_null("Adventure") as Label
\tvar top_glow := signs.get_node_or_null("TopDoorGlow") as CanvasItem
\tvar right_glow := signs.get_node_or_null("RightDoorGlow") as CanvasItem
\tif top_glow:
\t\ttop_glow.visible = false
\tif right_glow:
\t\tright_glow.visible = false
\tif line_wars:
\t\tline_wars.visible = false
\tif adventure:
\t\tadventure.visible = false
\tif mine_wars:
\t\tmine_wars.visible = true
\t\tmine_wars.text = "EXPEDITION SHAFT\nDESCEND TO MINEWARS"
\t\tmine_wars.position = Vector2(-125, 214)
\t\tmine_wars.size = Vector2(250, 62)
\t\tmine_wars.modulate = Color.WHITE
'''
	)
	controller = controller.replace('str(reward.get("title", "STRONGHOLD EXPANDED"))', 'str(reward.get("title", "STRONGHOLD ENRICHED"))')

	var controller_file := FileAccess.open(CONTROLLER, FileAccess.WRITE)
	if controller_file == null:
		push_error("Could not write single-player controller")
		get_tree().quit(1)
		return
	controller_file.store_string(controller)
	controller_file.close()

	var ambience := FileAccess.get_file_as_string(AMBIENCE)
	if ambience.is_empty():
		push_error("Could not read ambience controller")
		get_tree().quit(1)
		return
	ambience = ambience.replace(
		'''\telse:
\t\t_create_forge_marker(Vector2(74, -14))
\t\t_create_forge_marker(Vector2(-78, -18))
\t\tvar caption := _create_caption("RAILWAY DORMANT", Vector2(-82, 78), Color(0.74, 0.58, 0.34, 0.72))
\t\tcaption.add_theme_font_size_override("font_size", 10)
''',
		'''\telse:
\t\t# Before the railway unlocks, quiet forge sparks make the base feel alive
\t\t# without advertising a missing feature in the middle of the room.
\t\t_create_forge_marker(Vector2(74, -14))
\t\t_create_forge_marker(Vector2(-78, -18))
'''
	)
	var ambience_file := FileAccess.open(AMBIENCE, FileAccess.WRITE)
	if ambience_file == null:
		push_error("Could not write ambience controller")
		get_tree().quit(1)
		return
	ambience_file.store_string(ambience)
	ambience_file.close()
	print("COMPACT_SINGLE_PLAYER_STRONGHOLD_CLEANED")
	get_tree().quit()
