extends Node

const TARGET := "res://scripts/systems/single_player_world_controller.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(TARGET)
	if source.is_empty():
		push_error("Could not read single_player_world_controller.gd")
		get_tree().quit(1)
		return

	source = source.replace("\tplayer.position = Vector2(0, 150)\n", "\tplayer.position = Vector2(0, 105)\n")
	source = source.replace("\t_refresh_stronghold_ambience()\n\t_create_practice_gem_station()\n", "\t_refresh_stronghold_ambience()\n\tif Global.minewars_runs_completed > 0:\n\t\t_create_practice_gem_station()\n")
	source = source.replace("\thub_camera.zoom = Vector2(0.82, 0.82)\n", "\thub_camera.zoom = Vector2(0.96, 0.96)\n")
	source = source.replace("\trestore.tween_property(hub_camera, \"zoom\", Vector2(0.82, 0.82), 0.45)\n", "\trestore.tween_property(hub_camera, \"zoom\", Vector2(0.96, 0.96), 0.45)\n")

	var hud_anchor := '''\thub_hud = HUB_HUD_SCENE.instantiate() as CanvasLayer
\tadd_child(hub_hud)
\tstatus_label = hub_hud.get_node("StatusPanel/Margin/Status") as Label
'''
	var hud_replacement := '''\thub_hud = HUB_HUD_SCENE.instantiate() as CanvasLayer
\tadd_child(hub_hud)
\tvar hub_title := hub_hud.get_node("TopPanel/Margin/VBox/Title") as Label
\tvar hub_subtitle := hub_hud.get_node("TopPanel/Margin/VBox/Subtitle") as Label
\tstatus_label = hub_hud.get_node("StatusPanel/Margin/Status") as Label
\thub_title.text = "STRONGHOLD"
\thub_subtitle.text = "One warm base  •  one expedition shaft"
'''
	if source.contains(hud_anchor):
		source = source.replace(hud_anchor, hud_replacement)

	source = _replace_function(source, "func _process(_delta: float) -> void:", "func _advanced_modes_unlocked() -> bool:", _compact_process())
	source = _replace_function(source, "func _configure_progression_signs() -> void:", "func _set_initial_status() -> void:", _compact_signs())

	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not write single_player_world_controller.gd")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("COMPACT_SINGLE_PLAYER_STRONGHOLD_APPLIED")
	get_tree().quit()

func _replace_function(source: String, start_marker: String, end_marker: String, replacement: String) -> String:
	var start_index := source.find(start_marker)
	var end_index := source.find(end_marker, start_index + start_marker.length())
	if start_index < 0 or end_index < 0:
		push_error("Could not replace function beginning with %s" % start_marker)
		get_tree().quit(1)
		return source
	return source.substr(0, start_index) + replacement + "\n\n" + source.substr(end_index)

func _compact_process() -> String:
	return '''func _process(_delta: float) -> void:
	if _committing or world == null or player == null:
		return
	if Global.selected_base_id != _last_ambience_base_id:
		_refresh_stronghold_ambience()
	var cell := block_layer.local_to_map(block_layer.to_local(player.global_position))
	var in_expedition_shaft := cell.x >= ROUTE_X_MIN and cell.x <= ROUTE_X_MAX
	if in_expedition_shaft and cell.y >= MINE_WARS_ENTRY_Y:
		_activate_standard_mode(GameMode.Mode.SIEGE, "MineWars active — mine, return resources, and survive the assault.")
'''

func _compact_signs() -> String:
	return '''func _configure_progression_signs() -> void:
	if signs == null:
		return
	var line_wars := signs.get_node_or_null("LineWars") as Label
	var mine_wars := signs.get_node_or_null("MineWars") as Label
	var adventure := signs.get_node_or_null("Adventure") as Label
	if line_wars:
		line_wars.visible = false
	if adventure:
		adventure.visible = false
	if mine_wars:
		mine_wars.visible = true
		mine_wars.text = "EXPEDITION SHAFT\nDESCEND TO MINEWARS"
		mine_wars.position = Vector2(-125, 276)
		mine_wars.size = Vector2(250, 62)
		mine_wars.modulate = Color.WHITE
'''
