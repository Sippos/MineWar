extends CharacterBody2D

const GEM_SCENE = preload("res://scenes/entities/collectibles/gems/gem.tscn")
const INVALID_CELL = Vector2i(999999, 999999)
const TARGET_SEARCH_RADIUS = 9
const WANDER_RADIUS = 7
const TARGET_RECHECK_TIME = 0.4

@export var max_lifetime := 70.0

var owner_player: Node2D = null
var state = "FIND_TARGET"
var target_cell = INVALID_CELL
var target_stand_cell = INVALID_CELL
var astar_path = []
var path_index = 0
var speed = 135.0
var dig_speed_multiplier := 1.0
var dig_timer = 0.0
var target_recheck_timer = 0.0
var anim_timer = 0.0
var current_anim_row = 0
var lifetime = 70.0

@onready var world = get_parent()
@onready var block_layer: TileMapLayer = world.get_node("BlockLayer")
@onready var damage_layer: TileMapLayer = world.get_node("DamageLayer")
@onready var front_damage_layer: TileMapLayer = world.get_node("FrontDamageLayer")
@onready var front_layer: TileMapLayer = world.get_node("FrontWallLayer")

func _ready() -> void:
	add_to_group("nerubian_spiders")
	add_to_group("friendly_minions")
	lifetime = max_lifetime
	randomize()

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		_clear_target_damage()
		queue_free()
		return
	
	target_recheck_timer -= delta
	match state:
		"FIND_TARGET":
			if _choose_dig_target():
				state = "MOVE_TO_TARGET"
			elif _choose_wander_path():
				state = "WANDER"
			else:
				velocity = Vector2.ZERO
		"MOVE_TO_TARGET":
			if not _is_diggable_cell(target_cell):
				_reset_target()
				state = "FIND_TARGET"
			elif _path_finished():
				state = "DIG"
				velocity = Vector2.ZERO
			else:
				move_along_path(delta)
		"DIG":
			if not _is_diggable_cell(target_cell):
				_reset_target()
				state = "FIND_TARGET"
			else:
				_dig_target(delta)
		"WANDER":
			if target_recheck_timer <= 0.0:
				target_recheck_timer = TARGET_RECHECK_TIME
				if _choose_dig_target():
					state = "MOVE_TO_TARGET"
					_update_animation(delta)
					return
			if _path_finished():
				state = "FIND_TARGET"
			else:
				move_along_path(delta)
	
	_update_animation(delta)
	_update_lifespan_visual()

func get_max_lifetime() -> float:
	return max_lifetime

func get_lifetime_ratio() -> float:
	return clamp(lifetime / max(max_lifetime, 0.01), 0.0, 1.0)

func _update_lifespan_visual() -> void:
	if not has_node("Sprite2D"):
		return
	var ratio = get_lifetime_ratio()
	$Sprite2D.modulate.a = clamp(0.35 + ratio * 0.65, 0.35, 1.0)

func _choose_dig_target() -> bool:
	var start_cell = _nearest_walkable_cell(global_position, 3)
	if start_cell == INVALID_CELL:
		return false
	
	var best_cell = INVALID_CELL
	var best_stand = INVALID_CELL
	var best_path = []
	var best_score = 999999.0
	
	for x in range(start_cell.x - TARGET_SEARCH_RADIUS, start_cell.x + TARGET_SEARCH_RADIUS + 1):
		for y in range(start_cell.y - TARGET_SEARCH_RADIUS, start_cell.y + TARGET_SEARCH_RADIUS + 1):
			var cell = Vector2i(x, y)
			if not _is_diggable_cell(cell):
				continue
			var stand_cells = _get_adjacent_walk_cells(cell)
			for stand_cell in stand_cells:
				var path = _build_path_between(start_cell, stand_cell)
				if path.size() == 0:
					continue
				var score = float(path.size()) + float(abs(cell.x - start_cell.x) + abs(cell.y - start_cell.y)) * 0.25
				if world.gem_blocks.has(cell):
					score -= 4.0
				if score < best_score:
					best_score = score
					best_cell = cell
					best_stand = stand_cell
					best_path = path
	
	if best_cell == INVALID_CELL:
		return false
	
	target_cell = best_cell
	target_stand_cell = best_stand
	_set_path(best_path)
	return true

func _choose_wander_path() -> bool:
	if not _path_finished():
		return true
	var start_cell = _nearest_walkable_cell(global_position, 3)
	if start_cell == INVALID_CELL:
		return false
	var candidate_paths = []
	for x in range(start_cell.x - WANDER_RADIUS, start_cell.x + WANDER_RADIUS + 1):
		for y in range(start_cell.y - WANDER_RADIUS, start_cell.y + WANDER_RADIUS + 1):
			var cell = Vector2i(x, y)
			var manhattan = abs(cell.x - start_cell.x) + abs(cell.y - start_cell.y)
			if manhattan < 2:
				continue
			if not _is_walkable_cell(cell):
				continue
			var path = _build_path_between(start_cell, cell)
			if path.size() > 1 and path.size() <= WANDER_RADIUS * 2:
				candidate_paths.append(path)
	if candidate_paths.size() == 0:
		return false
	_set_path(candidate_paths[randi() % candidate_paths.size()])
	return true

func _dig_target(delta: float) -> void:
	velocity = Vector2.ZERO
	dig_timer += delta
	var block_id = block_layer.get_cell_source_id(target_cell)
	var target_dig_time = 0.9
	if block_id == 2:
		target_dig_time = 1.8
	elif block_id == 3:
		target_dig_time = 3.2
	if is_instance_valid(owner_player):
		target_dig_time *= max(0.55, 1.0 - (float(owner_player.get("intelligence")) - 1.0) * 0.04)
	target_dig_time /= max(0.1, dig_speed_multiplier)
	
	var damage_progress = dig_timer / target_dig_time
	var source_id = 7 if damage_progress < 0.66 else 8
	damage_layer.set_cell(target_cell, source_id, Vector2i(0, 0))
	var below_cell = Vector2i(target_cell.x, target_cell.y + 1)
	if front_layer.get_cell_source_id(below_cell) != -1:
		var front_source_id = 13 if damage_progress < 0.66 else 14
		front_damage_layer.set_cell(below_cell, front_source_id, Vector2i(0, 0))
	
	if dig_timer >= target_dig_time:
		block_layer.erase_cell(target_cell)
		damage_layer.erase_cell(target_cell)
		front_damage_layer.erase_cell(below_cell)
		var cell_had_gem = world.has_gem(target_cell)
		world.on_cell_dug(target_cell)
		if cell_had_gem:
			_spawn_gem(target_cell)
		_reset_target()
		state = "FIND_TARGET"

func _spawn_gem(cell: Vector2i) -> void:
	var gem = GEM_SCENE.instantiate()
	gem.global_position = block_layer.to_global(block_layer.map_to_local(cell)) + Vector2(randf_range(-10, 10), randf_range(-8, 8))
	world.call_deferred("add_child", gem)

func move_along_path(_delta: float) -> void:
	if _path_finished():
		velocity = Vector2.ZERO
		return
	var target_path_cell = astar_path[path_index]
	var target_pos = block_layer.to_global(block_layer.map_to_local(target_path_cell)) + Vector2(0, 12)
	if global_position.distance_to(target_pos) < 6.0:
		path_index += 1
		if _path_finished():
			velocity = Vector2.ZERO
			return
		target_path_cell = astar_path[path_index]
		target_pos = block_layer.to_global(block_layer.map_to_local(target_path_cell)) + Vector2(0, 12)
	var dir = global_position.direction_to(target_pos)
	velocity = dir * speed
	move_and_slide()

func _set_path(path) -> void:
	astar_path = path
	path_index = 1 if astar_path.size() > 1 else 0

func _path_finished() -> bool:
	return path_index >= astar_path.size()

func _reset_target() -> void:
	_clear_target_damage()
	target_cell = INVALID_CELL
	target_stand_cell = INVALID_CELL
	dig_timer = 0.0
	astar_path.clear()
	path_index = 0

func _clear_target_damage() -> void:
	if target_cell == INVALID_CELL:
		return
	damage_layer.erase_cell(target_cell)
	front_damage_layer.erase_cell(Vector2i(target_cell.x, target_cell.y + 1))

func _nearest_walkable_cell(target_global: Vector2, max_radius: int) -> Vector2i:
	var center = block_layer.local_to_map(block_layer.to_local(target_global))
	if _is_walkable_cell(center):
		return center
	for radius in range(1, max_radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			for y in range(center.y - radius, center.y + radius + 1):
				if x != center.x - radius and x != center.x + radius and y != center.y - radius and y != center.y + radius:
					continue
				var cell = Vector2i(x, y)
				if _is_walkable_cell(cell):
					return cell
	return INVALID_CELL

func _get_adjacent_walk_cells(cell: Vector2i) -> Array:
	var cells = [
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1)
	]
	var result = []
	for c in cells:
		if _is_walkable_cell(c):
			result.append(c)
	return result

func _build_path_between(start_cell: Vector2i, end_cell: Vector2i):
	if not world or not world.astar:
		return []
	var astar = world.astar
	if not astar.is_in_bounds(start_cell.x, start_cell.y):
		return []
	if not astar.is_in_bounds(end_cell.x, end_cell.y):
		return []
	if astar.is_point_solid(start_cell) or astar.is_point_solid(end_cell):
		return []
	return astar.get_id_path(start_cell, end_cell)

func _is_walkable_cell(cell: Vector2i) -> bool:
	if not world or not world.astar:
		return false
	var astar = world.astar
	if not astar.is_in_bounds(cell.x, cell.y):
		return false
	if astar.is_point_solid(cell):
		return false
	return block_layer.get_cell_source_id(cell) == -1

func _is_diggable_cell(cell: Vector2i) -> bool:
	if not world or not world.astar:
		return false
	var astar = world.astar
	if not astar.is_in_bounds(cell.x, cell.y):
		return false
	if (cell.y <= 1 and cell.x != 0) or cell.y < 0:
		return false
	return block_layer.get_cell_source_id(cell) != -1

func _update_animation(delta: float) -> void:
	if velocity.length() > 0.1:
		var angle = velocity.angle()
		var PI_8 = PI / 8.0
		if angle > -PI_8 and angle <= PI_8:
			current_anim_row = 6
		elif angle > PI_8 and angle <= 3 * PI_8:
			current_anim_row = 7
		elif angle > 3 * PI_8 and angle <= 5 * PI_8:
			current_anim_row = 0
		elif angle > 5 * PI_8 and angle <= 7 * PI_8:
			current_anim_row = 1
		elif angle > 7 * PI_8 or angle <= -7 * PI_8:
			current_anim_row = 2
		elif angle > -7 * PI_8 and angle <= -5 * PI_8:
			current_anim_row = 3
		elif angle > -5 * PI_8 and angle <= -3 * PI_8:
			current_anim_row = 4
		elif angle > -3 * PI_8 and angle <= -PI_8:
			current_anim_row = 5
		anim_timer += delta * 12.0
		$Sprite2D.frame = current_anim_row * 8 + (int(anim_timer) % 8)
	else:
		anim_timer = 0.0
		$Sprite2D.frame = current_anim_row * 8
