extends Node

signal vs_opening_ready(side_label: String)
signal vs_run_finished(side_label: String, victory: bool, base_health: int)

const BUILDER_PEON_SCENE := preload("res://scenes/entities/workers/peon/builder_peon_player.tscn")
const WAR_MACHINE_CONTROLLER := preload("res://scripts/systems/linewars_war_machine_controller.gd")
const HUD_SCENE := preload("res://scenes/ui/overlays/continuous_line_wars_hud.tscn")
const ENEMY_SCENE := preload("res://enemy.tscn")

# The upper LineWars field is a macro layer. The hero remains active in the mine
# while a single click commissions a complete peon tunnel or radar job.
const SURFACE_MIN_CELL := Vector2i(-10, -33)
const SURFACE_MAX_CELL := Vector2i(10, -7)
const SEARCH_MIN_CELL := Vector2i(-10, -33)
const SEARCH_MAX_CELL := Vector2i(10, -7)
const BASE_TARGET_CELL := Vector2i(0, -1)
const MINE_ENTRY_CELL := Vector2i(0, 8)
const MINE_HERO_START_CELL := Vector2i(0, 8)
const FIRST_INVASION_DELAY := 28.0
const MINIMUM_OPENING_ROUTE_LENGTH := 6
const OPENING_REQUIRED_NEW_TILES := MINIMUM_OPENING_ROUTE_LENGTH - 1
const INVASION_INTERVAL := 24.0
const TELEGRAPH_DURATION := 2.2
const RADAR_WARNING_PER_DEVICE := 1.5
const RADAR_GOLD_COST := 10
const MAX_RADARS := 3
const RADAR_DETECTION_RADIUS := 250.0
const FINAL_WAVE := 10
const FIRST_WAVE_WARNING_TIME := 10.0
const INVALID_CELL := Vector2i(99999, 99999)
const COMBAT_FEEDBACK = preload("res://combat_feedback.gd")
const TOUCH_SNAP_RADIUS := 2
const OPENING_CAMERA_ZOOM := Vector2(1.35, 1.35)
const DESKTOP_COMMAND_CAMERA_ZOOM := Vector2(0.95, 0.95)
const TOUCH_COMMAND_CAMERA_ZOOM := Vector2(0.78, 0.78)
const ESTIMATED_TUNNEL_TILE_SECONDS := 0.85
const GATE_ERUPTION_RADIUS := 92.0
const GATE_ERUPTION_DAMAGE := 4
const GATE_ERUPTION_KNOCKBACK := 72.0
const GATE_ERUPTION_COOLDOWN_MSEC := 650
const LINEWARS_LEAK_DAMAGE := [0, 18, 20, 22, 24, 27, 30, 34, 40, 48, 100]
const CARDINAL_DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var breakthrough_position := Vector2.ZERO
var world: Node2D
var block_layer: TileMapLayer
var opening_overlay_layer: TileMapLayer
var opening_front_overlay_layer: TileMapLayer
var opening_front_wall_layer: TileMapLayer
var hero: CharacterBody2D
var peon: CharacterBody2D
var base: Node2D
var world_hud: CanvasLayer
var hud: CanvasLayer
var mode_label: Label
var hint_label: Label
var threat_label: Label
var switch_button: Button
var radar_button: Button
var opening_progress: ProgressBar
var alert_banner: PanelContainer
var alert_label: Label
var breach_flash: ColorRect
var touch_action_panel: PanelContainer
var touch_confirm_button: Button
var touch_cancel_button: Button
var command_cursor: Node2D
var command_preview_line: Line2D
var order_marker: Node2D
var order_line: Line2D
var war_machine_controller: Node

var opening_build_active := true
var command_view_active := false
var command_mode := "DIG"
var command_message := ""
var tunnel_exit_cell := Vector2i(0, -7)
var radar_cells: Array[Vector2i] = []
var radar_nodes: Dictionary = {}
var portal_nodes: Dictionary = {}

var invasion_timer := FIRST_INVASION_DELAY
var next_wave := 1
var current_wave := 0
var completed_wave := 0
var spawning := false
var wave_in_progress := false
var run_finished := false
var last_spawn_cell := Vector2i.ZERO
var current_telegraph_duration := TELEGRAPH_DURATION
var alert_timer := 0.0
var opening_topology_start := 0
var opening_dig_count := 0
var opening_overlay_cells: Array[Vector2i] = []
var first_wave_warning_shown := false
var touch_command_mode := false
var touch_selected_cell := INVALID_CELL
var command_preview_cell := INVALID_CELL
var active_order_target := INVALID_CELL
var active_order_route_before := 1
var last_breach_feedback_msec := -10000
var last_gate_eruption_msec := -10000
var vs_match_gate_enabled := false
var vs_match_started := true
var vs_side_label := "SIDE"

func _ready() -> void:
	world = get_parent() as Node2D
	if world:
		block_layer = world.get_node_or_null("BlockLayer") as TileMapLayer
		opening_overlay_layer = world.get_node_or_null("DamageLayer") as TileMapLayer
		opening_front_overlay_layer = world.get_node_or_null("FrontDamageLayer") as TileMapLayer
		opening_front_wall_layer = world.get_node_or_null("FrontWallLayer") as TileMapLayer
		hero = world.get_node_or_null("Player") as CharacterBody2D
		base = world.get_node_or_null("Base") as Node2D
		world_hud = world.get_node_or_null("HUD") as CanvasLayer
	if world == null or block_layer == null or opening_overlay_layer == null or hero == null or base == null:
		push_error("Continuous LineWars requires the persistent mine world")
		queue_free()
		return

	touch_command_mode = DisplayServer.is_touchscreen_available() or bool(world.get_meta("force_touch_commands", false))
	world.set_meta("continuous_line_wars_active", true)
	_ensure_switch_action()
	_resolve_layer_portals()
	_spawn_peon()
	_build_portal_markers()
	_build_hud()
	_build_command_visuals()
	_build_war_machine()
	opening_topology_start = _world_topology_revision()
	opening_dig_count = 0
	_update_opening_route_marker(opening_dig_count)
	_apply_control()
	command_message = "Dig the marked dirt blocks to shape the opening tunnel. The overlay follows the peon; waves stay paused until 5/5."
	_update_interface()

func _resolve_layer_portals() -> void:
	var breakthrough_cell := block_layer.local_to_map(block_layer.to_local(breakthrough_position))
	tunnel_exit_cell = Vector2i(clampi(breakthrough_cell.x, -1, 1), -7)
	_ensure_cell_open(tunnel_exit_cell)
	for y in range(BASE_TARGET_CELL.y + 1, MINE_ENTRY_CELL.y + 1):
		_ensure_cell_open(Vector2i(MINE_ENTRY_CELL.x, y))
	hero.global_position = _cell_world_position(MINE_HERO_START_CELL)
	hero.velocity = Vector2.ZERO

func _ensure_cell_open(cell: Vector2i) -> void:
	if block_layer.get_cell_source_id(cell) == -1:
		return
	if world.has_method("on_cell_dug"):
		world.call("on_cell_dug", cell)

func _spawn_peon() -> void:
	peon = BUILDER_PEON_SCENE.instantiate() as CharacterBody2D
	peon.name = "BuilderPeon"
	world.add_child(peon)
	peon.global_position = _cell_world_position(tunnel_exit_cell)
	peon.set("movement_bounds", _surface_movement_bounds())
	peon.call("configure_world_digging", world, SURFACE_MIN_CELL, SURFACE_MAX_CELL)
	peon.call("set_controlled", false)
	peon.call("set_command_camera_enabled", false)
	if peon.has_signal("work_order_finished"):
		peon.work_order_finished.connect(_on_peon_work_order_finished)
	if peon.has_signal("work_order_failed"):
		peon.work_order_failed.connect(_on_peon_work_order_failed)

func _build_hud() -> void:
	hud = HUD_SCENE.instantiate() as CanvasLayer
	add_child(hud)
	mode_label = hud.get_node("TopBar/Margin/Row/Mode") as Label
	switch_button = hud.get_node("TopBar/Margin/Row/Switch") as Button
	radar_button = hud.get_node("TopBar/Margin/Row/Radar") as Button
	threat_label = hud.get_node("TopBar/Margin/Row/Threat") as Label
	hint_label = hud.get_node("HintPanel/Margin/Hint") as Label
	opening_progress = hud.get_node("OpeningProgress") as ProgressBar
	alert_banner = hud.get_node("AlertBanner") as PanelContainer
	alert_label = hud.get_node("AlertBanner/Margin/Alert") as Label
	breach_flash = ColorRect.new()
	breach_flash.name = "BreachFlash"
	breach_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	breach_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breach_flash.color = Color(0.16, 0.58, 1.0, 0.0)
	hud.add_child(breach_flash)
	hud.move_child(breach_flash, 0)
	_build_touch_command_panel()
	switch_button.pressed.connect(_toggle_front)
	radar_button.pressed.connect(_begin_radar_command)

func _build_war_machine() -> void:
	war_machine_controller = WAR_MACHINE_CONTROLLER.new()
	war_machine_controller.name = "WarMachineController"
	add_child(war_machine_controller)
	war_machine_controller.call("setup", world, hero, world_hud)

func _process(delta: float) -> void:
	if alert_timer > 0.0:
		alert_timer = maxf(alert_timer - delta, 0.0)
		if alert_banner:
			alert_banner.visible = alert_timer > 0.0

	_animate_world_markers(delta)
	_update_order_visual()

	if Input.is_action_just_pressed("switch_front"):
		_toggle_front()

	if run_finished:
		return
	var base_health: Variant = base.get("health") if base else null
	if base_health != null and int(base_health) <= 0:
		_finish_run(false)
		return

	_process_layer_transfers()
	if not opening_build_active and next_wave == 1 and not wave_in_progress and not spawning and not first_wave_warning_shown and invasion_timer <= FIRST_WAVE_WARNING_TIME:
		first_wave_warning_shown = true
		_show_alert("FIRST WAVE IN 10\nRETURN TO THE BLUE GATE", 1.8)
		_play_sound("play_error")
	if opening_build_active:
		var newly_dug_tiles := _opening_new_tiles_dug()
		if newly_dug_tiles != opening_dig_count:
			opening_dig_count = newly_dug_tiles
		_update_opening_route_marker(opening_dig_count)
		if opening_dig_count >= OPENING_REQUIRED_NEW_TILES:
			_complete_opening_build()
		_update_interface()
		return
	if vs_match_gate_enabled and not vs_match_started:
		_update_interface()
		return
	if wave_in_progress:
		if not spawning and _count_world_enemies() == 0:
			wave_in_progress = false
			if completed_wave >= FINAL_WAVE:
				_finish_run(true)
				return
			invasion_timer = INVASION_INTERVAL
	else:
		invasion_timer = maxf(invasion_timer - delta, 0.0)
		if invasion_timer <= 0.0 and next_wave <= FINAL_WAVE:
			_begin_invasion(next_wave)

	_update_interface()

func _unhandled_input(event: InputEvent) -> void:
	if run_finished:
		return
	if opening_build_active and touch_command_mode:
		if _handle_touch_opening_input(event):
			get_viewport().set_input_as_handled()
		return
	if not command_view_active:
		return
	if event is InputEventMouseMotion:
		if not touch_command_mode:
			_update_command_preview(_snap_command_cell(_viewport_to_command_cell(event.position)))
		return
	if event is InputEventScreenDrag:
		_select_touch_command_cell(_snap_command_cell(_viewport_to_command_cell(event.position)))
		get_viewport().set_input_as_handled()
		return
	var pressed_position := Vector2.ZERO
	var is_command_click := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed_position = event.position
		is_command_click = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed_position = event.position
		is_command_click = true
	if not is_command_click:
		return

	var target_cell := _snap_command_cell(_viewport_to_command_cell(pressed_position))
	if touch_command_mode:
		_select_touch_command_cell(target_cell)
	else:
		_update_command_preview(target_cell)
		_issue_command(target_cell)
	get_viewport().set_input_as_handled()

func _issue_command(target_cell: Vector2i) -> void:
	if not _is_surface_cell(target_cell):
		command_message = "Choose a tile inside the upper LineWars field."
		_update_interface()
		return
	if bool(peon.call("is_order_active")):
		command_message = "The peon is already working. Return to the hero and let the order finish."
		_update_interface()
		return

	if command_mode == "RADAR":
		_issue_radar_order(target_cell)
		return

	if block_layer.get_cell_source_id(target_cell) == -1:
		command_message = "Tunnel orders need a dirt destination. Use Radar for an open tile."
		_update_interface()
		return
	active_order_route_before = _tunnel_route_length()
	if bool(peon.call("issue_dig_order", target_cell)):
		command_message = "Tunnel commissioned to %s. Hero control restored while the peon digs." % _format_cell(target_cell)
		_show_order_visual(target_cell, "DIG")
		_play_sound("play_purchase")
		_exit_command_view()

func _issue_radar_order(target_cell: Vector2i) -> void:
	if radar_cells.size() >= MAX_RADARS:
		command_message = "All %d radar slots are already installed." % MAX_RADARS
		_update_interface()
		return
	if block_layer.get_cell_source_id(target_cell) != -1:
		command_message = "Radar must be installed inside an open tunnel."
		_update_interface()
		return
	if radar_cells.has(target_cell):
		command_message = "A radar already covers that tunnel tile."
		_update_interface()
		return
	if _available_gold() < RADAR_GOLD_COST:
		command_message = "Bank %d gold at the base before commissioning another radar." % RADAR_GOLD_COST
		_update_interface()
		return
	if bool(peon.call("issue_build_order", target_cell, "RADAR")):
		_spend_gold(RADAR_GOLD_COST)
		command_message = "Radar commissioned at %s. The peon will install it while you defend below." % _format_cell(target_cell)
		_show_order_visual(target_cell, "RADAR")
		_play_sound("play_purchase")
		_exit_command_view()

func _begin_invasion(wave_number: int) -> void:
	if spawning or wave_in_progress or run_finished:
		return
	spawning = true
	wave_in_progress = true
	current_wave = wave_number
	last_spawn_cell = _find_farthest_tunnel_cell()
	var spawn_position := _cell_world_position(last_spawn_cell)
	var is_boss := wave_number == FINAL_WAVE
	current_telegraph_duration = TELEGRAPH_DURATION + float(mini(radar_cells.size(), 2)) * RADAR_WARNING_PER_DEVICE
	_move_portal_marker("EnemyPortal", last_spawn_cell)
	if world.has_method("_spawn_wave_telegraph"):
		world.call("_spawn_wave_telegraph", spawn_position, is_boss)
	if wave_number == 1:
		_show_alert("ENEMY PORTAL OPENING\nUPPER TUNNEL", 1.6)
		_play_sound("play_error")
	command_message = "Enemy portal locked at %s. Survivors will transfer through the orange gate into the blue mine gate." % _format_cell(last_spawn_cell)
	_update_interface()

	await get_tree().create_timer(current_telegraph_duration).timeout
	if not is_instance_valid(self) or run_finished:
		return

	var spawn_count := 1 if is_boss else mini(1 + int((wave_number - 1) / 2), 6)
	for index in range(spawn_count):
		_spawn_enemy_at_endpoint(wave_number, is_boss, index, spawn_count, spawn_position)
		await get_tree().create_timer(0.28).timeout

	completed_wave = wave_number
	next_wave = wave_number + 1
	spawning = false
	_update_interface()

func _spawn_enemy_at_endpoint(wave_number: int, is_boss: bool, index: int, count: int, spawn_position: Vector2, forced_enemy_type: int = -1) -> void:
	var enemy := ENEMY_SCENE.instantiate() as CharacterBody2D
	if enemy == null:
		return
	enemy.set("target_base_cell", tunnel_exit_cell)
	enemy.set_meta("linewars_layer", "tunnel")
	enemy.set_meta("linewars_wave", wave_number)
	var angle := TAU * float(index) / float(maxi(count, 1))
	var offset := Vector2(cos(angle), sin(angle)) * (8.0 if count > 1 else 0.0)
	enemy.position = world.to_local(spawn_position + offset)
	world.add_child(enemy)
	if enemy.has_method("initialize"):
		var enemy_type: int = forced_enemy_type if forced_enemy_type >= 0 else (0 if wave_number == 1 else int(world.call("get_random_enemy_type", wave_number)))
		enemy.call("initialize", wave_number, is_boss, enemy_type)
	enemy.set_meta("linewars_single_leak", true)
	enemy.set_meta("linewars_leak_damage", _linewars_leak_damage(wave_number, is_boss))
	if enemy.has_method("begin_breach_emergence"):
		enemy.call("begin_breach_emergence", 0.65 if not is_boss else 0.9)

func configure_vs_match(side_label: String) -> void:
	vs_match_gate_enabled = true
	vs_match_started = false
	vs_side_label = side_label
	world.set_meta("linewars_vs_mirror_active", true)
	command_message = "Build the five-tile opening route. Your side becomes READY when it is complete."
	_update_interface()

func start_vs_match() -> void:
	if not vs_match_gate_enabled or opening_build_active or run_finished:
		return
	vs_match_started = true
	invasion_timer = FIRST_INVASION_DELAY
	first_wave_warning_shown = false
	command_message = "VS MATCH LIVE. Mine, defend, and use the War Machine to pressure the opponent."
	_show_alert("BOTH SIDES READY\nVS MATCH LIVE", 2.2)
	_update_interface()

func receive_vs_send(send_data: Dictionary, sender_label: String) -> void:
	if run_finished or not vs_match_started or opening_build_active:
		return
	var incoming := send_data.duplicate(true)
	incoming["sender"] = sender_label
	var label := str(incoming.get("label", "ENEMY SEND"))
	_show_alert("%s SENT %s\nENEMIES ENTERED YOUR TUNNEL" % [sender_label, label], 2.0)
	_play_sound("play_error")
	_spawn_vs_payload(incoming)
	_update_interface()

func get_vs_state() -> Dictionary:
	return {
		"side": vs_side_label,
		"ready": not opening_build_active,
		"started": vs_match_started,
		"finished": run_finished,
		"base_health": int(base.get("health")) if base else 0,
		"enemy_pressure": _count_world_enemies(),
		"wave": current_wave
	}

func _spawn_vs_payload(payload: Dictionary) -> void:
	last_spawn_cell = _find_farthest_tunnel_cell()
	var spawn_position := _cell_world_position(last_spawn_cell)
	_move_portal_marker("EnemyPortal", last_spawn_cell)
	if world.has_method("_spawn_wave_telegraph"):
		world.call("_spawn_wave_telegraph", spawn_position, false)
	var count := maxi(1, int(payload.get("count", 1)))
	var enemy_type := _vs_enemy_type_id(str(payload.get("enemy_type", "RAT")))
	var scaling_wave := maxi(1, current_wave if current_wave > 0 else next_wave)
	for index in range(count):
		_spawn_enemy_at_endpoint(scaling_wave, false, index, count, spawn_position, enemy_type)
	var sender := str(payload.get("sender", "OPPONENT"))
	var label := str(payload.get("label", "Enemy pressure"))
	command_message = "%s sent %s directly to your farthest tunnel endpoint." % [sender, label]

func _vs_enemy_type_id(enemy_type_name: String) -> int:
	match enemy_type_name.to_upper():
		"SPIDER":
			return 1
		"BAT":
			return 2
		"TROGG":
			return 3
		"ORC":
			return 4
		_:
			return 0

func _process_layer_transfers() -> void:
	var exit_position := _cell_world_position(tunnel_exit_cell)
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as CharacterBody2D
		if enemy == null or not is_instance_valid(enemy) or not world.is_ancestor_of(enemy):
			continue
		if str(enemy.get_meta("linewars_layer", "")) != "tunnel":
			continue
		if enemy.global_position.distance_to(exit_position) <= 46.0:
			_transfer_enemy_to_mine(enemy)

func _transfer_enemy_to_mine(enemy: CharacterBody2D) -> void:
	if not is_instance_valid(enemy):
		return
	# Command view is intentionally brief, but a real mine breach always takes
	# priority. Return the camera and controls to the hero before the invader
	# emerges so touch players are never trapped upstairs during an emergency.
	if command_view_active:
		_exit_command_view()
	var source_position := enemy.global_position
	var mine_position := _cell_world_position(MINE_ENTRY_CELL)
	_spawn_portal_transfer_effect(source_position, Color(1.0, 0.48, 0.12, 1.0), "TRANSFER")
	var offset := Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0))
	enemy.global_position = mine_position + offset
	_spawn_portal_transfer_effect(mine_position, Color(0.18, 0.7, 1.0, 1.0), "MINE BREACH")
	_trigger_gate_eruption()
	enemy.set("target_base_cell", BASE_TARGET_CELL)
	enemy.set_meta("linewars_layer", "mine")
	if enemy.has_method("recalculate_path"):
		enemy.call("recalculate_path")
	if enemy.has_method("begin_breach_emergence"):
		enemy.call("begin_breach_emergence", 0.55)
	command_message = "BREACH: an invader transferred into the mine. Intercept it before it reaches the base."
	_play_breach_feedback()

func _linewars_leak_damage(wave_number: int, is_boss: bool) -> int:
	if is_boss:
		return 100
	var index := clampi(wave_number, 1, LINEWARS_LEAK_DAMAGE.size() - 1)
	return int(LINEWARS_LEAK_DAMAGE[index])

func _trigger_gate_eruption() -> void:
	var now := Time.get_ticks_msec()
	if now - last_gate_eruption_msec < GATE_ERUPTION_COOLDOWN_MSEC:
		return
	last_gate_eruption_msec = now
	var center := _cell_world_position(MINE_ENTRY_CELL)
	_spawn_portal_transfer_effect(center, Color(0.34, 0.88, 1.0, 1.0), "GATE SURGE")
	_apply_gate_eruption(center)

func _apply_gate_eruption(center: Vector2) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	if hero.global_position.distance_to(center) > GATE_ERUPTION_RADIUS:
		return
	var push_direction := (hero.global_position - center).normalized()
	if push_direction.length_squared() < 0.01:
		push_direction = Vector2.UP
	if hero.has_method("take_damage"):
		hero.call("take_damage", GATE_ERUPTION_DAMAGE)
	hero.global_position += push_direction * GATE_ERUPTION_KNOCKBACK
	hero.velocity = push_direction * 240.0

func _find_farthest_tunnel_cell() -> Vector2i:
	# Distance starts at the orange transfer gate, not at the base. The player is
	# deliberately extending one delay network whose endpoint becomes the portal.
	if block_layer.get_cell_source_id(tunnel_exit_cell) != -1:
		return tunnel_exit_cell

	var queue: Array[Vector2i] = [tunnel_exit_cell]
	var head := 0
	var distance_by_cell: Dictionary = {tunnel_exit_cell: 0}
	var farthest_any := tunnel_exit_cell
	var farthest_any_distance := 0
	var farthest_endpoint := tunnel_exit_cell
	var farthest_endpoint_distance := -1

	while head < queue.size():
		var cell := queue[head]
		head += 1
		var distance := int(distance_by_cell[cell])
		if distance > farthest_any_distance:
			farthest_any = cell
			farthest_any_distance = distance
		if _count_open_neighbors(cell) <= 1 and distance > farthest_endpoint_distance:
			farthest_endpoint = cell
			farthest_endpoint_distance = distance

		for direction_value in CARDINAL_DIRECTIONS:
			var direction: Vector2i = direction_value
			var neighbor: Vector2i = cell + direction
			if not _is_search_cell(neighbor):
				continue
			if distance_by_cell.has(neighbor):
				continue
			if block_layer.get_cell_source_id(neighbor) != -1:
				continue
			distance_by_cell[neighbor] = distance + 1
			queue.append(neighbor)

	return farthest_endpoint if farthest_endpoint_distance >= 0 else farthest_any

func _count_open_neighbors(cell: Vector2i) -> int:
	var count := 0
	for direction_value in CARDINAL_DIRECTIONS:
		var direction: Vector2i = direction_value
		var neighbor := cell + direction
		if _is_search_cell(neighbor) and block_layer.get_cell_source_id(neighbor) == -1:
			count += 1
	return count

func _is_search_cell(cell: Vector2i) -> bool:
	return cell.x >= SEARCH_MIN_CELL.x and cell.x <= SEARCH_MAX_CELL.x and cell.y >= SEARCH_MIN_CELL.y and cell.y <= SEARCH_MAX_CELL.y

func _is_surface_cell(cell: Vector2i) -> bool:
	return cell.x >= SURFACE_MIN_CELL.x and cell.x <= SURFACE_MAX_CELL.x and cell.y >= SURFACE_MIN_CELL.y and cell.y <= SURFACE_MAX_CELL.y

func _count_world_enemies() -> int:
	var count := 0
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(candidate) and world.is_ancestor_of(candidate):
			count += 1
	return count

func _count_enemies_in_layer(layer_name: String) -> int:
	var count := 0
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not world.is_ancestor_of(candidate):
			continue
		if str(candidate.get_meta("linewars_layer", "")) == layer_name:
			count += 1
	return count

func _radar_contact_count() -> int:
	if radar_cells.is_empty():
		return 0
	var count := 0
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Node2D
		if enemy == null or not is_instance_valid(enemy) or not world.is_ancestor_of(enemy):
			continue
		if str(enemy.get_meta("linewars_layer", "")) != "tunnel":
			continue
		for radar_cell in radar_cells:
			if enemy.global_position.distance_to(_cell_world_position(radar_cell)) <= RADAR_DETECTION_RADIUS:
				count += 1
				break
	return count

func _toggle_front() -> void:
	if run_finished:
		return
	if opening_build_active:
		command_message = "Dig the minimum opening route first. Waves remain paused until the meter is full."
		_update_interface()
		return
	if command_view_active:
		_exit_command_view()
		return
	_begin_command_view("DIG")

func _begin_radar_command() -> void:
	if run_finished:
		return
	if opening_build_active:
		command_message = "Finish the minimum tunnel before installing infrastructure."
		_update_interface()
		return
	if radar_cells.size() >= MAX_RADARS:
		command_message = "Radar network full: %d/%d installed." % [radar_cells.size(), MAX_RADARS]
		_update_interface()
		return
	if _available_gold() < RADAR_GOLD_COST:
		command_message = "Bank %d gold at the base to install a radar." % RADAR_GOLD_COST
		_update_interface()
		return
	_begin_command_view("RADAR")

func _begin_command_view(mode: String) -> void:
	command_view_active = true
	command_mode = mode
	touch_selected_cell = INVALID_CELL
	command_message = (
		"Tap an open tunnel tile, then press BUILD RADAR. The target snaps to nearby valid tiles."
		if touch_command_mode and mode == "RADAR"
		else
		"Tap dirt, then press DIG HERE. The target snaps to nearby blocks so precise tapping is unnecessary."
		if touch_command_mode
		else
		"Click one open tunnel tile. The peon will walk there and install the radar."
		if mode == "RADAR"
		else
		"Click one distant dirt block. The peon will dig an L-shaped tunnel to it, then remain there for the next order."
	)
	_apply_control()
	if touch_action_panel:
		touch_action_panel.visible = touch_command_mode
	if touch_confirm_button:
		touch_confirm_button.disabled = true
		touch_confirm_button.text = "BUILD RADAR" if mode == "RADAR" else "DIG HERE"
	if not touch_command_mode:
		_update_command_preview(_snap_command_cell(_viewport_to_command_cell(get_viewport().get_mouse_position())))
	_update_interface()

func _exit_command_view() -> void:
	command_view_active = false
	command_mode = "DIG"
	touch_selected_cell = INVALID_CELL
	command_preview_cell = INVALID_CELL
	if touch_action_panel:
		touch_action_panel.visible = false
	if command_cursor:
		command_cursor.visible = false
	if command_preview_line:
		command_preview_line.visible = false
	_apply_control()
	_update_interface()

func _apply_control() -> void:
	if peon == null or hero == null:
		return
	# Only the opening build uses direct peon control. After the safe minimum route
	# exists, the hero owns continuous play and later peon work is commissioned.
	var peon_direct_control := opening_build_active
	var peon_camera_active := opening_build_active or command_view_active
	peon.call("set_controlled", peon_direct_control)
	peon.call("set_command_camera_enabled", peon_camera_active)
	var peon_camera := peon.get_node_or_null("Camera2D") as Camera2D
	if peon_camera:
		if opening_build_active:
			peon_camera.zoom = OPENING_CAMERA_ZOOM
		elif command_view_active:
			peon_camera.zoom = TOUCH_COMMAND_CAMERA_ZOOM if touch_command_mode else DESKTOP_COMMAND_CAMERA_ZOOM
	peon.visible = true

	hero.velocity = Vector2.ZERO
	hero.visible = true
	hero.process_mode = Node.PROCESS_MODE_DISABLED if peon_camera_active else Node.PROCESS_MODE_INHERIT
	var hero_camera := hero.get_node_or_null("Camera2D") as Camera2D
	if hero_camera:
		hero_camera.enabled = not peon_camera_active
		if not peon_camera_active:
			hero_camera.reset_smoothing()

func _complete_opening_build() -> void:
	if not opening_build_active:
		return
	opening_build_active = false
	command_view_active = false
	invasion_timer = FIRST_INVASION_DELAY
	command_message = (
		"Opening route complete. READY — waiting for the opponent before waves begin."
		if vs_match_gate_enabled and not vs_match_started
		else
		"Hero active. Mine below; Tab / RB opens peon orders. First invasion in 28 seconds."
	)
	_clear_opening_dig_overlays()
	var tunnel_gate := portal_nodes.get("TunnelGate") as Node2D
	if tunnel_gate:
		tunnel_gate.visible = true
	first_wave_warning_shown = false
	_show_alert("SAFE ROUTE ESTABLISHED\nHERO CONTROL RESTORED", 2.2)
	_play_sound("play_upgrade")
	_apply_control()
	if vs_match_gate_enabled:
		vs_opening_ready.emit(vs_side_label)

func _on_peon_work_order_finished(kind: String, cell: Vector2i) -> void:
	_hide_order_visual()
	_play_sound("play_deposit")
	if opening_build_active and kind == "DIG":
		command_message = "Tile carved. Dig another marked block until the safe route reaches 5/5."
		_apply_control()
		_update_interface()
		return
	if kind == "RADAR":
		_install_radar(cell)
		command_message = "Radar online at %s. Incoming tunnel contacts now create earlier alerts." % _format_cell(cell)
	else:
		var route_after := _tunnel_route_length()
		var added_tiles := maxi(route_after - active_order_route_before, 0)
		var added_seconds := float(added_tiles) * ESTIMATED_TUNNEL_TILE_SECONDS
		if added_tiles > 0:
			command_message = "Route extended by %d tile%s: about +%.1f seconds before the mine breach." % [added_tiles, "s" if added_tiles != 1 else "", added_seconds]
		else:
			command_message = "Tunnel complete at %s. This branch did not extend the farthest invasion route yet." % _format_cell(cell)
	_update_interface()

func _on_peon_work_order_failed(message: String) -> void:
	_hide_order_visual()
	_play_sound("play_error")
	command_message = message
	_update_interface()

func _install_radar(cell: Vector2i) -> void:
	if radar_cells.has(cell):
		return
	radar_cells.append(cell)
	var marker := _create_world_marker("Radar_%d_%d" % [cell.x, cell.y], cell, Color(0.22, 0.86, 1.0, 0.96), "RADAR", 18.0)
	radar_nodes[cell] = marker

func _build_portal_markers() -> void:
	portal_nodes["TunnelGate"] = _create_world_marker("TunnelTransferGate", tunnel_exit_cell, Color(1.0, 0.52, 0.16, 0.96), "TO MINE", 25.0)
	var tunnel_gate := portal_nodes["TunnelGate"] as Node2D
	if tunnel_gate:
		tunnel_gate.visible = false
	portal_nodes["MineGate"] = _create_world_marker("MineBreachGate", MINE_ENTRY_CELL, Color(0.22, 0.72, 1.0, 0.96), "BREACH", 25.0)
	portal_nodes["EnemyPortal"] = _create_world_marker("EnemyTunnelPortal", tunnel_exit_cell, Color(1.0, 0.18, 0.24, 0.96), "ENEMY", 27.0)
	var enemy_portal := portal_nodes["EnemyPortal"] as Node2D
	if enemy_portal:
		enemy_portal.visible = false

func _move_portal_marker(marker_key: String, cell: Vector2i) -> void:
	var marker := portal_nodes.get(marker_key) as Node2D
	if marker == null:
		return
	marker.global_position = _cell_world_position(cell)
	marker.visible = true

func _create_world_marker(node_name: String, cell: Vector2i, color: Color, caption: String, radius: float) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.global_position = _cell_world_position(cell)
	root.z_index = 18
	world.add_child(root)

	var outer := Polygon2D.new()
	outer.name = "Outer"
	outer.polygon = _circle_polygon(radius, 18)
	outer.color = Color(color.r, color.g, color.b, 0.28)
	root.add_child(outer)
	var inner := Polygon2D.new()
	inner.name = "Inner"
	inner.polygon = _circle_polygon(radius * 0.52, 18)
	inner.color = color
	root.add_child(inner)
	var label := Label.new()
	label.name = "Caption"
	label.position = Vector2(-46, radius + 5.0)
	label.size = Vector2(92, 22)
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color.lightened(0.18))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return root

func _update_opening_route_marker(_newly_dug_tiles: int) -> void:
	if opening_overlay_layer == null:
		return
	var active_dig_cell := INVALID_CELL
	if peon:
		var raw_dig_cell: Variant = peon.get("current_dig_cell")
		if raw_dig_cell is Vector2i:
			active_dig_cell = raw_dig_cell

	var next_overlay_cells: Array[Vector2i] = []
	if opening_build_active and peon:
		var peon_cell := block_layer.local_to_map(block_layer.to_local(peon.global_position))
		for direction_value in CARDINAL_DIRECTIONS:
			var direction: Vector2i = direction_value
			var candidate := peon_cell + direction
			if _is_surface_cell(candidate) and block_layer.get_cell_source_id(candidate) != -1:
				next_overlay_cells.append(candidate)

	for old_cell in opening_overlay_cells:
		if old_cell == active_dig_cell:
			continue
		if not next_overlay_cells.has(old_cell):
			opening_overlay_layer.erase_cell(old_cell)
			if opening_front_overlay_layer:
				opening_front_overlay_layer.erase_cell(old_cell + Vector2i.DOWN)

	opening_overlay_cells = next_overlay_cells
	for overlay_cell in opening_overlay_cells:
		if overlay_cell == active_dig_cell:
			continue
		opening_overlay_layer.set_cell(overlay_cell, 7, Vector2i.ZERO)
		if opening_front_overlay_layer and opening_front_wall_layer:
			var below_cell := overlay_cell + Vector2i.DOWN
			if opening_front_wall_layer.get_cell_source_id(below_cell) != -1:
				opening_front_overlay_layer.set_cell(below_cell, 13, Vector2i.ZERO)
			else:
				opening_front_overlay_layer.erase_cell(below_cell)

func _clear_opening_dig_overlays() -> void:
	if opening_overlay_layer:
		for overlay_cell in opening_overlay_cells:
			opening_overlay_layer.erase_cell(overlay_cell)
			if opening_front_overlay_layer:
				opening_front_overlay_layer.erase_cell(overlay_cell + Vector2i.DOWN)
	opening_overlay_cells.clear()

func _world_topology_revision() -> int:
	varrld.get("topology_revision") if world else null
	return int(revision) if revision != null else 0

func _opening_new_tiles_dug() -> int:
	return maxi(_world_topology_revision() - opening_topology_start, 0)

func _show_alert(text: String, duration: float) -> void:
	if alert_banner == null or alert_label == null:
		return
	alert_label.text = text
	alert_banner.visible = true
	alert_timer = duration

func _build_command_visuals() -> void:
	var cursor_radius := 21.0 if touch_command_mode else 15.0
	command_cursor = _create_world_marker("CommandCursor", tunnel_exit_cell, Color(0.35, 0.9, 1.0, 0.95), "DIG TARGET", cursor_radius)
	command_cursor.visible = false
	command_preview_line = Line2D.new()
	command_preview_line.name = "CommandPreviewLine"
	command_preview_line.width = 4.0
	command_preview_line.default_color = Color(0.35, 0.9, 1.0, 0.78)
	command_preview_line.z_index = 17
	command_preview_line.visible = false
	world.add_child(command_preview_line)
	order_marker = _create_world_marker("ActiveOrderTarget", tunnel_exit_cell, Color(0.25, 0.95, 0.55, 0.96), "PEON ORDER", 14.0)
	order_marker.visible = false
	order_line = Line2D.new()
	order_line.name = "ActiveOrderLine"
	order_line.width = 3.0
	order_line.default_color = Color(0.25, 0.95, 0.55, 0.72)
	order_line.z_index = 16
	order_line.visible = false
	world.add_child(order_line)

func _viewport_to_command_cell(viewport_position: Vector2) -> Vector2i:
	var canvas_inverse := get_viewport().get_canvas_transform().affine_inverse()
	var world_position := canvas_inverse * viewport_position
	return block_layer.local_to_map(block_layer.to_local(world_position))

func _update_command_preview(cell: Vector2i) -> void:
	command_preview_cell = cell
	if command_cursor == null or command_preview_line == null or peon == null:
		return
	var valid := _is_valid_command_target(cell)
	command_cursor.visible = valid
	command_preview_line.visible = valid
	if not valid:
		return
	var target_position := _cell_world_position(cell)
	command_cursor.global_position = target_position
	var caption := command_cursor.get_node_or_null("Caption") as Label
	if caption:
		if touch_command_mode:
			caption.text = "RADAR SELECTED" if command_mode == "RADAR" else "DIG SELECTED"
		else:
			caption.text = "RADAR TARGET" if command_mode == "RADAR" else "DIG TARGET"
	command_preview_line.points = _build_command_line_points(cell, command_mode)

func _is_valid_command_target(cell: Vector2i) -> bool:
	if not _is_surface_cell(cell):
		return false
	if command_mode == "RADAR":
		return block_layer.get_cell_source_id(cell) == -1 and not radar_cells.has(cell)
	return block_layer.get_cell_source_id(cell) != -1

func _snap_command_cell(cell: Vector2i) -> Vector2i:
	if _is_valid_command_target(cell):
		return cell
	var best_cell := INVALID_CELL
	var best_distance := 999999
	for x in range(cell.x - TOUCH_SNAP_RADIUS, cell.x + TOUCH_SNAP_RADIUS + 1):
		for y in range(cell.y - TOUCH_SNAP_RADIUS, cell.y + TOUCH_SNAP_RADIUS + 1):
			var candidate := Vector2i(x, y)
			if not _is_valid_command_target(candidate):
				continue
			var distance: int = absi(candidate.x - cell.x			if distance < best_distance:
				best_distance = distance
				best_cell = candidate
	return best_cell

func _select_touch_command_cell(cell: Vector2i) -> void:
	touch_selected_cell = cell if _is_valid_command_target(cell) else INVALID_CELL
	_update_command_preview(touch_selected_cell)
	if touch_confirm_button:
		touch_confirm_button.disabled = touch_selected_cell == INVALID_CELL
	if touch_selected_cell == INVALID_CELL:
		command_message = "Tap near a valid %s tile. The selector snaps within two blocks." % ("open tunnel" if command_mode == "RADAR" else "dirt")
	else:
		command_message = "Target selected at %s. Confirm below, or tap elsewhere to change it." % _format_cell(touch_selected_cell)
	_update_interface()

func _confirm_touch_command() -> void:
	if touch_selected_cell == INVALID_CELL or not _is_valid_command_target(touch_selected_cell):
		_play_sound("play_error")
		return
	_issue_command(touc) + absi(candidate.y - cell.y)
