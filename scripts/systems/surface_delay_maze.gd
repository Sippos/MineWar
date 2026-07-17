extends Control

signal enemy_reached_portal(enemy_type: String)
signal route_changed(estimated_seconds: float)
signal builder_status_changed(message: String)

const COLS := 17
const ROWS := 9
const ENTRANCE := Vector2i(0, 4)
const PORTAL := Vector2i(COLS - 1, 4)
const STARTING_DIG_POINTS := 42
const PEON_BUILD_RANGE := 3
const SPAWN_INTERVAL := 0.55

@onready var title_label: Label = $TitleLabel
@onready var stats_label: Label = $StatsLabel
@onready var status_label: Label = $StatusLabel
@onready var reset_button: Button = $ResetButton

var grid: Array[bool] = []
var current_path: Array[Vector2i] = []
var enemies: Array[Dictionary] = []
var spawn_queue: Array[String] = []
var spawn_clock := 0.0
var dig_points := STARTING_DIG_POINTS
var peon_cell := Vector2i(8, 2)
var builder_active := false
var hovered_cell := Vector2i(-1, -1)
var status_text := "Move the flying peon, then dig within its working radius."
var movement_repeat_timer := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	reset_button.pressed.connect(_on_reset_pressed)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(queue_redraw)
	_reset_grid()
	_update_ui()
	queue_redraw()

func set_builder_active(active: bool) -> void:
	builder_active = active
	if active:
		grab_focus()
	status_text = "Surface control active. The maze only buys time; the hero fights survivors at base." if active else "Surface continues running while you mine below."
	_update_ui()
	queue_redraw()

func set_round(round_number: int) -> void:
	dig_points += 5
	status_text = "Round %d: five new dig points delivered." % round_number
	_update_ui()
	queue_redraw()

func spawn_invasion(enemy_types: Array[String]) -> void:
	for enemy_type in enemy_types:
		spawn_queue.append(enemy_type)
	status_text = "%d invader%s entered the upper tunnels." % [enemy_types.size(), "" if enemy_types.size() == 1 else "s"]
	builder_status_changed.emit(status_text)
	_update_ui()

func get_enemy_count() -> int:
	return enemies.size() + spawn_queue.size()

func get_path_length() -> int:
	return current_path.size()

func get_estimated_first_arrival() -> float:
	var best := INF
	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
		var path_value: Array = enemy.get("path", [])
		if path_value.is_empty():
			continue
		var path_index := int(enemy.get("path_index", 0))
		var progress := float(enemy.get("segment_progress", 0.0))
		var remaining_segments := maxf(float(path_value.size() - 1 - path_index) - progress, 0.0)
		var speed := maxf(float(enemy.get("speed", 1.0)), 0.01)
		best = minf(best, remaining_segments / speed)
	if best == INF and not spawn_queue.is_empty():
		best = float(maxi(current_path.size() - 1, 0)) / _speed_for_type(spawn_queue[0])
	return -1.0 if best == INF else best

func _process(delta: float) -> void:
	_process_builder_movement(delta)
	_process_spawning(delta)
	_process_enemies(delta)
	_update_ui()
	queue_redraw()

func _process_builder_movement(delta: float) -> void:
	if not builder_active:
		movement_repeat_timer = 0.0
		return
	movement_repeat_timer = maxf(movement_repeat_timer - delta, 0.0)
	var direction := Vector2i.ZERO
	if Input.is_action_pressed("p1_left") or Input.is_action_pressed("ui_left"):
		direction = Vector2i.LEFT
	elif Input.is_action_pressed("p1_right") or Input.is_action_pressed("ui_right"):
		direction = Vector2i.RIGHT
	elif Input.is_action_pressed("p1_up") or Input.is_action_pressed("ui_up"):
		direction = Vector2i.UP
	elif Input.is_action_pressed("p1_down") or Input.is_action_pressed("ui_down"):
		direction = Vector2i.DOWN
	if direction == Vector2i.ZERO or movement_repeat_timer > 0.0:
		return
	peon_cell = Vector2i(
		clampi(peon_cell.x + direction.x, 0, COLS - 1),
		clampi(peon_cell.y + direction.y, 0, ROWS - 1)
	)
	movement_repeat_timer = 0.11

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
		var speed := float(enemy.get("speed", 1.0))
		var segment_progress := float(enemy.get("segment_progress", 0.0)) + speed * delta
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
	var eta := get_estimated_first_arrival()
	route_changed.emit(eta)

func _spawn_enemy(enemy_type: String) -> void:
	var path_from_entrance := _find_path_from(ENTRANCE)
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
		"Orc": return 1.45
		"Spider": return 2.4
		_: return 3.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered_cell = _cell_from_position(event.position)
		queue_redraw()
		return
	if not builder_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := _cell_from_position(event.position)
		if _is_in_bounds(cell):
			_toggle_cell(cell)
			accept_event()

func _toggle_cell(cell: Vector2i) -> void:
	if cell == ENTRANCE or cell == PORTAL:
		_set_status("The entrance and portal cannot be changed.")
		return
	if _manhattan_distance(cell, peon_cell) > PEON_BUILD_RANGE:
		_set_status("Move the peon closer. Its build range is %d tiles." % PEON_BUILD_RANGE)
		return
	if _cell_is_occupied(cell):
		_set_status("An invader occupies that tunnel.")
		return
	var was_open := _is_open(cell)
	if was_open:
		_set_open(cell, false)
		if not _all_routes_remain_valid():
			_set_open(cell, true)
			_set_status("Blocked: this edit would strand enemies or disconnect the portal.")
			return
		dig_points += 1
	else:
		if dig_points <= 0:
			_set_status("No dig points left. Reinforce an unused tunnel to refund one.")
			return
		_set_open(cell, true)
		dig_points -= 1
	_update_path()
	_recalculate_all_enemy_paths()
	_set_status("Maze updated live. Estimated arrival recalculated.")

func _all_routes_remain_valid() -> bool:
	if _find_path_from(ENTRANCE).is_empty():
		return false
	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
		var cell := _enemy_current_cell(enemy)
		if _find_path_from(cell).is_empty():
			return false
	return true

func _cell_is_occupied(cell: Vector2i) -> bool:
	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
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
	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
		_recalculate_enemy_path(enemy)

func _recalculate_enemy_path(enemy: Dictionary) -> void:
	var start := _enemy_current_cell(enemy)
	var new_path := _find_path_from(start)
	if new_path.is_empty():
		return
	enemy["path"] = new_path
	enemy["path_index"] = 0
	enemy["segment_progress"] = 0.0

func _on_reset_pressed() -> void:
	if not builder_active:
		return
	if not enemies.is_empty():
		_set_status("Reset is disabled while invaders are inside the maze.")
		return
	dig_points = STARTING_DIG_POINTS
	_reset_grid()
	_set_status("Direct route restored. Build detours before the next invasion.")

func _reset_grid() -> void:
	grid.clear()
	grid.resize(COLS * ROWS)
	grid.fill(false)
	for x in COLS:
		_set_open(Vector2i(x, ENTRANCE.y), true)
	for x in range(6, 11):
		_set_open(Vector2i(x, ENTRANCE.y - 1), true)
	_update_path()

func _update_path() -> void:
	current_path = _find_path_from(ENTRANCE)
	route_changed.emit(get_estimated_first_arrival())

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
		for neighbor in _neighbors(current):
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

func _board_rect() -> Rect2:
	return Rect2(18.0, 88.0, maxf(1.0, size.x - 36.0), maxf(1.0, size.y - 170.0))

func _cell_from_position(position: Vector2) -> Vector2i:
	var rect := _board_rect()
	if not rect.has_point(position):
		return Vector2i(-1, -1)
	var local_position := position - rect.position
	return Vector2i(
		int(floor(local_position.x / (rect.size.x / float(COLS)))),
		int(floor(local_position.y / (rect.size.y / float(ROWS))))
	)

func _cell_rect(cell: Vector2i) -> Rect2:
	var rect := _board_rect()
	var cell_size := Vector2(rect.size.x / float(COLS), rect.size.y / float(ROWS))
	return Rect2(rect.position + Vector2(cell.x, cell.y) * cell_size, cell_size)

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
	var rect := _board_rect()
	draw_rect(rect, Color(0.025, 0.02, 0.016, 1.0), true)
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var cell_rect := _cell_rect(cell).grow(-1.0)
			var fill := Color(0.13, 0.11, 0.09, 1.0) if _is_open(cell) else Color(0.36, 0.21, 0.10, 1.0)
			if cell == hovered_cell:
				fill = fill.lightened(0.14)
			if _manhattan_distance(cell, peon_cell) <= PEON_BUILD_RANGE:
				fill = fill.lerp(Color(0.20, 0.38, 0.46, 1.0), 0.13)
			draw_rect(cell_rect, fill, true)
			draw_rect(cell_rect, Color(0.07, 0.045, 0.025, 0.9), false, 1.0)
	if current_path.size() > 1:
		for index in current_path.size() - 1:
			draw_line(_cell_center(current_path[index]), _cell_center(current_path[index + 1]), Color(0.34, 0.75, 0.98, 0.72), 5.0, true)
	var radius := minf(_cell_rect(ENTRANCE).size.x, _cell_rect(ENTRANCE).size.y) * 0.25
	draw_circle(_cell_center(ENTRANCE), radius, Color(0.30, 0.92, 0.38, 1.0))
	draw_circle(_cell_center(PORTAL), radius, Color(0.72, 0.30, 1.0, 1.0))
	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
		var enemy_type := str(enemy.get("type", "Rat"))
		var enemy_color := Color(0.78, 0.72, 0.58, 1.0)
		var enemy_radius := radius * 0.7
		if enemy_type == "Orc":
			enemy_color = Color(0.36, 0.76, 0.30, 1.0)
			enemy_radius = radius * 1.05
		elif enemy_type == "Spider":
			enemy_color = Color(0.65, 0.32, 0.82, 1.0)
		draw_circle(_enemy_position(enemy), enemy_radius, enemy_color)
	var peon_position := _cell_center(peon_cell)
	draw_circle(peon_position, radius * 1.35, Color(0.35, 0.86, 1.0, 0.20))
	draw_circle(peon_position, radius * 0.78, Color(0.95, 0.82, 0.28, 1.0))
	draw_line(peon_position + Vector2(-radius, 0), peon_position + Vector2(radius, 0), Color.WHITE, 2.0)
	draw_line(peon_position + Vector2(0, -radius), peon_position + Vector2(0, radius), Color.WHITE, 2.0)

func _set_status(message: String) -> void:
	status_text = message
	builder_status_changed.emit(message)
	_update_ui()
	queue_redraw()

func _on_mouse_exited() -> void:
	hovered_cell = Vector2i(-1, -1)
	queue_redraw()

func _update_ui() -> void:
	if not is_node_ready():
		return
	title_label.text = "SURFACE DELAY MAZE  •  FLYING BUILDER PEON"
	var eta := get_estimated_first_arrival()
	var eta_text := "CLEAR" if eta < 0.0 else "%ds" % int(ceil(eta))
	stats_label.text = "Dig %d  •  Route %d tiles  •  Invaders %d  •  First arrival %s" % [dig_points, current_path.size(), get_enemy_count(), eta_text]
	status_label.text = status_text
	reset_button.disabled = not builder_active or not enemies.is_empty()
