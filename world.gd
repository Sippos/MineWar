extends Node2D

@export var player_id: int = 1:
	set(val):
		player_id = val
		if has_node("Player"):
			$Player.player_id = val

@export var is_vs_mode: bool = false
var income: int = 1
var income_timer: float = 3.0


@onready var bg_layer: TileMapLayer = $BackgroundLayer
@onready var block_layer: TileMapLayer = $BlockLayer
@onready var edge_layer: TileMapLayer = $EdgeLayer
@onready var damage_layer: TileMapLayer = $DamageLayer
@onready var fog_layer: TileMapLayer = $FogLayer
@onready var front_layer: TileMapLayer = $FrontWallLayer

var astar: AStarGrid2D
const ENEMY_SCENE = preload("res://enemy.tscn")

var gem_blocks = {}

var wave_timer = 60.0
var wave_interval = 45.0
var enemies_per_wave = 1

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not get_tree().paused:
		if player_id == 1:
			get_tree().paused = true
			var pause_menu = preload("res://pause_menu.tscn").instantiate()
			get_tree().root.add_child(pause_menu)

func _ready() -> void:
	$Player.player_id = player_id
	_add_wasd_input()
	
	astar = AStarGrid2D.new()
	astar.region = Rect2i(-30, -15, 60, 60)
	astar.cell_size = Vector2(64, 64)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	
	generate_initial_world()

func on_cell_dug(cell: Vector2i) -> void:
	if astar.is_in_bounds(cell.x, cell.y):
		astar.set_point_solid(cell, false)
		update_astar_weight(cell)
		update_astar_weight(Vector2i(cell.x, cell.y - 1))
	
	block_layer.erase_cell(cell)
	damage_layer.erase_cell(cell)
	edge_layer.erase_cell(cell)
	fog_layer.erase_cell(cell)
	bg_layer.erase_cell(cell)
	front_layer.erase_cell(Vector2i(cell.x, cell.y + 1)) # Erase its own front wall
	
	update_fog_mask(cell)
	update_front_wall(cell) # Clean up this cell
	has_gem(cell) # Ensure any gem overlays are removed if the cell is destroyed automatically
	
	var neighbors = [
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1)
	]
	
	for n in neighbors:
		update_fog_mask(n)
		update_front_wall(n)

func update_fog_mask(cell: Vector2i) -> void:
	if block_layer.get_cell_source_id(cell) == -1:
		fog_layer.erase_cell(cell)
		return
		
	var top_open = block_layer.get_cell_source_id(Vector2i(cell.x, cell.y - 1)) == -1
	var right_open = block_layer.get_cell_source_id(Vector2i(cell.x + 1, cell.y)) == -1
	var bottom_open = block_layer.get_cell_source_id(Vector2i(cell.x, cell.y + 1)) == -1
	var left_open = block_layer.get_cell_source_id(Vector2i(cell.x - 1, cell.y)) == -1
	
	var index = 0
	if top_open: index += 1
	if right_open: index += 2
	if bottom_open: index += 4
	if left_open: index += 8
	
	var atlas_x = index % 4
	var atlas_y = index / 4
	
	# Source 9 is the new fog_mask_atlas
	fog_layer.set_cell(cell, 9, Vector2i(atlas_x, atlas_y))
	
	if index != 0:
		var block_type = block_layer.get_cell_source_id(cell)
		var edge_source = 4 # Easy
		if block_type == 2: edge_source = 5
		elif block_type == 3: edge_source = 6
		edge_layer.set_cell(cell, edge_source, Vector2i(atlas_x, atlas_y))
	else:
		edge_layer.erase_cell(cell)
		
	if gem_blocks.has(cell):
		var sprites = gem_blocks[cell]
		if is_instance_valid(sprites.top):
			sprites.top.visible = (index != 0)
			if index != 0:
				sprites.top.region_enabled = true
				sprites.top.region_rect = Rect2(atlas_x * 64, atlas_y * 64, 64, 64)

func _add_wasd_input() -> void:
	var keys_p1 = {
		"p1_left": KEY_A,
		"p1_right": KEY_D,
		"p1_up": KEY_W,
		"p1_down": KEY_S,
		"p1_interact": KEY_E,
		"p1_grab": KEY_SPACE,
		"p1_drop": KEY_Q,
		"p1_stomp": KEY_R
	}
	var keys_p2 = {
		"p2_left": KEY_LEFT,
		"p2_right": KEY_RIGHT,
		"p2_up": KEY_UP,
		"p2_down": KEY_DOWN,
		"p2_interact": KEY_ENTER,
		"p2_grab": KEY_CTRL,
		"p2_drop": KEY_SHIFT,
		"p2_stomp": KEY_PERIOD
	}
	var joy_buttons = {
		"left": JOY_BUTTON_DPAD_LEFT,
		"right": JOY_BUTTON_DPAD_RIGHT,
		"up": JOY_BUTTON_DPAD_UP,
		"down": JOY_BUTTON_DPAD_DOWN,
		"interact": JOY_BUTTON_Y,
		"grab": JOY_BUTTON_A,
		"drop": JOY_BUTTON_B,
		"stomp": JOY_BUTTON_X
	}
	
	for action in keys_p1:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event = InputEventKey.new(); event.physical_keycode = keys_p1[action]; InputMap.action_add_event(action, event)
	
	for action in keys_p2:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event = InputEventKey.new(); event.physical_keycode = keys_p2[action]; InputMap.action_add_event(action, event)
		
	var axes = {
		"left": {"axis": JOY_AXIS_LEFT_X, "val": -1.0},
		"right": {"axis": JOY_AXIS_LEFT_X, "val": 1.0},
		"up": {"axis": JOY_AXIS_LEFT_Y, "val": -1.0},
		"down": {"axis": JOY_AXIS_LEFT_Y, "val": 1.0}
	}
	
	for p_id in [1, 2]:
		var prefix = "p%d_" % p_id
		var joy_id = p_id - 1
		for key in joy_buttons:
			var action = prefix + key
			var joy_event = InputEventJoypadButton.new()
			joy_event.button_index = joy_buttons[key]
			joy_event.device = joy_id
			InputMap.action_add_event(action, joy_event)
		for key in axes:
			var action = prefix + key
			var motion_event = InputEventJoypadMotion.new()
			motion_event.axis = axes[key].axis
			motion_event.axis_value = axes[key].val
			motion_event.device = joy_id
			InputMap.action_add_event(action, motion_event)

	# Add UI controls for menus
	var ui_joy_buttons = {
		"ui_left": JOY_BUTTON_DPAD_LEFT,
		"ui_right": JOY_BUTTON_DPAD_RIGHT,
		"ui_up": JOY_BUTTON_DPAD_UP,
		"ui_down": JOY_BUTTON_DPAD_DOWN,
		"ui_accept": JOY_BUTTON_A,
		"ui_cancel": JOY_BUTTON_B
	}
	for action in ui_joy_buttons:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var joy_event = InputEventJoypadButton.new()
		joy_event.button_index = ui_joy_buttons[action]
		InputMap.action_add_event(action, joy_event)
		
	# Pause action (ESC + Start)
	if not InputMap.has_action("pause"): InputMap.add_action("pause")
	var esc_event = InputEventKey.new(); esc_event.physical_keycode = KEY_ESCAPE; InputMap.action_add_event("pause", esc_event)
	var start_event = InputEventJoypadButton.new(); start_event.button_index = JOY_BUTTON_START; InputMap.action_add_event("pause", start_event)

func generate_initial_world() -> void:
	var width = 40
	var depth = 30
	
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.1
	
	for x in range(-width / 2, width / 2):
		for y in range(-10, depth):
			var cell = Vector2i(x, y)
			
			var block_type = 1
			if y >= 0:
				var depth_factor = y / float(depth)
				var n_val = noise.get_noise_2d(x, y)
				var score = depth_factor + n_val * 0.5
				
				if score > 0.8:
					block_type = 3
				elif score > 0.4:
					block_type = 2
					
			block_layer.set_cell(cell, block_type, Vector2i(0, 0))
			if astar.is_in_bounds(cell.x, cell.y):
				astar.set_point_solid(cell, true)
				
			if y >= 0 and randf() < 0.10:
				var sprite = Sprite2D.new()
				sprite.texture = load("res://Easy_Edge_Atlas-1-Stat-Ressources.png")
				sprite.position = block_layer.map_to_local(cell)
				sprite.visible = false
				sprite.z_index = 1
				edge_layer.add_child(sprite)
				
				var front_sprite = Sprite2D.new()
				front_sprite.texture = load("res://Stat_Ressources_Overlay_Front.png")
				front_sprite.position = front_layer.map_to_local(Vector2i(cell.x, cell.y + 1))
				front_sprite.position.y += 1 # Ensure it sorts AFTER the front wall cell (whose origin is 0)
				front_sprite.offset.y = -17 # Visually shift it back up to its intended position
				front_sprite.visible = false
				front_layer.add_child(front_sprite)
				
				gem_blocks[cell] = { "top": sprite, "front": front_sprite }
				
	# Now that all blocks are placed, calculate masks and front walls
	for x in range(-width / 2, width / 2):
		for y in range(-10, depth):
			update_fog_mask(Vector2i(x, y))
			update_front_wall(Vector2i(x, y))
	

	for x in range(-width / 2, width / 2):
		for y in range(-10, depth):
			update_astar_weight(Vector2i(x, y))
			
	# Area around the base
	for x in range(-5, 6):
		for y in range(-4, 0):
			var cell = Vector2i(x, y)
			if astar.is_in_bounds(cell.x, cell.y):
				on_cell_dug(cell)

	# Small clearing for the entrance funnel
	for x in range(-2, 3):
		for y in range(0, 2):
			var cell = Vector2i(x, y)
			if astar.is_in_bounds(cell.x, cell.y):
				on_cell_dug(cell)

func has_gem(cell: Vector2i) -> bool:
	if gem_blocks.has(cell):
		var sprites = gem_blocks[cell]
		if is_instance_valid(sprites.top):
			sprites.top.queue_free()
		if is_instance_valid(sprites.front):
			sprites.front.queue_free()
		gem_blocks.erase(cell)
		return true
	return false

var current_wave_number = 1

func _process(delta: float) -> void:
	if is_vs_mode:
		income_timer -= delta
		if income_timer <= 0:
			income_timer = 3.0
			var hud = get_node_or_null("HUD")
			if hud and hud.has_method("add_gold") and income > 0:
				hud.add_gold(income)
		return
	var enemies_alive = get_tree().get_nodes_in_group("enemies").size()
	
	if enemies_alive == 0:
		wave_timer -= delta
		
	var hud = get_node_or_null("HUD")
	if hud and hud.has_method("update_wave_info"):
		var is_boss = (current_wave_number % 10 == 0)
		var max_wave_time = wave_interval if current_wave_number > 1 else 60.0
		
		if enemies_alive > 0:
			hud.update_wave_info(current_wave_number, -1.0, max_wave_time, is_boss)
		else:
			hud.update_wave_info(current_wave_number, max(wave_timer, 0.0), max_wave_time, is_boss)
		
	if wave_timer <= 0 and enemies_alive == 0:
		spawn_wave()
		wave_timer = wave_interval
		current_wave_number += 1
		enemies_per_wave += 1

func get_farthest_open_cell() -> Vector2i:
	var start_cell = Vector2i(0, -1)
	var queue = [start_cell]
	var visited = {start_cell: 0}
	var farthest_cell = start_cell
	var max_dist = 0
	
	while queue.size() > 0:
		var curr = queue.pop_front()
		var dist = visited[curr]
		
		# Update farthest if it's underground and inside the map bounds
		if curr.y >= 0 and curr.y < 30 and curr.x >= -20 and curr.x < 20:
			if dist > max_dist:
				max_dist = dist
				farthest_cell = curr
			
		var neighbors = [
			Vector2i(curr.x + 1, curr.y),
			Vector2i(curr.x - 1, curr.y),
			Vector2i(curr.x, curr.y + 1),
			Vector2i(curr.x, curr.y - 1)
		]
		
		for n in neighbors:
			# Only traverse within the playable area
			if n.x >= -20 and n.x < 20 and n.y >= -10 and n.y < 30:
				if not astar.is_point_solid(n) and not visited.has(n):
					visited[n] = dist + 1
					queue.append(n)
					
	return farthest_cell

func get_random_enemy_type(wave: int) -> int:
	var roll = randf()
	
	# RAT(0), SPIDER(1), BAT(2), TROGG(3), ORC(4)
	var rat_prob = max(0.2, 0.6 - wave * 0.02)
	var spider_prob = min(0.3, 0.2 + wave * 0.01)
	var bat_prob = min(0.25, 0.1 + wave * 0.01)
	var trogg_prob = min(0.15, 0.05 + wave * 0.01)
	var orc_prob = min(0.1, 0.0 + wave * 0.01)
	
	var sum = rat_prob + spider_prob + bat_prob + trogg_prob + orc_prob
	rat_prob /= sum
	spider_prob /= sum
	bat_prob /= sum
	trogg_prob /= sum
	orc_prob /= sum
	
	if roll < rat_prob:
		return 0 # RAT
	elif roll < rat_prob + spider_prob:
		return 1 # SPIDER
	elif roll < rat_prob + spider_prob + bat_prob:
		return 2 # BAT
	elif roll < rat_prob + spider_prob + bat_prob + trogg_prob:
		return 3 # TROGG
	else:
		return 4 # ORC

func spawn_wave() -> void:
	var target_cell = get_farthest_open_cell()
	var spawn_pos = block_layer.to_global(block_layer.map_to_local(target_cell))
	var is_boss = (current_wave_number % 10 == 0)
	
	var spawn_count = 1 if is_boss else enemies_per_wave
	
	for i in range(spawn_count):
		var enemy = ENEMY_SCENE.instantiate()
		var offset = Vector2(randf_range(-10, 10), 0)
		if is_boss:
			offset = Vector2.ZERO # Spawn boss directly in the center
		enemy.global_position = spawn_pos + offset
		add_child(enemy)
		if enemy.has_method("initialize"):
			var e_type = get_random_enemy_type(current_wave_number)
			enemy.initialize(current_wave_number, is_boss, e_type)
		await get_tree().create_timer(0.4).timeout


func update_front_wall(cell: Vector2i) -> void:
	var block_id = block_layer.get_cell_source_id(cell)
	var below_cell = Vector2i(cell.x, cell.y + 1)
	var has_front_wall = false
	
	if block_id != -1:
		# If cell is solid, check if below is empty
		if block_layer.get_cell_source_id(below_cell) == -1:
			var front_id = 10 # Easy Front
			if block_id == 2: front_id = 11
			elif block_id == 3: front_id = 12
			
			front_layer.set_cell(below_cell, front_id, Vector2i(0, 0))
			has_front_wall = true
		else:
			front_layer.erase_cell(below_cell)
	else:
		# If cell is empty, it can't have a front wall projecting down
		front_layer.erase_cell(below_cell)
		
	if gem_blocks.has(cell):
		var sprites = gem_blocks[cell]
		if is_instance_valid(sprites.front):
			sprites.front.visible = has_front_wall

func update_astar_weight(cell: Vector2i) -> void:
	if not astar.is_in_bounds(cell.x, cell.y):
		return
	
	var cell_below = Vector2i(cell.x, cell.y + 1)
	var is_grounded = false
	if not astar.is_in_bounds(cell_below.x, cell_below.y):
		is_grounded = true
	else:
		is_grounded = astar.is_point_solid(cell_below)
		
	if is_grounded:
		astar.set_point_weight_scale(cell, 1.0)
	else:
		astar.set_point_weight_scale(cell, 50.0)

func update_rail_autotile(cell: Vector2i) -> void:
	if not has_node("RailLayer"): return
	var rail_layer = get_node("RailLayer")
	
	if rail_layer.get_cell_source_id(cell) == -1: return
	
	var up = rail_layer.get_cell_source_id(Vector2i(cell.x, cell.y - 1)) != -1
	var down = rail_layer.get_cell_source_id(Vector2i(cell.x, cell.y + 1)) != -1
	var left = rail_layer.get_cell_source_id(Vector2i(cell.x - 1, cell.y)) != -1
	var right = rail_layer.get_cell_source_id(Vector2i(cell.x + 1, cell.y)) != -1
	
	var atlas_coords = Vector2i(0, 0)
	if up and down and left and right:
		atlas_coords = Vector2i(0, 1) # Intersection
	elif (left or right) and not (up or down):
		atlas_coords = Vector2i(1, 0) # Horizontal
	elif (up or down) and not (left or right):
		atlas_coords = Vector2i(0, 0) # Vertical
	else:
		atlas_coords = Vector2i(0, 1) # Intersection as fallback
		
	rail_layer.set_cell(cell, 15, atlas_coords)
