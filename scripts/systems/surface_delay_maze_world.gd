extends Node2D

signal enemy_reached_portal(enemy_type: String)
signal route_changed(estimated_seconds: float)
signal builder_status_changed(message: String)

const COLS := 17
const ROWS := 9
const ENTRANCE := Vector2i(8, 0)
const PORTAL := Vector2i(8, ROWS - 1)
const STARTING_DIG_POINTS := 34
const PEON_BUILD_RANGE := 3
const SPAWN_INTERVAL := 0.65
const BOARD_RECT := Rect2(-408.0, -180.0, 816.0, 360.0)

var grid: Array[bool] = []
var current_path: Array[Vector2i] = []
var enemies: Array[Dictionary] = []
var spawn_queue: Array[String] = []
var spawn_clock := 0.0
var dig_points := STARTING_DIG_POINTS
var builder_active := false
var builder_peon: Node2D
var hovered_cell := Vector2i(-1, -1)
var status_text := "The surface maze buys time. The hero fights anything that reaches the portal."

func _ready() -> void:
	z_index = 8
	_reset_grid()
	queue_redraw()

func set_builder_peon(peon: Node2D) -> void:
	builder_peon = peon
	queue_redraw()

func set_builder_active(active: bool) -> void:
	builder_active = active
	status_text = "Surface control active. Walk near a tile and click to change the route." if active else "The maze continues running while the hero mines below."
	builder_status_changed.emit(status_text)
	queue_redraw()

func set_round(round_number: int) -> void:
	dig_points += 5
	_set_status("Invasion %d delivered five new dig points." % round_number)

func spawn_invasion(enemy_types: Array[String]) -> void:
	for enemy_type: String in enemy_types:
		spawn_queue.append(enemy_type)
	_set_status("%d invader%s entered the surface maze." % [enemy_types.size(), "" if enemy_types.size() == 1 else "s"])

func get_enemy_count() -> int:
	return enemies.size() + spawn_queue.size()

func get_path_length() -> int:
	return current_path.size()

func get_status_text() -> String:
	return status_text

func get_stats_text() -> String:
	var eta := get_estimated_first_arrival()
	var eta_text := "clear" if eta < 0.0 else "%ds" % int(ceil(eta))
	return "Dig %d  •  Route %d tiles  •  Invaders %d  •  Arrival %s" % [dig_points, current_path.size(), get_enemy_count(), eta_text]

func get_estimated_first_arrival() -> float:
	var best := INF
	for enemy_value: Dictionary in enemies:
		var path_value: Array = enemy_value.get("path", [])
		if path_value.is_empty():
			continue
		var path_index := int(enemy_value.get("path_index", 0))
		var progress := float(enemy_value.get("segment_progress", 0.0))
		var remaining_segments := maxf(float(path_value.size() - 1 - path_index) - progress, 0.0)
		var speed := maxf(float(enemy_value.get("speed", 0.5)), 0.01)
		best = minf(best, remaining_segments / speed)
	if best == INF and not spawn_queue.is_empty():
		best = float(maxi(current_path.size() - 1, 0)) / _speed_for_type(spawn_queue[0])
	return -1.0 if best == INF else best

func _process(delta: float) -> void:
	_process_spawning(delta)
	_process_enemies(delta)
	_update_hovered_cell()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not builder_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := _cell_from_local_position(to_local(get_global_mouse_position()))
		if _is_in_bounds(cell):
			_toggle_cell(cell)
			get_viewport().set_input_as_handled()

func _update_hovered_cell() -> void:
	if not builder_active:
		hovered_cell = Vector2i(-1, -1)
		return
	hovered_cell = _cell_from_local_position(to_local(get_global_mouse_position()))

func _process_spawning(delta: float) -> void:
	if spawn_queue.is_empty():
		spawn_clock = 0.0
		return
	spawn_clock -= delta
	if spawn_clock > 0.0:
		return
	var enemy_type: String = spawn_queue.pop_front()
	_spawn_enemy(enemy_type)
	spawn_clock = SPAWN_INTERVAL

func _process_enemies(delta: float) -> void:
	for index in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[index]
		var path_value: Array = enemy.get("path", [])
		if path_value.size() < 2:
			_recalculate_enemy_path(enemy)
			path_value = enemy.get("path", [])
			if path_value.size() < 2:
				continue
		var segment_progress := float(enemy.get("segment_progress", 0.0)) + float(enemy.get("speed", 0.5)) * delta
		var path_index := int(enemy.get("path_index", 0))
		while segment_progress >= 1.0 and path_index < path_value.size() - 1:
			segment_progress -= 1.0
			path_index += 1
		enemy["segment_progress"] = segment_progress
		enemy["path_index"] = path_index
		if path_index >= path_value.size() - 1:
			var enemy_type := str(enemy.get("type", "Rat"))
			enemies.remove_at(index)
			enemy_reached_portal.emit(enemy_type)
	route_changed.emit(get_estimated_first_arrival())

func _spawn_enemy(enemy_type: String) -> void:
	var path_from_entrance: Array[Vector2i] = _find_path_from(ENTRANCE)
	if path_from_entrance.is_empty():
		return
	enemies.append({
		"type": enemy_type,
		"path": path_from_entrance,
		"path_index": 0,
		"segment_progress": 0.0,
		"speed": _speed_for_type(enemy_type)
	})

func _speed_for_type(enemy_type: String) -> float:
	match enemy_type:
		"Orc":
			return 0.34
		"Spider":
			return 0.48
		_:
			return 0.62

func _toggle_cell(cell: Vector2i) -> void:
	if cell == ENTRANCE or cell == PORTAL:
		_set_status("The invasion entrance and breach portal cannot be changed.")
		return
	var peon_cell := _get_builder_cell()
	if not _is_in_bounds(peon_cell):
		_set_status("Move the peon onto the maze before building.")
		return
	if _manhattan_distance(cell, peon_cell) > PEON_BUILD_RANGE:
		_set_status("Move closer. The peon can work within %d tiles." % PEON_BUILD_RANGE)
		return
	if _cell_is_occupied(cell):
		_set_status("An invader currently occupies that tile.")
		return
	var was_open := _is_open(cell)
	if was_open:
		_set_open(cell, false)
		if not _all_routes_remain_valid():
			_set_open(cell, true)
			_set_status("Blocked: that edit would disconnect the portal or strand an invader.")
			return
		dig_points += 1
	else:
		if dig_points <= 0:
			_set_status("No dig points left. Close an unused tunnel to refund one.")
			return
		_set_open(cell, true)
		dig_points -= 1
	_update_path()
	_recalculate_all_enemy_paths()
	_set_status("Maze updated live. The arrival estimate has changed.")

func _all_routes_remain_valid() -> bool:
	if _find_path_from(ENTRANCE).is_empty():
		return false
	for enemy: Dictionary in enemies:
		if _find_path_from(_enemy_current_cell(enemy)).is_empty():
			return false
	return true

func _cell_is_occupied(cell: Vector2i) -> bool:
	for enemy: Dictionary in enemies:
		if _enemy_current_cell(enemy) == cell:
			return true
	return false

func _enemy_current_cell(enemy: Dictionary) -> Vector2i:
	var path_value: Array = enemy.get("path", [])
	if path_value.is_empty():
		return ENTRANCE
	var path_index := clampi(int(enemy.get("path_index", 0)), 0, path_value.size() - 1)
	return Vector2i(path_value[path_index])

func _recalculate_all_enemy_paths() -> void:
	for enemy: Dictionary in enemies:
		_recalculate_enemy_path(enemy)

func _recalculate_enemy_path(enemy: Dictionary) -> void:
	var new_path: Array[Vector2i] = _find_path_from(_enemy_current_cell(enemy))
	if new_path.is_empty():
		return
	enemy["path"] = new_path
	enemy["path_index"] = 0
	enemy["segment_progress"] = 0.0

func _reset_grid() -> void:
	grid.clear()
	grid.resize(COLS * ROWS)
	grid.fill(false)
	for y in ROWS:
		_set_open(Vector2i(ENTRANCE.x, y), true)
	for x in range(6, 11):
		_set_open(Vector2i(x, 3), true)
	_update_path()

func reset_maze() -> bool:
	if not enemies.is_empty():
		_set_status("The maze cannot reset while invaders are inside it.")
		return false
	dig_points = STARTING_DIG_POINTS
	_reset_grid()
	_set_status("Direct route restored. Build a longer route before the next invasion.")
	return true

func _update_path() -> void:
	current_path = _find_path_from(ENTRANCE)
	route_changed.emit(get_estimated_first_arrival())
	queue_redraw()

func _find_path_from(start: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if not _is_open(start) or not _is_open(PORTAL):
		return empty
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var head := 0
	while head < frontier.size():
		var current: Vector2i = frontier[head]
		head += 1
		if current == PORTAL:
			break
		for neighbor: Vector2i in _neighbors(current):
			if _is_open(neighbor) and not came_from.has(neighbor):
				came_from[neighbor] = current
				frontier.append(neighbor)
	if not came_from.has(PORTAL):
		return empty
	var result: Array[Vector2i] = []
	var cursor := PORTAL
	result.append(cursor)
	while cursor != start:
		cursor = Vector2i(came_from[cursor])
		result.append(cursor)
	result.reverse()
	return result

func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for direction: Vector2i in directions:
		var neighbor: Vector2i = cell + direction
		if _is_in_bounds(neighbor):
			result.append(neighbor)
	return result

func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS

func _grid_index(cell: Vector2i) -> int:
	return cell.y * COLS + cell.x

func _is_open(cell: Vector2i) -> bool:
	return _is_in_bounds(cell) and grid[_grid_index(cell)]

func _set_open(cell: Vector2i, value: bool) -> void:
	if _is_in_bounds(cell):
		grid[_grid_index(cell)] = value

func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _cell_from_local_position(local_position: Vector2) -> Vector2i:
	if not BOARD_RECT.has_point(local_position):
		return Vector2i(-1, -1)
	var position_in_board := local_position - BOARD_RECT.position
	return Vector2i(
		int(floor(position_in_board.x / (BOARD_RECT.size.x / float(COLS)))),
		int(floor(position_in_board.y / (BOARD_RECT.size.y / float(ROWS))))
	)

func _get_builder_cell() -> Vector2i:
	if builder_peon == null or not is_instance_valid(builder_peon):
		return Vector2i(-1, -1)
	return _cell_from_local_position(to_local(builder_peon.global_position))

func _cell_rect(cell: Vector2i) -> Rect2:
	var cell_size := Vector2(BOARD_RECT.size.x / float(COLS), BOARD_RECT.size.y / float(ROWS))
	return Rect2(BOARD_RECT.position + Vector2(cell.x, cell.y) * cell_size, cell_size)

func _cell_center(cell: Vector2i) -> Vector2:
	return _cell_rect(cell).get_center()

func _enemy_position(enemy: Dictionary) -> Vector2:
	var path_value: Array = enemy.get("path", [])
	if path_value.is_empty():
		return _cell_center(ENTRANCE)
	var path_index := clampi(int(enemy.get("path_index", 0)), 0, path_value.size() - 1)
	if path_index >= path_value.size() - 1:
		return _cell_center(Vector2i(path_value[-1]))
	var from := _cell_center(Vector2i(path_value[path_index]))
	var to := _cell_center(Vector2i(path_value[path_index + 1]))
	return from.lerp(to, clampf(float(enemy.get("segment_progress", 0.0)), 0.0, 1.0))

func _draw() -> void:
	draw_rect(BOARD_RECT.grow(14.0), Color(0.025, 0.018, 0.012, 0.94), true)
	draw_rect(BOARD_RECT.grow(14.0), Color(0.78, 0.49, 0.18, 0.88), false, 4.0)
	var builder_cell := _get_builder_cell()
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var cell_rect := _cell_rect(cell).grow(-1.2)
			var fill := Color(0.14, 0.105, 0.075, 1.0) if _is_open(cell) else Color(0.39, 0.235, 0.11, 1.0)
			if cell == hovered_cell:
				fill = fill.lightened(0.16)
			if _is_in_bounds(builder_cell) and _manhattan_distance(cell, builder_cell) <= PEON_BUILD_RANGE:
				fill = fill.lerp(Color(0.16, 0.46, 0.56, 1.0), 0.18)
			draw_rect(cell_rect, fill, true)
			draw_rect(cell_rect, Color(0.07, 0.045, 0.025, 0.92), false, 1.0)
	if current_path.size() > 1:
		for index in current_path.size() - 1:
			draw_line(_cell_center(current_path[index]), _cell_center(current_path[index + 1]), Color(0.32, 0.78, 1.0, 0.78), 5.0, true)
	var radius := minf(_cell_rect(ENTRANCE).size.x, _cell_rect(ENTRANCE).size.y) * 0.24
	draw_circle(_cell_center(ENTRANCE), radius, Color(0.28, 0.94, 0.38, 1.0))
	draw_circle(_cell_center(PORTAL), radius * 1.18, Color(0.72, 0.28, 1.0, 1.0))
	for enemy: Dictionary in enemies:
		var enemy_type := str(enemy.get("type", "Rat"))
		var enemy_color := Color(0.80, 0.72, 0.56, 1.0)
		var enemy_radius := radius * 0.72
		if enemy_type == "Orc":
			enemy_color = Color(0.36, 0.78, 0.29, 1.0)
			enemy_radius = radius
		elif enemy_type == "Spider":
			enemy_color = Color(0.66, 0.31, 0.84, 1.0)
		draw_circle(_enemy_position(enemy), enemy_radius, enemy_color)

func _set_status(message: String) -> void:
	status_text = message
	builder_status_changed.emit(message)
	queue_redraw()
