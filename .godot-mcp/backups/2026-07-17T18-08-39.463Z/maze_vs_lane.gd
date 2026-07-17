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
const RUNNER_COST := 1
const BRUTE_COST := 2
const ABILITY_COOLDOWN := 9.0

@onready var title_label: Label = $TitleLabel
@onready var stats_label: Label = $StatsLabel
@onready var status_label: Label = $StatusLabel
@onready var ready_button: Button = $ReadyButton
@onready var runner_button: Button = $RunnerButton
@onready var brute_button: Button = $BruteButton
@onready var ability_button: Button = $AbilityButton
@onready var reset_button: Button = $ResetButton

var player_number := 1
var player_label := "Player 1"
var hero_name := "Dwarf"
var current_round := 1
var core_hp := CORE_MAX_HP
var build_points := BASE_BUILD_POINTS
var send_capacity := 3
var queued_runners := 0
var queued_brutes := 0
var is_ready := false
var wave_running := false
var grid: Array[bool] = []
var current_path: Array[Vector2i] = []
var enemies: Array[Dictionary] = []
var spawn_queue: Array[Dictionary] = []
var spawn_total := 0
var spawned_count := 0
var spawn_clock := 0.0
var defense_dps := 8.0
var ability_cooldown := 0.0
var slow_timer := 0.0
var ability_flash_timer := 0.0
var ability_flash_color := Color(1.0, 0.82, 0.28, 0.0)
var hovered_cell := Vector2i(-1, -1)
var status_text := "Dig a detour, then close part of the direct tunnel."
var _destroyed_emitted := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	ready_button.pressed.connect(_on_ready_pressed)
	runner_button.pressed.connect(_on_runner_pressed)
	brute_button.pressed.connect(_on_brute_pressed)
	ability_button.pressed.connect(activate_hero_ability)
	reset_button.pressed.connect(_on_reset_pressed)
	runner_button.gui_input.connect(_on_runner_gui_input)
	brute_button.gui_input.connect(_on_brute_gui_input)
	resized.connect(queue_redraw)
	_reset_grid()
	_configure_tooltips()
	_update_ui()
	queue_redraw()

func setup(display_name: String, number: int, selected_hero: String = "Dwarf") -> void:
	player_label = display_name
	player_number = number
	hero_name = selected_hero
	if is_node_ready():
		_configure_tooltips()
		_update_ui()

func enter_build_phase(round_number: int) -> void:
	current_round = round_number
	wave_running = false
	is_ready = false
	enemies.clear()
	spawn_queue.clear()
	build_points = BASE_BUILD_POINTS + max(0, current_round - 1) * 6
	send_capacity = 3 + int((current_round - 1) / 2)
	queued_runners = 0
	queued_brutes = 0
	ability_cooldown = 0.0
	slow_timer = 0.0
	status_text = "Build phase: every edit must preserve one entrance-to-core path."
	ready_changed.emit(false)
	attack_changed.emit(0)
	_update_path()
	_update_ui()
	queue_redraw()

func begin_wave(round_number: int, base_count: int, hp: float, speed: float, bonus_attackers: Array[String]) -> void:
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
	spawn_queue.clear()
	for attacker_type in bonus_attackers:
		spawn_queue.append(_make_enemy(attacker_type, hp, speed))
	for _index in max(1, base_count):
		spawn_queue.append(_make_enemy("raider", hp, speed))
	spawn_total = spawn_queue.size()
	spawned_count = 0
	spawn_clock = 0.0
	defense_dps = 8.0 + float(round_number - 1) * 0.35
	ability_cooldown = 0.0
	slow_timer = 0.0
	enemies.clear()
	status_text = "Wave %d: %d attackers incoming. %s is ready." % [round_number, spawn_total, _ability_name()]
	_spawn_enemy()
	_update_ui()
	queue_redraw()

func consume_queued_attack() -> Array[String]:
	var result: Array[String] = []
	for _index in queued_runners:
		result.append("runner")
	for _index in queued_brutes:
		result.append("brute")
	queued_runners = 0
	queued_brutes = 0
	attack_changed.emit(0)
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

func get_queued_send_points() -> int:
	return _spent_send_points()

func _process(delta: float) -> void:
	ability_flash_timer = maxf(0.0, ability_flash_timer - delta)
	if not wave_running:
		if ability_flash_timer > 0.0:
			queue_redraw()
		return

	ability_cooldown = maxf(0.0, ability_cooldown - delta)
	slow_timer = maxf(0.0, slow_timer - delta)
	spawn_clock += delta
	while spawned_count < spawn_total and spawn_clock >= SPAWN_INTERVAL:
		spawn_clock -= SPAWN_INTERVAL
		_spawn_enemy()

	var speed_modifier := 0.46 if slow_timer > 0.0 else 1.0
	for enemy in enemies:
		var movement_speed: float = float(enemy["speed"])
		enemy["progress"] = float(enemy["progress"]) + movement_speed * speed_modifier * delta

	var target_index: int = _front_enemy_index()
	if target_index >= 0:
		enemies[target_index]["hp"] = float(enemies[target_index]["hp"]) - defense_dps * delta

	for index in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[index]
		if float(enemy["hp"]) <= 0.0:
			enemies.remove_at(index)
			continue
		if float(enemy["progress"]) >= float(max(0, current_path.size() - 1)):
			var core_damage: int = int(enemy["damage"])
			enemies.remove_at(index)
			core_hp = max(0, core_hp - core_damage)
			status_text = "%s reached the core for %d damage!" % [_enemy_display_name(str(enemy["kind"])), core_damage]
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

func _unhandled_input(event: InputEvent) -> void:
	var ability_action := "p%d_stomp" % player_number
	if InputMap.has_action(ability_action) and event.is_action_pressed(ability_action):
		activate_hero_ability()

func activate_hero_ability() -> void:
	if not wave_running or core_hp <= 0:
		return
	if ability_cooldown > 0.0:
		status_text = "%s recharges in %.1f seconds." % [_ability_name(), ability_cooldown]
		_update_ui()
		return
	if enemies.is_empty():
		status_text = "Wait for an attacker before using %s." % _ability_name()
		_update_ui()
		return

	match hero_name:
		"Shaman":
			_damage_front_enemies(4, 12.0 + float(current_round) * 0.8)
			status_text = "Chain Lightning struck the four leading attackers."
			ability_flash_color = Color(0.35, 0.75, 1.0, 0.30)
		"Nerubian":
			slow_timer = 3.6
			status_text = "Web Burst slowed every attacker for 3.6 seconds."
			ability_flash_color = Color(0.72, 0.78, 1.0, 0.24)
		"Druid":
			_push_back_front_enemies(3, 3.2)
			status_text = "Deep Roots dragged the leading attackers backward."
			ability_flash_color = Color(0.32, 0.86, 0.38, 0.26)
		"Undead King":
			var kills: int = _soul_nova_damage(6.0 + float(current_round) * 0.45)
			if kills > 0:
				core_hp = min(CORE_MAX_HP, core_hp + 1)
			status_text = "Soul Nova consumed %d attacker%s%s." % [kills, "" if kills == 1 else "s", " and repaired the core" if kills > 0 else ""]
			ability_flash_color = Color(0.62, 0.28, 0.82, 0.28)
		_:
			_damage_all_enemies(7.0 + float(current_round) * 0.65)
			status_text = "Ground Stomp damaged the entire wave."
			ability_flash_color = Color(1.0, 0.68, 0.18, 0.28)

	ability_cooldown = ABILITY_COOLDOWN
	ability_flash_timer = 0.48
	_update_ui()
	queue_redraw()

func _damage_all_enemies(amount: float) -> void:
	for enemy in enemies:
		enemy["hp"] = float(enemy["hp"]) - amount

func _damage_front_enemies(count: int, amount: float) -> void:
	for index in _front_enemy_indices(count):
		enemies[index]["hp"] = float(enemies[index]["hp"]) - amount

func _push_back_front_enemies(count: int, distance: float) -> void:
	for index in _front_enemy_indices(count):
		enemies[index]["progress"] = maxf(0.0, float(enemies[index]["progress"]) - distance)
		enemies[index]["hp"] = float(enemies[index]["hp"]) - 2.0

func _soul_nova_damage(amount: float) -> int:
	var kills := 0
	for enemy in enemies:
		var previous_hp: float = float(enemy["hp"])
		var next_hp := previous_hp - amount
		enemy["hp"] = next_hp
		if previous_hp > 0.0 and next_hp <= 0.0:
			kills += 1
	return kills

func _front_enemy_indices(count: int) -> Array[int]:
	var available: Array[int] = []
	for index in enemies.size():
		available.append(index)
	available.sort_custom(func(a: int, b: int) -> bool:
		return float(enemies[a]["progress"]) > float(enemies[b]["progress"])
	)
	if available.size() > count:
		available.resize(count)
	return available

func _make_enemy(kind: String, base_hp: float, base_speed: float) -> Dictionary:
	match kind:
		"runner":
			return {
				"kind": "runner",
				"progress": 0.0,
				"hp": base_hp * 0.66,
				"max_hp": base_hp * 0.66,
				"speed": base_speed * 1.55,
				"damage": 1,
				"color": Color(1.0, 0.58, 0.12, 1.0),
				"radius_scale": 0.78,
			}
		"brute":
			return {
				"kind": "brute",
				"progress": 0.0,
				"hp": base_hp * 2.15,
				"max_hp": base_hp * 2.15,
				"speed": base_speed * 0.62,
				"damage": 2,
				"color": Color(0.72, 0.24, 0.82, 1.0),
				"radius_scale": 1.22,
			}
		_:
			return {
				"kind": "raider",
				"progress": 0.0,
				"hp": base_hp,
				"max_hp": base_hp,
				"speed": base_speed,
				"damage": 1,
				"color": Color(0.90, 0.18, 0.14, 1.0),
				"radius_scale": 1.0,
			}

func _spawn_enemy() -> void:
	if spawned_count >= spawn_total:
		return
	var enemy_data: Dictionary = spawn_queue[spawned_count].duplicate(true)
	enemies.append(enemy_data)
	spawned_count += 1

func _front_enemy_index() -> int:
	var result := -1
	var best_progress := -1.0
	for index in enemies.size():
		var progress: float = float(enemies[index]["progress"])
		if progress > best_progress:
			best_progress = progress
			result = index
	return result

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		hovered_cell = _cell_from_position(motion_event.position)
		queue_redraw()
		return
	if wave_running or is_ready:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var cell: Vector2i = _cell_from_position(mouse_event.position)
			if _is_in_bounds(cell):
				_toggle_cell(cell)
				accept_event()

func _toggle_cell(cell: Vector2i) -> void:
	if cell == ENTRANCE or cell == CORE:
		status_text = "The entrance and core cannot be changed."
		_update_ui()
		return

	var was_open: bool = _is_open(cell)
	if was_open:
		_set_open(cell, false)
		var candidate: Array[Vector2i] = _find_path()
		if candidate.is_empty():
			_set_open(cell, true)
			status_text = "Blocked: the maze must always keep one complete route."
		else:
			build_points += 1
			current_path = candidate
			status_text = "Tunnel reinforced. Route rating: %s." % _route_rating()
	else:
		if build_points <= 0:
			status_text = "No dig points left. Reinforce an open tile to refund one."
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
	status_text = "Ready. %s route locked for this wave." % _route_rating() if is_ready else "Build phase unlocked."
	ready_changed.emit(is_ready)
	_update_ui()
	queue_redraw()

func _on_runner_pressed() -> void:
	if wave_running or is_ready:
		return
	if _remaining_send_points() < RUNNER_COST:
		status_text = "No pressure points left. Right-click a send button to undo."
		_update_ui()
		return
	queued_runners += 1
	status_text = "Queued a fast Runner for the opponent."
	attack_changed.emit(_spent_send_points())
	_update_ui()

func _on_brute_pressed() -> void:
	if wave_running or is_ready:
		return
	if _remaining_send_points() < BRUTE_COST:
		status_text = "A Brute costs 2 pressure points. Right-click a send to undo."
		_update_ui()
		return
	queued_brutes += 1
	status_text = "Queued a Brute: slow, durable, and worth 2 core damage."
	attack_changed.emit(_spent_send_points())
	_update_ui()

func _on_runner_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed and not wave_running and not is_ready:
			if queued_runners > 0:
				queued_runners -= 1
				status_text = "Removed one queued Runner."
				attack_changed.emit(_spent_send_points())
				_update_ui()
			runner_button.accept_event()

func _on_brute_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed and not wave_running and not is_ready:
			if queued_brutes > 0:
				queued_brutes -= 1
				status_text = "Removed one queued Brute."
				attack_changed.emit(_spent_send_points())
				_update_ui()
			brute_button.accept_event()

func _on_reset_pressed() -> void:
	if wave_running or is_ready:
		return
	build_points = BASE_BUILD_POINTS + max(0, current_round - 1) * 6
	queued_runners = 0
	queued_brutes = 0
	_reset_grid()
	status_text = "Direct tunnel restored and enemy sends cleared."
	ready_changed.emit(false)
	attack_changed.emit(0)
	_update_ui()
	queue_redraw()

func _spent_send_points() -> int:
	return queued_runners * RUNNER_COST + queued_brutes * BRUTE_COST

func _remaining_send_points() -> int:
	return max(0, send_capacity - _spent_send_points())

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
		var current: Vector2i = frontier[head]
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
	var cursor: Vector2i = CORE
	result.append(cursor)
	while cursor != ENTRANCE:
		cursor = Vector2i(came_from[cursor])
		result.append(cursor)
	result.reverse()
	return result

func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction_value in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var direction: Vector2i = direction_value
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

func _board_rect() -> Rect2:
	return Rect2(10.0, 78.0, maxf(1.0, size.x - 20.0), maxf(1.0, size.y - 150.0))

func _cell_from_position(position: Vector2) -> Vector2i:
	var rect: Rect2 = _board_rect()
	if not rect.has_point(position):
		return Vector2i(-1, -1)
	var local_position: Vector2 = position - rect.position
	return Vector2i(
		int(floor(local_position.x / (rect.size.x / float(COLS)))),
		int(floor(local_position.y / (rect.size.y / float(ROWS))))
	)

func _cell_rect(cell: Vector2i) -> Rect2:
	var rect: Rect2 = _board_rect()
	var cell_size := Vector2(rect.size.x / float(COLS), rect.size.y / float(ROWS))
	return Rect2(rect.position + Vector2(cell.x, cell.y) * cell_size, cell_size)

func _cell_center(cell: Vector2i) -> Vector2:
	return _cell_rect(cell).get_center()

func _enemy_position(progress: float) -> Vector2:
	if current_path.is_empty():
		return Vector2.ZERO
	var clamped: float = clampf(progress, 0.0, float(current_path.size() - 1))
	var index := int(floor(clamped))
	if index >= current_path.size() - 1:
		return _cell_center(current_path[-1])
	var fraction: float = clamped - float(index)
	return _cell_center(current_path[index]).lerp(_cell_center(current_path[index + 1]), fraction)

func _route_rating() -> String:
	var length := current_path.size()
	if length <= COLS:
		return "CRITICAL"
	if length <= 19:
		return "RISKY"
	if length <= 25:
		return "HOLDING"
	return "FORTIFIED"

func _ability_name() -> String:
	match hero_name:
		"Shaman":
			return "CHAIN LIGHTNING"
		"Nerubian":
			return "WEB BURST"
		"Druid":
			return "DEEP ROOTS"
		"Undead King":
			return "SOUL NOVA"
		_:
			return "GROUND STOMP"

func _enemy_display_name(kind: String) -> String:
	match kind:
		"runner":
			return "A Runner"
		"brute":
			return "A Brute"
		_:
			return "A Raider"

func _configure_tooltips() -> void:
	runner_button.tooltip_text = "Runner • Costs 1 pressure • Fast but fragile • Right-click to remove"
	brute_button.tooltip_text = "Brute • Costs 2 pressure • Slow, durable, deals 2 core damage • Right-click to remove"
	ability_button.tooltip_text = "%s • Press the player ability key during a wave" % _ability_name()
	reset_button.tooltip_text = "Restore the direct tunnel and clear queued attackers"

func _draw() -> void:
	var rect: Rect2 = _board_rect()
	draw_rect(rect, Color(0.035, 0.028, 0.022, 1.0), true)

	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var cell_rect: Rect2 = _cell_rect(cell).grow(-1.0)
			var fill := Color(0.12, 0.105, 0.09, 1.0) if _is_open(cell) else Color(0.34, 0.20, 0.10, 1.0)
			draw_rect(cell_rect, fill, true)
			draw_rect(cell_rect, Color(0.07, 0.05, 0.035, 0.9), false, 1.0)

	if current_path.size() > 1:
		for index in current_path.size() - 1:
			draw_line(_cell_center(current_path[index]), _cell_center(current_path[index + 1]), Color(0.30, 0.72, 0.94, 0.72), 5.0, true)

	var marker_radius: float = minf(_cell_rect(ENTRANCE).size.x, _cell_rect(ENTRANCE).size.y) * 0.26
	draw_circle(_cell_center(ENTRANCE), marker_radius, Color(0.24, 0.85, 0.35, 1.0))
	draw_circle(_cell_center(CORE), marker_radius, Color(1.0, 0.72, 0.18, 1.0))

	for enemy in enemies:
		var position: Vector2 = _enemy_position(float(enemy["progress"]))
		var radius_scale: float = float(enemy["radius_scale"])
		var radius: float = maxf(4.0, marker_radius * 0.68 * radius_scale)
		var enemy_color: Color = enemy["color"] as Color
		draw_circle(position, radius, enemy_color)
		if str(enemy["kind"]) == "brute":
			draw_circle(position, radius * 0.48, Color(0.18, 0.05, 0.22, 0.9))
		elif str(enemy["kind"]) == "runner":
			draw_line(position - Vector2(radius * 1.8, 0.0), position - Vector2(radius * 0.7, 0.0), enemy_color, 2.0)
		var hp_ratio: float = clampf(float(enemy["hp"]) / float(enemy["max_hp"]), 0.0, 1.0)
		var bar_rect := Rect2(position + Vector2(-radius, -radius - 5.0), Vector2(radius * 2.0, 3.0))
		draw_rect(bar_rect, Color(0.10, 0.04, 0.03, 1.0), true)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * hp_ratio, bar_rect.size.y)), Color(0.35, 0.95, 0.35, 1.0), true)

	if slow_timer > 0.0:
		draw_rect(rect, Color(0.32, 0.62, 1.0, 0.10), true)
	if ability_flash_timer > 0.0:
		var flash_alpha := ability_flash_color.a * (ability_flash_timer / 0.48)
		draw_rect(rect, Color(ability_flash_color.r, ability_flash_color.g, ability_flash_color.b, flash_alpha), true)
	if is_ready and not wave_running:
		draw_rect(rect, Color(0.05, 0.15, 0.06, 0.18), true)
	if not wave_running and not is_ready and _is_in_bounds(hovered_cell):
		draw_rect(_cell_rect(hovered_cell).grow(-2.0), Color(1.0, 0.86, 0.36, 0.9), false, 2.0)

func _update_ui() -> void:
	if not is_node_ready():
		return
	title_label.text = "%s  •  Core %d/%d" % [player_label, core_hp, CORE_MAX_HP]
	stats_label.text = "Dig %d  |  Route %d • %s  |  Pressure %d/%d" % [build_points, current_path.size(), _route_rating(), _spent_send_points(), send_capacity]
	status_label.text = status_text
	ready_button.text = "UNREADY" if is_ready else "READY"
	ready_button.disabled = wave_running or core_hp <= 0
	runner_button.text = "RUNNER %d" % queued_runners
	brute_button.text = "BRUTE %d" % queued_brutes
	runner_button.disabled = wave_running or is_ready or core_hp <= 0
	brute_button.disabled = wave_running or is_ready or core_hp <= 0
	if wave_running:
		ability_button.text = "%s %.1fs" % [_ability_name(), ability_cooldown] if ability_cooldown > 0.0 else "%s READY" % _ability_name()
	else:
		ability_button.text = _ability_name()
	ability_button.disabled = not wave_running or ability_cooldown > 0.0 or enemies.is_empty() or core_hp <= 0
	reset_button.disabled = wave_running or is_ready or core_hp <= 0
