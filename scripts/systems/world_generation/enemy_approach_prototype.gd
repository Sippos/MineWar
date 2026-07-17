extends Node2D

# Debug prototype for the "enemies dig through fog toward the mine" wave loop.
# It deliberately takes over the single-player wave timer, while leaving VS mode untouched.

const ENEMY_SCENE := preload("res://enemy.tscn")
const BASE_TARGET_CELL := Vector2i(0, -1)
const MAP_MIN := Vector2i(-20, -10)
const MAP_MAX := Vector2i(19, 29)
const FIRST_WAVE_DELAY := 32.0
const STANDARD_WAVE_INTERVAL := 36.0
const WAVES_PER_FRONT := 2
const DIG_STEP_DELAY := 0.065
const CARDINALS: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]
const THREAT_ORIGINS: Array[Vector2i] = [
	Vector2i(0, 13),
	Vector2i(-16, 12),
	Vector2i(16, 12),
	Vector2i(-17, 24),
	Vector2i(17, 24),
	Vector2i(0, 27),
]

var world: Node2D
var block_layer: TileMapLayer
var hud: Node
var prototype_active := false
var wave_spawning := false
var plan_valid := false
var topology_seen := -1
var front_index := -1
var waves_left_at_front := 0
var pulse_time := 0.0

var threat_origin_cell := Vector2i.ZERO
var planned_contact_cell := Vector2i.ZERO
var planned_open_cell := Vector2i.ZERO
var planned_dig_path: Array[Vector2i] = []
var planned_open_route: Array[Vector2i] = []
var legend_layer: CanvasLayer

func _ready() -> void:
	z_index = 40
	call_deferred("_activate_prototype")

func _activate_prototype() -> void:
	world = get_parent() as Node2D
	if world == null or not is_instance_valid(world):
		queue_free()
		return
	if bool(world.get("is_vs_mode")):
		queue_free()
		return
	block_layer = world.get_node_or_null("BlockLayer") as TileMapLayer
	hud = world.get_node_or_null("HUD")
	if block_layer == null:
		push_error("Enemy approach prototype could not find BlockLayer.")
		queue_free()
		return

	# The original world process owns the old persistent-breach wave loop.
	# Disable only that process and reproduce its timer/HUD behavior here.
	world.set_process(false)
	world.wave_timer = FIRST_WAVE_DELAY
	world.wave_interval = STANDARD_WAVE_INTERVAL
	world.current_wave_number = 1
	world.enemies_per_wave = 1
	world.set_meta("wave_spawning", false)
	world.set_meta("enemy_approach_prototype", true)
	prototype_active = true
	_create_legend()
	_ensure_front_for_wave(1)
	queue_redraw()
	if hud and hud.has_method("show_notice"):
		hud.show_notice("Prototype active: red threat digs toward the nearest green mine route. Dig toward it to move the breach.", 6.0)

func _process(delta: float) -> void:
	if not prototype_active or world == null:
		return
	pulse_time += delta
	queue_redraw()
	if bool(world.get("preparation_active")):
		return

	var enemies_alive := get_tree().get_nodes_in_group("enemies").size()
	var wave_active := enemies_alive > 0 or wave_spawning
	var tutorial_holds_threat := bool(world.get("onboarding_active"))

	if not wave_active and not tutorial_holds_threat:
		_ensure_front_for_wave(int(world.current_wave_number))
		var revision := int(world.topology_revision)
		if revision != topology_seen:
			_refresh_plan()
		world.wave_timer -= delta

	_update_wave_hud(wave_active)

	if world.wave_timer <= 0.0 and not wave_active and not tutorial_holds_threat:
		var wave_to_spawn := int(world.current_wave_number)
		world.set_meta("active_wave_number", wave_to_spawn)
		world.set_meta("wave_spawning", true)
		wave_spawning = true
		_run_wave(wave_to_spawn)
		world.wave_timer = world.wave_interval
		world.current_wave_number += 1
		world.enemies_per_wave += 1

func _update_wave_hud(wave_active: bool) -> void:
	if hud == null or not hud.has_method("update_wave_info"):
		return
	var displayed_wave := int(world.get_meta("active_wave_number", world.current_wave_number)) if wave_active else int(world.current_wave_number)
	var is_boss := displayed_wave % 10 == 0
	var max_wave_time := float(world.wave_interval if displayed_wave > 1 else FIRST_WAVE_DELAY)
	if wave_active:
		hud.update_wave_info(displayed_wave, -1.0, max_wave_time, is_boss)
	else:
		hud.update_wave_info(displayed_wave, maxf(float(world.wave_timer), 0.0), max_wave_time, is_boss)

func _ensure_front_for_wave(wave_number: int) -> void:
	if waves_left_at_front > 0 and plan_valid:
		return
	front_index += 1
	waves_left_at_front = WAVES_PER_FRONT
	threat_origin_cell = _choose_available_origin(front_index)
	_refresh_plan()
	if hud and hud.has_method("show_notice"):
		hud.show_notice("Wave %d threat detected in distant dirt. The contact point updates while you dig." % wave_number, 4.5)

func _choose_available_origin(start_index: int) -> Vector2i:
	for offset in range(THREAT_ORIGINS.size()):
		var candidate := THREAT_ORIGINS[posmod(start_index + offset, THREAT_ORIGINS.size())]
		if _is_solid(candidate):
			return candidate
	# If the player has eventually opened all authored origins, find a remaining
	# dirt cell near the next authored position instead of failing the wave.
	var desired := THREAT_ORIGINS[posmod(start_index, THREAT_ORIGINS.size())]
	for radius in range(1, 9):
		for x in range(desired.x - radius, desired.x + radius + 1):
			for y in [desired.y - radius, desired.y + radius]:
				var cell := Vector2i(x, y)
				if _inside_map(cell) and _is_solid(cell):
					return cell
		for y in range(desired.y - radius + 1, desired.y + radius):
			for x in [desired.x - radius, desired.x + radius]:
				var cell := Vector2i(x, y)
				if _inside_map(cell) and _is_solid(cell):
					return cell
	return desired

func _refresh_plan() -> void:
	if wave_spawning or block_layer == null:
		return
	topology_seen = int(world.topology_revision)
	var result := _find_approach_plan(threat_origin_cell)
	if result.is_empty():
		plan_valid = false
		planned_dig_path.clear()
		planned_open_route.clear()
		queue_redraw()
		return

	planned_contact_cell = result["contact"]
	planned_open_cell = result["open"]
	planned_dig_path = result["dig_path"]
	planned_open_route = _get_open_route(planned_open_cell, BASE_TARGET_CELL)
	plan_valid = not planned_open_route.is_empty()

	# Keep the old public breach fields coherent for HUD helpers and debug tools.
	world.current_breach_cell = planned_open_cell
	world.current_breach_valid = plan_valid
	world.current_breach_is_surface = false
	world.current_breach_waves_remaining = waves_left_at_front
	world.prepared_breach_wave = int(world.current_wave_number)
	queue_redraw()

func _find_approach_plan(origin: Vector2i) -> Dictionary:
	var reachable := _get_reachable_open_cells()
	if reachable.is_empty():
		return {}

	# Reused fronts are already connected after their first wave.
	if reachable.has(origin):
		return {
			"contact": origin,
			"open": origin,
			"dig_path": [] as Array[Vector2i],
		}
	if not _inside_map(origin) or not _is_solid(origin):
		return {}

	# Breadth-first search only through dirt. The first reachable open neighbor is
	# the physically nearest point where this hidden group would meet the mine.
	var queue: Array[Vector2i] = [origin]
	var visited: Dictionary = {origin: true}
	var parents: Dictionary = {}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for direction in CARDINALS:
			var neighbor := cell + direction
			if not _inside_map(neighbor):
				continue
			if reachable.has(neighbor):
				return {
					"contact": cell,
					"open": neighbor,
					"dig_path": _reconstruct_solid_path(parents, origin, cell),
				}
			if visited.has(neighbor) or not _is_solid(neighbor):
				continue
			visited[neighbor] = true
			parents[neighbor] = cell
			queue.append(neighbor)
	return {}

func _reconstruct_solid_path(parents: Dictionary, origin: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var reversed_path: Array[Vector2i] = [goal]
	var current := goal
	while current != origin and parents.has(current):
		current = parents[current]
		reversed_path.append(current)
	reversed_path.reverse()
	return reversed_path

func _get_reachable_open_cells() -> Dictionary:
	var reachable: Dictionary = {}
	if not _inside_map(BASE_TARGET_CELL) or _is_solid(BASE_TARGET_CELL):
		return reachable
	var queue: Array[Vector2i] = [BASE_TARGET_CELL]
	reachable[BASE_TARGET_CELL] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for direction in CARDINALS:
			var neighbor := cell + direction
			if not _inside_map(neighbor) or reachable.has(neighbor) or _is_solid(neighbor):
				continue
			reachable[neighbor] = true
			queue.append(neighbor)
	return reachable

func _get_open_route(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	if world.astar == null:
		return route
	if not world.astar.is_in_bounds(from_cell.x, from_cell.y) or not world.astar.is_in_bounds(to_cell.x, to_cell.y):
		return route
	var id_path: Array[Vector2i] = world.astar.get_id_path(from_cell, to_cell)
	for cell in id_path:
		route.append(cell)
	return route

func _run_wave(wave_number: int) -> void:
	_refresh_plan()
	if not plan_valid:
		wave_spawning = false
		world.set_meta("wave_spawning", false)
		world.wave_timer = 3.0
		return

	var origin_snapshot := threat_origin_cell
	var dig_snapshot: Array[Vector2i] = planned_dig_path.duplicate()
	var is_boss := wave_number % 10 == 0
	if hud and hud.has_method("notify_wave_started"):
		hud.notify_wave_started(is_boss, wave_number)
	if not dig_snapshot.is_empty() and hud and hud.has_method("show_notice"):
		hud.show_notice("Contact! Enemies are carving the yellow approach tunnel.", 2.2)

	# Freeze topology bookkeeping while the approach tunnel is animated, then
	# publish one revision so every enemy recalculates against the completed path.
	var previous_generation_flag := bool(world.world_generation_in_progress)
	world.world_generation_in_progress = true
	for cell in dig_snapshot:
		if _is_solid(cell):
			world.on_cell_dug(cell)
			queue_redraw()
			await get_tree().create_timer(DIG_STEP_DELAY).timeout
	world.world_generation_in_progress = previous_generation_flag
	world.topology_revision += 1
	topology_seen = int(world.topology_revision)

	var spawn_position := _cell_world_position(origin_snapshot)
	if world.has_method("_spawn_wave_telegraph"):
		world._spawn_wave_telegraph(spawn_position, is_boss)
	await get_tree().create_timer(0.55).timeout

	var spawn_count := 1 if is_boss else int(world.enemies_per_wave)
	for i in range(spawn_count):
		var enemy := ENEMY_SCENE.instantiate()
		world.add_child(enemy)
		enemy.global_position = _spread_spawn_position(origin_snapshot, i)
		if enemy.has_method("initialize"):
			var enemy_type := 0 if wave_number == 1 else int(world.get_random_enemy_type(wave_number))
			enemy.initialize(wave_number, is_boss, enemy_type)
		if enemy.has_method("begin_breach_emergence"):
			enemy.begin_breach_emergence(0.55 if not is_boss else 0.85)
		await get_tree().create_timer(0.32).timeout

	waves_left_at_front = maxi(waves_left_at_front - 1, 0)
	world.current_breach_waves_remaining = waves_left_at_front
	world.prepared_breach_wave = 0
	wave_spawning = false
	world.set_meta("wave_spawning", false)
	plan_valid = false
	_refresh_plan()

func _spread_spawn_position(cell: Vector2i, index: int) -> Vector2:
	var center := _cell_world_position(cell)
	var route := _get_open_route(cell, BASE_TARGET_CELL)
	var direction := Vector2.UP
	if route.size() > 1:
		direction = center.direction_to(_cell_world_position(route[1]))
	var perpendicular := direction.orthogonal()
	var lane := float((index % 3) - 1) * 9.0
	return center + perpendicular * lane

func _inside_map(cell: Vector2i) -> bool:
	return cell.x >= MAP_MIN.x and cell.x <= MAP_MAX.x and cell.y >= MAP_MIN.y and cell.y <= MAP_MAX.y

func _is_solid(cell: Vector2i) -> bool:
	return block_layer.get_cell_source_id(cell) != -1

func _cell_world_position(cell: Vector2i) -> Vector2:
	return block_layer.to_global(block_layer.map_to_local(cell))

func _cell_draw_position(cell: Vector2i) -> Vector2:
	return to_local(_cell_world_position(cell))

func _draw() -> void:
	if not prototype_active or not plan_valid:
		return

	var origin_position := _cell_draw_position(threat_origin_cell)
	var pulse := 13.0 + sin(pulse_time * 4.0) * 3.0
	draw_circle(origin_position, pulse, Color(0.95, 0.04, 0.04, 0.28))
	draw_circle(origin_position, 8.0, Color(1.0, 0.05, 0.04, 1.0))
	draw_arc(origin_position, 19.0, 0.0, TAU, 32, Color(1.0, 0.3, 0.18, 0.92), 3.0, true)

	var yellow_points := PackedVector2Array()
	for cell in planned_dig_path:
		yellow_points.append(_cell_draw_position(cell))
	yellow_points.append(_cell_draw_position(planned_open_cell))
	if yellow_points.size() > 1:
		draw_polyline(yellow_points, Color(1.0, 0.78, 0.08, 0.95), 6.0, true)

	var contact_center := _cell_draw_position(planned_contact_cell)
	var contact_rect := Rect2(contact_center - Vector2(27, 27), Vector2(54, 54))
	draw_rect(contact_rect, Color(1.0, 0.42, 0.05, 0.22), true)
	draw_rect(contact_rect, Color(1.0, 0.5, 0.08, 1.0), false, 4.0)

	var green_points := PackedVector2Array()
	for cell in planned_open_route:
		green_points.append(_cell_draw_position(cell))
	if green_points.size() > 1:
		draw_polyline(green_points, Color(0.12, 1.0, 0.34, 0.9), 5.0, true)

func _create_legend() -> void:
	legend_layer = CanvasLayer.new()
	legend_layer.layer = 30
	add_child(legend_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 96)
	panel.custom_minimum_size = Vector2(360, 0)
	legend_layer.add_child(panel)
	var label := Label.new()
	label.text = "ENEMY APPROACH PROTOTYPE\n🔴 hidden enemy group   🟡 dirt route\n🟧 planned contact wall   🟢 route to core\nDig toward the red threat: the plan updates live."
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	panel.add_child(label)
