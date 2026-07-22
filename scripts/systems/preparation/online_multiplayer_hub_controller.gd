extends Node

const HUB_HUD_SCENE := preload("res://scenes/ui/overlays/single_player_hub_hud.tscn")
const REMOTE_PLAYER_SCENE := preload("res://local_coop_player.tscn")

const ONLINE_MATCH_SCENE := preload("res://vs_online.tscn")
const MAIN_MENU_SCENE := "res://scenes/menus/main/menu.tscn"
const READY_COUNTDOWN := 1.5
const ONLINE_READY_ZONE := Rect2(-126.0, 246.0, 252.0, 270.0)
const HUB_CAMERA_ZOOM := Vector2(1.0, 1.0)
const CAMERA_X_LIMIT := 92.0
const CAMERA_Y_MIN := -42.0
const CAMERA_Y_MAX := 255.0
const STATE_SEND_INTERVAL := 0.05
const HERO_SELECT_DISTANCE := 56.0

const HERO_ORDER: Array[String] = ["Dwarf", "Shaman", "Druid", "Nerubian", "Undead King", "Mech"]
const HERO_TEXTURES := {
	"Dwarf": preload("res://character_sprites/hero_idle/dwarf_idle_front.png"),
	"Shaman": preload("res://character_sprites/hero_idle/shaman_idle_front.png"),
	"Druid": preload("res://character_sprites/hero_idle/druid_idle_front.png"),
	"Nerubian": preload("res://character_sprites/hero_idle/nerubian_idle_front.png"),
	"Undead King": preload("res://character_sprites/hero_idle/undead_king_idle_front.png"),
	"Mech": preload("res://character_sprites/hero_idle/mech_idle_front.png"),
}
const HERO_ACCENTS := {
	"Dwarf": Color(1.0, 0.61, 0.18, 1.0),
	"Shaman": Color(0.34, 0.88, 1.0, 1.0),
	"Druid": Color(0.42, 1.0, 0.48, 1.0),
	"Nerubian": Color(0.72, 0.38, 1.0, 1.0),
	"Undead King": Color(0.52, 0.72, 1.0, 1.0),
	"Mech": Color(1.0, 0.46, 0.16, 1.0),
}

@export var world_path: NodePath = NodePath("../Level")

var world: Node2D
var local_player: CharacterBody2D
var remote_player: CharacterBody2D
var base: Node2D
var game_hud: CanvasLayer
var hub_hud: CanvasLayer
var status_label: Label
var shared_camera: Camera2D
var local_camera: Camera2D
var route_root: Node2D
var shrine_root: Node2D

var host_choices: Array[String] = []
var host_base_id := "default_base"
var host_hero := "Dwarf"
var guest_hero := "Dwarf"
var remote_target_position := Vector2.ZERO
var remote_velocity := Vector2.ZERO
var remote_state_received := false
var local_last_shrine := ""
var hero_nodes: Dictionary = {}

var _state_send_timer := 0.0
var _countdown_remaining := 0.0
var _committing := false
var _last_status := ""
var _profile_announced := false

func _ready() -> void:
	if multiplayer.multiplayer_peer == null:
		push_error("Online stronghold requires an active multiplayer peer")
		_return_to_menu()
		return
	world = get_node_or_null(world_path) as Node2D
	if world == null:
		push_error("Online multiplayer hub could not find Level")
		return
	local_player = world.get_node_or_null("Player") as CharacterBody2D
	base = world.get_node_or_null("Base") as Node2D
	game_hud = world.get_node_or_null("HUD") as CanvasLayer
	if local_player == null or base == null:
		push_error("Online multiplayer hub requires Player and Base")
		return

	GameMode.set_mode(GameMode.Mode.HUB)
	world.set_meta("local_multiplayer_hub_active", true)
	world.set_meta("online_multiplayer_hub_active", true)
	world.set_process(false)
	world.preparation_active = true
	world.preparation_mode = true

	_setup_profiles()
	_setup_world()
	_create_route()
	_create_hud()
	_create_markers()
	_connect_network_signals()
	call_deferred("_announce_network_profile")

func _setup_profiles() -> void:
	var selected := str(Global.selected_hero_id)
	if not Global.hero_data.has(selected):
		selected = "Dwarf"
	if multiplayer.is_server():
		host_hero = selected
		host_base_id = str(Global.selected_base_id)
		host_choices = _host_compact_choices()
		if not host_choices.has(host_hero) and not host_choices.is_empty():
			host_hero = host_choices[0]
	else:
		guest_hero = selected
	Global.hero_p1 = _local_hero()
	Global.current_hero = _local_hero()
	Global.hero_p2 = _remote_hero()

func _host_compact_choices() -> Array[String]:
	var choices: Array[String] = []
	_add_host_choice(choices, str(Global.selected_hero_id))
	for index in range(Global.unlocked_heroes.size() - 1, -1, -1):
		_add_host_choice(choices, str(Global.unlocked_heroes[index]))
		if choices.size() >= 2:
			break
	if choices.is_empty():
		choices.append("Dwarf")
	return choices

func _add_host_choice(choices: Array[String], hero_name: String) -> void:
	if choices.size() >= 2 or hero_name.is_empty() or choices.has(hero_name):
		return
	if not Global.hero_data.has(hero_name):
		return
	if not Global.is_hero_unlocked(hero_name):
		return
	choices.append(hero_name)

func _setup_world() -> void:
	base.position = Vector2(0, -78)
	if multiplayer.is_server():
		local_player.position = Vector2(-42, 112)
		remote_target_position = Vector2(42, 112)
	else:
		local_player.position = Vector2(42, 112)
		remote_target_position = Vector2(-42, 112)
	local_player.visible = true
	local_player.process_mode = Node.PROCESS_MODE_INHERIT
	local_player.velocity = Vector2.ZERO
	local_player.set("player_id", 1)
	local_player.add_to_group("online_players")
	if local_player.has_method("update_hero_sprites"):
		local_player.update_hero_sprites()
	local_camera = local_player.get_node_or_null("Camera2D") as Camera2D
	if local_camera:
		local_camera.enabled = false

	remote_player = REMOTE_PLAYER_SCENE.instantiate() as CharacterBody2D
	remote_player.name = "RemotePlayer"
	remote_player.position = remote_target_position
	remote_player.set("player_id", 2)
	remote_player.add_to_group("online_players")
	remote_player.process_mode = Node.PROCESS_MODE_DISABLED
	remote_player.collision_layer = 0
	remote_player.collision_mask = 0
	world.add_child(remote_player)
	if remote_player.has_method("update_hero_sprites"):
		remote_player.update_hero_sprites()

	if base.has_method("refresh_base_sprite"):
		base.refresh_base_sprite()
	if game_hud:
		game_hud.visible = false

	shared_camera = Camera2D.new()
	shared_camera.name = "OnlineHubSharedCamera"
	shared_camera.position = Vector2(0, 24)
	shared_camera.zoom = HUB_CAMERA_ZOOM
	shared_camera.position_smoothing_enabled = true
	shared_camera.position_smoothing_speed = 7.0
	world.add_child(shared_camera)
	shared_camera.enabled = true

func _create_route() -> void:
	route_root = Node2D.new()
	route_root.name = "OnlineRoute"
	route_root.z_index = 18
	world.add_child(route_root)

	var glow := Polygon2D.new()
	glow.name = "OnlineDoorGlow"
	glow.position = Vector2(0, 320)
	glow.polygon = PackedVector2Array([
		Vector2(-104, -38), Vector2(104, -38),
		Vector2(104, 38), Vector2(-104, 38),
	])
	glow.color = Color(0.42, 0.55, 1.0, 0.26)
	route_root.add_child(glow)

	var label := Label.new()
	label.name = "OnlineMatchLabel"
	label.position = Vector2(-170, 214)
	label.size = Vector2(340, 64)
	label.text = "ONLINE EXPEDITION VS\nBOTH PLAYERS ENTER"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.56, 0.78, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	route_root.add_child(label)

func _create_hud() -> void:
	hub_hud = HUB_HUD_SCENE.instantiate() as CanvasLayer
	add_child(hub_hud)
	var title := hub_hud.get_node("TopPanel/Margin/VBox/Title") as Label
	var subtitle := hub_hud.get_node("TopPanel/Margin/VBox/Subtitle") as Label
	status_label = hub_hud.get_node("StatusPanel/Margin/Status") as Label
	title.text = "ONLINE STRONGHOLD  •  %s" % ("HOST" if multiplayer.is_server() else "GUEST")
	subtitle.text = "A private hosted hub  •  Choose heroes together"
	_set_status("Connected. Synchronizing the host stronghold…")

func _create_markers() -> void:
	_create_player_marker(local_player, "HOST" if multiplayer.is_server() else "GUEST", Color(0.3, 0.85, 1.0, 1.0))
	_create_player_marker(remote_player, "GUEST" if multiplayer.is_server() else "HOST", Color(1.0, 0.55, 0.24, 1.0))

func _create_player_marker(target: CharacterBody2D, text: String, color: Color) -> void:
	var marker := Label.new()
	marker.name = text + "Marker"
	marker.text = text
	marker.position = Vector2(-40, -84)
	marker.size = Vector2(80, 20)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.z_index = 40
	marker.add_theme_font_size_override("font_size", 12)
	marker.add_theme_color_override("font_color", color)
	marker.add_theme_color_override("font_outline_color", Color.BLACK)
	marker.add_theme_constant_override("outline_size", 4)
	target.add_child(marker)

func _connect_network_signals() -> void:
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _announce_network_profile() -> void:
	await get_tree().create_timer(0.35).timeout
	if _committing or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		_build_host_shrines(host_choices)
		rpc_id(2, "receive_host_profile", host_choices, host_base_id, host_hero)
	else:
		rpc_id(1, "receive_guest_profile", guest_hero)
	_profile_announced = true

@rpc("authority", "call_remote", "reliable")
func receive_host_profile(choices: Array, base_id: String, selected_hero: String) -> void:
	host_choices.clear()
	for value in choices:
		var hero_name := str(value)
		if Global.hero_data.has(hero_name) and not host_choices.has(hero_name):
			host_choices.append(hero_name)
	if host_choices.is_empty():
		host_choices.append("Dwarf")
	host_base_id = base_id
	host_hero = selected_hero if Global.hero_data.has(selected_hero) else host_choices[0]
	Global.selected_base_id = host_base_id
	Global.hero_p2 = host_hero
	if base and base.has_method("refresh_base_sprite"):
		base.refresh_base_sprite()
	_refresh_remote_hero()
	_build_host_shrines(host_choices)
	_set_status("Joined the host stronghold. Choose a hero, then enter the tunnel together.")

@rpc("any_peer", "call_remote", "reliable")
func receive_guest_profile(selected_hero: String) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != 2:
		return
	guest_hero = selected_hero if Global.hero_data.has(selected_hero) else "Dwarf"
	Global.hero_p2 = guest_hero
	_refresh_remote_hero()
	rpc_id(2, "receive_host_profile", host_choices, host_base_id, host_hero)

func _build_host_shrines(choices: Array[String]) -> void:
	if shrine_root != null and is_instance_valid(shrine_root):
		shrine_root.queue_free()
	shrine_root = Node2D.new()
	shrine_root.name = "OnlineHeroShrines"
	shrine_root.z_index = 12
	world.add_child(shrine_root)
	hero_nodes.clear()
	var positions: Array[Vector2] = [Vector2(-190, -42), Vector2(190, -42)]
	if choices.size() == 1:
		positions[0] = Vector2(-185, -42)
	for index in range(mini(choices.size(), 2)):
		_create_hero_shrine(choices[index], positions[index])
	_refresh_shrines()

func _create_hero_shrine(hero_name: String, shrine_position: Vector2) -> void:
	var root := Node2D.new()
	root.name = hero_name.replace(" ", "") + "Shrine"
	root.position = shrine_position
	shrine_root.add_child(root)
	var accent: Color = HERO_ACCENTS.get(hero_name, Color.WHITE)

	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.position = Vector2(0, 18)
	glow.polygon = _ring_polygon(29.0)
	glow.color = Color(accent.r, accent.g, accent.b, 0.18)
	root.add_child(glow)

	var pedestal := Polygon2D.new()
	pedestal.name = "Pedestal"
	pedestal.position = Vector2(0, 18)
	pedestal.polygon = _ring_polygon(24.0)
	pedestal.color = Color(0.055, 0.07, 0.095, 0.98)
	root.add_child(pedestal)

	var edge := Line2D.new()
	edge.name = "Edge"
	edge.position = Vector2(0, 18)
	edge.points = _ring_line(24.0)
	edge.width = 2.0
	edge.default_color = Color(accent.r, accent.g, accent.b, 0.72)
	root.add_child(edge)

	var sprite := Sprite2D.new()
	sprite.name = "Hero"
	sprite.texture = HERO_TEXTURES.get(hero_name, HERO_TEXTURES["Dwarf"])
	sprite.position = Vector2(0, -23)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var texture_size: Vector2 = sprite.texture.get_size()
	var scale_factor := 58.0 / maxf(texture_size.y, 1.0)
	sprite.scale = Vector2(scale_factor, scale_factor)
	root.add_child(sprite)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.position = Vector2(-86, 43)
	name_label.size = Vector2(172, 28)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 4)
	root.add_child(name_label)

	hero_nodes[hero_name] = {
		"root": root,
		"glow": glow,
		"pedestal": pedestal,
		"edge": edge,
		"name": name_label,
	}

func _ring_polygon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(12):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / 12.0) * radius)
	return points

func _ring_line(radius: float) -> PackedVector2Array:
	var points := _ring_polygon(radius)
	points.append(points[0])
	return points

func _process(delta: float) -> void:
	if _committing or local_player == null or remote_player == null:
		return
	_update_camera(delta)
	_update_remote_avatar(delta)
	_process_local_hero_selection()
	_send_local_state(delta)
	_update_readiness(delta)

func _update_camera(delta: float) -> void:
	var midpoint := (local_player.global_position + remote_player.global_position) * 0.5 + Vector2(0, -20)
	midpoint.x = clampf(midpoint.x, -CAMERA_X_LIMIT, CAMERA_X_LIMIT)
	midpoint.y = clampf(midpoint.y, CAMERA_Y_MIN, CAMERA_Y_MAX)
	var camera_weight := 1.0 - exp(-7.0 * delta)
	shared_camera.global_position = shared_camera.global_position.lerp(midpoint, camera_weight)
	shared_camera.zoom = HUB_CAMERA_ZOOM

func _update_remote_avatar(delta: float) -> void:
	if not remote_state_received:
		return
	var weight := 1.0 - exp(-14.0 * delta)
	remote_player.global_position = remote_player.global_position.lerp(remote_target_position, weight)
	remote_player.velocity = remote_velocity
	if remote_velocity.length() > 3.0 and remote_player.has_method("_update_directional_animation"):
		remote_player.call("_update_directional_animation", remote_velocity.normalized(), delta)

func _send_local_state(delta: float) -> void:
	_state_send_timer -= delta
	if _state_send_timer > 0.0:
		return
	_state_send_timer = STATE_SEND_INTERVAL
	var other_id := 2 if multiplayer.is_server() else 1
	rpc_id(other_id, "receive_avatar_state", local_player.global_position, local_player.velocity, _local_hero())

@rpc("any_peer", "call_remote", "unreliable")
func receive_avatar_state(position: Vector2, velocity_value: Vector2, hero_name: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var expected := 2 if multiplayer.is_server() else 1
	if sender != expected:
		return
	remote_target_position = position
	remote_velocity = velocity_value
	if not remote_state_received:
		remote_player.global_position = position
	remote_state_received = true
	if hero_name != _remote_hero() and Global.hero_data.has(hero_name):
		if multiplayer.is_server():
			guest_hero = hero_name
		else:
			host_hero = hero_name
		Global.hero_p2 = hero_name
		_refresh_remote_hero()
		_refresh_shrines()

func _process_local_hero_selection() -> void:
	if hero_nodes.is_empty():
		return
	var closest := ""
	var closest_distance := HERO_SELECT_DISTANCE
	for hero_name in hero_nodes:
		var shrine: Node2D = hero_nodes[hero_name]["root"]
		var distance := local_player.global_position.distance_to(shrine.global_position)
		if distance <= closest_distance:
			closest = hero_name
			closest_distance = distance
	if not closest.is_empty() and closest != local_last_shrine:
		_set_local_hero(closest)
	local_last_shrine = closest

func _set_local_hero(hero_name: String) -> void:
	if not host_choices.has(hero_name):
		return
	if multiplayer.is_server():
		host_hero = hero_name
		rpc("receive_host_hero", hero_name)
	else:
		guest_hero = hero_name
		rpc_id(1, "receive_guest_hero", hero_name)
	Global.hero_p1 = hero_name
	Global.current_hero = hero_name
	if local_player.has_method("update_hero_sprites"):
		local_player.update_hero_sprites()
	_refresh_shrines()
	_set_status("You chose %s. Enter the lower tunnel when both players are ready." % hero_name)
	var pulse := create_tween()
	pulse.tween_property(local_player, "scale", Vector2(1.14, 1.14), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(local_player, "scale", Vector2.ONE, 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

@rpc("authority", "call_remote", "reliable")
func receive_host_hero(hero_name: String) -> void:
	if not Global.hero_data.has(hero_name):
		return
	host_hero = hero_name
	Global.hero_p2 = host_hero
	_refresh_remote_hero()
	_refresh_shrines()

@rpc("any_peer", "call_remote", "reliable")
func receive_guest_hero(hero_name: String) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != 2:
		return
	if not Global.hero_data.has(hero_name):
		return
	guest_hero = hero_name
	Global.hero_p2 = guest_hero
	_refresh_remote_hero()
	_refresh_shrines()

func _refresh_remote_hero() -> void:
	Global.hero_p2 = _remote_hero()
	if remote_player and remote_player.has_method("update_hero_sprites"):
		remote_player.update_hero_sprites()

func _refresh_shrines() -> void:
	for hero_name in hero_nodes:
		var data: Dictionary = hero_nodes[hero_name]
		var host_selected: bool = host_hero == hero_name
		var guest_selected: bool = guest_hero == hero_name
		var accent: Color = HERO_ACCENTS.get(hero_name, Color.WHITE)
		var label: Label = data["name"]
		var pedestal: Polygon2D = data["pedestal"]
		var edge: Line2D = data["edge"]
		var glow: Polygon2D = data["glow"]
		var suffix := ""
		if host_selected and guest_selected:
			suffix = "  •  HOST + GUEST"
		elif host_selected:
			suffix = "  •  HOST"
		elif guest_selected:
			suffix = "  •  GUEST"
		label.text = hero_name + suffix
		label.add_theme_color_override("font_color", accent if host_selected or guest_selected else Color(0.82, 0.91, 1.0, 1.0))
		pedestal.color = Color(0.17, 0.105, 0.028, 0.98) if host_selected or guest_selected else Color(0.055, 0.07, 0.095, 0.98)
		edge.width = 4.0 if host_selected or guest_selected else 2.0
		glow.color = Color(accent.r, accent.g, accent.b, 0.55) if host_selected or guest_selected else Color(accent.r, accent.g, accent.b, 0.18)

func _update_readiness(delta: float) -> void:
	var local_ready := ONLINE_READY_ZONE.has_point(local_player.global_position)
	var remote_ready := remote_state_received and ONLINE_READY_ZONE.has_point(remote_player.global_position)
	if multiplayer.is_server():
		if local_ready and remote_ready:
			if _countdown_remaining <= 0.0:
				_countdown_remaining = READY_COUNTDOWN
			_countdown_remaining -= delta
			var message := "BOTH READY  •  Online match starts in %.1f" % maxf(_countdown_remaining, 0.0)
			_set_status(message)
			rpc_id(2, "receive_host_status", message)
			if _countdown_remaining <= 0.0:
				_start_online_match()
			return
		_countdown_remaining = 0.0
		var waiting := "Choose a hero, then enter the lower tunnel together."
		if local_ready:
			waiting = "HOST READY  •  Waiting for Guest"
		elif remote_ready:
			waiting = "GUEST READY  •  Waiting for Host"
		_set_status(waiting)
		rpc_id(2, "receive_host_status", waiting)

@rpc("authority", "call_remote", "unreliable")
func receive_host_status(message: String) -> void:
	if not multiplayer.is_server():
		_set_status(message)

func _start_online_match() -> void:
	if _committing or not multiplayer.is_server():
		return
	_committing = true
	var seed_value := randi()
	rpc("launch_online_match", seed_value, host_hero, guest_hero)

@rpc("authority", "call_local", "reliable")
func launch_online_match(world_seed: int, selected_host_hero: String, selected_guest_hero: String) -> void:
	if _committing and not multiplayer.is_server():
		return
	_committing = true
	if multiplayer.is_server():
		Global.hero_p1 = selected_host_hero
		Global.current_hero = selected_host_hero
	else:
		Global.hero_p1 = selected_guest_hero
		Global.current_hero = selected_guest_hero
	GameMode.set_mode(GameMode.Mode.EXPLORATION_VS)
	world.remove_meta("local_multiplayer_hub_active")
	world.remove_meta("online_multiplayer_hub_active")
	var online_scene = ONLINE_MATCH_SCENE.instantiate()
	online_scene.world_seed = world_seed
	get_tree().root.add_child(online_scene)
	get_tree().current_scene = online_scene
	get_parent().queue_free()

func _local_hero() -> String:
	return host_hero if multiplayer.is_server() else guest_hero

func _remote_hero() -> String:
	return guest_hero if multiplayer.is_server() else host_hero

func _set_status(message: String) -> void:
	if message == _last_status:
		return
	_last_status = message
	if status_label:
		status_label.text = message

func _on_peer_disconnected(_id: int) -> void:
	_set_status("The other player left the stronghold.")
	remote_state_received = false
	_countdown_remaining = 0.0

func _on_server_disconnected() -> void:
	_set_status("The host closed the stronghold.")
	await get_tree().create_timer(1.2).timeout
	_return_to_menu()

func _unhandled_input(event: InputEvent) -> void:
	if _committing:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_return_to_menu()
		get_viewport().set_input_as_handled()

func _return_to_menu() -> void:
	_committing = true
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	Global.rtc_peer = null
	Global.rtc_conn = null
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
