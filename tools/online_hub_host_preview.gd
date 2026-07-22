extends Node

func _ready() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(28777, 2)
	if error != OK:
		push_error("Could not create preview host peer: %s" % error_string(error))
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	var hub: Node = load("res://scenes/world/preparation/online_multiplayer_hub.tscn").instantiate()
	add_child(hub)
