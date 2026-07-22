extends Node

const HUB_HUD_SCENE := preload("res://scenes/ui/overlays/single_player_hub_hud.tscn")
const PLAYER_TWO_SCENE := preload("res://local_coop_player.tscn")

const LOCAL_COOP_SCENE := "res://local_coop_mode.tscn"
const MAIN_MENU_SCENE := "res://scenes/menus/main/menu.tscn"
const READY_COUNTDOWN := 1.35
const COOP_READY_ZONE := Rect2(-126.0, 246.0, 252.0, 270.0)
const HUB_CAMERA_ZOOM := Vector2(1.0, 1.0)
const CAMERA_X_LIMIT := 92.0
const CAMERA_Y_MIN := -42.0
const CAMERA_Y_MAX := 255.0

@export var world_path: NodePath = NodePath("../Level")

var world: Node2D
var player_one: CharacterBody2D
var player_two: CharacterBody2D
var base: Node2D
var game_hud: CanvasLayer
var hub_hud: CanvasLayer
var status_label: Label
var shared_camera: Camera2D
var player_one_camera: Camera2D
var route_root: Node2D

var _committing := false
var _countdown_remaining := 0.0
var _last_status := ""

func _ready() -> void:
	world = get_node_or_null(world_path) as Node2D
	if world == null:
		push_error("Local multiplayer hub could not find its compact Level")
		return
	player_one = world.get_node_or_null("Player") as CharacterBody2D
	base = world.get_node_or_null("Base") as Node2D
	game_hud = world.get_node_or_null("HUD") as CanvasLayer
	if player_one == null or base == null:
		push_error("Local multiplayer hub requires Player and Base")
		return

	GameMode.set_mode(GameMode.Mode.HUB)
	world.set_meta("local_multiplayer_hub_active", true)
	world.set_process(false)
	world.preparation_active = true
	world.preparation_mode = true

	Global.apply_selected_loadout()
	base.position = Vector2(0, -78)
	_setup_player_one()
	_spawn_player_two()
	_refresh_base()
	_create_shared_camera()

	if game_hud:
		game_hud.visible = false
	_create_single_route()
	_create_hub_hud()
	_create_player_marker(player_one, "P1", Color(0.3, 0.85, 1.0, 1.0))
	_create_player_marker(player_two, "P2", Color(1.0, 0.55, 0.24, 1.0))
	_set_status("Choose a hero, then enter the lower tunnel together.  P1: WASD  •  P2: Arrow Keys")

func _setup_player_one() -> void:
	player_one.position = Vector2(-42, 112)
	player_one.visible = true
	player_one.process_mode = Node.PROCESS_MODE_INHERIT
	player_one.velocity = Vector2.ZERO
	player_one.set("player_id", 1)
	player_one.add_to_group("coop_players")
	if player_one.has_method("update_hero_sprites"):
		player_one.update_hero_sprites()
	player_one_camera = player_one.get_node_or_null("Camera2D") as Camera2D
	if player_one_camera:
		player_one_camera.enabled = false

func _spawn_player_two() -> void:
	player_two = PLAYER_TWO_SCENE.instantiate() as CharacterBody2D
	player_two.name = "Player2"
	player_two.position = Vector2(42, 112)
	player_two.set("player_id", 2)
	player_two.add_to_group("coop_players")
	world.add_child(player_two)
	if player_two.has_method("update_hero_sprites"):
		player_two.update_hero_sprites()

func _refresh_base() -> void:
	if base.has_method("refresh_base_sprite"):
		base.refresh_base_sprite()

func _create_shared_camera() -> void:
	shared_camera = Camera2D.new()
	shared_camera.name = "LocalHubSharedCamera"
	shared_camera.position = Vector2(0, 24)
	shared_camera.zoom = HUB_CAMERA_ZOOM
	shared_camera.position_smoothing_enabled = true
	shared_camera.position_smoothing_speed = 7.0
	world.add_child(shared_camera)
	shared_camera.enabled = true

func _create_single_route() -> void:
	route_root = Node2D.new()
	route_root.name = "CompactCoopRoute"
	route_root.z_index = 18
	world.add_child(route_root)

	var glow := Polygon2D.new()
	glow.name = "CoopDoorGlow"
	glow.position = Vector2(0, 320)
	glow.polygon = PackedVector2Array([
		Vector2(-104, -38), Vector2(104, -38),
		Vector2(104, 38), Vector2(-104, 38),
	])
	glow.color = Color(0.08, 0.72, 1.0, 0.25)
	route_root.add_child(glow)

	var label := Label.new()
	label.name = "CoopMineLabel"
	label.position = Vector2(-150, 214)
	label.size = Vector2(300, 64)
	label.text = "CO-OP MINE\nBOTH PLAYERS ENTER"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.38, 0.88, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	route_root.add_child(label)

func _create_hub_hud() -> void:
	hub_hud = HUB_HUD_SCENE.instantiate() as CanvasLayer
	add_child(hub_hud)
	var title := hub_hud.get_node("TopPanel/Margin/VBox/Title") as Label
	var subtitle := hub_hud.get_node("TopPanel/Margin/VBox/Subtitle") as Label
	status_label = hub_hud.get_node("StatusPanel/Margin/Status") as Label
	title.text = "LOCAL CO-OP  •  STRONGHOLD"
	subtitle.text = "P1 %s  •  P2 %s  •  One tunnel, one shared run" % [Global.hero_p1, Global.hero_p2]

func _create_player_marker(target: CharacterBody2D, text: String, color: Color) -> void:
	if target == null:
		return
	var marker := Label.new()
	marker.name = text + "Marker"
	marker.text = text
	marker.position = Vector2(-26, -84)
	marker.size = Vector2(52, 20)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.z_index = 40
	marker.add_theme_font_size_override("font_size", 13)
	marker.add_theme_color_override("font_color", color)
	marker.add_theme_color_override("font_outline_color", Color.BLACK)
	marker.add_theme_constant_override("outline_size", 4)
	target.add_child(marker)

func _process(delta: float) -> void:
	if _committing or not is_instance_valid(player_one) or not is_instance_valid(player_two):
		return
	_update_shared_camera(delta)
	_update_readiness(delta)
	_update_hud_heroes()

func _update_shared_camera(delta: float) -> void:
	# Follow the pair gently, but never zoom out. The compact walls and clamped
	# midpoint keep the stronghold intimate even after many progression unlocks.
	var midpoint := (player_one.global_position + player_two.global_position) * 0.5 + Vector2(0, -20)
	midpoint.x = clampf(midpoint.x, -CAMERA_X_LIMIT, CAMERA_X_LIMIT)
	midpoint.y = clampf(midpoint.y, CAMERA_Y_MIN, CAMERA_Y_MAX)
	var camera_weight := 1.0 - exp(-7.0 * delta)
	shared_camera.global_position = shared_camera.global_position.lerp(midpoint, camera_weight)
	shared_camera.zoom = HUB_CAMERA_ZOOM

func _update_readiness(delta: float) -> void:
	var p1_ready := COOP_READY_ZONE.has_point(player_one.global_position)
	var p2_ready := COOP_READY_ZONE.has_point(player_two.global_position)
	if p1_ready and p2_ready:
		if _countdown_remaining <= 0.0:
			_countdown_remaining = READY_COUNTDOWN
		_countdown_remaining -= delta
		_set_status("CO-OP MINE  •  BOTH READY  •  Starting in %.1f" % maxf(_countdown_remaining, 0.0))
		if _countdown_remaining <= 0.0:
			_start_coop_mine()
		return

	_countdown_remaining = 0.0
	if p1_ready:
		_set_status("P1 READY  •  Waiting for Player 2")
	elif p2_ready:
		_set_status("P2 READY  •  Waiting for Player 1")
	else:
		_set_status("P1 %s  •  P2 %s  •  Enter the lower tunnel together." % [Global.hero_p1, Global.hero_p2])

func _start_coop_mine() -> void:
	if _committing:
		return
	_committing = true
	Global.current_hero = Global.hero_p1
	Global.save_game()
	world.remove_meta("local_multiplayer_hub_active")
	GameMode.set_mode(GameMode.Mode.EXPLORATION)
	get_tree().change_scene_to_file(LOCAL_COOP_SCENE)

func _update_hud_heroes() -> void:
	if hub_hud == null or not is_instance_valid(hub_hud):
		return
	var subtitle := hub_hud.get_node("TopPanel/Margin/VBox/Subtitle") as Label
	var desired := "P1 %s  •  P2 %s  •  One tunnel, one shared run" % [Global.hero_p1, Global.hero_p2]
	if subtitle.text != desired:
		subtitle.text = desired

func _set_status(message: String) -> void:
	if message == _last_status:
		return
	_last_status = message
	if status_label:
		status_label.text = message

func _unhandled_input(event: InputEvent) -> void:
	if _committing:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
