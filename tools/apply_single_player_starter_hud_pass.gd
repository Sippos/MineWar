extends Node

const COMPACT_WORLD := "res://scripts/systems/preparation/single_player_compact_world.gd"
const HUB_CONTROLLER := "res://scripts/systems/single_player_world_controller.gd"
const SIEGE_CONTROLLER := "res://scripts/systems/world_generation/siege_mode_controller.gd"
const HERO_ABILITIES := "res://hero_abilities.gd"
const HUD := "res://hud.gd"

func _ready() -> void:
	var ok := true
	# Compact cave constants were applied by the first pass attempt.
	ok = true and ok
	ok = _patch_hub_controller() and ok
	ok = _patch_siege_controller() and ok
	ok = _patch_hero_abilities() and ok
	ok = _patch_hud() and ok
	if ok:
		print("SINGLE_PLAYER_STARTER_HUD_PASS_APPLIED")
	get_tree().quit(0 if ok else 1)

func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _write(path: String, source: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return false
	file.store_string(source)
	file.close()
	return true

func _replace_required(source: String, old_text: String, new_text: String, label: String) -> Dictionary:
	if not source.contains(old_text):
		push_error("Missing patch anchor: %s" % label)
		return {"ok": false, "source": source}
	return {"ok": true, "source": source.replace(old_text, new_text)}

func _patch_compact_world() -> bool:
	var source := _read(COMPACT_WORLD)
	var result := _replace_required(
		source,
		"const FRESH_ROOM_HALF_WIDTH := 4\nconst PROGRESSED_ROOM_HALF_WIDTH := 5\nconst ROOM_Y_MIN := -3\nconst ROOM_Y_MAX := 3",
		"const FRESH_ROOM_HALF_WIDTH := 3\nconst PROGRESSED_ROOM_HALF_WIDTH := 4\nconst ROOM_Y_MIN := -2\nconst ROOM_Y_MAX := 3",
		"smaller single-player cave"
	)
	if not bool(result["ok"]):
		return false
	return _write(COMPACT_WORLD, str(result["source"]))

func _patch_hub_controller() -> bool:
	var source := _read(HUB_CONTROLLER)
	if not source.contains("player.position = Vector2(0, 105)"):
		push_error("Missing compact player spawn anchor")
		return false
	source = source.replace("player.position = Vector2(0, 105)", "player.position = Vector2(0, 84)")
	if not source.contains("hub_camera.position = Vector2(0, 20)
	hub_camera.zoom = Vector2(0.96, 0.96)"):
		push_error("Missing cozy hub camera anchor")
		return false
	source = source.replace(
		"hub_camera.position = Vector2(0, 20)
	hub_camera.zoom = Vector2(0.96, 0.96)",
		"hub_camera.position = Vector2(0, 12)
	hub_camera.zoom = Vector2(1.08, 1.08)"
	)
	var old_sign := '''mine_wars.text = "EXPEDITION SHAFT
DESCEND TO MINEWARS"'''
	if not source.contains(old_sign):
		push_error("Missing expedition sign anchor")
		return false
	source = source.replace(old_sign, 'mine_wars.text = "EXPEDITION SHAFT"')
	if not source.contains("mine_wars.position = Vector2(-125, 214)
		mine_wars.size = Vector2(250, 62)"):
		push_error("Missing compact expedition sign layout anchor")
		return false
	source = source.replace(
		"mine_wars.position = Vector2(-125, 214)
		mine_wars.size = Vector2(250, 62)",
		"mine_wars.position = Vector2(-125, 220)
		mine_wars.size = Vector2(250, 34)"
	)
	return _write(HUB_CONTROLLER, source)

func _patch_siege_controller() -> bool:
	var source := _read(SIEGE_CONTROLLER)
	var result := _replace_required(
		source,
		"\tui_layer.add_child(panel)\n\tvar margin := MarginContainer.new()",
		"\tui_layer.add_child(panel)\n\t# Objectives still drive world markers and completion feedback, but the large\n\t# permanent MineWars text card is intentionally removed from the play HUD.\n\tpanel.visible = false\n\tvar margin := MarginContainer.new()",
		"hide MineWars text card"
	)
	if not bool(result["ok"]):
		return false
	return _write(SIEGE_CONTROLLER, str(result["source"]))

func _patch_hero_abilities() -> bool:
	var source := _read(HERO_ABILITIES)
	var replacements := [
		["const ICON_SIZE := Vector2(68, 68)\n", "const ICON_SIZE := Vector2(68, 68)\nconst LEVEL_UP_MENU_SCENE := preload(\"res://scenes/ui/overlays/level_up/level_up_menu.tscn\")\n", "starter menu preload"],
		["var mole_level := 1", "var mole_level := 0", "Druid starter level"],
		["var undead_summon_level := 1", "var undead_summon_level := 0", "Undead starter level"],
		["var configured_input_player_id := 0\n", "var configured_input_player_id := 0\nvar starter_choice_open := false\nvar learned_hud_signature := \"\"\n", "starter HUD state"],
		["\t_ensure_hud()\n\t_update_facing_direction()", "\t_ensure_hud()\n\t_ensure_starter_choice()\n\t_update_facing_direction()", "starter choice process"],
		["\tvar hero := _hero_name()\n\tif hero != current_hud_hero:\n\t\t_initialize_starting_skill()\n\t\t_rebuild_hud()", "\tvar hero := _hero_name()\n\tvar learned_signature := _learned_ability_signature()\n\tif hero != current_hud_hero or learned_signature != learned_hud_signature:\n\t\t_initialize_starting_skill()\n\t\t_rebuild_hud()", "dynamic learned-slot refresh"],
		["func _initialize_starting_skill() -> void:\n\tmatch _hero_name():\n\t\tHERO_DWARF:\n\t\t\tif int(player.get(\"stomp_level\")) <= 0:\n\t\t\t\tplayer.set(\"stomp_level\", 1)\n\t\tHERO_SHAMAN:\n\t\t\tif totem_level <= 0:\n\t\t\t\ttotem_level = 1\n\t\tHERO_NERUBIAN:\n\t\t\tif brood_level <= 0:\n\t\t\t\tbrood_level = 1\n", _starting_skill_functions(), "starter choice functions"],
		["func get_level_up_options() -> Array:\n\tvar options := []", "func get_level_up_options() -> Array:\n\tif starter_choice_open:\n\t\treturn _starter_options()\n\tvar options := []", "starter option filter"],
		["\treturn options\n\nfunc _option(id: String", "\treturn options\n\n" + _starter_options_function() + "\nfunc _option(id: String", "starter options function"],
		["\t_refresh_stats_hud()\n\t_update_ability_hud()", "\tstarter_choice_open = false\n\t_refresh_stats_hud()\n\t_rebuild_hud()", "rebuild slots after learning"],
		["\tability_bar.visible = definitions.size() > 0\n\tfor definition in definitions:\n\t\tvar ability_id := str(definition[0])", "\tvar learned_definitions := []\n\tfor definition in definitions:\n\t\tif _ability_is_learned(str(definition[0])):\n\t\t\tlearned_definitions.append(definition)\n\tability_bar.visible = learned_definitions.size() > 0\n\tfor definition in learned_definitions:\n\t\tvar ability_id := str(definition[0])", "hide unlearned ability slots"],
		["\t_update_ability_hud()\n\nfunc _mobile_action_for_ability", "\tlearned_hud_signature = _learned_ability_signature()\n\t_update_ability_hud()\n\nfunc _mobile_action_for_ability", "store learned HUD signature"]
	]
	for entry in replacements:
		var result := _replace_required(source, entry[0], entry[1], entry[2])
		if not bool(result["ok"]):
			return false
		source = str(result["source"])
	return _write(HERO_ABILITIES, source)

func _starting_skill_functions() -> String:
	return '''func _initialize_starting_skill() -> void:
	# Single player now begins each expedition by choosing one of three basic
	# abilities. Other modes retain one automatic starter so co-op never opens two
	# competing modal menus.
	if _uses_single_player_starter_choice():
		return
	match _hero_name():
		HERO_DWARF:
			if int(player.get("stomp_level")) <= 0:
				player.set("stomp_level", 1)
		HERO_SHAMAN:
			if totem_level <= 0:
				totem_level = 1
		HERO_NERUBIAN:
			if brood_level <= 0:
				brood_level = 1
		HERO_DRUID:
			if mole_level <= 0:
				mole_level = 1
		HERO_UNDEAD_KING:
			if undead_summon_level <= 0:
				undead_summon_level = 1

func _uses_single_player_starter_choice() -> bool:
	if _player_id() != 1 or world == null or world.get_parent() == null:
		return false
	return world.get_parent().name == "SinglePlayerWorld"

func _ensure_starter_choice() -> void:
	if not _uses_single_player_starter_choice() or not GameMode.is_siege():
		return
	if starter_choice_open or _has_any_learned_basic_ability() or get_tree().paused:
		return
	if _starter_options().is_empty():
		return
	starter_choice_open = true
	get_tree().paused = true
	var menu := LEVEL_UP_MENU_SCENE.instantiate()
	menu.name = "StarterAbilityChoice"
	world.add_child(menu)
	if menu.has_method("setup_for_player"):
		menu.setup_for_player(player)
	menu.connect("upgrade_selected", Callable(self, "_on_starter_ability_selected"), CONNECT_ONE_SHOT)

func _on_starter_ability_selected(ability_id: String) -> void:
	# Ground Stomp is stored on Player for legacy combat compatibility; every
	# other starter is owned directly by this controller.
	if ability_id == "stomp" and int(player.get("stomp_level")) <= 0:
		player.set("stomp_level", 1)
	starter_choice_open = false
	call_deferred("_rebuild_hud")

func _has_any_learned_basic_ability() -> bool:
	match _hero_name():
		HERO_DWARF:
			return int(player.get("stomp_level")) > 0 or hammer_level > 0 or bash_level > 0
		HERO_SHAMAN:
			return totem_level > 0 or chain_level > 0 or wisdom_level > 0
		HERO_NERUBIAN:
			return brood_level > 0 or web_level > 0 or carapace_level > 0
		HERO_DRUID:
			return mole_level > 0 or tunnel_level > 0 or deep_roots_level > 0
		HERO_UNDEAD_KING:
			return undead_summon_level > 0 or grave_might_level > 0 or soul_harvest_level > 0
	return true

func _ability_is_learned(ability_id: String) -> bool:
	match ability_id:
		"stomp": return int(player.get("stomp_level")) > 0
		"hammer": return hammer_level > 0
		"bash": return bash_level > 0
		"avatar": return avatar_level > 0
		"totem": return totem_level > 0
		"chain": return chain_level > 0
		"wisdom": return wisdom_level > 0
		"ascendance": return ascendance_level > 0
		"brood": return brood_level > 0
		"web": return web_level > 0
		"carapace": return carapace_level > 0
		"broodmother": return broodmother_level > 0
		"mole": return mole_level > 0
		"tunnel": return tunnel_level > 0
		"deep_roots": return deep_roots_level > 0
		"worldroot": return worldroot_level > 0
		"raise_dead": return undead_summon_level > 0
		"grave_might": return grave_might_level > 0
		"soul_harvest": return soul_harvest_level > 0
		"death_march": return death_march_level > 0
	return false

func _learned_ability_signature() -> String:
	return "%s:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d" % [
		_hero_name(), int(player.get("stomp_level")), hammer_level, bash_level, avatar_level,
		totem_level, chain_level, wisdom_level, ascendance_level,
		brood_level, web_level, carapace_level, broodmother_level,
		mole_level, tunnel_level, deep_roots_level, worldroot_level,
		undead_summon_level, grave_might_level, soul_harvest_level + death_march_level
	]
'''

func _starter_options_function() -> String:
	return '''func _starter_options() -> Array:
	match _hero_name():
		HERO_DWARF:
			return [
				_option("stomp", "Ground Stomp", "Area damage and stun", int(player.get("stomp_level")), MAX_BASIC_LEVEL, 0),
				_option("hammer", "Throwing Hammer", "Ranged stun that breaks soft blocks", hammer_level, MAX_BASIC_LEVEL, 0),
				_option("bash", "Dwarven Bash", "Every third attack or mined block is empowered", bash_level, MAX_BASIC_LEVEL, 0),
			]
		HERO_SHAMAN:
			return [
				_option("totem", "Totemic Invocation", "Choose Dig, Heal, Radar, or Gem totem", totem_level, MAX_BASIC_LEVEL, 0),
				_option("chain", "Chain Lightning", "Lightning jumps between nearby enemies", chain_level, MAX_BASIC_LEVEL, 0),
				_option("wisdom", "Ancestral Wisdom", "Improves totems and grants Intelligence", wisdom_level, MAX_BASIC_LEVEL, 0),
			]
		HERO_NERUBIAN:
			return [
				_option("brood", "Spawn Brood", "More, faster, longer-lived mining spiders", brood_level, MAX_BASIC_LEVEL, 0),
				_option("web", "Web Burst", "Damage, root, and slow nearby enemies", web_level, MAX_BASIC_LEVEL, 0),
				_option("carapace", "Worker Carapace", "Toughens the hero and improves spider digging", carapace_level, MAX_BASIC_LEVEL, 0),
			]
		HERO_DRUID:
			return [
				_option("mole", "Mole Form", "Transform for faster digging", mole_level, MAX_BASIC_LEVEL, 0),
				_option("tunnel", "Burrow Tunnel", "Place linked tunnel openings", tunnel_level, MAX_BASIC_LEVEL, 0),
				_option("deep_roots", "Deep Roots", "Gain health and natural recovery", deep_roots_level, MAX_BASIC_LEVEL, 0),
			]
		HERO_UNDEAD_KING:
			return [
				_option("raise_dead", "Raise Dead", "Summon an undead miner", undead_summon_level, MAX_BASIC_LEVEL, 0),
				_option("grave_might", "Grave Might", "Empower the undead host", grave_might_level, MAX_BASIC_LEVEL, 0),
				_option("soul_harvest", "Soul Harvest", "Minion damage heals the king", soul_harvest_level, MAX_BASIC_LEVEL, 0),
			]
	return []
'''

func _patch_hud() -> bool:
	var source := _read(HUD)
	var replacements := [
		["var hero_portrait_timer: Label\n", "var hero_portrait_timer: Label\nvar hero_level_badge: PanelContainer\nvar hero_level_label: Label\n", "hero level badge variables"],
		["\tportrait_content.add_child(hero_portrait_timer)\n\n\tadd_child(hero_portrait_container)", "\tportrait_content.add_child(hero_portrait_timer)\n\n" + _level_badge_setup() + "\n\tadd_child(hero_portrait_container)", "hero level badge setup"],
		["\tvar hero_name = _get_active_hero_name_for_portrait()\n\tif not force and hero_name == hero_portrait_hero_name:", "\tvar hero_name = _get_active_hero_name_for_portrait()\n\t_refresh_hero_level_badge()\n\tif not force and hero_name == hero_portrait_hero_name:", "refresh hero level badge"],
		["func _refresh_base_status_icon(hero_name: String = \"\") -> void:", _level_badge_refresh() + "\nfunc _refresh_base_status_icon(hero_name: String = \"\") -> void:", "hero level badge refresh function"]
	]
	for entry in replacements:
		var result := _replace_required(source, entry[0], entry[1], entry[2])
		if not bool(result["ok"]):
			return false
		source = str(result["source"])
	return _write(HUD, source)

func _level_badge_setup() -> String:
	return '''	hero_level_badge = PanelContainer.new()
	hero_level_badge.name = "LevelBadge"
	hero_level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_level_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hero_level_badge.offset_left = -25
	hero_level_badge.offset_top = -25
	hero_level_badge.offset_right = 1
	hero_level_badge.offset_bottom = 1
	var level_style := StyleBoxFlat.new()
	level_style.bg_color = Color(0.06, 0.035, 0.015, 0.98)
	level_style.border_color = Color(1.0, 0.72, 0.24, 1.0)
	level_style.set_border_width_all(2)
	level_style.set_corner_radius_all(13)
	hero_level_badge.add_theme_stylebox_override("panel", level_style)
	portrait_content.add_child(hero_level_badge)
	hero_level_label = Label.new()
	hero_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_level_label.add_theme_font_size_override("font_size", 12)
	hero_level_label.add_theme_color_override("font_color", Color.WHITE)
	hero_level_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hero_level_label.add_theme_constant_override("outline_size", 3)
	hero_level_badge.add_child(hero_level_label)
'''

func _level_badge_refresh() -> String:
	return '''func _refresh_hero_level_badge() -> void:
	if hero_level_label == null:
		return
	var player := _get_player_node()
	var level_value := 1
	if player != null and player.get("level") != null:
		level_value = maxi(1, int(player.get("level")))
	hero_level_label.text = str(level_value)
'''
