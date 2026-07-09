extends RigidBody2D

const RAIL_SOURCE_ID = 15

var rail_path: Array[Vector2i] = []
var path_index = 0
var speed = 100.0
var income_timer = 0.0
var anim_timer = 0.0
var current_anim_row = 0
var tethered_to = null
var placed_on_rail = false

var rail_layer: TileMapLayer = null
var block_layer: TileMapLayer = null

func _ready() -> void:
	add_to_group("minecarts")
	var area = get_node_or_null("PickupArea")
	if area:
		if not area.body_exited.is_connected(_on_pickup_area_body_exited):
			area.body_exited.connect(_on_pickup_area_body_exited)
	_update_world_layers()
	freeze = false

func should_deposit_as_gem() -> bool:
	return false

func tether_to(player) -> void:
	if placed_on_rail:
		placed_on_rail = false
		rail_path.clear()
		freeze = false
	tethered_to = player
	if player is PhysicsBody2D:
		add_collision_exception_with(player)
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.position = Vector2(0, -24)

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
		var target_pos = tethered_to.global_position
		var dir = (target_pos - global_position).normalized()
		var dist = global_position.distance_to(target_pos)
		if dist > 55.0:
			apply_central_force(dir * minf(dist * 30.0, 5000.0))
		elif dist < 40.0:
			apply_central_force(-dir * (40.0 - dist) * 100.0)

func _process(delta: float) -> void:
	if not placed_on_rail:
		return
	if not _has_valid_path():
		if not _rebuild_path():
			return
	_update_income(delta)
	_move_along_path(delta)

func _try_place_on_rail() -> bool:
	_update_world_layers()
	if rail_layer == null or block_layer == null:
		return false
	var cell = rail_layer.local_to_map(rail_layer.to_local(global_position))
	if not _is_open_rail_cell(cell):
		return false
	if not _rebuild_path(cell):
		return false
	placed_on_rail = true
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_position = rail_layer.to_global(rail_layer.map_to_local(rail_path[0]))
	return true

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

func _on_pickup_area_body_entered(body) -> void:
	if body.name == "Player" and body.has_method("add_nearby_gem"):
		body.add_nearby_gem(self)

func _on_pickup_area_body_exited(body) -> void:
	if body.name == "Player" and body.has_method("remove_nearby_gem"):
		body.remove_nearby_gem(self)
