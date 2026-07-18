extends Node

var failures: Array[String] = []

func _ready() -> void:
	patch_base()
	patch_player()
	patch_mech_pilot()
	patch_global()
	patch_mech_unlock()
	patch_hub_ambience()
	patch_preparation()
	patch_loadout()
	patch_lexicon()
	if failures.is_empty():
		print("BASE_IDENTITIES_PATCH_OK")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func replace_once(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		failures.append("Could not read %s" % path)
		return
	if source.contains(new_text):
		return
	if not source.contains(old_text):
		failures.append("Missing patch target in %s: %s" % [path, old_text.left(100)])
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write %s" % path)
		return
	file.store_string(source.replace(old_text, new_text))
	file.close()

func patch_base() -> void:
	var path := "res://base.gd"
	replace_once(path, "extends Area2D\n\nsignal gems_deposited", "extends Area2D\n\nconst BASE_IDENTITY_SCRIPT := preload(\"res://base_identity_controller.gd\")\n\nsignal gems_deposited")
	replace_once(path, "\t\"undead_king_base\": preload(\"res://UndeadKingBase.png\")\n}", "\t\"undead_king_base\": preload(\"res://UndeadKingBase.png\"),\n\t\"mech_base\": preload(\"res://DwarfBase.png\")\n}")
	replace_once(path, "\tcall_deferred(\"refresh_base_sprite\")", "\tif get_node_or_null(\"BaseIdentityController\") == null:\n\t\tvar identity := Node.new()\n\t\tidentity.name = \"BaseIdentityController\"\n\t\tidentity.set_script(BASE_IDENTITY_SCRIPT)\n\t\tadd_child(identity)\n\tcall_deferred(\"refresh_base_sprite\")")

func patch_player() -> void:
	replace_once("res://player.gd", "\treturn BASE_FREE_CARRY_ALLOWANCE + strength_bonus + cave_reward_carry_bonus + permanent_carry_bonus", "\tvar base_carry_bonus := int(get_meta(\"base_carry_bonus\", 0))\n\treturn BASE_FREE_CARRY_ALLOWANCE + strength_bonus + cave_reward_carry_bonus + permanent_carry_bonus + base_carry_bonus")

func patch_mech_pilot() -> void:
	replace_once("res://mech_player_pilot.gd", "\trebuild_timer = minf(REBUILD_TIME, rebuild_timer + delta)", "\tvar rebuild_multiplier := float(base.get_meta(\"mech_rebuild_multiplier\", 1.0))\n\trebuild_timer = minf(REBUILD_TIME, rebuild_timer + delta * rebuild_multiplier)")

func patch_global() -> void:
	replace_once("res://global.gd", "\t\"undead_king_base\": {\n\t\t\"name\": \"Undead Citadel\",\n\t\t\"texture\": preload(\"res://UndeadKingBase.png\")\n\t}\n}", "\t\"undead_king_base\": {\n\t\t\"name\": \"Undead Citadel\",\n\t\t\"texture\": preload(\"res://UndeadKingBase.png\")\n\t},\n\t\"mech_base\": {\n\t\t\"name\": \"Goblin Mech Workshop\",\n\t\t\"texture\": preload(\"res://DwarfBase.png\")\n\t}\n}")

func patch_mech_unlock() -> void:
	var path := "res://mech_unlock_persistence.gd"
	replace_once(path, "\t\"type\": \"hero\",\n\t\"hero\": \"Mech\",", "\t\"type\": \"hero_base\",\n\t\"hero\": \"Mech\",\n\t\"base\": \"mech_base\",")
	replace_once(path, "\tif global_state and global_state.has_method(\"unlock_hero\"):\n\t\tglobal_state.unlock_hero(\"Mech\")", "\tif global_state and global_state.has_method(\"unlock_hero\"):\n\t\tglobal_state.unlock_hero(\"Mech\")\n\tif global_state and global_state.has_method(\"unlock_base\"):\n\t\tglobal_state.unlock_base(\"mech_base\")")

func patch_hub_ambience() -> void:
	var path := "res://scripts/systems/single_player_world_controller.gd"
	var old_text := "func _refresh_stronghold_ambience() -> void:\n\t_last_ambience_base_id = Global.selected_base_id\n\tvar should_show_dwarf_cart := Global.selected_base_id == Global.DEFAULT_BASE_ID and Global.is_stronghold_ambience_unlocked(\"dwarf_minecart\")\n\tif should_show_dwarf_cart and stronghold_ambience != null and is_instance_valid(stronghold_ambience):\n\t\treturn\n\tif stronghold_ambience != null and is_instance_valid(stronghold_ambience):\n\t\tstronghold_ambience.queue_free()\n\tstronghold_ambience = null\n\tif not should_show_dwarf_cart or world == null or base == null:\n\t\treturn\n\tvar ambience := Node2D.new()\n\tambience.name = \"StrongholdAmbience\"\n\tambience.set_script(STRONGHOLD_AMBIENCE_SCRIPT)\n\tambience.position = base.position\n\tworld.add_child(ambience)\n\tstronghold_ambience = ambience"
	var new_text := "func _refresh_stronghold_ambience() -> void:\n\t_last_ambience_base_id = Global.selected_base_id\n\tvar selected_base := str(Global.selected_base_id)\n\tvar cart_unlocked := selected_base == Global.DEFAULT_BASE_ID and Global.is_stronghold_ambience_unlocked(\"dwarf_minecart\")\n\tvar signature := \"%s:%s\" % [selected_base, str(cart_unlocked)]\n\tif stronghold_ambience != null and is_instance_valid(stronghold_ambience) and str(stronghold_ambience.get_meta(\"ambience_signature\", \"\")) == signature:\n\t\treturn\n\tif stronghold_ambience != null and is_instance_valid(stronghold_ambience):\n\t\tstronghold_ambience.queue_free()\n\tstronghold_ambience = null\n\tif world == null or base == null:\n\t\treturn\n\tvar ambience := Node2D.new()\n\tambience.name = \"StrongholdAmbience\"\n\tambience.set_script(STRONGHOLD_AMBIENCE_SCRIPT)\n\tambience.set(\"base_id\", selected_base)\n\tambience.set(\"dwarf_cart_unlocked\", cart_unlocked)\n\tambience.set_meta(\"ambience_signature\", signature)\n\tambience.position = base.position\n\tworld.add_child(ambience)\n\tstronghold_ambience = ambience"
	replace_once(path, old_text, new_text)

func patch_preparation() -> void:
	var path := "res://scripts/systems/preparation/preparation_world_controller.gd"
	replace_once(path, "const BASE_ORDER := [\"shaman_base\", \"nerubian_base\", \"default_base\", \"druid_base\", \"undead_king_base\"]", "const BASE_ORDER := [\"shaman_base\", \"nerubian_base\", \"default_base\", \"mech_base\", \"druid_base\", \"undead_king_base\"]")
	replace_once(path, "const BASE_POSITIONS := [\n\tVector2(-188, -222),\n\tVector2(-94, -222),\n\tVector2(0, -222),\n\tVector2(94, -222),\n\tVector2(188, -222)\n]", "const BASE_POSITIONS := [\n\tVector2(-235, -222),\n\tVector2(-141, -222),\n\tVector2(-47, -222),\n\tVector2(47, -222),\n\tVector2(141, -222),\n\tVector2(235, -222)\n]")
	var old_details := "const BASE_DETAILS := {\n\t\"default_base\": {\n\t\t\"archetype\": \"DWARF ENGINEERING\",\n\t\t\"summary\": \"The dependable all-round bastion.\",\n\t\t\"upgrades\": \"MINECART  •  Build a cart for the dwarf rail network.\"\n\t},\n\t\"shaman_base\": {\n\t\t\"archetype\": \"TOTEM SANCTUARY\",\n\t\t\"summary\": \"A support-focused lodge for utility-heavy runs.\",\n\t\t\"upgrades\": \"PEON  •  Recruit a worker to support the mine.\"\n\t},\n\t\"nerubian_base\": {\n\t\t\"archetype\": \"BROOD NEST\",\n\t\t\"summary\": \"A living fortress designed around summoned defenders.\",\n\t\t\"upgrades\": \"BROOD WORKER  •  Planned faction helper for tunnel control.\"\n\t},\n\t\"druid_base\": {\n\t\t\"archetype\": \"LIVING GROVE\",\n\t\t\"summary\": \"A regenerative base with nature-driven utility.\",\n\t\t\"upgrades\": \"GROVE WISP  •  Planned faction support for regeneration.\"\n\t},\n\t\"undead_king_base\": {\n\t\t\"archetype\": \"SOUL CITADEL\",\n\t\t\"summary\": \"A dark stronghold built for attrition and summoned pressure.\",\n\t\t\"upgrades\": \"SOUL THRALL  •  Planned faction servant for base defense.\"\n\t}\n}"
	var new_details := "const BASE_DETAILS := {\n\t\"default_base\": {\n\t\t\"archetype\": \"DWARF ENGINEERING\",\n\t\t\"summary\": \"Carry one extra gem without slowdown. Repairs 8 bastion HP after every assault.\",\n\t\t\"upgrades\": \"PASSIVE +1 carry  •  DEFENCE post-assault repairs  •  WORLD railway and minecart\"\n\t},\n\t\"shaman_base\": {\n\t\t\"archetype\": \"TOTEM SANCTUARY\",\n\t\t\"summary\": \"Ancestral pulses reveal nearby crystal seams. A healing totem supports the defence area.\",\n\t\t\"upgrades\": \"PASSIVE crystal prospect pulse  •  DEFENCE healing totem  •  WORLD peon patrol\"\n\t},\n\t\"nerubian_base\": {\n\t\t\"archetype\": \"BROOD NEST\",\n\t\t\"summary\": \"Detects assaults three seconds earlier and webs the first three attackers.\",\n\t\t\"upgrades\": \"PASSIVE +3s warning  •  DEFENCE breach webs  •  WORLD crawling brood\"\n\t},\n\t\"mech_base\": {\n\t\t\"archetype\": \"GOBLIN WORKSHOP\",\n\t\t\"summary\": \"Reinforces the bastion, fires an automatic turret, and rebuilds the Mech faster.\",\n\t\t\"upgrades\": \"PASSIVE +15 base HP and rapid rebuild  •  DEFENCE auto-turret  •  WORLD crane and repair bay\"\n\t},\n\t\"druid_base\": {\n\t\t\"archetype\": \"LIVING GROVE\",\n\t\t\"summary\": \"Regenerates the hero while safe. Periodic roots entangle enemies near the bastion.\",\n\t\t\"upgrades\": \"PASSIVE safe regeneration  •  DEFENCE root pulse  •  WORLD wisps and living roots\"\n\t},\n\t\"undead_king_base\": {\n\t\t\"archetype\": \"SOUL CITADEL\",\n\t\t\"summary\": \"Enemy deaths charge souls. Four souls release a nova or repair the bastion.\",\n\t\t\"upgrades\": \"PASSIVE soul collection  •  DEFENCE nova or soul mend  •  WORLD orbiting spirits\"\n\t}\n}"
	replace_once(path, old_details, new_details)
	replace_once(path, "\t\tvar pad := _create_base_pad(base_id, BASE_POSITIONS[index])\n\t\tchoices_root.add_child(pad)\n\t\tbase_pads.append({\"id\": base_id, \"node\": pad, \"phase\": float(index) * 0.85})", "\t\tvar unlocked := Global.is_base_unlocked(base_id)\n\t\tvar pad := _create_base_pad(base_id, BASE_POSITIONS[index], unlocked)\n\t\tchoices_root.add_child(pad)\n\t\tbase_pads.append({\"id\": base_id, \"node\": pad, \"phase\": float(index) * 0.85, \"unlocked\": unlocked})")
	replace_once(path, "func _create_base_pad(base_id: String, pad_position: Vector2) -> Node2D:", "func _create_base_pad(base_id: String, pad_position: Vector2, unlocked: bool) -> Node2D:")
	replace_once(path, "\tdisk.color = Color(0.18, 0.105, 0.025, 0.58)", "\tdisk.color = Color(0.18, 0.105, 0.025, 0.58) if unlocked else Color(0.035, 0.045, 0.055, 0.7)")
	replace_once(path, "\tring.default_color = Color(0.95, 0.62, 0.2, 0.7)", "\tring.default_color = Color(0.95, 0.62, 0.2, 0.7) if unlocked else Color(0.28, 0.33, 0.38, 0.52)")
	replace_once(path, "\tsprite.position = Vector2(0, -18)\n\thover.add_child(sprite)", "\tsprite.position = Vector2(0, -18)\n\tsprite.modulate = (Color(1.16, 0.82, 0.46, 1.0) if base_id == \"mech_base\" else Color.WHITE) if unlocked else Color(0.32, 0.36, 0.4, 0.62)\n\thover.add_child(sprite)")
	replace_once(path, "\tlabel.add_theme_color_override(\"font_color\", Color(1.0, 0.84, 0.52, 1.0))", "\tlabel.add_theme_color_override(\"font_color\", Color(1.0, 0.84, 0.52, 1.0) if unlocked else Color(0.45, 0.5, 0.54, 1.0))")
	replace_once(path, "\thover.add_child(label)\n\treturn pad", "\thover.add_child(label)\n\tif not unlocked:\n\t\tvar lock_label := Label.new()\n\t\tlock_label.name = \"LockedLabel\"\n\t\tlock_label.position = Vector2(-42, -67)\n\t\tlock_label.size = Vector2(84, 18)\n\t\tlock_label.text = \"LOCKED\"\n\t\tlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\t\tlock_label.add_theme_font_size_override(\"font_size\", 8)\n\t\tlock_label.add_theme_color_override(\"font_color\", Color(0.5, 0.56, 0.6, 0.96))\n\t\tlock_label.add_theme_color_override(\"font_outline_color\", Color.BLACK)\n\t\tlock_label.add_theme_constant_override(\"outline_size\", 2)\n\t\thover.add_child(lock_label)\n\treturn pad")
	replace_once(path, "func _select_base(entry: Dictionary) -> void:\n\tvar base_id := str(entry[\"id\"])", "func _select_base(entry: Dictionary) -> void:\n\tif not bool(entry.get(\"unlocked\", false)):\n\t\treturn\n\tvar base_id := str(entry[\"id\"])")
	replace_once(path, "\t\tdetail_body.text = \"%s\\nUPGRADE PREVIEW  •  %s\"", "\t\tdetail_body.text = \"%s\\nBASE EFFECTS  •  %s\"")
	replace_once(path, "\t\tvar selected := Global.selected_base_id == choice_id\n\t\tdetail_style.border_color = Color(1.0, 0.7, 0.24, 0.95)", "\t\tvar unlocked := bool(entry.get(\"unlocked\", false))\n\t\tvar selected := unlocked and Global.selected_base_id == choice_id\n\t\tdetail_style.border_color = Color(1.0, 0.7, 0.24, 0.95) if unlocked else Color(0.38, 0.43, 0.48, 0.9)")
	replace_once(path, "\t\tif selected:\n\t\t\tdetail_hint.text = \"SELECTED  •  This base will anchor the run.\"", "\t\tif not unlocked:\n\t\t\tvar requirement := \"Defeat the Goblin War Mech and its pilot.\" if choice_id == \"mech_base\" else \"Earn more MineWars victories to recruit this faction.\"\n\t\t\tdetail_hint.text = \"LOCKED  •  %s\" % requirement\n\t\t\tdetail_hint.add_theme_color_override(\"font_color\", Color(0.66, 0.68, 0.7, 1.0))\n\t\t\tstatus_label.text = \"%s has not joined the stronghold yet.\" % base_name\n\t\telif selected:\n\t\t\tdetail_hint.text = \"SELECTED  •  Mix this base freely with any unlocked hero.\"")
	replace_once(path, "\t\tvar selected := base_id == Global.selected_base_id\n\t\tvar hovered := _nearby_kind == \"base\"", "\t\tvar unlocked := bool(entry.get(\"unlocked\", false))\n\t\tvar selected := unlocked and base_id == Global.selected_base_id\n\t\tvar hovered := _nearby_kind == \"base\"")
	replace_once(path, "\t\telif hovered:\n\t\t\tring.default_color = Color(1.0, 0.72, 0.28, 1.0)", "\t\telif hovered and unlocked:\n\t\t\tring.default_color = Color(1.0, 0.72, 0.28, 1.0)")
	replace_once(path, "\t\telse:\n\t\t\tring.default_color = Color(0.92, 0.58, 0.18, 0.72)\n\t\t\tring.width = 2.0\n\t\t\tdisk.color = Color(0.12, 0.075, 0.025, 0.84)", "\t\telif hovered:\n\t\t\tring.default_color = Color(0.48, 0.52, 0.56, 0.9)\n\t\t\tring.width = 3.0\n\t\t\tdisk.color = Color(0.04, 0.055, 0.065, 0.9)\n\t\t\tpad.scale = Vector2(1.02, 1.02)\n\t\telse:\n\t\t\tring.default_color = Color(0.92, 0.58, 0.18, 0.72) if unlocked else Color(0.25, 0.3, 0.34, 0.55)\n\t\t\tring.width = 2.0\n\t\t\tdisk.color = Color(0.12, 0.075, 0.025, 0.84) if unlocked else Color(0.025, 0.04, 0.055, 0.88)")

func patch_loadout() -> void:
	var path := "res://scripts/ui/menus/loadout_selection_menu.gd"
	replace_once(path, "const BASE_ORDER: Array[String] = [\"default_base\", \"shaman_base\", \"nerubian_base\", \"druid_base\", \"undead_king_base\"]", "const BASE_ORDER: Array[String] = [\"default_base\", \"shaman_base\", \"nerubian_base\", \"mech_base\", \"druid_base\", \"undead_king_base\"]")
	replace_once(path, "\t\"undead_king_base\": \"Undead King\",\n}", "\t\"undead_king_base\": \"Undead King\",\n\t\"mech_base\": \"Mech\",\n}")
	var old_desc := "const BASE_DESCRIPTIONS := {\n\t\"default_base\": \"DWARF ENGINEERING  •  Unlocks the rail and Minecart upgrade path. Best for fast resource transport and dependable infrastructure.\",\n\t\"shaman_base\": \"TOTEM SANCTUARY  •  Unlocks Peon recruitment. Best for worker support, utility, and keeping the mine productive while you fight.\",\n\t\"nerubian_base\": \"BROOD NEST  •  Built around brood workers and summoned tunnel control. Best for spreading helpers through the mine.\",\n\t\"druid_base\": \"LIVING GROVE  •  Focuses on regeneration, roots, and nature utility. Best for recovery and flexible traversal support.\",\n\t\"undead_king_base\": \"SOUL CITADEL  •  Focuses on servants, attrition, and summoned defence. Best for building pressure through expendable minions.\",\n}"
	var new_desc := "const BASE_DESCRIPTIONS := {\n\t\"default_base\": \"DWARF ENGINEERING  •  +1 free gem carry and 8 bastion HP repaired after every assault.\",\n\t\"shaman_base\": \"TOTEM SANCTUARY  •  Reveals nearby crystal seams and heals heroes fighting near the lodge.\",\n\t\"nerubian_base\": \"BROOD NEST  •  Warns three seconds earlier and webs the first three attackers.\",\n\t\"mech_base\": \"GOBLIN WORKSHOP  •  +15 bastion HP, faster Mech rebuilding, and an automatic defence turret.\",\n\t\"druid_base\": \"LIVING GROVE  •  Safe regeneration and periodic roots around the bastion.\",\n\t\"undead_king_base\": \"SOUL CITADEL  •  Enemy deaths charge a defensive nova or soul-powered repair.\",\n}"
	replace_once(path, old_desc, new_desc)
	replace_once(path, "\t\tbutton.custom_minimum_size = Vector2(104, 66)", "\t\tbutton.custom_minimum_size = Vector2(92, 66)")
	replace_once(path, "\tbase_texture.texture = selected_data.get(\"texture\") as Texture2D", "\tbase_texture.texture = selected_data.get(\"texture\") as Texture2D\n\tbase_texture.modulate = Color(1.16, 0.82, 0.46, 1.0) if selected_base == \"mech_base\" else Color.WHITE")
	replace_once(path, "\tmatch_label.text = \"FACTION HOME  •  %s\" % matching_hero", "\tmatch_label.text = \"ORIGIN  •  %s  •  Mix freely with %s\" % [matching_hero, hero_name]")

func patch_lexicon() -> void:
	var path := "res://scripts/ui/menus/lexicon/lexikon.gd"
	replace_once(path, "\t{\n\t\t\"name\": \"Undead Crypt\",\n\t\t\"hero\": \"Undead King\",\n\t\t\"texture\": preload(\"res://UndeadKingBase.png\")\n\t}\n]", "\t{\n\t\t\"name\": \"Undead Crypt\",\n\t\t\"hero\": \"Undead King\",\n\t\t\"texture\": preload(\"res://UndeadKingBase.png\")\n\t},\n\t{\n\t\t\"name\": \"Goblin Mech Workshop\",\n\t\t\"hero\": \"Mech\",\n\t\t\"texture\": preload(\"res://DwarfBase.png\")\n\t}\n]")
	replace_once(path, "\tif viewport_width >= 760.0:\n\t\tbases_grid.columns = 5", "\tif viewport_width >= 900.0:\n\t\tbases_grid.columns = 6\n\telif viewport_width >= 760.0:\n\t\tbases_grid.columns = 5")
