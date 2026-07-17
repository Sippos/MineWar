extends Control

signal enemy_purchased(enemy_type: String)
signal core_destroyed(lane: Control)
signal economy_changed

const COLS := 15
const ROWS := 9
const ENTRANCE := Vector2i(0, 1)
const CORE := Vector2i(COLS - 1, 1)
const BASE_BUILD_POINTS := 36
const CORE_MAX_HP := 10
const RAT_COST := 2
const RAT_INCOME_GAIN := 1
const ORC_COST := 7
const ORC_INCOME_GAIN := 2
const ABILITY_COOLDOWN := 9.0

@onready var title_label: Label = $TitleLabel
@onready var stats_label: Label = $StatsLabel
@onready var status_label: Label = $StatusLabel
@onready var rat_button: Button = $RatButton
@onready var orc_button: Button = $OrcButton
@onready var ability_button: Button = $AbilityButton
@onready var reset_button: Button = $ResetButton

var player_number := 1
var player_label := "Player 1"
var hero_name := "Dwarf"
var current_round := 1
var core_hp := CORE_MAX_HP
var build_points := BASE_BUILD_POINTS
var gold := 8
var income := 2
var combat_active := false
var grid: Array[bool] = []
var current_path: Array[Vector2i] = []
var enemies: Array[Dictionary] = []
var defense_dps := 8.0
var ability_cooldown := 0.0
var status_text := "Build a detour before combat begins."
var hovered_cell := Vector2i(-1, -1)
var _destroyed_emitted := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	rat_button.pressed.connect(_purchase_rat)
	orc_button.pressed.connect(_purchase_orc)
	ability_button.pressed.connect(_use_hero_ability)
	reset_button.pressed.connect(_on_reset_pressed)
	resized.connect(queue_redraw)
	_reset_grid()
	_update_ui()
	queue_redraw()

func setup(display_name: String, number: int, selected_hero: String) -> void:
	player_label = display_name
	player_number = number
	hero_name = selected_hero
	if is_node_ready():
		_update_ui()

func enter_preparation() -> void:
	combat_active = false
	current_round = 1
	core_hp = CORE_MAX_HP
	build_points = BASE_BUILD_POINTS
	gold = 8
	income = 2
	ability_cooldown = 0.0
	enemies.clear()
	_destroyed_emitted = false
	_reset_grid()
	status_text = "Opening build phase: create a longer route before sends unlock."
	_update_ui()
	queue_redraw()

func start_combat() -> void:
	combat_active = true
	status_text = "Combat live: dig, send enemies, and react at the same time."
	_update_ui()

func start_round(round_number: int) -> void:
	current_round = round_number
	defense_dps = 8.0 + float(current_round - 1) * 0.45
	if current_round > 1:
		build_points += 6
		income += 1
	status_text = "Round %d: +6 dig points and stronger passive income." % current_round
	_update_ui()
	economy_changed.emit()

func grant_income() -> void:
	if not combat_active or core_hp <= 0:
		return
	gold += income
	status_text = "+%d gold income received." % income
	_update_ui()
	economy_changed.emit()

func receive_enemy(enemy_type: String, sender_round: int) -> void:
	if not combat_active or core_hp <= 0:
		return
	var path := _find_path_from(ENTRANCE)
	if path.is_empty():
		return
	var enemy := _enemy_definition(enemy_type, sender_round)
	enemy["cell"] = ENTRANCE
	enemy["path"] = path
	enemy["path_index"] = 0
	enemy["segment_progress"] = 0.0
	enemy["slow_timer"] = 0.0
	enemies.append(enemy)
	status_text = "%s entered the mine!" % enemy_type
	_update_ui()
	queue_redraw()

func get_core_hp() -> int:
	return core_hp

func get_enemy_count() -> int:
	return enemies.size()

func get_gold() -> int:
	return gold

func get_income() -> int:
	return income

func get_path_length() -> int:
	return current_path.size()

func get_route_rating() -> String:
	var length := current_path.size()
	if length <= 15:
		return "CRITICAL"
	if length <= 19:
		return "RISKY"
	if length <= 25:
		return "HOLDING"
	return "FORTIFIED"

func is_combat_active() -> bool:
	return combat_active

func _process(delta: float) -> void:
	if ability_cooldown > 0.0:
		ability_cooldown = maxf(0.0, ability_cooldown - delta)

	if not combat_active or enemies.is_empty() or core_hp <= 0:
		_update_ui()
		return

	var target_index := _front_enemy_index()
	if target_index >= 0:
		enemies[target_index]["hp"] = float(enemies[target_index]["hp"]) - defense_dps * delta

	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
		var slow_timer := maxf(0.0, float(enemy.get("slow_timer", 0.0)) - delta)
		enemy["slow_timer"] = slow_timer
		_advance_enemy(enemy, delta)

	for index in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[index]
		if float(enemy["hp"]) <= 0.0:
			enemies.remove_at(index)
			continue
		if bool(enemy.get("reached_core", false)):
			var damage := int(enemy.get("core_damage", 1))
			enemies.remove_at(index)
			core_hp = maxi(0, core_hp - damage)
			status_text = "%s hit the core for %d!" % [str(enemy.get("type", "Enemy")), damage]
			if core_hp <= 0:
				combat_active = false
				if not _destroyed_emitted:
					_destroyed_emitted = true
					core_destroyed.emit(self)
				break

	_update_ui()
	queue_redraw()

func _advance_enemy(enemy: Dictionary, delta: float) -> void:
	var path: Array = enemy.get("path", [])
	if path.size() < 2:
		enemy["reached_core"] = true
		return
	var path_index := int(enemy.get("path_index", 0))
	var segment_progress := float(enemy.get("segment_progress", 0.0))
	var effective_speed := float(enemy.get("speed", 2.5))
	if float(enemy.get("slow_timer", 0.0)) > 0.0:
		effective_speed *= 0.58
	segment_progress += effective_speed * delta
	while segment_progress >= 1.0:
		segment_progress -= 1.0
		path_index += 1
		if path_index >= path.size():
			enemy["reached_core"] = true
			return
		enemy["cell"] = Vector2i(path[path_index])
		if path_index >= path.size() - 1:
			enemy["reached_core"] = true
			return
	enemy["path_index"] = path_index
	enemy["segment_progress"] = segment_progress

func _enemy_definition(enemy_type: String, sender_round: int) -> Dictionary:
	var round_scale := maxi(1, sender_round)
	if enemy_type == "Orc":
		var orc_hp := 32.0 + float(round_scale - 1) * 4.5
		return {
			"type": "Orc",
			"hp": orc_hp,
			"max_hp": orc_hp,
			"speed": 1.72 + float(round_scale - 1) * 0.025,
			"core_damage": 2,
			"radius_scale": 1.12,
			"color": Color(0.34, 0.66, 0.22, 1.0),
		}
	var rat_hp := 8.0 + float(round_scale - 1) * 1.4
	return {
		"type": "Rat",
		"hp": rat_hp,
		"max_hp": rat_hp,
		"speed": 3.75 + float(round_scale - 1) * 0.055,
		"core_damage": 1,
		"radius_scale": 0.68,
		"color": Color(0.78, 0.32, 0.22, 1.0),
	}

func _front_enemy_index() -> int:
	var result := -1
	var shortest_remaining := INF
	for index in enemies.size():
		var enemy: Dictionary = enemies[index]
		var path: Array = enemy.get("path", [])
		var path_index := int(enemy.get("path_index", 0))
		var remaining := float(maxi(0, path.size() - 1 - path_index)) - float(enemy.get("segment_progress", 0.0))
		if remaining < shortest_remaining:
			shortest_remaining = remaining
			result = index
	return result

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered_cell = _cell_from_position(event.position)
		queue_redraw()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := _cell_from_position(event.position)
		if _is_in_bounds(cell):
			_toggle_cell(cell)
			accept_event()

func _unhandled_input(event: InputEvent) -> void:
	var action_name := "p%d_stomp" % player_number
	if combat_active and InputMap.has_action(action_name) and event.is_action_pressed(action_name):
		_use_hero_ability()

func _toggle_cell(cell: Vector2i) -> void:
	if core_hp <= 0:
		return
	if cell == ENTRANCE or cell == CORE:
		status_text = "The entrance and core cannot be changed."
		_update_ui()
		return

	var was_open := _is_open(cell)
	if was_open:
		if _enemy_occupies_cell(cell):
			status_text = "Blocked: an enemy currently occupies that tunnel."
			_update_ui()
			return
		_set_open(cell, false)
		var entrance_path := _find_path_from(ENTRANCE)
		if entrance_path.is_empty() or not _all_enemies_can_reach_core():
			_set_open(cell, true)
			status_text = "Blocked: this edit would strand the route or an active enemy."
			_update_ui()
			return
		build_points += 1
		current_path = entrance_path
		status_text = "Tunnel reinforced. Active enemies rerouted immediately."
	else:
		if build_points <= 0:
			status_text = "No dig points left. Reinforce an unused tunnel to refund one."
			_update_ui()
			return
		_set_open(cell, true)
		build_points -= 1
		_update_path()
		status_text = "Tunnel opened. Any shortcut is usable immediately."

	_reroute_all_enemies()
	_update_ui()
	queue_redraw()

func _all_enemies_can_reach_core() -> bool:
	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
		var current_cell := Vector2i(enemy.get("cell", ENTRANCE))
		if _find_path_from(current_cell).is_empty():
			return false
	return true

func _enemy_occupies_cell(cell: Vector2i) -> bool:
	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
		if Vector2i(enemy.get("cell", ENTRANCE)) == cell:
			return true
		var path: Array = enemy.get("path", [])
		var path_index := int(enemy.get("path_index", 0))
		if path_index + 1 < path.size() and float(enemy.get("segment_progress", 0.0)) > 0.12:
			if Vector2i(path[path_index + 1]) == cell:
				return true
	return false

func _reroute_all_enemies() -> void:
	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
		var current_cell := Vector2i(enemy.get("cell", ENTRANCE))
		var new_path := _find_path_from(current_cell)
		if new_path.is_empty():
			continue
		enemy["path"] = new_path
		enemy["path_index"] = 0
		enemy["segment_progress"] = 0.0

func _purchase_rat() -> void:
	_purchase_enemy("Rat", RAT_COST, RAT_INCOME_GAIN)

func _purchase_orc() -> void:
	if current_round < 2:
		status_text = "Orcs unlock in Round 2."
		_update_ui()
		return
	_purchase_enemy("Orc", ORC_COST, ORC_INCOME_GAIN)

func _purchase_enemy(enemy_type: String, cost: int, income_gain: int) -> void:
	if not combat_active or core_hp <= 0:
		return
	if gold < cost:
		status_text = "Not enough gold for %s." % enemy_type
		_update_ui()
		return
	gold -= cost
	income += income_gain
	status_text = "%s sent instantly. Future income +%d." % [enemy_type, income_gain]
	enemy_purchased.emit(enemy_type)
	economy_changed.emit()
	_update_ui()

func _use_hero_ability() -> void:
	if not combat_active or enemies.is_empty() or ability_cooldown > 0.0 or core_hp <= 0:
		return
	match hero_name:
		"Dwarf":
			for enemy in enemies:
				enemy["hp"] = float(enemy["hp"]) - (8.0 + float(current_round))
			status_text = "Ground Stomp damaged every invader."
		"Shaman":
			var targets := _front_enemy_indices(4)
			for index in targets:
				enemies[index]["hp"] = float(enemies[index]["hp"]) - (12.0 + float(current_round) * 1.5)
			status_text = "Chain Lightning struck the leading enemies."
		"Nerubian":
			for enemy in enemies:
				enemy["slow_timer"] = 3.5
			status_text = "Web Burst slowed the entire invasion."
		"Druid":
			for enemy in enemies:
				var path: Array = enemy.get("path", [])
				var path_index := maxi(0, int(enemy.get("path_index", 0)) - 2)
				if not path.is_empty():
					enemy["path_index"] = path_index
					enemy["cell"] = Vector2i(path[path_index])
					enemy["segment_progress"] = 0.0
			status_text = "Deep Roots dragged the invasion backward."
		"Undead King":
			var kills := 0
			for enemy in enemies:
				var before := float(enemy["hp"])
				enemy["hp"] = before - (7.0 + float(current_round))
				if before > 0.0 and float(enemy["hp"]) <= 0.0:
					kills += 1
			core_hp = mini(CORE_MAX_HP, core_hp + mini(2, kills))
			status_text = "Soul Nova damaged enemies and repaired the core."
		_:
			for enemy in enemies:
				enemy["hp"] = float(enemy["hp"]) - 8.0
			status_text = "Hero burst damaged every invader."
	ability_cooldown = ABILITY_COOLDOWN
	_update_ui()
	queue_redraw()

func _front_enemy_indices(limit: int) -> Array[int]:
	var ranked: Array[Dictionary] = []
	for index in enemies.size():
		var enemy: Dictionary = enemies[index]
		var path: Array = enemy.get("path", [])
		var remaining := float(maxi(0, path.size() - 1 - int(enemy.get("path_index", 0)))) - float(enemy.get("segment_progress", 0.0))
		ranked.append({"index": index, "remaining": remaining})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["remaining"]) < float(b["remaining"]))
	var result: Array[int] = []
	for entry in ranked:
		if result.size() >= limit:
			break
		result.append(int(entry["index"]))
	return result

func _on_reset_pressed() -> void:
	if combat_active or core_hp <= 0:
		return
	build_points = BASE_BUILD_POINTS
	_reset_grid()
	status_text = "Direct tunnel restored. Build a detour before combat starts."
	_update_ui()
	queue_redraw()

func _reset_grid() -> void:
	grid.clear()
	grid.resize(COLS * ROWS)
	grid.fill(false)
	for x in COLS:
		_set_open(Vector2i(x, ENTRANCE.y), true)
	_update_path()

func _update_path() -> void:
	current_path = _find_path_from(ENTRANCE)

func _find_path_from(start: Vector2i) -> Array[Vector2i]:
	var empty_path: Array[Vector2i] = []
	if not _is_open(start) or not _is_open(CORE):
		return empty_path
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
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
	while cursor != start:
		cursor = Vector2i(came_from[cursor])
		result.append(cursor)
	result.reverse()
	return result

func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction_value in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := cell + Vector2i(direction_value)
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
	var path: Array = enemy.get("path", [])
	if path.is_empty():
		return _cell_center(ENTRANCE)
	var path_index := clampi(int(enemy.get("path_index", 0)), 0, path.size() - 1)
	if path_index >= path.size() - 1:
		return _cell_center(Vector2i(path[-1]))
	var from := _cell_center(Vector2i(path[path_index]))
	var to := _cell_center(Vector2i(path[path_index + 1]))
	return from.lerp(to, clampf(float(enemy.get("segment_progress", 0.0)), 0.0, 1.0))

func _draw() -> void:
	var rect := _board_rect()
	draw_rect(rect, Color(0.035, 0.028, 0.022, 1.0), true)
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var cell_rect := _cell_rect(cell).grow(-1.0)
			var fill := Color(0.12, 0.105, 0.09, 1.0) if _is_open(cell) else Color(0.34, 0.20, 0.10, 1.0)
			if cell == hovered_cell:
				fill = fill.lightened(0.16)
			draw_rect(cell_rect, fill, true)
			draw_rect(cell_rect, Color(0.07, 0.05, 0.035, 0.9), false, 1.0)
	if current_path.size() > 1:
		for index in current_path.size() - 1:
			draw_line(_cell_center(current_path[index]), _cell_center(current_path[index + 1]), Color(0.30, 0.72, 0.94, 0.72), 5.0, true)
	var marker_radius := minf(_cell_rect(ENTRANCE).size.x, _cell_rect(ENTRANCE).size.y) * 0.26
	draw_circle(_cell_center(ENTRANCE), marker_radius, Color(0.24, 0.85, 0.35, 1.0))
	draw_circle(_cell_center(CORE), marker_radius, Color(1.0, 0.72, 0.18, 1.0))
	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
		var position := _enemy_position(enemy)
		var radius := maxf(4.0, marker_radius * float(enemy.get("radius_scale", 0.7)))
		var enemy_color: Color = enemy.get("color", Color.RED)
		if float(enemy.get("slow_timer", 0.0)) > 0.0:
			enemy_color = enemy_color.lerp(Color(0.35, 0.65, 1.0, 1.0), 0.55)
		draw_circle(position, radius, enemy_color)
		var hp_ratio := clampf(float(enemy["hp"]) / float(enemy["max_hp"]), 0.0, 1.0)
		var bar_rect := Rect2(position + Vector2(-radius, -radius - 5.0), Vector2(radius * 2.0, 3.0))
		draw_rect(bar_rect, Color(0.10, 0.04, 0.03, 1.0), true)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * hp_ratio, bar_rect.size.y)), Color(0.35, 0.95, 0.35, 1.0), true)
	if not combat_active:
		draw_rect(rect, Color(0.05, 0.12, 0.18, 0.10), true)

func _ability_title() -> String:
	match hero_name:
		"Dwarf": return "GROUND STOMP"
		"Shaman": return "CHAIN LIGHTNING"
		"Nerubian": return "WEB BURST"
		"Druid": return "DEEP ROOTS"
		"Undead King": return "SOUL NOVA"
	return "HERO BURST"

func _update_ui() -> void:
	if not is_node_ready():
		return
	title_label.text = "%s • %s • Core %d/%d" % [player_label, hero_name, core_hp, CORE_MAX_HP]
	stats_label.text = "Gold %d • Income %d • Dig %d • Route %d %s" % [gold, income, build_points, current_path.size(), get_route_rating()]
	status_label.text = status_text
	rat_button.text = "RAT  %dg  (+%d INC)" % [RAT_COST, RAT_INCOME_GAIN]
	orc_button.text = "ORC LOCKED • ROUND 2" if current_round < 2 else "ORC  %dg  (+%d INC)" % [ORC_COST, ORC_INCOME_GAIN]
	rat_button.disabled = not combat_active or gold < RAT_COST or core_hp <= 0
	orc_button.disabled = not combat_active or current_round < 2 or gold < ORC_COST or core_hp <= 0
	ability_button.text = "%s  %.1fs" % [_ability_title(), ability_cooldown] if ability_cooldown > 0.0 else _ability_title()
	ability_button.disabled = not combat_active or enemies.is_empty() or ability_cooldown > 0.0 or core_hp <= 0
	reset_button.disabled = combat_active or core_hp <= 0
