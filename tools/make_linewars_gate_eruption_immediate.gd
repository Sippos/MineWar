extends Node

const PATH := "res://scripts/systems/continuous_line_wars_controller.gd"

func _ready() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Could not read LineWars controller")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	var from_text := "func _trigger_gate_eruption() -> void:\n\tvar now := Time.get_ticks_msec()\n\tif now - last_gate_eruption_msec < GATE_ERUPTION_COOLDOWN_MSEC:\n\t\treturn\n\tlast_gate_eruption_msec = now\n\tvar center := _cell_world_position(MINE_ENTRY_CELL)\n\t_spawn_portal_transfer_effect(center, Color(0.34, 0.88, 1.0, 1.0), \"GATE SURGE\")\n\tvar timer := get_tree().create_timer(0.24)\n\ttimer.timeout.connect(_apply_gate_eruption.bind(center), CONNECT_ONE_SHOT)\n\nfunc _apply_gate_eruption(center: Vector2) -> void:\n\tif not is_instance_valid(self) or hero == null or not is_instance_valid(hero):\n\t\treturn\n\tif hero.global_position.distance_to(center) > GATE_ERUPTION_RADIUS:\n\t\treturn\n\tvar push_direction := (hero.global_position - center).normalized()\n\tif push_direction.length_squared() < 0.01:\n\t\tpush_direction = Vector2.DOWN\n\tif hero.has_method(\"take_damage\"):\n\t\thero.call(\"take_damage\", GATE_ERUPTION_DAMAGE)\n\thero.global_position += push_direction * GATE_ERUPTION_KNOCKBACK\n\thero.velocity = push_direction * 240.0\n"
	var to_text := "func _trigger_gate_eruption() -> void:\n\tvar now := Time.get_ticks_msec()\n\tif now - last_gate_eruption_msec < GATE_ERUPTION_COOLDOWN_MSEC:\n\t\treturn\n\tlast_gate_eruption_msec = now\n\tvar center := _cell_world_position(MINE_ENTRY_CELL)\n\t_spawn_portal_transfer_effect(center, Color(0.34, 0.88, 1.0, 1.0), \"GATE SURGE\")\n\t_apply_gate_eruption(center)\n\nfunc _apply_gate_eruption(center: Vector2) -> void:\n\tif hero == null or not is_instance_valid(hero):\n\t\treturn\n\tif hero.global_position.distance_to(center) > GATE_ERUPTION_RADIUS:\n\t\treturn\n\tvar push_direction := (hero.global_position - center).normalized()\n\tif push_direction.length_squared() < 0.01:\n\t\tpush_direction = Vector2.DOWN\n\tif hero.has_method(\"take_damage\"):\n\t\thero.call(\"take_damage\", GATE_ERUPTION_DAMAGE)\n\thero.global_position += push_direction * GATE_ERUPTION_KNOCKBACK\n\thero.velocity = push_direction * 240.0\n"
	if source.count(from_text) != 1:
		push_error("Immediate gate eruption patch target mismatch")
		get_tree().quit(1)
		return
	source = source.replace(from_text, to_text)
	var output := FileAccess.open(PATH, FileAccess.WRITE)
	if output == null:
		push_error("Could not write LineWars controller")
		get_tree().quit(1)
		return
	output.store_string(source)
	print("LINEWARS_GATE_ERUPTION_IMMEDIATE_PASS")
	get_tree().quit(0)
