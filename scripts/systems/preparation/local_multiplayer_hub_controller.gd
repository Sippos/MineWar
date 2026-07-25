extends Node

const HUB_HUD_SCENE := preload("res://scenes/ui/overlays/single_player_hub_hud.tscn")
const PLAYER_TWO_SCENE := preload("res://local_coop_player.tscn")
const BASE_SWITCH_POPUP_SCRIPT := preload("res://scripts/systems/preparation/base_switch_popup.gd")
const BASE_INTERACT_DISTANCE := 96.0

const LOCAL_COOP_SCENE := "res://local_coop_mode.tscn"
const MAIN_MENU_SCENE := "res://scenes/menus/main/menu.tscn"
const READY_COUNTDOWN := 1.35
const COOP_READY_ZONE := Rect2(-126.0, 246.0, 252.0, 270.0)
const VS_READY_ZONE := Rect2(-126.0, -516.0, 252.0, 270.0)
const HUB_CAMERA_ZOOM := Vector2(1.0, 1.0)
const CAMERA_X_LIMIT := 92.0
const CAMERA_Y_MIN := -255.0
const CAMERA_Y_MAX := 255.0

const VS_SELECT_TUNNEL_ZONE := Rect2(-90.0, -210.0, 60.0, 60.0)
const VS_SELECT_MAZE_ZONE := Rect2(30.0, -210.0, 60.0, 60.0)

@export var world_path: NodePath = NodePath("../Level")

var world: Node2D
var player_one: CharacterBody2D
var player_two: CharacterBody2D
var base: Node2D
var base_two: Node2D
var base_popups: Dictionary = {}
var game_hud: CanvasLayer
var hub_hud: CanvasLayer
var status_label: Label
var shared_camera: Camera2D
var player_one_camera: Camera2D
var route_root: Node2D

var _committing := false
var _countdown_remaining := 0.0
var _last_status := ""
var _selected_vs_mode: int = 0
var _status_hold := 0.0
var tunnel_select_bg: Polygon2D
var maze_select_bg: Polygon2D
var vs_mode_label: Label

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
	base.position = Vector2(-90, 0)
	base.set("base_owner_id", 1)

	var base2 := base.duplicate()
	base2.name = "Base2"
	world.add_child(base2)
	base2.position = Vector2(90, 0)
	base2.set("base_owner_id", 2)
	if base2.has_method("refresh_base_sprite"):
		base2.refresh_base_sprite()
	base_two = base2 as Node2D

	var upgrade_menu = world.get_node_or_null("UpgradeMenu")
	if upgrade_menu:
		upgrade_menu.visible = false
		upgrade_menu.process_mode = Node.PROCESS_MODE_DISABLED

	_setup_player_one()
	_spawn_player_two()
	_refresh_base()
	_setup_base_interaction()
	_create_shared_camera()

	if game_hud:
		game_hud.visible = false
	_create_single_route()
	_create_hub_hud()
	_create_player_marker(player_one, "P1", Color(0.3, 0.85, 1.0, 1.0))
	_create_player_marker(player_two, "P2", Color(1.0, 0.55, 0.24, 1.0))
	_set_status("")

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
	if base_two != null and is_instance_valid(base_two) and base_two.has_method("refresh_base_sprite"):
		base_two.refresh_base_sprite()

func _setup_base_interaction() -> void:
	# Each player owns the stronghold on their side of the room. Walking up to it
	# pops a small switcher over the dome that swaps the base in realtime.
	for entry in [{"node": base, "id": 1}, {"node": base_two, "id": 2}]:
		var base_node: Node2D = entry["node"]
		if base_node == null or not is_instance_valid(base_node):
			continue
		base_node.set_process(false)
		base_node.set_process_input(false)
		var own_prompt := base_node.get_node_or_null("PromptLabel") as Label
		if own_prompt:
			own_prompt.visible = false
		base_popups[int(entry["id"])] = _create_base_popup(base_node, int(entry["id"]))

func _create_base_popup(base_node: Node2D, player_id: int) -> Node2D:
	var popup := Node2D.new()
	popup.name = "BaseSwitcherP%d" % player_id
	popup.set_script(BASE_SWITCH_POPUP_SCRIPT)
	popup.call("setup", player_id, "P%d STRONGHOLD  •  E / Y" % player_id)
	popup.position = Vector2(0, -74)
	popup.visible = false
	base_node.add_child(popup)
	popup.connect("base_change_requested", _on_base_change_requested.bind(player_id))
	return popup

func _base_for_player(player_id: int) -> Node2D:
	return base if player_id == 1 else base_two

func _player_at_own_base(player_id: int) -> bool:
	var target := player_one if player_id == 1 else player_two
	var base_node := _base_for_player(player_id)
	if target == null or not is_instance_valid(target) or base_node == null or not is_instance_valid(base_node):
		return false
	return target.global_position.distance_to(base_node.global_position) <= BASE_INTERACT_DISTANCE

func _update_base_popups() -> void:
	for player_id in base_popups:
		var popup: Node2D = base_popups[player_id]
		if is_instance_valid(popup):
			popup.visible = _player_at_own_base(int(player_id))

func _on_base_change_requested(base_id: String, player_id: int) -> void:
	if _committing or not Global.base_data.has(base_id):
		return
	Global.set_base_for_player(player_id, base_id, true)
	Global.save_game()
	_refresh_base()
	for popup_id in base_popups:
		var popup: Node2D = base_popups[popup_id]
		if is_instance_valid(popup):
			popup.call("refresh")
	_status_hold = 2.0
	_set_status("P%d stronghold: %s" % [player_id, str(Global.base_data[base_id]["name"])])

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
	label.text = "CO-OP MINE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.38, 0.88, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	route_root.add_child(label)

	var vs_glow := Polygon2D.new()
	vs_glow.name = "VsModeGlow"
	vs_glow.position = Vector2(0, -320)
	vs_glow.polygon = PackedVector2Array([
		Vector2(-104, -38), Vector2(104, -38),
		Vector2(104, 38), Vector2(-104, 38),
	])
	vs_glow.color = Color(1.0, 0.2, 0.2, 0.25)
	route_root.add_child(vs_glow)

	var vs_label := Label.new()
	vs_label.name = "VsModeLabel"
	vs_label.position = Vector2(-150, -260)
	vs_label.text = "VS MODE"
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.add_theme_font_size_override("font_size", 16)
	vs_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38, 1.0))
	vs_label.add_theme_color_override("font_outline_color", Color.BLACK)
	vs_label.add_theme_constant_override("outline_size", 5)
	route_root.add_child(vs_label)
	vs_mode_label = vs_label

	tunnel_select_bg = Polygon2D.new()
	tunnel_select_bg.polygon = PackedVector2Array([
		Vector2(VS_SELECT_TUNNEL_ZONE.position.x, VS_SELECT_TUNNEL_ZONE.position.y),
		Vector2(VS_SELECT_TUNNEL_ZONE.position.x + VS_SELECT_TUNNEL_ZONE.size.x, VS_SELECT_TUNNEL_ZONE.position.y),
		Vector2(VS_SELECT_TUNNEL_ZONE.position.x + VS_SELECT_TUNNEL_ZONE.size.x, VS_SELECT_TUNNEL_ZONE.position.y + VS_SELECT_TUNNEL_ZONE.size.y),
		Vector2(VS_SELECT_TUNNEL_ZONE.position.x, VS_SELECT_TUNNEL_ZONE.position.y + VS_SELECT_TUNNEL_ZONE.size.y)
	])
	tunnel_select_bg.color = Color(1.0, 0.5, 0.2, 0.8)
	route_root.add_child(tunnel_select_bg)

	var tunnel_label := Label.new()
	tunnel_label.position = Vector2(VS_SELECT_TUNNEL_ZONE.position.x, VS_SELECT_TUNNEL_ZONE.position.y + 20)
	tunnel_label.size = Vector2(VS_SELECT_TUNNEL_ZONE.size.x, 20)
	tunnel_label.text = "Tunnel"
	tunnel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tunnel_label.add_theme_font_size_override("font_size", 12)
	tunnel_label.add_theme_color_override("font_outline_color", Color.BLACK)
	tunnel_label.add_theme_constant_override("outline_size", 4)
	route_root.add_child(tunnel_label)

	maze_select_bg = Polygon2D.new()
	maze_select_bg.polygon = PackedVector2Array([
		Vector2(VS_SELECT_MAZE_ZONE.position.x, VS_SELECT_MAZE_ZONE.position.y),
		Vector2(VS_SELECT_MAZE_ZONE.position.x + VS_SELECT_MAZE_ZONE.size.x, VS_SELECT_MAZE_ZONE.position.y),
		Vector2(VS_SELECT_MAZE_ZONE.position.x + VS_SELECT_MAZE_ZONE.size.x, VS_SELECT_MAZE_ZONE.position.y + VS_SELECT_MAZE_ZONE.size.y),
		Vector2(VS_SELECT_MAZE_ZONE.position.x, VS_SELECT_MAZE_ZONE.position.y + VS_SELECT_MAZE_ZONE.size.y)
	])
	maze_select_bg.color = Color(0.3, 0.3, 0.3, 0.5)
	route_root.add_child(maze_select_bg)

	var maze_label := Label.new()
	maze_label.position = Vector2(VS_SELECT_MAZE_ZONE.position.x, VS_SELECT_MAZE_ZONE.position.y + 20)
	maze_label.size = Vector2(VS_SELECT_MAZE_ZONE.size.x, 20)
	maze_label.text = "Maze"
	maze_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	maze_label.add_theme_font_size_override("font_size", 12)
	maze_label.add_theme_color_override("font_outline_color", Color.BLACK)
	maze_label.add_theme_constant_override("outline_size", 4)
	route_root.add_child(maze_label)
	
	var tunnel_sprite := Sprite2D.new()
	tunnel_sprite.texture = preload("res://assets/sprites/characters/dwarf/dwarf_walk_highres_spritesheet.png")
	tunnel_sprite.hframes = 8
	tunnel_sprite.vframes = 8
	tunnel_sprite.scale = Vector2(0.5, 0.5)
	tunnel_sprite.position = Vector2(VS_SELECT_TUNNEL_ZONE.position.x + 30, VS_SELECT_TUNNEL_ZONE.position.y + VS_SELECT_TUNNEL_ZONE.size.y + 12)
	route_root.add_child(tunnel_sprite)

	var maze_sprite := Sprite2D.new()
	maze_sprite.texture = preload("res://character_sprites/peon_walk_spritesheet_25d.png")
	maze_sprite.hframes = 8
	maze_sprite.vframes = 8
	maze_sprite.scale = Vector2(0.5, 0.5)
	maze_sprite.position = Vector2(VS_SELECT_MAZE_ZONE.position.x + 30, VS_SELECT_MAZE_ZONE.position.y + VS_SELECT_MAZE_ZONE.size.y + 12)
	route_root.add_child(maze_sprite)

func _create_hub_hud() -> void:
	hub_hud = HUB_HUD_SCENE.instantiate() as CanvasLayer
	add_child(hub_hud)
	var title := hub_hud.get_node("TopPanel/Margin/VBox/Title") as Label
	var subtitle := hub_hud.get_node("TopPanel/Margin/VBox/Subtitle") as Label
	status_label = hub_hud.get_node("StatusPanel/Margin/Status") as Label
	title.text = ""
	subtitle.text = ""
	var top_panel = hub_hud.get_node_or_null("TopPanel")
	if top_panel:
		top_panel.visible = false

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
	_status_hold = maxf(_status_hold - delta, 0.0)
	_update_shared_camera(delta)
	_update_base_popups()
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
	var p1_coop := COOP_READY_ZONE.has_point(player_one.global_position)
	var p2_coop := COOP_READY_ZONE.has_point(player_two.global_position)
	var p1_vs := VS_READY_ZONE.has_point(player_one.global_position)
	var p2_vs := VS_READY_ZONE.has_point(player_two.global_position)

	var p1_pos = player_one.global_position
	var p2_pos = player_two.global_position
	if VS_SELECT_TUNNEL_ZONE.has_point(p1_pos) or VS_SELECT_TUNNEL_ZONE.has_point(p2_pos):
		if _selected_vs_mode != 0:
			_selected_vs_mode = 0
			_update_vs_selection_visuals()
	elif VS_SELECT_MAZE_ZONE.has_point(p1_pos) or VS_SELECT_MAZE_ZONE.has_point(p2_pos):
		if _selected_vs_mode != 1:
			_selected_vs_mode = 1
			_update_vs_selection_visuals()

	if p1_coop and p2_coop:
		_process_countdown(delta, "CO-OP MINE", _start_coop_mine)
		return
	elif p1_vs and p2_vs:
		var mode_str = "VS MODE (TUNNEL)" if _selected_vs_mode == 0 else "VS MODE (MAZE)"
		_process_countdown(delta, mode_str, _start_vs_mode)
		return

	_countdown_remaining = 0.0

	# A fresh stronghold confirmation stays readable for a moment instead of
	# being wiped by the idle status on the very next frame.
	if _status_hold > 0.0:
		return

	if p1_coop or p1_vs:
		_set_status("P1 READY  •  Waiting for Player 2")
	elif p2_coop or p2_vs:
		_set_status("P2 READY  •  Waiting for Player 1")
	else:
		_set_status("")

func _process_countdown(delta: float, mode_name: String, callback: Callable) -> void:
	if _countdown_remaining <= 0.0:
		_countdown_remaining = READY_COUNTDOWN
	_countdown_remaining -= delta
	_set_status("%s  •  BOTH READY  •  Starting in %.1f" % [mode_name, maxf(_countdown_remaining, 0.0)])
	if _countdown_remaining <= 0.0:
		callback.call()

func _start_coop_mine() -> void:
	if _committing:
		return
	_committing = true
	Global.current_hero = Global.hero_p1
	Global.save_game()
	world.remove_meta("local_multiplayer_hub_active")
	GameMode.set_mode(GameMode.Mode.EXPLORATION)
	get_tree().change_scene_to_file(LOCAL_COOP_SCENE)

func _update_vs_selection_visuals() -> void:
	if _selected_vs_mode == 0:
		tunnel_select_bg.color = Color(1.0, 0.5, 0.2, 0.8)
		maze_select_bg.color = Color(0.3, 0.3, 0.3, 0.5)
		if vs_mode_label:
			vs_mode_label.text = "VS MODE"
	else:
		tunnel_select_bg.color = Color(0.3, 0.3, 0.3, 0.5)
		maze_select_bg.color = Color(1.0, 0.5, 0.2, 0.8)
		if vs_mode_label:
			vs_mode_label.text = "MAZE MODE"

func _start_vs_mode() -> void:
	if _committing:
		return
	_committing = true
	Global.current_hero = Global.hero_p1
	Global.save_game()
	world.remove_meta("local_multiplayer_hub_active")
	if _selected_vs_mode == 0:
		GameMode.set_mode(GameMode.Mode.EXPLORATION_VS)
		get_tree().change_scene_to_file("res://vs_mode.tscn")
	else:
		GameMode.set_mode(GameMode.Mode.LINE_WARS)
		get_tree().change_scene_to_file("res://vs_mode.tscn")

func _update_hud_heroes() -> void:
	pass

func _set_status(message: String) -> void:
	if message == _last_status:
		return
	_last_status = message
	if status_label:
		status_label.text = message
		var panel = status_label.get_parent().get_parent()
		if panel is Control:
			panel.visible = not message.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if _committing:
		return
	for player_id in [1, 2]:
		var action_name := "p%d_interact" % player_id
		if InputMap.has_action(action_name) and event.is_action_pressed(action_name) and _player_at_own_base(player_id):
			# Keyboard and gamepad get the same switch without touching the arrows.
			var popup: Node2D = base_popups.get(player_id)
			if popup != null and is_instance_valid(popup):
				popup.call("cycle_next")
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
