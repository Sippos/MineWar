extends Control

const SIGNALING_SERVER_URL = "wss://minewar.onrender.com"

@onready var connect_btn = $VBoxContainer/ConnectBtn
@onready var room_input = $VBoxContainer/RoomInput
@onready var status_label = $VBoxContainer/StatusLabel
@onready var back_btn = $VBoxContainer/BackBtn

var ws: WebSocketPeer
var rtc_peer: WebRTCMultiplayerPeer
var rtc_conn: WebRTCPeerConnection
var is_host = false

func _ready():
	connect_btn.pressed.connect(_on_connect_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	ws = WebSocketPeer.new()
	
func _process(delta):
	ws.poll()
	var state = ws.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count():
			var packet = ws.get_packet()
			var msg = JSON.parse_string(packet.get_string_from_utf8())
			_handle_signaling_message(msg)

func _on_connect_pressed():
	var room = room_input.text.strip_edges()
	if room == "":
		status_label.text = "Please enter a Room Code"
		return
		
	status_label.text = "Connecting to signaling server..."
	var err = ws.connect_to_url(SIGNALING_SERVER_URL)
	if err != OK:
		status_label.text = "Failed to connect to signaling server"
		return
		
	connect_btn.disabled = true
	# Wait for WebSocket to open, then send join
	set_process(true)
	await get_tree().create_timer(1.0).timeout
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify({ "type": "join", "room": room }))

func _handle_signaling_message(msg: Dictionary):
	if msg.type == "joined":
		is_host = (msg.role == "host")
		status_label.text = "Joined as " + msg.role.capitalize() + ". Waiting for opponent..."
		
		rtc_peer = WebRTCMultiplayerPeer.new()
		if is_host:
			rtc_peer.create_server()
		else:
			rtc_peer.create_client(1)
		multiplayer.multiplayer_peer = rtc_peer
			
	elif msg.type == "peer_connected":
		status_label.text = "Opponent found! Establishing P2P connection..."
		_create_rtc_connection(2) # 1 is host, 2 is client
		
		# Host creates offer
		rtc_conn.create_offer()
		
	elif msg.type == "offer":
		status_label.text = "Opponent found! Establishing P2P connection..."
		_create_rtc_connection(1)
		rtc_conn.set_remote_description("offer", msg.sdp)
		# After receiving offer, client must create an answer
		rtc_conn.create_answer()
		
	elif msg.type == "answer":
		rtc_conn.set_remote_description("answer", msg.sdp)
		
	elif msg.type == "candidate":
		rtc_conn.add_ice_candidate(msg.media, msg.index, msg.name)
		
	elif msg.type == "error":
		status_label.text = "Error: " + msg.message
		connect_btn.disabled = false
		
	elif msg.type == "peer_disconnected":
		status_label.text = "Opponent disconnected"
		get_tree().change_scene_to_file("res://menu.tscn")

func _create_rtc_connection(id: int):
	rtc_conn = WebRTCPeerConnection.new()
	rtc_conn.initialize({
		"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ]
	})
	rtc_conn.session_description_created.connect(_on_session_description_created)
	rtc_conn.ice_candidate_created.connect(_on_ice_candidate_created)
	rtc_peer.add_peer(rtc_conn, id)
	
	if is_host:
		rtc_peer.peer_connected.connect(_on_rtc_peer_connected)
	else:
		rtc_peer.peer_connected.connect(_on_rtc_peer_connected)

func _on_session_description_created(type: String, sdp: String):
	rtc_conn.set_local_description(type, sdp)
	ws.send_text(JSON.stringify({ "type": type, "sdp": sdp }))

func _on_ice_candidate_created(media: String, index: int, name: String):
	ws.send_text(JSON.stringify({ "type": "candidate", "media": media, "index": index, "name": name }))

func _on_rtc_peer_connected(id: int):
	status_label.text = "P2P Connected! Starting game..."
	ws.close() # We don't need signaling server anymore!
	
	if is_host:
		var seed_val = randi()
		rpc("start_game", seed_val)

@rpc("authority", "call_local", "reliable")
func start_game(world_seed: int):
	var online_scene = load("res://vs_online.tscn").instantiate()
	online_scene.world_seed = world_seed
	get_tree().root.add_child(online_scene)
	get_tree().current_scene = online_scene
	self.queue_free()

func _on_back_pressed():
	if ws: ws.close()
	if rtc_peer: rtc_peer.close()
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://menu.tscn")
