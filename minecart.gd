extends RigidBody2D

const RAIL_SOURCE_ID = 15
const CARRIED_OFFSET = Vector2(0, 30)
const PICKUP_RADIUS = 72.0

var rail_path: Array[Vector2i] = []
var path_index = 0
var speed = 100.0
var income_timer = 0.0
var anim_timer = 0.0
var current_anim_row = 0
var tethered_to = null
var placed_on_rail = false
var stored_gems = 0

var rail_layer: TileMapLayer = null
var block_layer: TileMapLayer = null

func _ready() -> void:
	add_to_group("minecarts")
	var area = get_node_or_null("PickupArea")
	if area:
		if not area.body_entered.is_connected(_on_pickup_area_body_entered):
			area.body_entered.connect(_on_pickup_area_body_entered)
		if not area.body_exited.is_connected(_on_pickup_area_body_exited):
			area.body_exited.connect(_on_pickup_area_body_exited)
		call_deferred("_register_nearby_player")
	_update_world_layers()
	freeze = false

func should_deposit_as_gem() -> bool:
	return false

func tether_to(player) -> bool:
	if placed_on_rail:
		placed_on_rail = false
		rail_path.clear()
		path_index = 0
	tethered_to = player
	if player is PhysicsBody2D:
		add_collision_exception_with(player)
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_position = player.global_position + CARRIED_OFFSET
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.position = Vector2.ZERO
	return true

func untether() -> void:
	if tethered_to != null and tethered_to is PhysicsBody2D:
		remove_collision_exception_with(tethered_to)
	tethered_to = null
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.position = Vector2.ZERO
	if not _try_place_on_rail():
		placed_on_rail = false
		freeze = false

func _physics_process(delta: float) -> void:
	if placed_on_rail:
		return
	if tethered_to != null and is_instance_valid(tethered_to):
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		global_position = tethered_to.global_position + CARRIED_OFFSET

func _process(delta: float) -> void:
	if not placed_on_rail:
		return
	if not _has_valid_path():
		if not _rebuild_path():
			return
	_update_income(delta)
	_deposit_stored_gems()
	_move_along_path(delta)

func _try_place_on_rail() -> bool:
	_update_world_layers()
	if rail_layer == null or block_layer == null:
		return false
	var cell = rail_layer.local_to_map(rail_layer.to_local(global_position))
	if not _is_open_cell(cell):
		return false
	if not _is_open_rail_cell(cell):
		_build_trail_to_base(cell)
	if not _rebuild_path(cell):
		return false
	placed_on_rail = true
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_position = rail_layer.to_global(rail_layer.map_to_local(rail_path[0]))
	return true

func load_gem(gem, player = null) -> bool:
	if not placed_on_rail or gem == self or not is_instance_valid(gem):
		return false
	if gem.has_method("should_deposit_as_gem") and not gem.should_deposit_as_gem():
		return false
	if gem.has_method("untether"):
		gem.untether()
	if player != null and player is PhysicsBody2D:
		remove_collision_exception_with(player)
	stored_gems += 1
	gem.queue_free()
	return true

func refresh_rail_path() -> void:
	if placed_on_rail:
		_rebuild_path()

func _update_world_layers() -> void:
	var world = get_parent()
	if world == null:
		return
	rail_layer = world.get_node_or_null("RailLayer")
	block_layer = world.get_node_or_null("BlockLayer")

func _is_open_rail_cell(cell: Vector2i) -> bool:
	if rail_layer == null or block_layer == null:
		return false
	return rail_layer.get_cell_source_id(cell) == RAIL_SOURCE_ID and block_layer.get_cell_source_id(cell) == -1

func _is_open_cell(cell: Vector2i) -> bool:
	return block_layer != null and block_layer.get_cell_source_id(cell) == -1

func _build_trail_to_base(start_cell: Vector2i) -> void:
	var world = get_parent()
	if world == null:
		return
	var base = world.get_node_or_null("Base")
	if base == null:
		return
	var base_cell = rail_layer.local_to_map(rail_layer.to_local(base.global_position))
	var path = _find_open_path(start_cell, base_cell)
	if path.is_empty():
		return
	var max_length = 16
	if "minecart_trail_length" in world:
		max_length = world.minecart_trail_length
	var limit = mini(path.size(), max_length)
	for i in range(limit):
		var cell = path[i]
		if _is_open_cell(cell):
			rail_layer.set_cell(cell, RAIL_SOURCE_ID, Vector2i(0, 0))
	for i in range(limit):
		_update_rail_and_neighbors(path[i])

func _find_open_path(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	if not _is_open_cell(start_cell):
		return []
	var queue: Array[Vector2i] = [start_cell]
	var visited = {start_cell: null}
	var read_index = 0
	var best_cell = start_cell
	var best_dist = _cell_distance(start_cell, target_cell)
	var max_search = 1200
	while read_index < queue.size() and read_index < max_search:
		var curr = queue[read_index]
		read_index += 1
		var curr_dist = _cell_distance(curr, target_cell)
		if curr_dist < best_dist:
			best_dist = curr_dist
			best_cell = curr
		if curr == target_cell:
			best_cell = curr
			break
		for neighbor in _rail_neighbors(curr):
			if visited.has(neighbor) or not _is_open_cell(neighbor):
				continue
			if abs(neighbor.x - start_cell.x) > 40 or abs(neighbor.y - start_cell.y) > 60:
				continue
			visited[neighbor] = curr
			queue.append(neighbor)

	var path: Array[Vector2i] = []
	var cell = best_cell
	while cell != null:
		path.append(cell)
		cell = visited[cell]
	path.reverse()
	return path

func _cell_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _update_rail_and_neighbors(cell: Vector2i) -> void:
	var world = get_parent()
	if world == null or not world.has_method("update_rail_autotile"):
		return
	world.update_rail_autotile(cell)
	for neighbor in _rail_neighbors(cell):
		world.update_rail_autotile(neighbor)

func _has_valid_path() -> bool:
	if rail_path.is_empty():
		return false
	for cell in rail_path:
		if not _is_open_rail_cell(cell):
			return false
	return true

func _rebuild_path(preferred_start = null) -> bool:
	_update_world_layers()
	if rail_layer == null:
		return false
	var start_cell = preferred_start
	if start_cell == null:
		start_cell = rail_layer.local_to_map(rail_layer.to_local(global_position))
	if not _is_open_rail_cell(start_cell):
		start_cell = _nearest_open_rail_cell(start_cell)
	if start_cell == null:
		rail_path.clear()
		return false
	rail_path = _find_farthest_path(start_cell)
	path_index = 0
	return rail_path.size() > 0

func _nearest_open_rail_cell(origin: Vector2i):
	var best_cell = null
	var best_dist = INF
	for cell in rail_layer.get_used_cells():
		if not _is_open_rail_cell(cell):
			continue
		var dist = abs(cell.x - origin.x) + abs(cell.y - origin.y)
		if dist < best_dist:
			best_dist = dist
			best_cell = cell
	return best_cell

func _find_farthest_path(start_cell: Vector2i) -> Array[Vector2i]:
	var open_rails = {}
	for cell in rail_layer.get_used_cells():
		if _is_open_rail_cell(cell):
			open_rails[cell] = true
	if not open_rails.has(start_cell):
		return []

	var queue: Array[Vector2i] = [start_cell]
	var visited = {start_cell: null}
	var farthest = start_cell
	var read_index = 0
	while read_index < queue.size():
		var curr = queue[read_index]
		read_index += 1
		for neighbor in _rail_neighbors(curr):
			if open_rails.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = curr
				queue.append(neighbor)
				farthest = neighbor

	var path: Array[Vector2i] = []
	var cell = farthest
	while cell != null:
		path.append(cell)
		cell = visited[cell]
	path.reverse()
	return path

func _rail_neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1),
	]

func _update_income(delta: float) -> void:
	income_timer += delta
	if income_timer < 5.0:
		return
	income_timer = 0.0
	if rail_path.is_empty():
		return
	var base = get_parent().get_node_or_null("Base")
	if base and base.has_signal("gems_deposited"):
		base.gems_deposited.emit(max(1, int(rail_path.size() / 10.0)))

func _deposit_stored_gems() -> void:
	if stored_gems <= 0:
		return
	var base = get_parent().get_node_or_null("Base")
	if base == null or not base.has_signal("gems_deposited"):
		return
	if global_position.distance_to(base.global_position) > 96.0:
		return
	base.gems_deposited.emit(stored_gems)
	stored_gems = 0

func _move_along_path(delta: float) -> void:
	if rail_path.is_empty() or rail_layer == null:
		return
	path_index = clampi(path_index, 0, rail_path.size() - 1)
	var target_cell = rail_path[path_index]
	var target_pos = rail_layer.to_global(rail_layer.map_to_local(target_cell))
	var dir = global_position.direction_to(target_pos)
	if dir.length() > 0:
		global_position += dir * speed * delta
		animate_cart(dir, delta)
	if global_position.distance_to(target_pos) < 5.0:
		path_index += 1
		if path_index >= rail_path.size():
			rail_path.reverse()
			path_index = 0

func animate_cart(dir: Vector2, delta: float) -> void:
	var angle = dir.angle()
	var pi_8 = PI / 8.0
	if angle > -pi_8 and angle <= pi_8:
		current_anim_row = 6
	elif angle > pi_8 and angle <= 3 * pi_8:
		current_anim_row = 7
	elif angle > 3 * pi_8 and angle <= 5 * pi_8:
		current_anim_row = 0
	elif angle > 5 * pi_8 and angle <= 7 * pi_8:
		current_anim_row = 1
	elif angle > 7 * pi_8 or angle <= -7 * pi_8:
		current_anim_row = 2
	elif angle > -7 * pi_8 and angle <= -5 * pi_8:
		current_anim_row = 3
	elif angle > -5 * pi_8 and angle <= -3 * pi_8:
		current_anim_row = 4
	elif angle > -3 * pi_8 and angle <= -pi_8:
		current_anim_row = 5

	anim_timer += delta * 12.0
	$Sprite2D.frame = current_anim_row * 8 + (int(anim_timer) % 8)

func _register_nearby_player() -> void:
	var player = get_parent().get_node_or_null("Player")
	if player and player.has_method("add_nearby_gem") and global_position.distance_to(player.global_position) <= PICKUP_RADIUS:
		player.add_nearby_gem(self)

func _on_pickup_area_body_entered(body) -> void:
	if body.name == "Player" and body.has_method("add_nearby_gem"):
		body.add_nearby_gem(self)

func _on_pickup_area_body_exited(body) -> void:
	if body.name == "Player" and body.has_method("remove_nearby_gem"):
		body.remove_nearby_gem(self)
