extends Node2D

var rail_path = []
var path_index = 0
var speed = 100.0
var income_timer = 0.0

var rail_layer = null

func _ready():
	var world = get_parent()
	if world.has_node("RailLayer"):
		rail_layer = world.get_node("RailLayer")
	find_longest_rail_path()

func _process(delta):
	# Calculate passive income based on rail path length
	income_timer += delta
	if income_timer >= 5.0:
		income_timer = 0.0
		if rail_path.size() > 0:
			var base = get_parent().get_node_or_null("Base")
			if base and base.has_signal("gems_deposited"):
				# 1 gem per 10 tiles of rail
				var amount = max(1, int(rail_path.size() / 10.0))
				base.gems_deposited.emit(amount)

	# Movement visual only
	if rail_path.size() > 0 and rail_layer:
		var target_cell = rail_path[path_index]
		var target_pos = rail_layer.to_global(rail_layer.map_to_local(target_cell))
		var dir = global_position.direction_to(target_pos)
		
		if dir.length() > 0:
			global_position += dir * speed * delta
		
		if global_position.distance_to(target_pos) < 5.0:
			path_index += 1
			if path_index >= rail_path.size():
				rail_path.reverse()
				path_index = 0

func find_longest_rail_path():
	if not rail_layer: return
	
	var base = get_parent().get_node_or_null("Base")
	if not base: return
	
	var start_cell = rail_layer.local_to_map(rail_layer.to_local(base.global_position))
	var queue = [start_cell]
	var visited = {start_cell: null}
	var farthest = start_cell
	
	while queue.size() > 0:
		var curr = queue.pop_front()
		
		var neighbors = [
			Vector2i(curr.x + 1, curr.y),
			Vector2i(curr.x - 1, curr.y),
			Vector2i(curr.x, curr.y + 1),
			Vector2i(curr.x, curr.y - 1)
		]
		for n in neighbors:
			if rail_layer.get_cell_source_id(n) != -1 and not visited.has(n):
				visited[n] = curr
				queue.append(n)
				farthest = n
				
	rail_path = []
	var c = farthest
	while c != null:
		rail_path.append(c)
		c = visited[c]
	rail_path.reverse()
	
	if rail_path.size() > 0:
		path_index = 0
		global_position = rail_layer.to_global(rail_layer.map_to_local(rail_path[0]))
