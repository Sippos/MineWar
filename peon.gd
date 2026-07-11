extends CharacterBody2D

const INVALID_CELL = Vector2i(999999, 999999)
const WANDER_RADIUS = 7
const GEM_RECHECK_TIME = 0.6

var state = "IDLE"
var target_gem = null
var base_node = null

var astar_path = []
var path_index = 0

var speed = 120.0
var block_layer = null
var anim_timer = 0.0
var current_anim_row = 0
var gem_recheck_timer = 0.0
var last_walkable_cell = INVALID_CELL
var path_start_is_current = true

func _ready():
	add_to_group("peons")
	var world = get_parent()
	base_node = world.get_node_or_null("Base")
	block_layer = world.get_node_or_null("BlockLayer")
	last_walkable_cell = _nearest_walkable_cell(global_position, 8)
	randomize()

func _physics_process(delta):
	gem_recheck_timer -= delta
	
	if state == "IDLE":
		if gem_recheck_timer <= 0.0:
			gem_recheck_timer = GEM_RECHECK_TIME
			if _try_target_reachable_gem():
				state = "MOVE_TO_GEM"
			else:
				_choose_wander_path()
		
		move_along_path(delta)
		
	elif state == "MOVE_TO_GEM":
		if not is_instance_valid(target_gem):
			target_gem = null
			state = "IDLE"
			astar_path.clear()
			velocity = Vector2.ZERO
			_update_animation(delta)
			return
		
		if global_position.distance_to(target_gem.global_position) < 24.0:
			target_gem.queue_free()
			target_gem = null
			if base_node and _set_path_to_global(base_node.global_position):
				state = "RETURN_TO_BASE"
			else:
				state = "IDLE"
			_update_animation(delta)
			return
		
		if _path_finished():
			if not _set_path_to_global(target_gem.global_position):
				target_gem = null
				state = "IDLE"
				velocity = Vector2.ZERO
				_update_animation(delta)
				return
		
		move_along_path(delta)
		
	elif state == "RETURN_TO_BASE":
		if not base_node:
			state = "IDLE"
			velocity = Vector2.ZERO
			_update_animation(delta)
			return
		
		if global_position.distance_to(base_node.global_position) < 36.0:
			if base_node.has_signal("gems_deposited"):
				base_node.gems_deposited.emit(1)
			_find_next_job()
			velocity = Vector2.ZERO
			_update_animation(delta)
			return
		
		if _path_finished():
			if not _set_path_to_global(base_node.global_position):
				state = "IDLE"
				velocity = Vector2.ZERO
				_update_animation(delta)
				return
		
		move_along_path(delta)
	
	_update_animation(delta)

func _try_target_reachable_gem() -> bool:
	var gems = get_tree().get_nodes_in_group("gems")
	var best_gem = null
	var best_path = []
	var best_score = 999999.0
	
	for gem in gems:
		if not _is_collectible_gem(gem):
			continue
		
		var target_cell = _nearest_walkable_cell(gem.global_position, 4)
		if target_cell == INVALID_CELL:
			continue
		
		var path = _build_path_to_cell(target_cell)
		if path.size() == 0:
			continue
		
		var score = float(path.size()) + global_position.distance_to(gem.global_position) / 64.0
		if score < best_score:
			best_score = score
			best_gem = gem
			best_path = path
	
	if best_gem:
		target_gem = best_gem
		_set_path(best_path)
		return true
	return false

func _find_next_job() -> void:
	target_gem = null
	astar_path.clear()
	gem_recheck_timer = 0.0
	if _try_target_reachable_gem():
		state = "MOVE_TO_GEM"
	elif _choose_wander_path():
		state = "IDLE"
	else:
		state = "IDLE"

func _is_collectible_gem(gem) -> bool:
	if not is_instance_valid(gem):
		return false
	if gem.is_queued_for_deletion():
		return false
	if gem.is_in_group("rails"):
		return false
	if gem.tethered_to != null and is_instance_valid(gem.tethered_to):
		return false
	return true

func _choose_wander_path() -> bool:
	if not block_layer:
		return false
	if not _path_finished():
		return true
	
	var start_cell = _get_path_start_cell(8)
	if start_cell == INVALID_CELL:
		velocity = Vector2.ZERO
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
		velocity = Vector2.ZERO
		return false
	
	_set_path(candidate_paths[randi() % candidate_paths.size()])
	return true

func _set_path_to_global(target_global: Vector2) -> bool:
	var target_cell = _nearest_walkable_cell(target_global, 6)
	if target_cell == INVALID_CELL:
		return false
	var path = _build_path_to_cell(target_cell)
	if path.size() == 0:
		return false
	_set_path(path)
	return true

func _build_path_to_cell(end_cell: Vector2i):
	var start_cell = _get_path_start_cell(8)
	if start_cell == INVALID_CELL:
		return []
	return _build_path_between(start_cell, end_cell)

func _build_path_between(start_cell: Vector2i, end_cell: Vector2i):
	var world = get_parent()
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

func _set_path(path) -> void:
	astar_path = path
	path_index = 1 if path_start_is_current and astar_path.size() > 1 else 0

func _path_finished() -> bool:
	return path_index >= astar_path.size()

func _nearest_walkable_cell(target_global: Vector2, max_radius: int) -> Vector2i:
	if not block_layer:
		return INVALID_CELL
	
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

func _get_path_start_cell(max_radius: int) -> Vector2i:
	var cell = _nearest_walkable_cell(global_position, max_radius)
	if cell != INVALID_CELL:
		last_walkable_cell = cell
		path_start_is_current = true
		return cell
	if last_walkable_cell != INVALID_CELL and _is_walkable_cell(last_walkable_cell):
		path_start_is_current = false
		return last_walkable_cell
	path_start_is_current = true
	return INVALID_CELL

func _is_walkable_cell(cell: Vector2i) -> bool:
	if not block_layer:
		return false
	var world = get_parent()
	if not world or not world.astar:
		return false
	var astar = world.astar
	if not astar.is_in_bounds(cell.x, cell.y):
		return false
	if astar.is_point_solid(cell):
		return false
	return block_layer.get_cell_source_id(cell) == -1

func move_along_path(_delta):
	if _path_finished():
		velocity = Vector2.ZERO
		return
	
	var target_cell = astar_path[path_index]
	if not _is_walkable_cell(target_cell):
		astar_path.clear()
		path_index = 0
		velocity = Vector2.ZERO
		return
	last_walkable_cell = target_cell
	var target_pos = block_layer.to_global(block_layer.map_to_local(target_cell))
	# Walk near the lower half of the cleared tile so the peon appears grounded.
	target_pos.y += 16
	
	if global_position.distance_to(target_pos) < 5.0:
		path_index += 1
		if _path_finished():
			velocity = Vector2.ZERO
			return
		target_cell = astar_path[path_index]
		if not _is_walkable_cell(target_cell):
			astar_path.clear()
			path_index = 0
			velocity = Vector2.ZERO
			return
		last_walkable_cell = target_cell
		target_pos = block_layer.to_global(block_layer.map_to_local(target_cell))
		target_pos.y += 16
	
	var dir = global_position.direction_to(target_pos)
	velocity = dir * speed
	move_and_slide()

func _update_animation(delta):
	if velocity.length() > 0:
		var angle = velocity.angle()
		var PI_8 = PI / 8.0
		if angle > -PI_8 and angle <= PI_8:
			current_anim_row = 6 # Right
		elif angle > PI_8 and angle <= 3*PI_8:
			current_anim_row = 7 # Down-Right
		elif angle > 3*PI_8 and angle <= 5*PI_8:
			current_anim_row = 0 # Down
		elif angle > 5*PI_8 and angle <= 7*PI_8:
			current_anim_row = 1 # Down-Left
		elif angle > 7*PI_8 or angle <= -7*PI_8:
			current_anim_row = 2 # Left
		elif angle > -7*PI_8 and angle <= -5*PI_8:
			current_anim_row = 3 # Up-Left
		elif angle > -5*PI_8 and angle <= -3*PI_8:
			current_anim_row = 4 # Up
		elif angle > -3*PI_8 and angle <= -PI_8:
			current_anim_row = 5 # Up-Right
			
		$Sprite2D.flip_h = false
		anim_timer += delta * 12.0
		$Sprite2D.frame = current_anim_row * 8 + (int(anim_timer) % 8)
	else:
		anim_timer = 0.0
		$Sprite2D.frame = current_anim_row * 8
