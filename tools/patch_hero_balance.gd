extends Node

func _ready() -> void:
	if not _patch_spider_combat():
		get_tree().quit(1)
		return
	if not _patch_spider_scaling():
		get_tree().quit(1)
		return
	if not _patch_druid_burrow_pulse():
		get_tree().quit(1)
		return
	print("HERO_COMBAT_LOOPS_PATCHED")
	get_tree().quit()

func _patch_spider_combat() -> bool:
	var path := "res://spider_minion.gd"
	var text := FileAccess.get_file_as_string(path)
	var old_fields := "var lifetime = 70.0\n"
	var new_fields := "var lifetime = 70.0\n\n@export var attack_damage := 10\n@export var attack_range := 44.0\n@export var aggro_range := 260.0\n@export var attack_interval := 0.72\nvar target_enemy: Node2D\nvar combat_recheck_timer := 0.0\nvar attack_cooldown := 0.0\n"
	if text.contains(old_fields) and not text.contains("@export var attack_damage := 10"):
		text = text.replace(old_fields, new_fields)

	var old_tick := "\ttarget_recheck_timer -= delta\n\tmatch state:"
	var new_tick := "\tattack_cooldown = maxf(0.0, attack_cooldown - delta)\n\tcombat_recheck_timer -= delta\n\tif combat_recheck_timer <= 0.0 or not is_instance_valid(target_enemy) or global_position.distance_to(target_enemy.global_position) > aggro_range:\n\t\tcombat_recheck_timer = 0.25\n\t\ttarget_enemy = _find_nearest_enemy()\n\tif is_instance_valid(target_enemy):\n\t\t_process_enemy_target()\n\t\t_update_animation(delta)\n\t\t_update_lifespan_visual()\n\t\treturn\n\n\ttarget_recheck_timer -= delta\n\tmatch state:"
	if text.contains(old_tick):
		text = text.replace(old_tick, new_tick)
	elif not text.contains("func _find_nearest_enemy() -> Node2D:"):
		push_error("Spider physics insertion point not found")
		return false

	var marker := "func _choose_dig_target() -> bool:\n"
	var combat_functions := "func _find_nearest_enemy() -> Node2D:\n\tvar best: Node2D\n\tvar best_distance := aggro_range\n\tfor enemy: Node in get_tree().get_nodes_in_group(\"enemies\"):\n\t\tif not is_instance_valid(enemy) or not (enemy is Node2D):\n\t\t\tcontinue\n\t\tvar enemy_2d := enemy as Node2D\n\t\tvar distance := global_position.distance_to(enemy_2d.global_position)\n\t\tif distance < best_distance:\n\t\t\tbest_distance = distance\n\t\t\tbest = enemy_2d\n\treturn best\n\nfunc _process_enemy_target() -> void:\n\tif not is_instance_valid(target_enemy):\n\t\ttarget_enemy = null\n\t\treturn\n\tvar distance := global_position.distance_to(target_enemy.global_position)\n\tif distance <= attack_range:\n\t\tvelocity = Vector2.ZERO\n\t\tif attack_cooldown <= 0.0:\n\t\t\tif target_enemy.has_method(\"take_damage\"):\n\t\t\t\ttarget_enemy.call(\"take_damage\", attack_damage)\n\t\t\tattack_cooldown = attack_interval\n\t\t\t_spawn_bite_flash()\n\t\treturn\n\tvelocity = global_position.direction_to(target_enemy.global_position) * speed * 1.08\n\tmove_and_slide()\n\nfunc _spawn_bite_flash() -> void:\n\tif not has_node(\"Sprite2D\"):\n\t\treturn\n\tvar sprite := $Sprite2D as Sprite2D\n\tsprite.modulate = Color(1.25, 0.72, 1.35, sprite.modulate.a)\n\tvar tween := create_tween()\n\ttween.tween_property(sprite, \"modulate\", Color(1.0, 1.0, 1.0, sprite.modulate.a), 0.14)\n\n"
	if text.contains(marker) and not text.contains("func _find_nearest_enemy() -> Node2D:"):
		text = text.replace(marker, combat_functions + marker)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write spider_minion.gd")
		return false
	file.store_string(text)
	file.close()
	return true

func _patch_spider_scaling() -> bool:
	var path := "res://hero_abilities.gd"
	var text := FileAccess.get_file_as_string(path)
	var old_config := "\tspider.set(\"max_lifetime\", 48.0 + brood_level * 14.0 + carapace_level * 6.0)\n\tspider.set(\"lifetime\", float(spider.get(\"max_lifetime\")))\n\tspider.set(\"speed\", 112.0 + brood_level * 17.0)\n\tspider.set(\"dig_speed_multiplier\", 1.0 + carapace_level * 0.18)"
	var new_config := "\tvar intelligence := int(player.get(\"intelligence\"))\n\tspider.set(\"max_lifetime\", 48.0 + brood_level * 14.0 + carapace_level * 6.0)\n\tspider.set(\"lifetime\", float(spider.get(\"max_lifetime\")))\n\tspider.set(\"speed\", 112.0 + brood_level * 17.0)\n\tspider.set(\"dig_speed_multiplier\", 1.0 + carapace_level * 0.18)\n\tspider.set(\"attack_damage\", 5 + intelligence * 3 + brood_level * 4)\n\tspider.set(\"attack_interval\", maxf(0.38, 0.78 - float(brood_level) * 0.08))\n\tspider.set(\"aggro_range\", 220.0 + float(brood_level) * 35.0)"
	if text.contains(old_config):
		text = text.replace(old_config, new_config)
	elif not text.contains("spider.set(\"attack_damage\""):
		push_error("Spider configuration block not found")
		return false

	var old_buff := "\tif not spider.has_meta(\"broodmother_base_speed\"):\n\t\tspider.set_meta(\"broodmother_base_speed\", float(spider.get(\"speed\")))\n\tspider.set(\"speed\", float(spider.get_meta(\"broodmother_base_speed\")) * 1.45)\n\tspider.set(\"lifetime\", float(spider.get(\"lifetime\")) + 15.0)"
	var new_buff := "\tif not spider.has_meta(\"broodmother_base_speed\"):\n\t\tspider.set_meta(\"broodmother_base_speed\", float(spider.get(\"speed\")))\n\t\tspider.set_meta(\"broodmother_base_damage\", int(spider.get(\"attack_damage\")))\n\t\tspider.set_meta(\"broodmother_base_interval\", float(spider.get(\"attack_interval\")))\n\tspider.set(\"speed\", float(spider.get_meta(\"broodmother_base_speed\")) * 1.45)\n\tspider.set(\"attack_damage\", int(round(float(spider.get_meta(\"broodmother_base_damage\")) * 1.55)))\n\tspider.set(\"attack_interval\", maxf(0.26, float(spider.get_meta(\"broodmother_base_interval\")) * 0.72))\n\tspider.set(\"lifetime\", float(spider.get(\"lifetime\")) + 15.0)"
	if text.contains(old_buff):
		text = text.replace(old_buff, new_buff)

	var old_restore := "\t\tif spider.has_meta(\"broodmother_base_speed\"):\n\t\t\tspider.set(\"speed\", float(spider.get_meta(\"broodmother_base_speed\")))\n\t\t\tspider.remove_meta(\"broodmother_base_speed\")"
	var new_restore := "\t\tif spider.has_meta(\"broodmother_base_speed\"):\n\t\t\tspider.set(\"speed\", float(spider.get_meta(\"broodmother_base_speed\")))\n\t\t\tspider.set(\"attack_damage\", int(spider.get_meta(\"broodmother_base_damage\")))\n\t\t\tspider.set(\"attack_interval\", float(spider.get_meta(\"broodmother_base_interval\")))\n\t\t\tspider.remove_meta(\"broodmother_base_speed\")\n\t\t\tspider.remove_meta(\"broodmother_base_damage\")\n\t\t\tspider.remove_meta(\"broodmother_base_interval\")"
	if text.contains(old_restore):
		text = text.replace(old_restore, new_restore)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write hero_abilities.gd")
		return false
	file.store_string(text)
	file.close()
	return true

func _patch_druid_burrow_pulse() -> bool:
	var path := "res://hero_balance_controller.gd"
	var text := FileAccess.get_file_as_string(path)
	var old_field := "var druid_mole_speed_bonus := 0.0\n"
	var new_field := "var druid_mole_speed_bonus := 0.0\nvar druid_burrow_pulse_timer := 0.0\n"
	if text.contains(old_field) and not text.contains("druid_burrow_pulse_timer"):
		text = text.replace(old_field, new_field)

	var old_process := "\tdruid_was_mole = mole_active\n\tvar roots_level := int(hero_abilities.get(\"deep_roots_level\")) if hero_abilities else 0"
	var new_process := "\tdruid_was_mole = mole_active\n\tif mole_active:\n\t\tdruid_burrow_pulse_timer -= delta\n\t\tif druid_burrow_pulse_timer <= 0.0 and Vector2(player.get(\"velocity\")).length() > 24.0:\n\t\t\tdruid_burrow_pulse_timer = 0.9\n\t\t\t_druid_burrow_pulse()\n\telse:\n\t\tdruid_burrow_pulse_timer = 0.0\n\tvar roots_level := int(hero_abilities.get(\"deep_roots_level\")) if hero_abilities else 0"
	if text.contains(old_process):
		text = text.replace(old_process, new_process)
	elif not text.contains("_druid_burrow_pulse()"):
		push_error("Druid process insertion point not found")
		return false

	var marker := "func _end_druid_mole_bonus() -> void:\n"
	var pulse_func := "func _druid_burrow_pulse() -> void:\n\tvar mole_rank := int(hero_abilities.get(\"mole_level\")) if hero_abilities else 1\n\tvar radius := 62.0 + float(mole_rank) * 12.0\n\tvar damage := 4 + mole_rank * 4 + int(player.get(\"intelligence\")) * 2\n\tvar hit_any := false\n\tfor enemy: Node in get_tree().get_nodes_in_group(\"enemies\"):\n\t\tif not is_instance_valid(enemy) or not (enemy is Node2D):\n\t\t\tcontinue\n\t\tvar enemy_2d := enemy as Node2D\n\t\tif player.global_position.distance_to(enemy_2d.global_position) > radius:\n\t\t\tcontinue\n\t\thit_any = true\n\t\tif enemy.has_method(\"take_damage\"):\n\t\t\tenemy.call(\"take_damage\", damage)\n\t\t_apply_enemy_slow(enemy, 1.0 + float(mole_rank) * 0.2, 0.68)\n\tif hit_any:\n\t\t_spawn_burst(player.global_position, Color(0.42, 0.78, 0.28, 0.72), 14)\n\n"
	if text.contains(marker) and not text.contains("func _druid_burrow_pulse() -> void:"):
		text = text.replace(marker, pulse_func + marker)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write hero_balance_controller.gd")
		return false
	file.store_string(text)
	file.close()
	return true
