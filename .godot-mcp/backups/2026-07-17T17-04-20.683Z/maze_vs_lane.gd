extends Control

signal ready_changed(is_ready: bool)
signal wave_finished(lane: Control)
signal core_destroyed(lane: Control)
signal attack_changed(amount: int)

const COLS := 15
const ROWS := 9
const ENTRANCE := Vector2i(0, 1)
const CORE := Vector2i(COLS - 1, 1)
const BASE_BUILD_POINTS := 36
const CORE_MAX_HP := 10
const SPAWN_INTERVAL := 0.78

@onready var title_label: Label = $TitleLabel
@onready var stats_label: Label = $StatsLabel
@onready var status_label: Label = $StatusLabel
@onready var ready_button: Button = $ReadyButton
@onready var send_button: Button = $SendButton
@onready var reset_button: Button = $ResetButton

var player_number := 1
var player_label := "Player 1"
var current_round := 1
var core_hp := CORE_MAX_HP
var build_points := BASE_BUILD_POINTS
var send_capacity := 2
var queued_attack := 0
var is_ready := false
var wave_running := false
var grid: Array[bool] = []
var current_path: Array[Vector2i] = []
var enemies: Array[Dictionary] = []
var spawn_total := 0
var spawned_count := 0
var spawn_clock := 0.0
var enemy_hp := 10.0
var enemy_speed := 2.8
var defense_dps := 8.0
var status_text := "Dig a detour, then close part of the direct tunnel."
var _destroyed_emitted := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	ready_button.pressed.connect(_on_ready_pressed)
	send_button.pressed.connect(_on_send_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	resized.connect(queue_redraw)
	_reset_grid()
	_update_ui()
	queue_redraw()

func setup(display_name: String, number: int) -> void:
	player_label = display_name
	player_number = number
	if is_node_ready():
		_update_ui()

func enter_build_phase(round_number: int) -> void:
	current_round = round_number
	wave_running = false
	is_ready = false
	enemies.clear()
	build_points = BASE_BUILD_POINTS + max(0, current_round - 1) * 6
	send_capacity = 2 + int((current_round - 1) / 2)
	queued_attack = 0
	status_text = "Build phase: every edit must preserve one entrance-to-core path."
	ready_changed.emit(false)
	_update_path()
	_update_ui()
	queue_redraw()

func begin_wave(round_number: int, count: int, hp: float, speed: float) -> void:
	current_round = round_number
	_update_path()
	if current_path.is_empty():
		status_text = "No valid path. Reopen a tunnel before starting."
		is_ready = false
		ready_changed.emit(false)
		_update_ui()
		return
	wave_running = true
	is_ready = false
	spawn_total = max(1, count)
	spawned_count = 0
	spawn_clock = 0.0
	enemy_hp = hp
	enemy_speed = speed
	defense_dps = 8.0 + float(round_number - 1) * 0.35
	enemies.clear()
	status_text = "Wave %d: %d attackers incoming." % [round_number, spawn_total]
	_spawn_enemy()
	_update_ui()
	queue_redraw()

func consume_queued_attack() -> int:
	var result := queued_attack
	queued_attack = 0
	_update_ui()
	return result

func get_core_hp() -> int:
	return core_hp

func get_path_length() -> int:
	return current_path.size()

func is_lane_ready() -> bool:
	return is_ready

func is_wave_active() -> bool:
	return wave_running

func _process(delta: float) -> void:
	if not wave_running:
		return

	spawn_clock += delta
	while spawned_count < spawn_total and spawn_clock >= SPAWN_INTERVAL:
		spawn_clock -= SPAWN_INTERVAL
		_spawn_enemy()

	for enemy in enemies:
		enemy["progress"] = float(enemy["progress"]) + enemy_speed * delta

	var target_index := _front_enemy_index()
	if target_index >= 0:
		enemies[target_index]["hp"] = float(enemies[target_index]["hp"]) - defense_dps * delta

	for index in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[index]
		if float(enemy["hp"]) <= 0.0:
			enemies.remove_at(index)
			continue
		if float(enemy["progress"]) >= float(max(0, current_path.size() - 1)):
			enemies.remove_at(index)
			core_hp = max(0, core_hp - 1)
			status_text = "An attacker reached the core!"
			if core_hp <= 0:
				wave_running = false
				_update_ui()
				queue_redraw()
				if not _destroyed_emitted:
					_destroyed_emitted = true
					core_destroyed.emit(self)
				return

	if spawned_count >= spawn_total and enemies.is_empty():
		wave_running = false
		status_text = "Wave cleared. Compare the routes and rebuild."
		_update_ui()
		queue_redraw()
		wave_finished.emit(self)
		return

	_update_ui()
	queue_redraw()

func _spawn_enemy() -> void:
	if spawned_count >= spawn_total:
		return
	enemies.append({"progress": 0.0, "hp": enemy_hp, "max_hp": enemy_hp})
	spawned_count += 1

func _front_enemy_index() -> int:
	var result := -1
	var best_progress := -1.0
	for index in enemies.size():
		var progress := float(enemies[index]["progress"])
		if progress > best_progress:
			best_progress = progress
			result = index
	return result

func _gui_input(event: InputEvent) -> void:
	if wave_running or is_ready:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := _cell_from_position(event.position)
		if _is_in_bounds(cell):
			_toggle_cell(cell)
			accept_event()

func _toggle_cell(cell: Vector2i) -> void:
	if cell == ENTRANCE or cell == CORE:
		status_text = "The entrance and core cannot be changed."
		_update_ui()
		return

	var was_open := _is_open(cell)
	if was_open:
		_set_open(cell, false)
		var candidate := _find_path()
		if candidate.is_empty():
			_set_open(cell, true)
			status_text = "Blocked: the maze must always keep one complete route."
		else:
			build_points += 1
			current_path = candidate
			status_text = "Tunnel reinforced. The remaining route is now highlighted."
	else:
		if build_points <= 0:
			status_text = "No dig points left this round. Reinforce an open tile to refund one."
			_update_ui()
			return
		_set_open(cell, true)
		build_points -= 1
		_update_path()
		status_text = "Tunnel opened. Connect it twice to create a usable detour."

	is_ready = false
	ready_changed.emit(false)
	_update_ui()
	queue_redraw()

func _on_ready_pressed() -> void:
	if wave_running or core_hp <= 0:
		return
	_update_path()
	if current_path.is_empty():
		status_text = "A complete route is required before becoming ready."
		_update_ui()
		return
	is_ready = not is_ready
	status_text = "Ready. Route locked for this wave." if is_ready else "Build phase unlocked."
	ready_changed.emit(is_ready)
	_update_ui()
	queue_redraw()

func _on_send_pressed() -> void:
	if wave_running or is_ready:
		return
	queued_attack = (queued_attack + 1) % (send_capacity + 1)
	status_text = "Queued %d bonus attacker%s for the opponent." % [queued_attack, "" if queued_attack == 1 else "s"]
	attack_changed.emit(queued_attack)
	_update_ui()

func _on_reset_pressed() -> void:
	if wave_running or is_ready:
		return
	build_points = BASE_BUILD_POINTS + max(0, current_round - 1) * 6
	_reset_grid()
	status_text = "Direct safe tunnel restored. Dig a side loop before closing it."
	ready_changed.emit(false)
	_update_ui()
	queue_redraw()

func _reset_grid() -> void:
	grid.clear()
	grid.resize(COLS * ROWS)
	grid.fill(false)
	for x in COLS:
		_set_open(Vector2i(x, ENTRANCE.y), true)
	is_ready = false
	_update_path()

func _update_path() -> void:
	current_path = _find_path()

func _find_path() -> Array[Vector2i]:
	var empty_path: Array[Vector2i] = []
	if not _is_open(ENTRANCE) or not _is_open(CORE):
		return empty_path

	var frontier: Array[Vector2i] = [ENTRANCE]
	var came_from: Dictionary = {ENTRANCE: ENTRANCE}
	var head := 0
	while head < frontier.size():
		var current := frontier[head]
		head += 1
		if current == CORE:
			break
		for neighbor in _neighbors(current):
			if not came_from.has(neighbor) and _is_open(neighbor):
				came_from[neighbor] = current
				frontier.append(neighbor)

	if not came_from.has(CORE):
		return empty_path

	var result: Array[Vector2i] = []
	var cursor := CORE
	result.append(cursor)
	while cursor != ENTRANCE:
		cursor = came_from[cursor] as Vector2i
		result.append(cursor)
	result.reverse()
	return result

func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := cell + direction
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

func _board_rect() -> Rect2:
	return Rect2(10.0, 78.0, max(1.0, size.x - 20.0), max(1.0, size.y - 150.0))

func _cell_from_position(position: Vector2) -> Vector2i:
	var rect := _board_rect()
	if not rect.has_point(position):
		return Vector2i(-1, -1)
	var local := position - rect.position
	return Vector2i(
		int(floor(local.x / (rect.size.x / float(COLS)))),
		int(floor(local.y / (rect.size.y / float(ROWS))))
	)

func _cell_rect(cell: Vector2i) -> Rect2:
	var rect := _board_rect()
	var cell_size := Vector2(rect.size.x / float(COLS), rect.size.y / float(ROWS))
	return Rect2(rect.position + Vector2(cell.x, cell.y) * cell_size, cell_size)

func _cell_center(cell: Vector2i) -> Vector2:
	return _cell_rect(cell).get_center()

func _enemy_position(progress: float) -> Vector2:
	if current_path.is_empty():
		return Vector2.ZERO
	var clamped := clampf(progress, 0.0, float(current_path.size() - 1))
	var index := int(floor(clamped))
	if index >= current_path.size() - 1:
		return _cell_center(current_path[-1])
	var fraction := clamped - float(index)
	return _cell_center(current_path[index]).lerp(_cell_center(current_path[index + 1]), fraction)

func _draw() -> void:
	var rect := _board_rect()
	draw_rect(rect, Color(0.035, 0.028, 0.022, 1.0), true)

	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var cell_rect := _cell_rect(cell).grow(-1.0)
			var fill := Color(0.12, 0.105, 0.09, 1.0) if _is_open(cell) else Color(0.34, 0.20, 0.10, 1.0)
			draw_rect(cell_rect, fill, true)
			draw_rect(cell_rect, Color(0.07, 0.05, 0.035, 0.9), false, 1.0)

	if current_path.size() > 1:
		for index in current_path.size() - 1:
			draw_line(_cell_center(current_path[index]), _cell_center(current_path[index + 1]), Color(0.30, 0.72, 0.94, 0.72), 5.0, true)

	var marker_radius := min(_cell_rect(ENTRANCE).size.x, _cell_rect(ENTRANCE).size.y) * 0.26
	draw_circle(_cell_center(ENTRANCE), marker_radius, Color(0.24, 0.85, 0.35, 1.0))
	draw_circle(_cell_center(CORE), marker_radius, Color(1.0, 0.72, 0.18, 1.0))

	for enemy in enemies:
		var position := _enemy_position(float(enemy["progress"]))
		var radius := max(4.0, marker_radius * 0.68)
		draw_circle(position, radius, Color(0.90, 0.18, 0.14, 1.0))
		var hp_ratio := clampf(float(enemy["hp"]) / float(enemy["max_hp"]), 0.0, 1.0)
		var bar_rect := Rect2(position + Vector2(-radius, -radius - 5.0), Vector2(radius * 2.0, 3.0))
		draw_rect(bar_rect, Color(0.10, 0.04, 0.03, 1.0), true)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * hp_ratio, bar_rect.size.y)), Color(0.35, 0.95, 0.35, 1.0), true)

	if is_ready and not wave_running:
		draw_rect(rect, Color(0.05, 0.15, 0.06, 0.18), true)

func _update_ui() -> void:
	if not is_node_ready():
		return
	title_label.text = "%s  •  Core %d/%d" % [player_label, core_hp, CORE_MAX_HP]
	stats_label.text = "Dig %d   |   Route %d tiles   |   Send %d/%d" % [build_points, current_path.size(), queued_attack, send_capacity]
	status_label.text = status_text
	ready_button.text = "UNREADY" if is_ready else "READY"
	ready_button.disabled = wave_running or core_hp <= 0
	send_button.text = "ATTACK: %d / %d" % [queued_attack, send_capacity]
	send_button.disabled = wave_running or is_ready or core_hp <= 0
	reset_button.disabled = wave_running or is_ready or core_hp <= 0
