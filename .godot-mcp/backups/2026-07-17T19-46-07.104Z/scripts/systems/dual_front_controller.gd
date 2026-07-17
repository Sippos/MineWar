extends Node

const BUILDER_PEON_SCENE := preload("res://scenes/entities/workers/peon/builder_peon_player.tscn")
const SURFACE_MAZE_SCENE := preload("res://scenes/world/preparation/surface_delay_maze_world.tscn")
const DUAL_FRONT_HUD_SCENE := preload("res://scenes/ui/overlays/dual_front_hud.tscn")
const ENEMY_SCENE := preload("res://enemy.tscn")

const FIRST_INVASION_DELAY := 24.0
const INVASION_INTERVAL := 42.0
const PORTAL_CHARGE_DURATION := 8.0
const HERO_MINE_START := Vector2(0, 96)

enum Front { PEON, HERO }

@export var world_path: NodePath = NodePath("../Level")

var world: Node2D
var hero: CharacterBody2D
var base: Node2D
var builder_peon: CharacterBody2D
var surface_maze: Node2D
var dual_front_hud: CanvasLayer

var mode_label: Label
var threat_label: Label
var portal_label: Label
var status_label: Label
var switch_button: Button
var reset_button: Button

var run_started := false
var active_front: Front = Front.PEON
var invasion_number := 1
var invasion_timer := FIRST_INVASION_DELAY
var portal_queue: Array[String] = []
var portal_charge_remaining := 0.0
var first_maze_arrival := -1.0
var last_surface_status := "Walk around the preparation overworld as the builder peon."

func _ready() -> void:
	process_priority = -100
	call_deferred("_setup")

func _setup() -> void:
	world = get_node_or_null(world_path) as Node2D
	if world == null:
		push_error("Dual front controller could not find the mine world")
		return
	hero = world.get_node_or_null("Player") as CharacterBody2D
	base = world.get_node_or_null("Base") as Node2D
	if hero == null or base == null:
		push_error("Dual front controller requires the normal Player and Base nodes")
		return

	_ensure_switch_action()
	# The existing world process owns the previous random-wave timer. Mining,
	# combat, pickups, abilities, and the base are separate nodes and continue
	# running while this controller owns the new maze/portal invasion rhythm.
	world.set_process(false)
	world.set_meta("dual_front_active", true)
	base.z_index = maxi(base.z_index, 12)

	builder_peon = BUILDER_PEON_SCENE.instantiate() as CharacterBody2D
	builder_peon.name = "BuilderPeon"
	builder_peon.position = hero.position
	world.add_child(builder_peon)

	surface_maze = SURFACE_MAZE_SCENE.instantiate() as Node2D
	surface_maze.name = "SurfaceDelayMaze"
	surface_maze.visible = false
	world.add_child(surface_maze)
	surface_maze.call("set_builder_peon", builder_peon)
	surface_maze.connect("enemy_reached_portal", _on_enemy_reached_portal)
	surface_maze.connect("route_changed", _on_route_changed)
	surface_maze.connect("builder_status_changed", _on_builder_status_changed)

	dual_front_hud = DUAL_FRONT_HUD_SCENE.instantiate() as CanvasLayer
	add_child(dual_front_hud)
	mode_label = dual_front_hud.get_node("TopBar/Margin/Row/ModeLabel") as Label
	threat_label = dual_front_hud.get_node("TopBar/Margin/Row/ThreatLabel") as Label
	portal_label = dual_front_hud.get_node("TopBar/Margin/Row/PortalLabel") as Label
	reset_button = dual_front_hud.get_node("TopBar/Margin/Row/ResetMazeButton") as Button
	switch_button = dual_front_hud.get_node("TopBar/Margin/Row/SwitchButton") as Button
	status_label = dual_front_hud.get_node("StatusPanel/Margin/StatusLabel") as Label
	# Pointer input is handled in _input before the large legacy HUD can consume
	# it. The controls remain normal visual buttons, while Tab/RB also switch.
	switch_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dual_front_hud.visible = false

	_set_hero_preparation_state()
	builder_peon.call("set_controlled", true)

func _input(event: InputEvent) -> void:
	if not run_started or dual_front_hud == null or not dual_front_hud.visible:
		return
	var click_position := Vector2(-10000, -10000)
	var is_pressed := false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		is_pressed = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
		click_position = mouse_event.position
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		is_pressed = touch_event.pressed
		click_position = touch_event.position
	if not is_pressed:
		return
	if switch_button.get_global_rect().has_point(click_position):
		_toggle_front()
		get_viewport().set_input_as_handled()
	elif reset_button.visible and reset_button.get_global_rect().has_point(click_position):
		_on_reset_maze_pressed()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if world == null or hero == null or builder_peon == null:
		return

	if not run_started:
		# The mature preparation controller still handles hero/base selection.
		# Mirroring the hidden hero lets that system use the visible peon's position.
		hero.position = builder_peon.position
		hero.velocity = Vector2.ZERO
		if not bool(world.get("preparation_active")):
			_begin_dual_front_run()
		return

	if Input.is_action_just_pressed("switch_front"):
		_toggle_front()
	_process_invasions(delta)
	_process_portal_queue(delta)
	_update_interface()

func _set_hero_preparation_state() -> void:
	hero.visible = false
	hero.velocity = Vector2.ZERO
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	var hero_camera := hero.get_node_or_null("Camera2D") as Camera2D
	if hero_camera:
		hero_camera.enabled = false

func _begin_dual_front_run() -> void:
	run_started = true
	hero.position = HERO_MINE_START
	hero.velocity = Vector2.ZERO
	hero.visible = true
	surface_maze.visible = true
	dual_front_hud.visible = true
	active_front = Front.PEON
	_apply_front_control()
	last_surface_status = "Run started as the peon. Build now, or switch to the hero and dig immediately."
	var existing_hud := world.get_node_or_null("HUD")
	if existing_hud and existing_hud.has_method("show_notice"):
		existing_hud.show_notice("Peon controls the surface. Switch to the hero whenever you want to mine.", 4.5)
	_update_interface()

func _toggle_front() -> void:
	if not run_started:
		return
	active_front = Front.HERO if active_front == Front.PEON else Front.PEON
	_apply_front_control()
	_update_interface()

func _apply_front_control() -> void:
	var peon_is_active := active_front == Front.PEON
	builder_peon.call("set_controlled", peon_is_active)
	surface_maze.call("set_builder_active", peon_is_active)

	hero.process_mode = Node.PROCESS_MODE_DISABLED if peon_is_active else Node.PROCESS_MODE_INHERIT
	hero.velocity = Vector2.ZERO
	var hero_camera := hero.get_node_or_null("Camera2D") as Camera2D
	if hero_camera:
		hero_camera.enabled = not peon_is_active

func _process_invasions(delta: float) -> void:
	invasion_timer -= delta
	if invasion_timer > 0.0:
		return
	var roster := _build_invasion_roster(invasion_number)
	surface_maze.call("spawn_invasion", roster)
	surface_maze.call("set_round", invasion_number)
	last_surface_status = "Invasion %d entered the maze. Its route now determines your mining time." % invasion_number
	invasion_number += 1
	invasion_timer = INVASION_INTERVAL

func _build_invasion_roster(round_number: int) -> Array[String]:
	var roster: Array[String] = []
	var enemy_count := mini(2 + round_number, 8)
	for index in enemy_count:
		var enemy_type := "Rat"
		if round_number >= 2 and index % 3 == 2:
			enemy_type = "Spider"
		if round_number >= 3 and index == enemy_count - 1:
			enemy_type = "Orc"
		roster.append(enemy_type)
	return roster

func _on_enemy_reached_portal(enemy_type: String) -> void:
	portal_queue.append(enemy_type)
	if portal_queue.size() == 1:
		portal_charge_remaining = PORTAL_CHARGE_DURATION
	last_surface_status = "%s reached the breach portal. The hero has a final warning window." % enemy_type

func _process_portal_queue(delta: float) -> void:
	if portal_queue.is_empty():
		portal_charge_remaining = 0.0
		return
	portal_charge_remaining = maxf(portal_charge_remaining - delta, 0.0)
	if portal_charge_remaining <= 0.0:
		_release_portal_queue()

func _release_portal_queue() -> void:
	var released: Array[String] = portal_queue.duplicate()
	portal_queue.clear()
	portal_charge_remaining = 0.0
	for index in released.size():
		_spawn_arena_enemy(released[index], index, released.size())
	last_surface_status = "%d invader%s breached into the base arena." % [released.size(), "" if released.size() == 1 else "s"]
	var existing_hud := world.get_node_or_null("HUD")
	if existing_hud and existing_hud.has_method("show_notice"):
		existing_hud.show_notice("BREACH! %d enemies emerged beside the base." % released.size(), 3.2)

func _spawn_arena_enemy(enemy_type: String, index: int, released_count: int) -> void:
	var enemy := ENEMY_SCENE.instantiate()
	world.add_child(enemy)
	var angle := TAU * float(index) / float(maxi(released_count, 4))
	var offset := Vector2(cos(angle) * 118.0, sin(angle) * 52.0 - 34.0)
	enemy.global_position = base.global_position + offset
	if enemy.has_method("initialize"):
		enemy.initialize(maxi(invasion_number - 1, 1), false, _enemy_type_id(enemy_type))
	if enemy.has_method("begin_breach_emergence"):
		enemy.begin_breach_emergence(0.65)

func _enemy_type_id(enemy_type: String) -> int:
	match enemy_type:
		"Spider":
			return 1
		"Orc":
			return 4
		_:
			return 0

func _on_route_changed(estimated_seconds: float) -> void:
	first_maze_arrival = estimated_seconds

func _on_builder_status_changed(message: String) -> void:
	last_surface_status = message

func _on_reset_maze_pressed() -> void:
	if active_front == Front.PEON:
		surface_maze.call("reset_maze")

func _update_interface() -> void:
	if dual_front_hud == null or not dual_front_hud.visible:
		return
	var peon_is_active := active_front == Front.PEON
	mode_label.text = "PEON • SURFACE" if peon_is_active else "HERO • MINE"
	switch_button.text = "SWITCH TO HERO" if peon_is_active else "SWITCH TO PEON"
	reset_button.visible = peon_is_active
	reset_button.disabled = not peon_is_active or int(surface_maze.call("get_enemy_count")) > 0

	var enemies_in_maze := int(surface_maze.call("get_enemy_count"))
	if enemies_in_maze > 0:
		var eta_text := "calculating" if first_maze_arrival < 0.0 else "%ds" % int(ceil(first_maze_arrival))
		threat_label.text = "Invasion %d • %d in maze • first portal arrival %s" % [maxi(invasion_number - 1, 1), enemies_in_maze, eta_text]
	else:
		threat_label.text = "Next invasion in %ds" % int(ceil(maxf(invasion_timer, 0.0)))

	if portal_queue.is_empty():
		portal_label.text = "Portal clear"
	else:
		portal_label.text = "%d queued • opens in %ds" % [portal_queue.size(), int(ceil(portal_charge_remaining))]

	if peon_is_active:
		status_label.text = "%s  •  %s" % [str(surface_maze.call("get_stats_text")), last_surface_status]
	else:
		status_label.text = "Mine freely. Return toward the base before the breach portal opens.  •  %s" % last_surface_status

func _ensure_switch_action() -> void:
	if InputMap.has_action("switch_front"):
		return
	InputMap.add_action("switch_front")
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_TAB
	InputMap.action_add_event("switch_front", key_event)
	var joy_event := InputEventJoypadButton.new()
	joy_event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	InputMap.action_add_event("switch_front", joy_event)
