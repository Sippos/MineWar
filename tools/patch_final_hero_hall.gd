extends Node

func _ready() -> void:
	_patch_selector()
	_patch_controller()
	_patch_base_menu()
	get_tree().quit()

func _replace(path: String, from: String, to: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if not text.contains(from):
		push_error("Patch text not found in %s" % path)
		return
	text = text.replace(from, to)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)

func _patch_selector() -> void:
	var path := "res://scripts/systems/preparation/in_world_hero_selector.gd"
	_replace(path,
'''const HERO_POSITIONS := {
	"Undead King": Vector2(-285, -165),
	"Dwarf": Vector2(-110, -190),
	"Shaman": Vector2(95, -170),
	"Nerubian": Vector2(-275, 45),
	"Druid": Vector2(-80, 105),
}''',
'''const HERO_POSITIONS := {
	"Dwarf": Vector2(-265, -120),
	"Shaman": Vector2(0, -175),
	"Nerubian": Vector2(265, -120),
	"Druid": Vector2(-225, 145),
	"Undead King": Vector2(225, 145),
}''')
	_replace(path,
'''const HERO_CARD_SIDE := {
	"Undead King": 1.0,
	"Dwarf": 1.0,
	"Shaman": -1.0,
	"Nerubian": 1.0,
	"Druid": 1.0,
}''',
'''const HERO_CARD_SIDE := {
	"Dwarf": 1.0,
	"Shaman": 1.0,
	"Nerubian": -1.0,
	"Druid": 1.0,
	"Undead King": -1.0,
}''')
	_replace(path, 'const CARD_REVEAL_DISTANCE := 155.0\nconst INTERACT_DISTANCE := 90.0', 'const CARD_REVEAL_DISTANCE := 132.0\nconst INTERACT_DISTANCE := 46.0')
	_replace(path, 'var nearby_can_interact := false', 'var nearby_can_interact := false\nvar last_auto_zone := ""')
	_replace(path,
'''	var can_interact: bool = not closest.is_empty() and closest_distance <= INTERACT_DISTANCE
	if closest != nearby_hero or can_interact != nearby_can_interact:
		nearby_hero = closest
		nearby_distance = closest_distance
		nearby_can_interact = can_interact
		_refresh_shrines()
		_set_card_hero(nearby_hero)
	else:
		nearby_distance = closest_distance
	if not nearby_hero.is_empty():
		_update_card_position()''',
'''	var can_interact: bool = not closest.is_empty() and closest_distance <= INTERACT_DISTANCE
	if closest != nearby_hero or can_interact != nearby_can_interact:
		nearby_hero = closest
		nearby_distance = closest_distance
		nearby_can_interact = can_interact
		_refresh_shrines()
		_set_card_hero(nearby_hero)
	else:
		nearby_distance = closest_distance
	if not nearby_hero.is_empty():
		_update_card_position()
	if can_interact and closest != last_auto_zone:
		last_auto_zone = closest
		if _hero_unlocked(closest):
			_select_hero(closest)
		else:
			_show_locked_feedback(closest)
	elif not can_interact:
		last_auto_zone = ""''')
	_replace(path,
'''		glow.position = Vector2(0, 13)
		glow.polygon = PackedVector2Array([
			Vector2(-42, 0), Vector2(-29, -15), Vector2(0, -22), Vector2(29, -15),
			Vector2(42, 0), Vector2(29, 15), Vector2(0, 22), Vector2(-29, 15),
		])''',
'''		glow.position = Vector2(0, 20)
		glow.polygon = PackedVector2Array([
			Vector2(-28, 0), Vector2(-24, -14), Vector2(-14, -24), Vector2(0, -28),
			Vector2(14, -24), Vector2(24, -14), Vector2(28, 0), Vector2(24, 14),
			Vector2(14, 24), Vector2(0, 28), Vector2(-14, 24), Vector2(-24, 14),
		])''')
	_replace(path,
'''		pedestal.polygon = PackedVector2Array([
			Vector2(-49, 20), Vector2(-37, 3), Vector2(37, 3), Vector2(49, 20),
			Vector2(36, 37), Vector2(-36, 37),
		])''',
'''		pedestal.position = Vector2(0, 20)
		pedestal.polygon = PackedVector2Array([
			Vector2(-25, 0), Vector2(-21, -12), Vector2(-12, -21), Vector2(0, -25),
			Vector2(12, -21), Vector2(21, -12), Vector2(25, 0), Vector2(21, 12),
			Vector2(12, 21), Vector2(0, 25), Vector2(-12, 21), Vector2(-21, 12),
		])''')
	_replace(path,
'''		pedestal_edge.points = PackedVector2Array([
			Vector2(-49, 20), Vector2(-37, 3), Vector2(37, 3), Vector2(49, 20),
			Vector2(36, 37), Vector2(-36, 37), Vector2(-49, 20),
		])''',
'''		pedestal_edge.position = Vector2(0, 20)
		pedestal_edge.points = PackedVector2Array([
			Vector2(-25, 0), Vector2(-21, -12), Vector2(-12, -21), Vector2(0, -25),
			Vector2(12, -21), Vector2(21, -12), Vector2(25, 0), Vector2(21, 12),
			Vector2(12, 21), Vector2(0, 25), Vector2(-12, 21), Vector2(-21, 12), Vector2(-25, 0),
		])''')
	_replace(path, 'sprite.position = Vector2(0, -34)', 'sprite.position = Vector2(0, -22)')
	_replace(path, 'var scale_factor := 92.0 / maxf(texture_size.y, 1.0)', 'var scale_factor := 62.0 / maxf(texture_size.y, 1.0)')
	_replace(path, 'name_label.position = Vector2(-82, 40)\n\t\tname_label.size = Vector2(164, 23)', 'name_label.position = Vector2(-72, 48)\n\t\tname_label.size = Vector2(144, 20)')
	_replace(path, 'name_label.add_theme_font_size_override("font_size", 11)', 'name_label.add_theme_font_size_override("font_size", 9)')
	_replace(path, 'card_action.text = "E / Y  •  CHOOSE %s" % hero_name.to_upper()', 'card_action.text = "STEP ON THE RUNE TO CHOOSE"')
	_replace(path, 'card_action.text = "APPROACH THE ALTAR TO CHOOSE"', 'card_action.text = "APPROACH THE HERO RUNE"')

func _patch_controller() -> void:
	var path := "res://scripts/systems/single_player_world_controller.gd"
	_replace(path, 'const MINEWARS_ENTRY_Y := 5\nconst MINEWARS_MIN_X := -1\nconst MINEWARS_MAX_X := 1\nconst LINE_WARS_ENTRY_Y := -7\nconst ADVENTURE_ENTRY_X := 10\nconst ADVENTURE_MIN_Y := -1\nconst ADVENTURE_MAX_Y := 1', 'const MINEWARS_ENTRY_Y := 7\nconst MINEWARS_MIN_X := -1\nconst MINEWARS_MAX_X := 1\nconst LINE_WARS_ENTRY_Y := -7\nconst ADVENTURE_ENTRY_X := 10\nconst ADVENTURE_MIN_Y := -1\nconst ADVENTURE_MAX_Y := 1')
	_replace(path, 'var _last_locked_message := ""', 'var _last_locked_message := ""\nvar hub_camera: Camera2D')
	_replace(path,
'''	var player_camera := player.get_node_or_null("Camera2D") as Camera2D
	if player_camera:
		player_camera.enabled = true''',
'''	hub_camera = player.get_node_or_null("Camera2D") as Camera2D
	if hub_camera:
		hub_camera.enabled = true
		hub_camera.zoom = Vector2.ONE
		hub_camera.position_smoothing_enabled = false
		hub_camera.global_position = Vector2.ZERO''')
	_replace(path,
'''	if _committing or world == null or player == null:
		return
	var cell := block_layer.local_to_map(block_layer.to_local(player.global_position))''',
'''	if _committing or world == null or player == null:
		return
	if hub_camera:
		hub_camera.global_position = Vector2.ZERO
	var cell := block_layer.local_to_map(block_layer.to_local(player.global_position))''')
	_replace(path, 'line_wars.text = "↑  LINEWARS\\nENTER TOP DOOR"', 'line_wars.text = "LINEWARS\\nTOP TUNNEL"')
	_replace(path, 'mine_wars.text = "↓  MINEWARS\\nFIRST EXPEDITION"', 'mine_wars.text = "MINEWARS\\nBOTTOM TUNNEL"')
	_replace(path, 'adventure.text = "ADVENTURE  →\\nENTER RIGHT DOOR"', 'adventure.text = "ADVENTURE\\nRIGHT TUNNEL"')
	_replace(path,
'''	world.remove_meta("single_player_hub_active")
	world.begin_run_from_preparation()''',
'''	world.remove_meta("single_player_hub_active")
	if hub_camera:
		hub_camera.position = Vector2(0, -24)
		hub_camera.zoom = Vector2(1.5, 1.5)
		hub_camera.position_smoothing_enabled = true
	world.begin_run_from_preparation()''')

func _patch_base_menu() -> void:
	var path := "res://scripts/ui/menus/loadout_selection_menu.gd"
	_replace(path,
'''const BASE_DESCRIPTIONS := {
	"default_base": "A rugged dwarven stronghold built around forge and stone.",
	"shaman_base": "A spirit lodge shaped by totems, ritual fire, and clan craft.",
	"nerubian_base": "A living brood nest reinforced with web and chitin.",
	"druid_base": "A natural refuge grown from roots, earth, and ancient timber.",
	"undead_king_base": "A frozen citadel raised to shelter an undying army.",
}''',
'''const BASE_DESCRIPTIONS := {
	"default_base": "DWARF ENGINEERING  •  Unlocks the rail and Minecart upgrade path. Best for fast resource transport and dependable infrastructure.",
	"shaman_base": "TOTEM SANCTUARY  •  Unlocks Peon recruitment. Best for worker support, utility, and keeping the mine productive while you fight.",
	"nerubian_base": "BROOD NEST  •  Built around brood workers and summoned tunnel control. Best for spreading helpers through the mine.",
	"druid_base": "LIVING GROVE  •  Focuses on regeneration, roots, and nature utility. Best for recovery and flexible traversal support.",
	"undead_king_base": "SOUL CITADEL  •  Focuses on servants, attrition, and summoned defence. Best for building pressure through expendable minions.",
}''')
	_replace(path, 'title.text = "CHOOSE YOUR BASE"', 'title.text = "CHOOSE YOUR FORTRESS"')
	_replace(path, 'base_description_label.custom_minimum_size = Vector2(480, 38)', 'base_description_label.custom_minimum_size = Vector2(520, 64)')
	_replace(path, 'match_label.text = "MATCHING FORTRESS FOR %s" % matching_hero', 'match_label.text = "FACTION HOME  •  %s" % matching_hero')
