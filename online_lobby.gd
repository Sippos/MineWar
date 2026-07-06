extends Control

const PORT = 8080

@onready var host_btn = $VBoxContainer/HostBtn
@onready var join_btn = $VBoxContainer/JoinBtn
@onready var ip_input = $VBoxContainer/IPInput
@onready var status_label = $VBoxContainer/StatusLabel

var peer: WebSocketMultiplayerPeer

func _ready():
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	
	var back_btn = Button.new()
	back_btn.text = "Back to Main Menu"
	back_btn.custom_minimum_size = Vector2(0, 40)
	back_btn.pressed.connect(_on_back_pressed)
	$VBoxContainer.add_child(back_btn)
	
	host_btn.call_deferred("grab_focus")
	
	var http = HTTPRequest.new()
	http.name = "IPRequest"
	add_child(http)
	http.request_completed.connect(_on_ip_fetched)
	http.request("https://api.ipify.org")
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _process(_delta):
	if peer:
		peer.poll()


var public_ip = ""

func _on_ip_fetched(result, response_code, headers, body):
	if response_code == 200:
		public_ip = body.get_string_from_utf8()

func _on_host_pressed():
	peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		var local_ip = "127.0.0.1"
		for interface_data in IP.get_local_interfaces():
			if interface_data.has("addresses"):
				for addr in interface_data["addresses"]:
					if addr.begins_with("192.") or addr.begins_with("10.") or addr.begins_with("172."):
						local_ip = addr
		
		var msg = "Hosting on port %d.
" % PORT
		if public_ip != "":
			msg += "Public IP (Internet): %s
" % public_ip
		msg += "Local IP (LAN): %s
" % local_ip
		msg += "Waiting for player to join..."
		
		status_label.text = msg
		host_btn.disabled = true
		join_btn.disabled = true
	else:
		status_label.text = "Error hosting server!"

func _on_join_pressed():
	var ip = ip_input.text
	if ip == "":
		ip = "127.0.0.1"
		
	peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_client("ws://" + ip + ":" + str(PORT))
	if error == OK:
		multiplayer.multiplayer_peer = peer
		status_label.text = "Connecting to " + ip + "..."
		host_btn.disabled = true
		join_btn.disabled = true
	else:
		status_label.text = "Error creating client!"

func _on_peer_connected(id):
	status_label.text = "Player %d connected!" % id
	if multiplayer.is_server():
		# Start game on both sides!
		var seed_val = randi()
		rpc("start_game", seed_val)

func _on_peer_disconnected(id):
	status_label.text = "Player %d disconnected." % id
	# Go back to menu if disconnected mid-game
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_connected_to_server():
	status_label.text = "Connected! Waiting for host to start..."

func _on_connection_failed():
	status_label.text = "Connection failed."
	multiplayer.multiplayer_peer = null
	host_btn.disabled = false
	join_btn.disabled = false

@rpc("authority", "call_local", "reliable")
func start_game(world_seed: int):
	# Switch to vs_online.tscn
	var online_scene = load("res://vs_online.tscn").instantiate()
	online_scene.world_seed = world_seed
	get_tree().root.add_child(online_scene)
	get_tree().current_scene = online_scene
	self.queue_free() # Destroy the lobby

func _on_back_pressed():
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://menu.tscn")
