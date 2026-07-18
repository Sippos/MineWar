extends Node

const TARGET_PATH := "res://scripts/systems/continuous_line_wars_controller.gd"

func _ready() -> void:
	var file := FileAccess.open(TARGET_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open LineWars controller")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	var replacements: Array[Dictionary] = [
		{
			"from": "\tportal_nodes[\"TunnelGate\"] = _create_world_marker(\"TunnelTransferGate\", tunnel_exit_cell, Color(1.0, 0.52, 0.16, 0.96), \"TO MINE\", 25.0)\n\tportal_nodes[\"MineGate\"] = _create_world_marker",
			"to": "\tportal_nodes[\"TunnelGate\"] = _create_world_marker(\"TunnelTransferGate\", tunnel_exit_cell, Color(1.0, 0.52, 0.16, 0.96), \"TO MINE\", 25.0)\n\tvar tunnel_gate := portal_nodes[\"TunnelGate\"] as Node2D\n\tif tunnel_gate:\n\t\ttunnel_gate.visible = false\n\tportal_nodes[\"MineGate\"] = _create_world_marker"
		},
		{
			"from": "\tvar opening_marker := portal_nodes.get(\"OpeningRouteEnd\") as Node2D\n\tif opening_marker:\n\t\topening_marker.visible = false\n\t_show_alert(\"SAFE ROUTE ESTABLISHED\\nHERO CONTROL RESTORED\", 2.2)\n",
			"to": "\tvar opening_marker := portal_nodes.get(\"OpeningRouteEnd\") as Node2D\n\tif opening_marker:\n\t\topening_marker.visible = false\n\tvar tunnel_gate := portal_nodes.get(\"TunnelGate\") as Node2D\n\tif tunnel_gate:\n\t\ttunnel_gate.visible = true\n\t_show_alert(\"SAFE ROUTE ESTABLISHED\\nHERO CONTROL RESTORED\", 2.2)\n"
		}
	]

	for replacement in replacements:
		var from_text := str(replacement["from"])
		var to_text := str(replacement["to"])
		var count := source.count(from_text)
		if count != 1:
			push_error("Expected one gate-handoff match, found %d for %s" % [count, from_text.left(80)])
			get_tree().quit(1)
			return
		source = source.replace(from_text, to_text)

	var output := FileAccess.open(TARGET_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Could not write LineWars controller")
		get_tree().quit(1)
		return
	output.store_string(source)
	print("LINEWARS_GATE_HANDOFF_POLISH_PASS")
	get_tree().quit(0)
