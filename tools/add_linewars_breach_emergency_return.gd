extends Node

const CONTROLLER_PATH := "res://scripts/systems/continuous_line_wars_controller.gd"
const TEST_PATH := "res://tests/continuous_linewars_smoke_runner.gd"

func _ready() -> void:
	var controller_from := "func _transfer_enemy_to_mine(enemy: CharacterBody2D) -> void:\n\tif not is_instance_valid(enemy):\n\t\treturn\n\tvar source_position := enemy.global_position\n"
	var controller_to := "func _transfer_enemy_to_mine(enemy: CharacterBody2D) -> void:\n\tif not is_instance_valid(enemy):\n\t\treturn\n\t# Command view is intentionally brief, but a real mine breach always takes\n\t# priority. Return the camera and controls to the hero before the invader\n\t# emerges so touch players are never trapped upstairs during an emergency.\n\tif command_view_active:\n\t\t_exit_command_view()\n\tvar source_position := enemy.global_position\n"
	if not _replace_once(CONTROLLER_PATH, controller_from, controller_to):
		get_tree().quit(1)
		return

	var test_from := "\tif enemy:\n\t\tenemy.global_position = block_layer.to_global(block_layer.map_to_local(tunnel_exit))\n\t\tline_wars.call(\"_process_layer_transfers\")\n\t\tawait _wait_frames(3)\n\t\t_expect(str(enemy.get_meta(\"linewars_layer\", \"\")) == \"mine\", \"A tunnel survivor should breach into the mine layer\")\n\t\t_expect(Vector2i(enemy.get(\"target_base_cell\")) == Vector2i(0, -1), \"A breached enemy should retarget the actual base\")\n"
	var test_to := "\tif enemy:\n\t\tline_wars.call(\"_begin_command_view\", \"DIG\")\n\t\tawait _wait_frames(2)\n\t\t_expect(bool(line_wars.get(\"command_view_active\")), \"The peon view should be open before the emergency breach check\")\n\t\tenemy.global_position = block_layer.to_global(block_layer.map_to_local(tunnel_exit))\n\t\tline_wars.call(\"_process_layer_transfers\")\n\t\tawait _wait_frames(3)\n\t\t_expect(not bool(line_wars.get(\"command_view_active\")), \"A mine breach should immediately close the peon command view\")\n\t\t_expect(hero.process_mode == Node.PROCESS_MODE_INHERIT, \"A mine breach should immediately restore hero control\")\n\t\t_expect(str(enemy.get_meta(\"linewars_layer\", \"\")) == \"mine\", \"A tunnel survivor should breach into the mine layer\")\n\t\t_expect(Vector2i(enemy.get(\"target_base_cell\")) == Vector2i(0, -1), \"A breached enemy should retarget the actual base\")\n"
	if not _replace_once(TEST_PATH, test_from, test_to):
		get_tree().quit(1)
		return

	print("LINEWARS_BREACH_EMERGENCY_RETURN_PASS")
	get_tree().quit(0)

func _replace_once(path: String, from_text: String, to_text: String) -> bool:
	var input := FileAccess.open(path, FileAccess.READ)
	if input == null:
		push_error("Could not read %s" % path)
		return false
	var source := input.get_as_text()
	var count := source.count(from_text)
	if count != 1:
		push_error("Expected exactly one match in %s, found %d" % [path, count])
		return false
	source = source.replace(from_text, to_text)
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		push_error("Could not write %s" % path)
		return false
	output.store_string(source)
	return true
