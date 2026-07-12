import os

rail_item_gd = """extends "res://scripts/gameplay/collectibles/gems/gem.gd"

func _ready() -> void:
	add_to_group("gems")
	add_to_group("rails")
	var area = get_node_or_null("PickupArea")
	if area:
		if not area.body_exited.is_connected(_on_pickup_area_body_exited):
			area.body_exited.connect(_on_pickup_area_body_exited)

func untether() -> void:
	super.untether()
	var world = get_parent()
	if world and world.name == "World" and world.has_node("RailLayer"):
		var rail_layer = world.get_node("RailLayer")
		var block_layer = world.get_node("BlockLayer")
		var cell = block_layer.local_to_map(block_layer.to_local(global_position))
		
		if block_layer.get_cell_source_id(cell) == -1:
			rail_layer.set_cell(cell, 0, Vector2i(0, 0))
			world.update_rail_autotile(cell)
			var n_cells = [
				Vector2i(cell.x + 1, cell.y),
				Vector2i(cell.x - 1, cell.y),
				Vector2i(cell.x, cell.y + 1),
				Vector2i(cell.x, cell.y - 1)
			]
			for n in n_cells:
				world.update_rail_autotile(n)
			queue_free()
"""

with open("scripts/gameplay/collectibles/rail_items/rail_item.gd", "w") as f:
    f.write(rail_item_gd)

gem_tscn_path = "scenes/entities/collectibles/gems/gem.tscn"
with open(gem_tscn_path, "r") as f:
    gem_tscn = f.read()

rail_tscn = gem_tscn.replace('path="res://scripts/gameplay/collectibles/gems/gem.gd" id="1_script"', 'path="res://scripts/gameplay/collectibles/rail_items/rail_item.gd" id="1_script"')
rail_tscn = rail_tscn.replace('path="res://StatRessources.png" id="2_tex"', 'path="res://rail_item_placeholder.png" id="2_tex"')
rail_tscn = rail_tscn.replace('[node name="Gem" type="RigidBody2D"]', '[node name="RailItem" type="RigidBody2D"]')

with open("scenes/entities/collectibles/rail_items/rail_item.tscn", "w") as f:
    f.write(rail_tscn)

peon_gd = """extends CharacterBody2D

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
"""

with open("peon.gd", "w") as f:
    f.write(peon_gd)

peon_tscn = """[gd_scene load_steps=4 format=3 uid="uid://peonuid"]

[ext_resource type="Script" path="res://scripts/gameplay/workers/peon/peon.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://peon_placeholder.png" id="2_tex"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_peon"]
size = Vector2(32, 32)

[node name="Peon" type="CharacterBody2D"]
collision_layer = 0
collision_mask = 0
script = ExtResource("1_script")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_peon")
"""

with open("peon.tscn", "w") as f:
    f.write(peon_tscn)

minecart_gd = """extends Node2D

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
"""

with open("minecart.gd", "w") as f:
    f.write(minecart_gd)

minecart_tscn = """[gd_scene load_steps=3 format=3 uid="uid://minecartuid"]

[ext_resource type="Script" path="res://minecart.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://minecart_placeholder.png" id="2_tex"]

[node name="Minecart" type="Node2D"]
script = ExtResource("1_script")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
"""

with open("minecart.tscn", "w") as f:
    f.write(minecart_tscn)

# Patch base.gd to spawn these items
base_gd_path = "base.gd"
with open(base_gd_path, "r") as f:
    base_gd = f.read()

base_methods = """
func spawn_rail():
	var item = preload("res://scenes/entities/collectibles/rail_items/rail_item.tscn").instantiate()
	item.global_position = global_position
	get_parent().call_deferred("add_child", item)

func spawn_peon():
	var peon = preload("res://scenes/entities/workers/peon/peon.tscn").instantiate()
	peon.global_position = global_position
	get_parent().call_deferred("add_child", peon)

func spawn_minecart():
	var existing = get_parent().get_node_or_null("Minecart")
	if existing:
		existing.queue_free()
	var cart = preload("res://minecart.tscn").instantiate()
	cart.name = "Minecart"
	cart.global_position = global_position
	get_parent().call_deferred("add_child", cart)
"""

if "spawn_rail" not in base_gd:
    base_gd += base_methods
    with open(base_gd_path, "w") as f:
        f.write(base_gd)

print("Created faction scenes and updated base.gd")
