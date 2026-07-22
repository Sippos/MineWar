extends Node

const TARGET := "res://scripts/systems/preparation/online_multiplayer_hub_controller.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(TARGET)
	var replacements := {
		'''\tif multiplayer.is_server():
\t\t_build_host_shrines(host_choices)
\t\trpc_id(2, "receive_host_profile", host_choices, host_base_id, host_hero)
\telse:
\t\trpc_id(1, "receive_guest_profile", guest_hero)
''': '''\tif multiplayer.is_server():
\t\t_build_host_shrines(host_choices)
\t\tif _remote_peer_connected():