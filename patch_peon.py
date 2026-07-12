import os

peon_tscn = """[gd_scene load_steps=4 format=3 uid="uid://peonuid"]

[ext_resource type="Script" path="res://scripts/gameplay/peon/peon.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://peon_walk_spritesheet_25d.png" id="2_tex"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_peon"]
size = Vector2(32, 32)

[node name="Peon" type="CharacterBody2D"]
collision_layer = 0
collision_mask = 0
script = ExtResource("1_script")

[node name="Sprite2D" type="Sprite2D" parent="."]
position = Vector2(0, -16)
scale = Vector2(0.5, 0.5)
texture = ExtResource("2_tex")
hframes = 8
vframes = 8

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_peon")
"""

with open("peon.tscn", "w") as f:
    f.write(peon_tscn)


peon_gd = """extends CharacterBody2D

var state = "IDLE"
var target_gem = null
var base_node = null

var astar_path = []
var path_index = 0

var speed = 120.0
var block_layer = null
var anim_timer = 0.0
var current_anim_row = 0

func _ready():
	add_to_group("peons")
	var world = get_parent()
	if world.has_node("Base"):
		base_node = world.get_node("Base")
	if world.has_node("BlockLayer"):
		block_layer = world.get_node("BlockLayer")

func _physics_process(delta):
	# Apply a small gravity just in case to ground them if they end up flying?
	# No, astar ensures they walk on ground, but if they are off, let's just let move_along_path handle it.
	
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
		
	# Animation
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
		
		# Offset target pos to bottom center of cell so they walk on the ground
		target_pos.y += 16
		
		var dir = global_position.direction_to(target_pos)
		velocity = dir * speed
		
		if global_position.distance_to(target_pos) < 5.0:
			path_index += 1
			
		move_and_slide()
	else:
		velocity = Vector2.ZERO
"""

with open("peon.gd", "w") as f:
    f.write(peon_gd)
print("Updated peon")
