extends Node

const CONTROLLER_PATH := "res://scripts/systems/continuous_line_wars_controller.gd"
const ENEMY_PATH := "res://enemy.gd"

func _ready() -> void:
	var controller := _read(CONTROLLER_PATH)
	var enemy := _read(ENEMY_PATH)
	if controller.is_empty() or enemy.is_empty():
		get_tree().quit(1)
		return

	controller = _replace_once(controller,
		"const TOUCH_COMMAND_CAMERA_ZOOM := Vector2(0.78, 0.78)\nconst CARDINAL_DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]\n",
		"const TOUCH_COMMAND_CAMERA_ZOOM := Vector2(0.78, 0.78)\nconst ESTIMATED_TUNNEL_TILE_SECONDS := 0.85\nconst GATE_ERUPTION_RADIUS := 92.0\nconst GATE_ERUPTION_DAMAGE := 4\nconst GATE_ERUPTION_KNOCKBACK := 52.0\nconst GATE_ERUPTION_COOLDOWN_MSEC := 650\nconst LINEWARS_LEAK_DAMAGE := [0, 18, 20, 22, 24, 27, 30, 34, 40, 48, 100]\nconst CARDINAL_DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]\n")
	controller = _replace_once(controller,
		"var active_order_target := INVALID_CELL\nvar last_breach_feedback_msec := -10000\n",
		"var active_order_target := INVALID_CELL\nvar active_order_route_before := 1\nvar last_breach_feedback_msec := -10000\nvar last_gate_eruption_msec := -10000\n")
	controller = _replace_once(controller,
		"\tif bool(peon.call(\"issue_dig_order\", target_cell)):\n\t\tcommand_message = \"Tunnel commissioned to %s. Hero control restored while the peon digs.\" % _format_cell(target_cell)\n",
		"\tactive_order_route_before = _tunnel_route_length()\n\tif bool(peon.call(\"issue_dig_order\", target_cell)):\n\t\tcommand_message = \"Tunnel commissioned to %s. Hero control restored while the peon digs.\" % _format_cell(target_cell)\n")
	controller = _replace_once(controller,
		"\tif enemy.has_method(\"initialize\"):\n\t\tvar enemy_type := 0 if wave_number == 1 else int(world.call(\"get_random_enemy_type\", wave_number))\n\t\tenemy.call(\"initialize\", wave_number, is_boss, enemy_type)\n",
		"\tif enemy.has_method(\"initialize\"):\n\t\tvar enemy_type := 0 if wave_number == 1 else int(world.call(\"get_random_enemy_type\", wave_number))\n\t\tenemy.call(\"initialize\", wave_number, is_boss, enemy_type)\n\tenemy.set_meta(\"linewars_single_leak\", true)\n\tenemy.set_meta(\"linewars_leak_damage\", _linewars_leak_damage(wave_number, is_boss))\n")
	controller = _replace_once(controller,
		"\tenemy.global_position = mine_position + offset\n\t_spawn_portal_transfer_effect(mine_position, Color(0.18, 0.7, 1.0, 1.0), \"MINE BREACH\")\n",
		"\tenemy.global_position = mine_position + offset\n\t_spawn_portal_transfer_effect(mine_position, Color(0.18, 0.7, 1.0, 1.0), \"MINE BREACH\")\n\t_trigger_gate_eruption()\n")
	controller = _replace_once(controller,
		"\tif kind == \"RADAR\":\n\t\t_install_radar(cell)\n\t\tcommand_message = \"Radar online at %s. Incoming tunnel contacts now create earlier alerts.\" % _format_cell(cell)\n\telse:\n\t\tcommand_message = \"Tunnel order complete at %s. The next portal will use the farthest connected endpoint.\" % _format_cell(cell)\n",
		"\tif kind == \"RADAR\":\n\t\t_install_radar(cell)\n\t\tcommand_message = \"Radar online at %s. Incoming tunnel contacts now create earlier alerts.\" % _format_cell(cell)\n\telse:\n\t\tvar route_after := _tunnel_route_length()\n\t\tvar added_tiles := maxi(route_after - active_order_route_before, 0)\n\t\tvar added_seconds := float(added_tiles) * ESTIMATED_TUNNEL_TILE_SECONDS\n\t\tif added_tiles > 0:\n\t\t\tcommand_message = \"Route extended by %d tile%s: about +%.1f seconds before the mine breach.\" % [added_tiles, \"s\" if added_tiles != 1 else \"\", added_seconds]\n\t\telse:\n\t\t\tcommand_message = \"Tunnel complete at %s. This branch did not extend the farthest invasion route yet.\" % _format_cell(cell)\n")
	controller = _replace_once(controller,
		"func _find_farthest_tunnel_cell() -> Vector2i:\n",
		"func _linewars_leak_damage(wave_number: int, is_boss: bool) -> int:\n\tif is_boss:\n\t\treturn 100\n\tvar index := clampi(wave_number, 1, LINEWARS_LEAK_DAMAGE.size() - 1)\n\treturn int(LINEWARS_LEAK_DAMAGE[index])\n\nfunc _trigger_gate_eruption() -> void:\n\tvar now := Time.get_ticks_msec()\n\tif now - last_gate_eruption_msec < GATE_ERUPTION_COOLDOWN_MSEC:\n\t\treturn\n\tlast_gate_eruption_msec = now\n\tvar center := _cell_world_position(MINE_ENTRY_CELL)\n\t_spawn_portal_transfer_effect(center, Color(0.34, 0.88, 1.0, 1.0), \"GATE SURGE\")\n\tawait get_tree().create_timer(0.24).timeout\n\tif not is_instance_valid(self) or hero == null or not is_instance_valid(hero):\n\t\treturn\n\tif hero.global_position.distance_to(center) > GATE_ERUPTION_RADIUS:\n\t\treturn\n\tvar push_direction := (hero.global_position - center).normalized()\n\tif push_direction.length_squared() < 0.01:\n\t\tpush_direction = Vector2.DOWN\n\tif hero.has_method(\"take_damage\"):\n\t\thero.call(\"take_damage\", GATE_ERUPTION_DAMAGE)\n\thero.global_position += push_direction * GATE_ERUPTION_KNOCKBACK\n\thero.velocity = push_direction * 240.0\n\nfunc _find_farthest_tunnel_cell() -> Vector2i:\n")

	enemy = _replace_once(enemy,
		"\t\tif attack_cooldown_timer <= 0.0:\n\t\t\tif base.has_method(\"take_damage\"):\n\t\t\t\tbase.take_damage(damage)\n\t\t\tif \"spikes_level\" in base and base.spikes_level > 0:\n\t\t\t\ttake_damage(15 * base.spikes_level)\n\t\t\tattack_cooldown_timer = 1.0\n",
		"\t\tif attack_cooldown_timer <= 0.0:\n\t\t\tif base.has_method(\"take_damage\"):\n\t\t\t\tvar base_hit_damage := int(get_meta(\"linewars_leak_damage\", damage))\n\t\t\t\tbase.take_damage(base_hit_damage)\n\t\t\t\tif bool(get_meta(\"linewars_single_leak\", false)):\n\t\t\t\t\tqueue_free()\n\t\t\t\t\treturn\n\t\t\tif \"spikes_level\" in base and base.spikes_level > 0:\n\t\t\t\ttake_damage(15 * base.spikes_level)\n\t\t\tattack_cooldown_timer = 1.0\n")

	if controller.is_empty() or enemy.is_empty():
		get_tree().quit(1)
		return
	_write(CONTROLLER_PATH, controller)
	_write(ENEMY_PATH, enemy)
	print("LINEWARS_BREACH_LOOP_TUNING_PASS")
	get_tree().quit(0)

func _replace_once(source: String, from_text: String, to_text: String) -> String:
	var count := source.count(from_text)
	if count != 1:
		push_error("Expected one replacement, found %d for: %s" % [count, from_text.left(80)])
		return ""
	return source.replace(from_text, to_text)

func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read %s" % path)
		return ""
	return file.get_as_text()

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return
	file.store_string(content)
