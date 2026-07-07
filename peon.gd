extends CharacterBody2D

var state = "IDLE"
var target_gem = null
var base_node = null

var astar_path = []
var path_index = 0

var speed = 120.0
var block_layer = null

func _ready():
	add_to_group("peons")
	var world = get_parent()
	if world.has_node("Base"):
		base_node = world.get_node("Base")
	if world.has_node("BlockLayer"):
		block_layer = world.get_node("BlockLayer")

func _physics_process(delta):
	if state == "IDLE":
		# Wait for gems to drop
		target_gem = find_closest_gem()
		if target_gem:
			state = "SEEK_GEM"
	elif state == "SEEK_GEM":
		if not is_instance_valid(target_gem):
			state = "IDLE"
			return
		if calculate_path_to(target_gem.global_position):
			state = "MOVE_TO_GEM"
		else:
			target_gem = null
			state = "IDLE"
	elif state == "MOVE_TO_GEM":
		if not is_instance_valid(target_gem):
			state = "IDLE"
			return
			
		# Check if close to gem
		if global_position.distance_to(target_gem.global_position) < 20.0:
			# Pick it up
			target_gem.queue_free()
			target_gem = null
			state = "RETURN_TO_BASE"
			calculate_path_to(base_node.global_position)
			return
			
		move_along_path(delta)
	elif state == "RETURN_TO_BASE":
		if global_position.distance_to(base_node.global_position) < 30.0:
			# Deposit gem
			if base_node.has_signal("gems_deposited"):
				base_node.gems_deposited.emit(1)
			state = "IDLE"
			return
			
		move_along_path(delta)

func find_closest_gem():
	var gems = get_tree().get_nodes_in_group("gems")
	var closest = null
	var min_dist = 99999.0
	for gem in gems:
		if not gem.is_in_group("rails") and not is_instance_valid(gem.tethered_to):
			var d = global_position.distance_to(gem.global_position)
			if d < min_dist:
				min_dist = d
				closest = gem
	return closest

func calculate_path_to(target_global: Vector2) -> bool:
	if not block_layer: return false
	var world = get_parent()
	var astar = world.astar
	var start_cell = block_layer.local_to_map(block_layer.to_local(global_position))
	var end_cell = block_layer.local_to_map(block_layer.to_local(target_global))
	
	if astar.is_in_bounds(start_cell.x, start_cell.y) and astar.is_in_bounds(end_cell.x, end_cell.y):
		astar_path = astar.get_point_path(start_cell, end_cell)
		path_index = 0
		return astar_path.size() > 0
	return false

func move_along_path(delta):
	if path_index < astar_path.size():
		var target_pos = block_layer.to_global(block_layer.map_to_local(astar_path[path_index]))
		var dir = global_position.direction_to(target_pos)
		velocity = dir * speed
		
		# Flip sprite
		if dir.x != 0:
			$Sprite2D.flip_h = dir.x < 0
			
		if global_position.distance_to(target_pos) < 5.0:
			path_index += 1
			
		move_and_slide()
	else:
		velocity = Vector2.ZERO
