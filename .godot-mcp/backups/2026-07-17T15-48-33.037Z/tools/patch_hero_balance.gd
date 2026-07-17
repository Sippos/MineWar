extends Node

func _ready() -> void:
	var path := "res://hero_balance_controller.gd"
	var text := FileAccess.get_file_as_string(path)
	var old_profile := "func _apply_profile_once() -> void:\n\tvar hero := _hero_name()\n\tif hero == \"\" or hero == applied_hero or not HERO_PROFILES.has(hero):\n\t\treturn\n\tvar profile: Dictionary = HERO_PROFILES[hero]\n\tvar old_max_health := int(player.get(\"max_health\"))\n\tvar target_health := int(profile[\"health\"])\n\tif old_max_health <= 30:\n\t\tvar health_gain: int = maxi(0, target_health - old_max_health)\n\t\tplayer.set(\"max_health\", target_health)\n\t\tplayer.set(\"health\", min(target_health, int(player.get(\"health\")) + health_gain))\n\tif abs(float(player.get(\"base_speed\")) - 200.0) < 0.1:\n\t\tplayer.set(\"base_speed\", float(profile[\"speed\"]))\n\tif abs(float(player.get(\"base_dig_time\")) - 0.4) < 0.01:\n\t\tplayer.set(\"base_dig_time\", float(profile[\"dig_time\"]))\n\tapplied_hero = hero\n\t_refresh_hud()"
	var new_profile := "func _apply_profile_once() -> void:\n\tvar hero := _hero_name()\n\tif hero == \"\" or hero == applied_hero or not HERO_PROFILES.has(hero):\n\t\treturn\n\tvar profile: Dictionary = HERO_PROFILES[hero]\n\tvar previous_profile: Dictionary = HERO_PROFILES.get(applied_hero, {})\n\tvar old_max_health := int(player.get(\"max_health\"))\n\tvar target_health := int(profile[\"health\"])\n\tvar can_replace_health := old_max_health <= 30 or (not previous_profile.is_empty() and old_max_health == int(previous_profile.get(\"health\", old_max_health)))\n\tif can_replace_health:\n\t\tvar health_ratio: float = clampf(float(player.get(\"health\")) / maxf(1.0, float(old_max_health)), 0.0, 1.0)\n\t\tplayer.set(\"max_health\", target_health)\n\t\tplayer.set(\"health\", maxi(1, int(round(float(target_health) * health_ratio))))\n\tvar current_speed := float(player.get(\"base_speed\"))\n\tvar can_replace_speed := abs(current_speed - 200.0) < 0.1 or (not previous_profile.is_empty() and abs(current_speed - float(previous_profile.get(\"speed\", current_speed))) < 0.1)\n\tif can_replace_speed:\n\t\tplayer.set(\"base_speed\", float(profile[\"speed\"]))\n\tvar current_dig_time := float(player.get(\"base_dig_time\"))\n\tvar can_replace_dig := abs(current_dig_time - 0.4) < 0.01 or (not previous_profile.is_empty() and abs(current_dig_time - float(previous_profile.get(\"dig_time\", current_dig_time))) < 0.01)\n\tif can_replace_dig:\n\t\tplayer.set(\"base_dig_time\", float(profile[\"dig_time\"]))\n\tapplied_hero = hero\n\t_refresh_hud()"
	if not text.contains(old_profile):
		push_error("Profile block not found")
		get_tree().quit(1)
		return
	text = text.replace(old_profile, new_profile)
	text = text.replace("\"Nerubian\": 1.34", "\"Nerubian\": 1.70")
	text = text.replace("\t\toffset = Vector2(0, -5)", "\t\toffset = Vector2(0, -7)")
	text = text.replace("\treturn source_id == 2 or source_id == 3", "\treturn false")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("HERO_BALANCE_PROFILE_PATCHED")
	get_tree().quit()
