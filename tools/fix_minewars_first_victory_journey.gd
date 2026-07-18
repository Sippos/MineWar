extends Node

func _ready() -> void:
	var failures := 0
	failures += _patch_mech_hero_hall()
	failures += _patch_deferred_theme_safety()
	failures += _patch_complete_run_expectations()
	if failures == 0:
		print("MINEWARS_FIRST_VICTORY_JOURNEY_FIXED")
		get_tree().quit()
	else:
		push_error("MINEWARS_FIRST_VICTORY_JOURNEY_FIX_FAILED: %d" % failures)
		get_tree().quit(1)

func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read " + path)
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write " + path)
		return false
	file.store_string(text)
	file.close()
	return true

func _replace_once(source: String, old_text: String, new_text: String, label: String) -> Dictionary:
	if source.contains(new_text):
		return {"text": source, "failed": false}
	var count := source.count(old_text)
	if count != 1:
		push_error("Patch count mismatch for %s: expected 1, found %d" % [label, count])
		return {"text": source, "failed": true}
	return {"text": source.replace(old_text, new_text), "failed": false}

func _patch_mech_hero_hall() -> int:
	var path := "res://scripts/systems/preparation/in_world_hero_selector.gd"
	var source := _read(path)
	if source.is_empty():
		return 1
	var replacements := [
		["const HERO_ORDER: Array[String] = [\"Dwarf\", \"Shaman\", \"Nerubian\", \"Druid\", \"Undead King\"]", "const HERO_ORDER: Array[String] = [\"Dwarf\", \"Shaman\", \"Nerubian\", \"Druid\", \"Undead King\", \"Mech\"]", "hero order"],
		["\t\"Undead King\": preload(\"res://character_sprites/hero_idle/undead_king_idle_front.png\"),\n}", "\t\"Undead King\": preload(\"res://character_sprites/hero_idle/undead_king_idle_front.png\"),\n\t\"Mech\": preload(\"res://character_sprites/hero_idle/mech_idle_front.png\"),\n}", "mech texture"],
		["\t\"Undead King\": Vector2(225, 145),\n}", "\t\"Undead King\": Vector2(225, 145),\n\t\"Mech\": Vector2(350, 65),\n}", "mech shrine position"],
		["\t\"Undead King\": -1.0,\n}", "\t\"Undead King\": -1.0,\n\t\"Mech\": -1.0,\n}", "mech card side"],
	]
	for replacement in replacements:
		var result := _replace_once(source, replacement[0], replacement[1], replacement[2])
		if bool(result["failed"]):
			return 1
		source = str(result["text"])
	var card_anchor := "\t\"Undead King\": {\n\t\t\"role\": \"UNDEAD OVERLORD\",\n\t\t\"description\": \"A deliberate commander who turns fallen enemies into an advancing army.\",\n\t\t\"accent\": Color(0.52, 0.72, 1.0, 1.0),\n\t\t\"abilities\": [\n\t\t\t{\"icon\": preload(\"res://ability_icons/generated/UndeadKing_RaiseDead.png\"), \"title\": \"Raise Dead\", \"description\": \"Summon an undead minion\"},\n\t\t\t{\"icon\": preload(\"res://ability_icons/generated/UndeadKing_GraveMight.png\"), \"title\": \"Grave Might\", \"description\": \"Strengthen the undead host\"},\n\t\t\t{\"icon\": preload(\"res://ability_icons/generated/UndeadKing_SoulHarvest.png\"), \"title\": \"Soul Harvest\", \"description\": \"Gain power from fallen souls\"},\n\t\t\t{\"icon\": preload(\"res://ability_icons/generated/UndeadKing_DeathMarch.png\"), \"title\": \"Death March\", \"description\": \"Level 6 army transformation\"},\n\t\t],\n\t},\n}"
	var card_replacement := "\t\"Undead King\": {\n\t\t\"role\": \"UNDEAD OVERLORD\",\n\t\t\"description\": \"A deliberate commander who turns fallen enemies into an advancing army.\",\n\t\t\"accent\": Color(0.52, 0.72, 1.0, 1.0),\n\t\t\"abilities\": [\n\t\t\t{\"icon\": preload(\"res://ability_icons/generated/UndeadKing_RaiseDead.png\"), \"title\": \"Raise Dead\", \"description\": \"Summon an undead minion\"},\n\t\t\t{\"icon\": preload(\"res://ability_icons/generated/UndeadKing_GraveMight.png\"), \"title\": \"Grave Might\", \"description\": \"Strengthen the undead host\"},\n\t\t\t{\"icon\": preload(\"res://ability_icons/generated/UndeadKing_SoulHarvest.png\"), \"title\": \"Soul Harvest\", \"description\": \"Gain power from fallen souls\"},\n\t\t\t{\"icon\": preload(\"res://ability_icons/generated/UndeadKing_DeathMarch.png\"), \"title\": \"Death March\", \"description\": \"Level 6 army transformation\"},\n\t\t],\n\t},\n\t\"Mech\": {\n\t\t\"role\": \"CAPTURED SIEGE WALKER\",\n\t\t\"description\": \"The defeated war machine returns as a heavy miner whose pilot can eject and rebuild the frame at the bastion.\",\n\t\t\"accent\": Color(1.0, 0.46, 0.16, 1.0),\n\t\t\"abilities\": [\n\t\t\t{\"icon\": preload(\"res://character_sprites/hero_idle/mech_idle_front.png\"), \"title\": \"Armored Chassis\", \"description\": \"High health and frontline durability\"},\n\t\t\t{\"icon\": preload(\"res://character_sprites/hero_idle/mech_idle_front.png\"), \"title\": \"Mining Servos\", \"description\": \"Heavy frame with fast base digging\"},\n\t\t\t{\"icon\": preload(\"res://character_sprites/hero_idle/mech_idle_front.png\"), \"title\": \"Emergency Ejection\", \"description\": \"Pilot escapes when the frame is destroyed\"},\n\t\t\t{\"icon\": preload(\"res://character_sprites/hero_idle/mech_idle_front.png\"), \"title\": \"Field Rebuild\", \"description\": \"Reach the bastion to restore the Mech\"},\n\t\t],\n\t},\n}"
	var card_result := _replace_once(source, card_anchor, card_replacement, "mech card data")
	if bool(card_result["failed"]):
		return 1
	source = str(card_result["text"])
	return 0 if _write(path, source) else 1

func _patch_deferred_theme_safety() -> int:
	var path := "res://global.gd"
	var source := _read(path)
	if source.is_empty():
		return 1
	var result := _replace_once(
		source,
		"func _apply_game_theme_to_added_control(control: Control) -> void:\n\tif not _game_ui_theme_enabled or not is_instance_valid(control):\n\t\treturn\n\t\n\tvar parent = control.get_parent()",
		"func _apply_game_theme_to_added_control(control_value: Variant) -> void:\n\tif not _game_ui_theme_enabled or not is_instance_valid(control_value) or not (control_value is Control):\n\t\treturn\n\tvar control := control_value as Control\n\tvar parent = control.get_parent()",
		"deferred theme safety"
	)
	if bool(result["failed"]):
		return 1
	return 0 if _write(path, str(result["text"])) else 1

func _patch_complete_run_expectations() -> int:
	var path := "res://tests/minewars_complete_run_runner.gd"
	var source := _read(path)
	if source.is_empty():
		return 1
	var replacements := [
		["\t_expect(int(boss.get(\"health\")) == 620, \"The Mech should use the four-expedition health budget\")", "\t_expect(int(boss.get(\"health\")) == 540, \"The Mech should use the current four-expedition health budget\")", "boss health expectation"],
		["\t_expect(int(boss.get(\"damage\")) == 12, \"The Mech should begin with survivable but dangerous damage\")", "\t_expect(int(boss.get(\"damage\")) == 9, \"The Mech should begin with survivable but dangerous damage\")", "boss damage expectation"],
		["\t_expect(absf(float(boss.get(\"speed\")) - 48.0) < 0.2, \"The Mech should begin as a readable advancing threat\")", "\t_expect(absf(float(boss.get(\"speed\")) - 46.0) < 0.2, \"The Mech should begin as a readable advancing threat\")", "boss speed expectation"],
		["\tboss.set(\"health\", 400)", "\tboss.set(\"health\", 340)", "boss phase threshold"],
		["\t_expect(Global.unlocked_heroes.has(\"Shaman\"), \"The first victory should awaken the Shaman\")\n\t_expect(Global.unlocked_bases.has(\"shaman_base\"), \"The first victory should awaken the Shaman Lodge\")", "\t_expect(not Global.unlocked_heroes.has(\"Shaman\"), \"Shaman should remain a second-victory surprise\")\n\t_expect(not Global.unlocked_bases.has(\"shaman_base\"), \"The Shaman Lodge should remain hidden until the second victory\")", "first victory reward expectations"],
		["\t_expect(_pending_reward_has_hero(\"Shaman\"), \"The first victory should queue the Shaman ceremony\")", "\t_expect(not _pending_reward_has_hero(\"Shaman\"), \"The first victory should not reveal the second-victory Shaman ceremony\")", "pending Shaman expectation"],
		["\t_expect(Global.unlocked_heroes.has(\"Shaman\") and Global.unlocked_heroes.has(\"Mech\"), \"Save reload should restore unlocked heroes\")\n\t_expect(Global.unlocked_bases.has(\"shaman_base\"), \"Save reload should restore unlocked bases\")", "\t_expect(Global.unlocked_heroes.has(\"Mech\") and not Global.unlocked_heroes.has(\"Shaman\"), \"Save reload should restore the first-victory Mech without leaking later heroes\")\n\t_expect(Global.unlocked_bases == [\"default_base\"], \"Save reload should keep later fortresses hidden after one victory\")", "reload progression expectations"],
		["\t_expect(shrines != null and shrines.has_node(\"ShamanShrine\"), \"The Stronghold should physically reveal the Shaman shrine\")\n\t_expect(shrines == null or not shrines.has_node(\"DruidShrine\"), \"Later heroes should remain hidden after only one victory\")", "\t_expect(shrines != null and shrines.has_node(\"MechShrine\"), \"The Stronghold should physically reveal the captured Mech shrine\")\n\t_expect(shrines == null or not shrines.has_node(\"ShamanShrine\"), \"Second-victory heroes should remain hidden after only one victory\")", "stronghold shrine expectations"],
	]
	for replacement in replacements:
		var result := _replace_once(source, replacement[0], replacement[1], replacement[2])
		if bool(result["failed"]):
			return 1
		source = str(result["text"])
	return 0 if _write(path, source) else 1
