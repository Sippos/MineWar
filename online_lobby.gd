extends Control

const SIGNALING_SERVER_URL := "wss://minewar.onrender.com"
const ONLINE_HUB_SCENE := preload("res://scenes/world/preparation/online_multiplayer_hub.tscn")
const MENU_FONT: FontFile = preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")

@onready var panel: PanelContainer = $Dimmer/Center/Panel
@onready var vbox: VBoxContainer = $Dimmer/Center/Panel/VBoxContainer
@onready var title_label: Label = $Dimmer/Center/Panel/VBoxContainer/Label
@onready var status_label: Label = $Dimmer/Center/Panel/VBoxContainer/StatusLabel
@onready var room_input: LineEdit = $Dimmer/Center/Panel/VBoxContainer/RoomInput
@onready var helper_label: Label = $Dimmer/Center/Panel/VBoxContainer/Hint
@onready var host_btn: Button = $Dimmer/Center/Panel/VBoxContainer/ConnectBtn
@onready var join_btn: Button = $Dimmer/Center/Panel/VBoxContainer/JoinBtn
@onready var back_btn: Button = $Dimmer/Center/Panel/VBoxContainer/BackBtn

var ws: WebSocketPeer
var is_host := false
var wants_to_host := false
var pending_room := ""
var join_sent := false
var connecting := false
var leaving_lobby := false
var transition_started := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_main_menu_typography()
	helper_label.visible = false
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	room_input.text_submitted.connect(func(_value: String): _on_join_pressed())
	room_input.text_changed.connect(_on_room_text_changed)
	get_tree().root.size_changed.connect(_layout_for_screen)
	_layout_for_screen()
	set_process(false)
	room_input.call_deferred("grab_focus")

func _make_font_variation(weight: float, embolden: float = 0.0) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = MENU_FONT
	font.variation_opentype = {"wght": weight}
	font.variation_embolden = embolden
	return font

func _apply_main_menu_typography() -> void:
	var button_font := _make_font_variation(900.0, 0.85)
	var input_font := _make_font_variation(760.0, 0.3)
	var detail_font := _make_font_variation(650.0, 0.15)

	title_label.add_theme_font_override("font", button_font)
	title_label.add_theme_font_size_override("font_size", 27)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.03, 0.012, 0.006, 0.98))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 2)

	for button in [host_btn, join_btn, back_btn]:
		button.add_theme_font_override("font", button_font)
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.82, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 0.72, 0.32, 1.0))
		button.add_theme_color_override("font_focus_color", Color(0.73, 0.93, 1.0, 1.0))
		button.add_theme_color_override("font_outline_color", Color(0.03, 0.012, 0.006, 0.98))
		button.add_theme_constant_override("outline_size", 3)
		button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
		button.add_theme_constant_override("shadow_offset_x", 1)
		button.add_theme_constant_override("shadow_offset_y", 2)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	room_input.add_theme_font_override("font", input_font)
	room_input.add_theme_font_size_override("font_size", 15)
	room_input.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8, 1.0))
	room_input.add_theme_color_override("font_placeholder_color", Color(0.68, 0.66, 0.62, 0.9))
	room_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	for label in [status_label, helper_label]:
		label.add_theme_font_override("font", detail_font)
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.005, 0.92))
		label.add_theme_constant_override("outline_size", 2)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _layout_for_screen() -> void:
	if panel == null:
		return
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var compact := size.x < 700.0 or size.y < 520.0
	var panel_width := clampf(size.x * 0.46, 330.0, 520.0)
	var panel_height := clampf(size.y * 0.60, 330.0, 390.0)
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	vbox.add_theme_constant_override("separation", 8 if compact else 11)
	title_label.custom_minimum_size.y = 38.0 if compact else 44.0
	title_label.add_theme_font_size_override("font_size", 23 if compact else 27)
	status_label.custom_minimum_size.y = 34.0 if compact else 38.0
	status_label.add_theme_font_size_override("font_size", 11 if compact else 13)
	helper_label.visible = false
	var control_width := clampf(size.x * 0.22, 218.0, 252.0)
	var button_height := 46.0 if compact else 52.0
	room_input.custom_minimum_size = Vector2(control_width, 44.0 if compact else 48.0)
	host_btn.custom_minimum_size = Vector2(control_width, button_height)
	join_btn.custom_minimum_size = Vector2(control_width, button_height)
	back_btn.custom_minimum_size = Vector2(control_width, 44.0 if compact else 48.0)
	room_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	host_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	join_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _process(_delta: float) -> void:
	if ws == null:
		set_process(false)
		return
	ws.poll()
	var state := ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not join_sent:
			join_sent = true
			status_label.text = "Connected to relay. Opening stronghold %s…" % pending_room
			ws.send_text(JSON.stringify({"type": "join", "room": pending_room}))
		while ws.get_available_packet_count() > 0:
			var packet := ws.get_packet()
			var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
			if parsed is Dictionary:
				_handle_signaling_message(parsed as Dictionary)
	elif state == WebSocketPeer.STATE_CLOSED and connecting:
		connecting = false
		join_sent = false
		_set_controls_enabled(true)
		status_label.text = "Connection failed or closed. Check the password and try again."
		set_process(false)

func _on_room_text_changed(value: String) -> void:
	var normalized := value.to_upper().strip_edges()
	if normalized != value:
		var caret := room_input.caret_column
		room_input.text = normalized
		room_input.caret_column = mini(caret, normalized.length())

func _on_host_pressed() -> void:
	if connecting:
		return
	var room := room_input.text.to_upper().strip_edges()
	if room.is_empty():
		room = _generate_room_password()
		room_input.text = room
	_start_connection(room, true)

func _on_join_pressed() -> void:
	if connecting:
		return
	var room := room_input.text.to_upper().strip_edges()
	if room.is_empty():
		status_label.text = "Enter the host's private password first."
		room_input.grab_focus()
		return
	_start_connection(room, false)

func _start_connection(room: String, host_request: bool) -> void:
	_cleanup_peer(false)
	pending_room = room
	wants_to_host = host_request
	join_sent = false
	is_host = false
	ws = WebSocketPeer.new()
	status_label.text = "Creating your private stronghold…" if wants_to_host else "Searching for the hosted stronghold…"
	var err := ws.connect_to_url(SIGNALING_SERVER_URL)
	if err != OK:
		status_label.text = "Could not start the online connection."
		ws = null
		return
	connecting = true
	_set_controls_enabled(false)
	set_process(true)

func _set_controls_enabled(enabled: bool) -> void:
	host_btn.disabled = not enabled
	join_btn.disabled = not enabled
	room_input.editable = enabled

func _handle_signaling_message(msg: Dictionary) -> void:
	var message_type := str(msg.get("type", ""))
	match message_type:
		"joined":
			var role := str(msg.get("role", "guest"))
			is_host = role == "host"
			if wants_to_host and not is_host:
				_reject_role("That password already has a host. Use JOIN STRONGHOLD instead.")
				return
			if not wants_to_host and is_host:
				_reject_role("No hosted stronghold exists for that password yet.")
				return
			Global.rtc_peer = WebRTCMultiplayerPeer.new()
			if is_host:
				Global.rtc_peer.create_server()
				status_label.text = "Stronghold hosted. Share password: %s\nWaiting for one player…" % pending_room
			else:
				Global.rtc_peer.create_client(2)
				status_label.text = "Stronghold found. Connecting to the host…"
			multiplayer.multiplayer_peer = Global.rtc_peer
		"peer_connected":
			status_label.text = "Player found. Establishing peer-to-peer connection…"
			_create_rtc_connection(2)
			if Global.rtc_conn:
				Global.rtc_conn.create_offer()
		"offer":
			status_label.text = "Host found. Establishing peer-to-peer connection…"
			_create_rtc_connection(1)
			if Global.rtc_conn:
				Global.rtc_conn.set_remote_description("offer", str(msg.get("sdp", "")))
				Global.rtc_conn.create_answer()
		"answer":
			if Global.rtc_conn:
				Global.rtc_conn.set_remote_description("answer", str(msg.get("sdp", "")))
		"candidate":
			if Global.rtc_conn:
				Global.rtc_conn.add_ice_candidate(str(msg.get("media", "")), int(msg.get("index", 0)), str(msg.get("name", "")))
		"error":
			status_label.text = "Online error: %s" % str(msg.get("message", "Unknown signaling error"))
			connecting = false
			_set_controls_enabled(true)
		"peer_disconnected":
			status_label.text = "The other player disconnected before entering the hub."
			connecting = false
			_set_controls_enabled(true)

func _reject_role(message: String) -> void:
	status_label.text = message
	connecting = false
	if ws:
		ws.close()
	ws = null
	_cleanup_peer(false)
	_set_controls_enabled(true)
	set_process(false)

func _create_rtc_connection(id: int) -> void:
	Global.rtc_conn = WebRTCPeerConnection.new()
	var init_result := Global.rtc_conn.initialize({
		"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]
	})
	if init_result != OK:
		status_label.text = "WebRTC initialization failed on this device."
		connecting = false
		Global.rtc_conn = null
		_set_controls_enabled(true)
		return
	Global.rtc_conn.session_description_created.connect(_on_session_description_created)
	Global.rtc_conn.ice_candidate_created.connect(_on_ice_candidate_created)
	Global.rtc_peer.add_peer(Global.rtc_conn, id)
	if not Global.rtc_peer.peer_connected.is_connected(_on_rtc_peer_connected):
		Global.rtc_peer.peer_connected.connect(_on_rtc_peer_connected)

func _on_session_description_created(type: String, sdp: String) -> void:
	if Global.rtc_conn == null or ws == null:
		return
	Global.rtc_conn.set_local_description(type, sdp)
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify({"type": type, "sdp": sdp}))

func _on_ice_candidate_created(media: String, index: int, name: String) -> void:
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify({"type": "candidate", "media": media, "index": index, "name": name}))

func _on_rtc_peer_connected(_id: int) -> void:
	if transition_started:
		return
	status_label.text = "Connected. Opening the hosted stronghold…"
	connecting = false
	if ws:
		ws.close()
	if is_host:
		transition_started = true
		await get_tree().create_timer(0.25).timeout
		rpc("open_online_stronghold")

@rpc("authority", "call_local", "reliable")
func open_online_stronghold() -> void:
	if not transition_started:
		transition_started = true
	var online_hub := ONLINE_HUB_SCENE.instantiate()
	get_tree().root.add_child(online_hub)
	get_tree().current_scene = online_hub
	queue_free()

func _generate_room_password() -> String:
	const LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var result := ""
	for _index in range(6):
		result += LETTERS[randi_range(0, LETTERS.length() - 1)]
	return result

func _cleanup_peer(clear_socket: bool = true) -> void:
	if clear_socket and ws:
		ws.close()
	if Global.rtc_peer:
		Global.rtc_peer.close()
	Global.rtc_peer = null
	Global.rtc_conn = null
	multiplayer.multiplayer_peer = null

func _on_back_pressed() -> void:
	if leaving_lobby:
		return
	leaving_lobby = true
	connecting = false
	if ws:
		ws.close()
	_cleanup_peer(false)
	await get_tree().create_timer(0.12, true).timeout
	get_tree().change_scene_to_file("res://scenes/menus/main/menu.tscn")
