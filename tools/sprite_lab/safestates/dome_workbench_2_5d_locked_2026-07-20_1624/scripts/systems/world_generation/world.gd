extends Node2D

@export var player_id: int = 1:
	set(val):
		player_id = val
		if has_node("Player"):
			$Player.player_id = val

@export var is_vs_mode: bool = false
@export var preparation_mode: bool = false

@export_group("Mine Lighting")
@export var show_fog_overlay: bool = false
@export var ambient_tint: Color = Color(0.44, 0.47, 0.55, 1.0)
@export var player_light_color: Color = Color(1.0, 0.84, 0.66, 1.0)
@export_range(0.0, 2.0, 0.05) var player_light_energy: float = 1.15
@export_range(0.25, 3.0, 0.05) var player_light_scale: float = 1.25

var income: int = 1
var income_timer: float = 3.0
var minecart_trail_length: int = 16
var preparation_active: bool = false


@onready var bg_layer: TileMapLayer = $BackgroundLayer
@onready var block_layer: TileMapLayer = $BlockLayer
@onready var edge_layer: TileMapLayer = $EdgeLayer
@onready var damage_layer: TileMapLayer = $DamageLayer
@onready var fog_layer: TileMapLayer = $FogLayer
@onready var front_layer: TileMapLayer = $FrontWallLayer
@onready var canvas_modulate: CanvasModulate = $CanvasModulate

const INSIDE_CORNER_ATLAS_PATHS := {
	1: "res://assets/sprites/world/terrain/dome/Easy_Inside_Corners.png",
	2: "res://assets/sprites/world/terrain/dome/Medium_Inside_Corners.png",
	3: "res://assets/sprites/world/terrain/dome/Hard_Inside_Corners.png",
}
const INSIDE_CORNER_FRAME_SIZE := 128
const INSIDE_CORNER_Z_INDEX := 2
const FRONT_EXTRUSION_RENDERER := preload("res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd")
const FRONT_EXTRUSION_DEPTH := 10
var front_extrusion_renderer: Node2D
var inside_corner_textures: Dictionary = {}
var inside_corner_sprites: Dictionary = {}
var inside_corner_layer: Node2D
@onready var player_light: PointLight2D = $Player/PointLight2D

var astar: AStarGrid2D
const ENEMY_SCENE = preload("res://enemy.tscn")
const MINERS_SATCHEL_SCENE = preload("res://scenes/entities/collectibles/rewards/miners_satchel.tscn")
const CAVE_REWARD_MIN_DEPTH := 8
const FRONT_GEM_Z_INDEX = 2
const BASE_GEM_TEXTURE_FACTORY = preload("res://scripts/systems/preparation/gem_indicator_texture_factory.gd")
const GEM_TOP_TEXTURE_PATH := "res://assets/sprites/world/terrain/gem_embedded_edge.svg"
const GEM_FRONT_TEXTURE_PATH := "res://assets/sprites/world/terrain/gem_embedded_front.svg"
const GEM_INDICATOR_TOP_SCALE := Vector2.ONE
const GEM_INDICATOR_FRONT_SCALE := Vector2.ONE

var gem_top_texture: Texture2D
var gem_front_texture: Texture2D
const TUTORIAL_GEM_CELL := Vector2i(0, 2)
const FIRST_WAVE_DELAY := 32.0
const STANDARD_WAVE_INTERVAL := 36.0

# Enemy invasions are announced from persistent breaches instead of appearing
# at whichever tunnel tile happens to be farthest when the timer expires.
const BASE_TARGET_CELL := Vector2i(0, -1)
const SURFACE_BREACH_CELLS := [Vector2i(-10, -2), Vector2i(10, -2)]
const BREACH_MIN_BASE_PATH_CELLS := 10
const BREACH_MIN_PLAYER_GRID_DISTANCE := 7
const BREACH_MIN_PLAYER_WORLD_DISTANCE := 460.0
const BREACH_RECENT_DIG_GRACE_MSEC := 8000
const BREACH_SITE_WAVE_LIFETIME := 2
const BREACH_DYNAMIC_START_WAVE := 3
const BREACH_TOP_CANDIDATE_COUNT := 4
const BREACH_MARKER_Z_INDEX := 19

enum OnboardingStage { DIG_DOWN, FIND_GEM, PICK_UP_GEM, BANK_GEM, OPEN_UPGRADES, COMPLETE }

var gem_blocks = {}
var minewars_motherlodes: Dictionary = {}
var cave_reward_spawned := false
var onboarding_active := false
var onboarding_stage: int = OnboardingStage.DIG_DOWN
var onboarding_entry_marker: Node2D
var onboarding_entry_marker_tween: Tween
var first_deposit_received := false

var wave_timer = FIRST_WAVE_DELAY
var wave_interval = STANDARD_WAVE_INTERVAL
var enemies_per_wave = 1

var topology_revision := 0
var world_generation_in_progress := false
var dug_at_msec: Dictionary = {}
var current_breach_cell := Vector2i.ZERO
var current_breach_valid := false
var current_breach_is_surface := true
var current_breach_waves_remaining := 0
var prepared_breach_wave := 0
var breach_marker: Node2D
var breach_marker_tween: Tween
var breach_rng := RandomNumberGenerator.new()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not get_tree().paused:
		if player_id == 1:
			get_tree().paused = true
			var pause_menu = preload("res://scenes/ui/overlays/pause/pause_menu.tscn").instantiate()
			get_tree().root.add_child(pause_menu)

func _ready() -> void:
	$Player.player_id = player_id
	_add_wasd_input()
	_ensure_base_gem_indicator_textures()
	_setup_inside_corner_renderer()
	_setup_front_extrusion_renderer()
	_configure_mine_lighting()
	breach_rng.randomize()
	
	astar = AStarGrid2D.new()
	astar.region = Rect2i(-30, -15, 60, 60)
	astar.cell_size = Vector2(64, 64)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	
	world_generation_in_progress = true
	generate_initial_world()
	_rebuild_inside_corners()
	if front_extrusion_renderer != null:
		front_extrusion_renderer.call("rebuild_all")
	_normalize_gem_indicator_sprites()
	world_generation_in_progress = false
	preparation_active = preparation_mode and not is_vs_mode
	if not preparation_active:
		call_deferred("_begin_player_journey")

func _setup_front_extrusion_renderer() -> void:
	front_layer.clear()
	front_layer.visible = false
	front_extrusion_renderer = get_node_or_null("DomeFrontExtrusionRenderer") as Node2D
	if front_extrusion_renderer == null:
		front_extrusion_renderer = FRONT_EXTRUSION_RENDERER.new() as Node2D
		front_extrusion_renderer.name = "DomeFrontExtrusionRenderer"
		front_extrusion_renderer.z_index = 2
		add_child(front_extrusion_renderer)
	front_extrusion_renderer.call("setup", block_layer, FRONT_EXTRUSION_DEPTH)

func _setup_inside_corner_renderer() -> void:
	inside_corner_layer = get_node_or_null("InsideCornerLayer") as Node2D
	if inside_corner_layer == null:
		inside_corner_layer = Node2D.new()
		inside_corner_layer.name = "InsideCornerLayer"
		inside_corner_layer.z_index = INSIDE_CORNER_Z_INDEX
		add_child(inside_corner_layer)
	inside_corner_textures.clear()
	for block_id_value: Variant in INSIDE_CORNER_ATLAS_PATHS.keys():
		var block_id := int(block_id_value)
		var atlas_path := String(INSIDE_CORNER_ATLAS_PATHS[block_id])
		if not FileAccess.file_exists(atlas_path):
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(atlas_path))
		if image == null or image.is_empty():
			continue
		image.convert(Image.FORMAT_RGBA8)
		inside_corner_textures[block_id] = ImageTexture.create_from_image(image)

func _inside_corner_key(cell: Vector2i, frame: int) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, frame]

func _remove_inside_corner(cell: Vector2i, frame: int) -> void:
	var key := _inside_corner_key(cell, frame)
	var sprite := inside_corner_sprites.get(key) as Sprite2D
	if is_instance_valid(sprite):
		sprite.queue_free()
	inside_corner_sprites.erase(key)

func _refresh_inside_corners_for_empty_cell(cell: Vector2i) -> void:
	if inside_corner_layer == null:
		return
	if block_layer.get_cell_source_id(cell) != -1:
		for frame in range(4):
			_remove_inside_corner(cell, frame)
		return
	var rules := [
		[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],
		[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],
		[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],
		[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],
	]
	for rule_value: Variant in rules:
		var rule: Array = rule_value
		var first: Vector2i = rule[0]
		var second: Vector2i = rule[1]
		var diagonal: Vector2i = rule[2]
		var frame: int = rule[3]
		var first_solid := block_layer.get_cell_source_id(cell + first) != -1
		var second_solid := block_layer.get_cell_source_id(cell + second) != -1
		var owner_id := block_layer.get_cell_source_id(cell + diagonal)
		if not first_solid or not second_solid or not inside_corner_textures.has(owner_id):
			_remove_inside_corner(cell, frame)
			continue
		var key := _inside_corner_key(cell, frame)
		var sprite := inside_corner_sprites.get(key) as Sprite2D
		if not is_instance_valid(sprite):
			sprite = Sprite2D.new()
			sprite.name = "InsideCorner_%d_%d_%d" % [cell.x, cell.y, frame]
			sprite.centered = true
			sprite.region_enabled = true
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			inside_corner_layer.add_child(sprite)
			inside_corner_sprites[key] = sprite
		sprite.texture = inside_corner_textures[owner_id]
		sprite.region_rect = Rect2(Vector2(frame % 2, frame / 2) * INSIDE_CORNER_FRAME_SIZE, Vector2(INSIDE_CORNER_FRAME_SIZE, INSIDE_CORNER_FRAME_SIZE))
		# The 128x128 frame spans the four cells around the real grid vertex. It
		# restores the two border endpoints and draws the derived inverse curve.
		var vertex_offset := Vector2(-32.0, -32.0)
		match frame:
			1: vertex_offset = Vector2(32.0, -32.0)
			2: vertex_offset = Vector2(32.0, 32.0)
			3: vertex_offset = Vector2(-32.0, 32.0)
		var empty_center := block_layer.map_to_local(cell)
		sprite.position = inside_corner_layer.to_local(block_layer.to_global(empty_center + vertex_offset))
		sprite.visible = true

func _refresh_inside_corners_around(cell: Vector2i) -> void:
	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			_refresh_inside_corners_for_empty_cell(cell + Vector2i(x_offset, y_offset))

func _rebuild_inside_corners() -> void:
	for sprite_value: Variant in inside_corner_sprites.values():
		var sprite := sprite_value as Sprite2D
		if is_instance_valid(sprite):
			sprite.queue_free()
	inside_corner_sprites.clear()
	var used_rect := block_layer.get_used_rect().grow(1)
	for y in range(used_rect.position.y, used_rect.end.y):
		for x in range(used_rect.position.x, used_rect.end.x):
			var cell := Vector2i(x, y)
			if block_layer.get_cell_source_id(cell) == -1:
				_refresh_inside_corners_for_empty_cell(cell)

func _configure_mine_lighting() -> void:
	# Keep the generated fog data available for future secrets or minimap use,
	# but do not cover the world with an almost-black tile overlay during play.
	fog_layer.visible = show_fog_overlay
	canvas_modulate.color = ambient_tint
	player_light.color = player_light_color
	player_light.energy = player_light_energy
	player_light.texture_scale = player_light_scale
	if player_light.texture is GradientTexture2D:
		var radial_texture := player_light.texture as GradientTexture2D
		radial_texture.fill = GradientTexture2D.FILL_RADIAL
		radial_texture.fill_from = Vector2(0.5, 0.5)
		radial_texture.fill_to = Vector2(1.0, 0.5)
	# Tile occluder shadows caused hard seams around the 64 px terrain cells.
	# The broad radial light gives the mine atmosphere without those artifacts.
	player_light.shadow_enabled = false

func on_cell_dug(cell: Vector2i) -> void:
	if not world_generation_in_progress:
		topology_revision += 1
		dug_at_msec[cell] = Time.get_ticks_msec()
	if astar.is_in_bounds(cell.x, cell.y):
		astar.set_point_solid(cell, false)
	
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
	_refresh_navigation_weights_around(cell, 2)

func update_fog_mask(cell: Vector2i) -> void:
	if block_layer.get_cell_source_id(cell) == -1:
		fog_layer.erase_cell(cell)
		edge_layer.erase_cell(cell)
		_refresh_inside_corners_around(cell)
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
	
	# EdgeLayer now contains the complete visible cell, including the universal
	# mass for mask 0 and true transparent rounded cutouts for corner masks.
	var block_type = block_layer.get_cell_source_id(cell)
	var edge_source = 4 # Easy
	if block_type == 2: edge_source = 5
	elif block_type == 3: edge_source = 6
	edge_layer.set_cell(cell, edge_source, Vector2i(atlas_x, atlas_y))
		
	if gem_blocks.has(cell):
		_refresh_gem_indicator(cell)
	_refresh_inside_corners_around(cell)

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

func _ensure_base_gem_indicator_textures() -> void:
	if gem_top_texture == null:
		gem_top_texture = BASE_GEM_TEXTURE_FACTORY.load_svg_texture(GEM_TOP_TEXTURE_PATH)
	if gem_front_texture == null:
		gem_front_texture = BASE_GEM_TEXTURE_FACTORY.load_svg_texture(GEM_FRONT_TEXTURE_PATH)

func _gem_chance_for_cell(cell: Vector2i, block_type: int) -> float:
	var base_chance := 0.05
	if block_type == 2:
		base_chance = 0.14
	elif block_type == 3:
		base_chance = 0.28
	var depth_bonus := clampf(float(maxi(cell.y, 0)) / 30.0 * 0.08, 0.0, 0.08)
	return minf(base_chance + depth_bonus, 0.38)

func _create_gem_block(cell: Vector2i) -> void:
	if gem_blocks.has(cell):
		return
	var sprite := Sprite2D.new()
	sprite.texture = gem_top_texture
	sprite.position = block_layer.map_to_local(cell)
	sprite.visible = false
	edge_layer.add_child(sprite)

	var front_sprite := Sprite2D.new()
	front_sprite.texture = gem_front_texture
	front_sprite.offset.y = -17
	front_sprite.z_index = FRONT_GEM_Z_INDEX
	front_sprite.visible = false
	add_child(front_sprite)
	_position_front_gem_sprite(front_sprite, cell)
	gem_blocks[cell] = {"top": sprite, "front": front_sprite}

func _seed_expedition_motherlodes() -> void:
	if is_vs_mode:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var definitions := [
		{"stage": 1, "depth": 12, "count": 3, "rock": 2},
		{"stage": 2, "depth": 18, "count": 4, "rock": 2},
		{"stage": 3, "depth": 24, "count": 6, "rock": 3},
		{"stage": 4, "depth": 28, "count": 8, "rock": 3},
	]
	var pattern: Array[Vector2i] = [
		Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1)
	]
	var motherlodes := {}
	for definition_value in definitions:
		var definition: Dictionary = definition_value
		var side := -1 if rng.randi_range(0, 1) == 0 else 1
		var center := Vector2i(side * rng.randi_range(6, 12), int(definition["depth"]))
		motherlodes[int(definition["stage"])] = center
		for index in range(int(definition["count"])):
			var cell := center + pattern[index % pattern.size()]
			if block_layer.get_cell_source_id(cell) == -1:
				block_layer.set_cell(cell, int(definition["rock"]), Vector2i.ZERO)
			if astar.is_in_bounds(cell.x, cell.y):
				astar.set_point_solid(cell, true)
			_create_gem_block(cell)
			for refresh_cell in [cell, cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]:
				update_fog_mask(refresh_cell)
				update_front_wall(refresh_cell)
	minewars_motherlodes = motherlodes

func ensure_minewars_motherlodes() -> void:
	if minewars_motherlodes.is_empty():
		_seed_expedition_motherlodes()

func get_minewars_prospect_hint(stage: int) -> String:
	if not minewars_motherlodes.has(stage):
		var fallback_depths := {1: 12, 2: 18, 3: 24, 4: 28}
		return "A rich seam should lie near depth %d." % int(fallback_depths.get(stage, 8))
	var cell: Vector2i = minewars_motherlodes[stage]
	var direction := "west" if cell.x < 0 else "east"
	return "Prospecting marks point %s near depth %d." % [direction, cell.y]

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
				
			if y >= 0 and randf() < _gem_chance_for_cell(cell, block_type):
				_create_gem_block(cell)
				
	_seed_expedition_motherlodes()
	_ensure_tutorial_gem()
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
	_carve_surface_breach_corridors()

func _carve_surface_breach_corridors() -> void:
	# These narrow exterior tunnels guarantee a fair fallback entrance even when
	# the player has only dug one long shaft and is standing at its endpoint.
	for x in range(-10, -5):
		on_cell_dug(Vector2i(x, -2))
	for x in range(6, 11):
		on_cell_dug(Vector2i(x, -2))

func _ensure_tutorial_gem() -> void:
	if is_vs_mode or gem_blocks.has(TUTORIAL_GEM_CELL):
		return
	block_layer.set_cell(TUTORIAL_GEM_CELL, 1, Vector2i(0, 0))
	if astar.is_in_bounds(TUTORIAL_GEM_CELL.x, TUTORIAL_GEM_CELL.y):
		astar.set_point_solid(TUTORIAL_GEM_CELL, true)
	var sprite := Sprite2D.new()
	sprite.texture = gem_top_texture
	sprite.position = block_layer.map_to_local(TUTORIAL_GEM_CELL)
	sprite.visible = false
	edge_layer.add_child(sprite)
	var front_sprite := Sprite2D.new()
	front_sprite.texture = gem_front_texture
	front_sprite.offset.y = -17
	front_sprite.z_index = FRONT_GEM_Z_INDEX
	front_sprite.visible = false
	add_child(front_sprite)
	_position_front_gem_sprite(front_sprite, TUTORIAL_GEM_CELL)
	gem_blocks[TUTORIAL_GEM_CELL] = {"top": sprite, "front": front_sprite}

func begin_run_from_preparation() -> void:
	if not preparation_active:
		return
	preparation_active = false
	preparation_mode = false
	Global.apply_selected_loadout()
	Global.save_game()
	var player := get_node_or_null("Player")
	if player and player.has_method("update_hero_sprites"):
		player.update_hero_sprites()
	var base := get_node_or_null("Base")
	if base and base.has_method("refresh_base_sprite"):
		base.refresh_base_sprite()
	call_deferred("_begin_player_journey")

func _begin_player_journey() -> void:
	if is_vs_mode:
		return
	onboarding_active = not Global.prototype_onboarding_completed
	var hud := get_node_or_null("HUD")
	var legacy_summary := _apply_permanent_run_upgrades(hud)
	if onboarding_active and hud:
		# The first-run tutorial temporarily exposes the complete information HUD
		# so the player can learn what each system means. This does not set upgrade
		# ownership; the next run returns to the intended purchasable HUD modules.
		if hud.has_method("unlock_wave_timer"):
			hud.unlock_wave_timer()
		if hud.has_method("unlock_base_healthbar"):
			hud.unlock_base_healthbar()
		if hud.has_method("unlock_healthbar"):
			hud.unlock_healthbar()
		if hud.has_method("unlock_stats"):
			hud.unlock_stats()
		if hud.has_method("unlock_xp"):
			hud.unlock_xp()
		var player := get_node_or_null("Player")
		if player and hud.has_method("update_stats"):
			hud.update_stats(int(player.strength), int(player.agility), int(player.intelligence))
		if player and hud.has_method("update_xp"):
			hud.update_xp(int(player.level), int(player.xp), int(player.max_xp))
	if onboarding_active:
		_create_entry_marker()
		_set_onboarding_stage(OnboardingStage.DIG_DOWN)
	elif hud and hud.has_method("show_notice"):
		var notice := "Tutorial HUD offline. Restore health, stats, XP, and wave modules at the base."
		if not legacy_summary.is_empty():
			notice += "  Legacy active: %s." % legacy_summary
		hud.show_notice(notice, 5.0)

func _apply_permanent_run_upgrades(hud: Node) -> String:
	if bool(get_meta("permanent_run_upgrades_applied", false)):
		return ""
	set_meta("permanent_run_upgrades_applied", true)
	var active_bonuses: Array[String] = []
	var base := get_node_or_null("Base")
	var base_bonus := Global.get_permanent_base_health_bonus()
	if base and base_bonus > 0 and base.has_method("upgrade_max_health"):
		base.upgrade_max_health(base_bonus)
		active_bonuses.append("+%d base HP" % base_bonus)
	var starting_gems := Global.get_permanent_starting_gems()
	if hud and starting_gems > 0 and Global.prototype_onboarding_completed and hud.has_method("add_gems"):
		hud.add_gems(starting_gems)
		active_bonuses.append("+%d starting gem%s" % [starting_gems, "" if starting_gems == 1 else "s"])
	var carry_bonus := Global.get_permanent_carry_bonus()
	if carry_bonus > 0:
		active_bonuses.append("+%d free carry" % carry_bonus)
	return ", ".join(active_bonuses)

func _create_entry_marker() -> void:
	if onboarding_entry_marker and is_instance_valid(onboarding_entry_marker):
		return
	onboarding_entry_marker = Node2D.new()
	onboarding_entry_marker.name = "FirstRunDigMarker"
	onboarding_entry_marker.position = block_layer.map_to_local(TUTORIAL_GEM_CELL) + Vector2(0, -34)
	onboarding_entry_marker.z_index = 30
	add_child(onboarding_entry_marker)
	var glow := Polygon2D.new()
	var glow_points := PackedVector2Array()
	for index in range(25):
		glow_points.append(Vector2.RIGHT.rotated(TAU * float(index) / 24.0) * 28.0)
	glow.polygon = glow_points
	glow.color = Color(0.25, 0.94, 1.0, 0.12)
	onboarding_entry_marker.add_child(glow)
	for chevron_index in range(2):
		var chevron := Line2D.new()
		chevron.width = 5.0
		chevron.default_color = Color(0.38, 0.96, 1.0, 0.96 - float(chevron_index) * 0.22)
		var y := -18.0 + float(chevron_index) * 17.0
		chevron.points = PackedVector2Array([Vector2(-14, y), Vector2(0, y + 12), Vector2(14, y)])
		onboarding_entry_marker.add_child(chevron)
	onboarding_entry_marker_tween = create_tween().bind_node(onboarding_entry_marker).set_loops()
	onboarding_entry_marker_tween.tween_property(onboarding_entry_marker, "position:y", onboarding_entry_marker.position.y + 7.0, 0.55).set_trans(Tween.TRANS_SINE)
	onboarding_entry_marker_tween.tween_property(onboarding_entry_marker, "position:y", onboarding_entry_marker.position.y, 0.55).set_trans(Tween.TRANS_SINE)

func _remove_entry_marker() -> void:
	# This tween is created by the world but targets the short-lived tutorial
	# marker. Stop it before freeing the marker so the web build cannot enter a
	# zero-duration loop after the first block advances the tutorial.
	if onboarding_entry_marker_tween and onboarding_entry_marker_tween.is_valid():
		onboarding_entry_marker_tween.kill()
	onboarding_entry_marker_tween = null
	if onboarding_entry_marker and is_instance_valid(onboarding_entry_marker):
		onboarding_entry_marker.queue_free()
	onboarding_entry_marker = null

func _set_onboarding_stage(stage: int) -> void:
	onboarding_stage = stage
	var hud := get_node_or_null("HUD")
	if hud == null or not hud.has_method("show_objective"):
		return
	match stage:
		OnboardingStage.DIG_DOWN:
			hud.show_objective("I", "DIG  ▼", "")
		OnboardingStage.FIND_GEM:
			hud.show_objective("II", "CRYSTAL SEAM", "")
		OnboardingStage.PICK_UP_GEM:
			hud.show_objective("III", "SPACE / A", "")
		OnboardingStage.BANK_GEM:
			hud.show_objective("IV", "RETURN  ◇", "")
		OnboardingStage.OPEN_UPGRADES:
			hud.show_objective("V", "FORGE  E / Y", "")
		OnboardingStage.COMPLETE:
			hud.show_objective("READY", "MINE  •  RETURN  •  DEFEND", "")
			Global.complete_prototype_onboarding()
			var objective_hud := hud
			get_tree().create_timer(2.2).timeout.connect(func():
				if is_instance_valid(objective_hud) and objective_hud.has_method("hide_objective"):
					objective_hud.hide_objective()
			)

func notify_minewars_gem_dug(cell: Vector2i) -> void:
	if not bool(get_meta("minewars_expedition", false)):
		return
	var controller := get_node_or_null("SiegeModeController")
	if controller != null and controller.has_method("notify_objective_gem_dug"):
		controller.call("notify_objective_gem_dug", cell)

func notify_tutorial_cell_dug(_cell: Vector2i, contained_gem: bool) -> void:
	if not onboarding_active:
		return
	if onboarding_stage == OnboardingStage.DIG_DOWN:
		_remove_entry_marker()
		_set_onboarding_stage(OnboardingStage.FIND_GEM)
	if contained_gem and onboarding_stage <= OnboardingStage.PICK_UP_GEM:
		_set_onboarding_stage(OnboardingStage.PICK_UP_GEM)

func notify_tutorial_gem_spawned(gem: Node) -> void:
	if not onboarding_active:
		return
	if onboarding_stage <= OnboardingStage.PICK_UP_GEM:
		_set_onboarding_stage(OnboardingStage.PICK_UP_GEM)
	if gem and gem.has_method("set_tutorial_emphasis"):
		gem.set_tutorial_emphasis(true)
	_play_first_crystal_discovery(gem)

func _play_first_crystal_discovery(gem: Node) -> void:
	if gem == null or bool(get_meta("first_crystal_discovery_played", false)):
		return
	set_meta("first_crystal_discovery_played", true)
	var position := (gem as Node2D).global_position if gem is Node2D else Vector2.ZERO
	_spawn_resource_burst(position, Color(0.24, 1.0, 0.95, 1.0), "FirstCrystalDiscovery", 34)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_objective_tick"):
		sound_fx.play_objective_tick(2)
	var player := get_node_or_null("Player")
	var camera := player.get_node_or_null("Camera2D") as Camera2D if player else null
	if camera != null:
		var rest := camera.offset
		var shake := create_tween()
		shake.tween_property(camera, "offset", rest + Vector2(3, -2), 0.04)
		shake.tween_property(camera, "offset", rest + Vector2(-2, 2), 0.04)
		shake.tween_property(camera, "offset", rest, 0.07)

func notify_tutorial_gem_picked(_gem: Node) -> void:
	if onboarding_active and onboarding_stage <= OnboardingStage.BANK_GEM:
		_set_onboarding_stage(OnboardingStage.BANK_GEM)

func notify_tutorial_gems_deposited(amount: int) -> void:
	if amount <= 0:
		return
	if not first_deposit_received:
		first_deposit_received = true
		wave_timer = min(wave_timer, 18.0)
	if onboarding_active and onboarding_stage <= OnboardingStage.OPEN_UPGRADES:
		_set_onboarding_stage(OnboardingStage.OPEN_UPGRADES)

func notify_tutorial_upgrade_opened() -> void:
	if not onboarding_active or onboarding_stage != OnboardingStage.OPEN_UPGRADES:
		return
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("show_objective"):
		hud.show_objective("V", "CHOOSE  STR  •  AGI  •  INT", "")

func notify_tutorial_upgrade_purchased() -> void:
	if not onboarding_active or onboarding_stage != OnboardingStage.OPEN_UPGRADES:
		return
	onboarding_active = false
	wave_timer = min(wave_timer, 18.0)
	_set_onboarding_stage(OnboardingStage.COMPLETE)

func is_dig_cell_protected(cell: Vector2i) -> bool:
	# Protect the original base foundation during standard runs. Specialized
	# persistent-world subclasses can open deliberate routes through it.
	return (cell.y <= 1 and cell.x != 0) or cell.y < 0

func get_protected_dig_message(cell: Vector2i) -> String:
	if cell.y < 0:
		return "You cannot mine upward into the base floor. Continue deeper or return through the shaft."
	return "The surface supports are protected. Dig down through the central shaft."

func notify_protected_dig(world_position: Vector2, message: String) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("show_notice"):
		hud.show_notice(message, 1.8)
	spawn_blocked_dig_feedback(world_position)

func spawn_blocked_dig_feedback(world_position: Vector2) -> void:
	var blocked_label := Label.new()
	blocked_label.text = "PROTECTED"
	blocked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blocked_label.add_theme_font_size_override("font_size", 14)
	blocked_label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.18, 1.0))
	blocked_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	blocked_label.add_theme_constant_override("outline_size", 4)
	blocked_label.position = world_position - Vector2(70, 24)
	blocked_label.size = Vector2(140, 28)
	blocked_label.z_index = 32
	add_child(blocked_label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(blocked_label, "position", blocked_label.position + Vector2(0, -24), 0.7)
	tween.tween_property(blocked_label, "modulate", Color(1, 1, 1, 0), 0.7)
	tween.chain().tween_callback(blocked_label.queue_free)

func has_gem(cell: Vector2i) -> bool:
	if gem_blocks.has(cell):
		var sprites: Dictionary = gem_blocks[cell]
		var top_sprite: Sprite2D = sprites.get("top") as Sprite2D
		var front_sprite: Sprite2D = sprites.get("front") as Sprite2D
		if is_instance_valid(top_sprite):
			top_sprite.visible = false
			top_sprite.queue_free()
		if is_instance_valid(front_sprite):
			front_sprite.visible = false
			front_sprite.queue_free()
		gem_blocks.erase(cell)
		return true
	return false

func try_spawn_cave_reward(cell: Vector2i) -> bool:
	if is_vs_mode or cave_reward_spawned or cell.y < CAVE_REWARD_MIN_DEPTH:
		return false
	cave_reward_spawned = true
	var reward := MINERS_SATCHEL_SCENE.instantiate()
	var reward_world_position := block_layer.to_global(block_layer.map_to_local(cell))
	reward.position = to_local(reward_world_position)
	call_deferred("add_child", reward)
	spawn_cave_reward_reveal_feedback(reward_world_position)
	return true

var current_wave_number = 1

func _process(delta: float) -> void:
	if preparation_active:
		return
	if is_vs_mode:
		income_timer -= delta
		if income_timer <= 0:
			income_timer = 3.0
			var hud = get_node_or_null("HUD")
			if hud and hud.has_method("add_gold") and income > 0:
				hud.add_gold(income)
		return
	var enemies_alive := get_tree().get_nodes_in_group("enemies").size()
	var wave_spawning := bool(get_meta("wave_spawning", false))
	var wave_active := enemies_alive > 0 or wave_spawning
	var tutorial_holds_threat := onboarding_active
	
	if not wave_active and not tutorial_holds_threat:
		if prepared_breach_wave != current_wave_number:
			_prepare_breach_for_wave(current_wave_number)
		wave_timer -= delta
		_update_breach_marker_text(current_wave_number, false)
	elif wave_active and current_breach_valid:
		_update_breach_marker_text(int(get_meta("active_wave_number", current_wave_number)), true)
		
	var hud = get_node_or_null("HUD")
	if hud and hud.has_method("update_wave_info"):
		var displayed_wave: int = int(get_meta("active_wave_number", current_wave_number)) if wave_active else int(current_wave_number)
		var is_boss: bool = displayed_wave % 10 == 0
		var max_wave_time: float = float(wave_interval if displayed_wave > 1 else FIRST_WAVE_DELAY)
		
		if wave_active:
			hud.update_wave_info(displayed_wave, -1.0, max_wave_time, is_boss)
		else:
			hud.update_wave_info(displayed_wave, max(wave_timer, 0.0), max_wave_time, is_boss)
		
	if wave_timer <= 0 and not wave_active:
		var wave_to_spawn: int = int(current_wave_number)
		set_meta("active_wave_number", wave_to_spawn)
		set_meta("wave_spawning", true)
		spawn_wave(wave_to_spawn)
		wave_timer = wave_interval
		current_wave_number += 1
		enemies_per_wave += 1

func _get_cardinal_neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [cell + Vector2i.RIGHT, cell + Vector2i.LEFT, cell + Vector2i.DOWN, cell + Vector2i.UP]

func _get_reachable_open_distances() -> Dictionary:
	var distances: Dictionary = {}
	if not astar.is_in_bounds(BASE_TARGET_CELL.x, BASE_TARGET_CELL.y) or astar.is_point_solid(BASE_TARGET_CELL):
		return distances
	var queue: Array[Vector2i] = [BASE_TARGET_CELL]
	distances[BASE_TARGET_CELL] = 0
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_distance: int = int(distances[current])
		for neighbor in _get_cardinal_neighbors(current):
			if not astar.is_in_bounds(neighbor.x, neighbor.y):
				continue
			if astar.is_point_solid(neighbor) or distances.has(neighbor):
				continue
			distances[neighbor] = current_distance + 1
			queue.append(neighbor)
	return distances

func _is_dynamic_breach_endpoint(cell: Vector2i, distances: Dictionary) -> bool:
	if cell.y < 1 or cell.x < -20 or cell.x >= 20 or cell.y >= 30:
		return false
	var open_neighbors: Array[Vector2i] = []
	for neighbor in _get_cardinal_neighbors(cell):
		if astar.is_in_bounds(neighbor.x, neighbor.y) and not astar.is_point_solid(neighbor):
			open_neighbors.append(neighbor)
	if open_neighbors.size() > 2:
		return false
	var cell_distance: int = int(distances.get(cell, -1))
	if cell_distance < BREACH_MIN_BASE_PATH_CELLS:
		return false
	for neighbor in open_neighbors:
		if distances.has(neighbor) and int(distances[neighbor]) > cell_distance:
			return false
	return true

func _collect_dynamic_breach_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var distances := _get_reachable_open_distances()
	var player := get_node_or_null("Player")
	var player_position: Vector2 = player.global_position if player else block_layer.to_global(block_layer.map_to_local(BASE_TARGET_CELL))
	var player_cell: Vector2i = block_layer.local_to_map(block_layer.to_local(player_position))
	var now_msec := Time.get_ticks_msec()
	for cell_value in distances.keys():
		var cell: Vector2i = cell_value
		if not _is_dynamic_breach_endpoint(cell, distances):
			continue
		var grid_distance := absi(cell.x - player_cell.x) + absi(cell.y - player_cell.y)
		if grid_distance < BREACH_MIN_PLAYER_GRID_DISTANCE:
			continue
		var cell_world := block_layer.to_global(block_layer.map_to_local(cell))
		var player_distance := cell_world.distance_to(player_position)
		if player_distance < BREACH_MIN_PLAYER_WORLD_DISTANCE:
			continue
		var dug_time := int(dug_at_msec.get(cell, 0))
		if dug_time > 0 and now_msec - dug_time < BREACH_RECENT_DIG_GRACE_MSEC:
			continue
		var open_neighbor_count := get_open_neighbor_count(cell)
		var solid_neighbor_count := 4 - open_neighbor_count
		var score := float(int(distances[cell]) * 10 + cell.y * 2 + solid_neighbor_count * 6 + mini(grid_distance, 20) * 2)
		candidates.append({"cell": cell, "score": score, "player_distance": player_distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	return candidates

func _choose_surface_breach_cell(wave_number: int) -> Vector2i:
	var player := get_node_or_null("Player")
	if player == null:
		return SURFACE_BREACH_CELLS[wave_number % SURFACE_BREACH_CELLS.size()]
	var left: Vector2i = SURFACE_BREACH_CELLS[0]
	var right: Vector2i = SURFACE_BREACH_CELLS[1]
	var left_position := block_layer.to_global(block_layer.map_to_local(left))
	var right_position := block_layer.to_global(block_layer.map_to_local(right))
	var left_distance := left_position.distance_to(player.global_position)
	var right_distance := right_position.distance_to(player.global_position)
	if is_equal_approx(left_distance, right_distance):
		return SURFACE_BREACH_CELLS[wave_number % SURFACE_BREACH_CELLS.size()]
	return left if left_distance > right_distance else right

func _select_new_breach(wave_number: int) -> Dictionary:
	if wave_number >= BREACH_DYNAMIC_START_WAVE:
		var candidates := _collect_dynamic_breach_candidates()
		if not candidates.is_empty():
			var top_count := mini(candidates.size(), BREACH_TOP_CANDIDATE_COUNT)
			var choice_index := posmod(wave_number + topology_revision, top_count)
			return {"cell": candidates[choice_index]["cell"], "surface": false}
	return {"cell": _choose_surface_breach_cell(wave_number), "surface": true}

func _is_breach_reachable(cell: Vector2i) -> bool:
	if not astar.is_in_bounds(cell.x, cell.y) or astar.is_point_solid(cell):
		return false
	return _get_reachable_open_distances().has(cell)

func _prepare_breach_for_wave(wave_number: int) -> void:
	if prepared_breach_wave == wave_number and current_breach_valid:
		_update_breach_marker_text(wave_number, false)
		return
	# Once announced, a breach stays fixed for its full wave lifetime. The mine
	# only opens new cells, so revalidating it here could rotate a promised
	# entrance between waves because of transient AStar/editor state.
	var needs_new_site := not current_breach_valid or current_breach_waves_remaining <= 0
	if needs_new_site:
		var selection := _select_new_breach(wave_number)
		current_breach_cell = selection["cell"]
		current_breach_is_surface = bool(selection["surface"])
		current_breach_valid = true
		current_breach_waves_remaining = BREACH_SITE_WAVE_LIFETIME
	prepared_breach_wave = wave_number
	_show_or_move_breach_marker(wave_number)
	var hud := get_node_or_null("HUD")
	var breach_position := block_layer.to_global(block_layer.map_to_local(current_breach_cell))
	if hud and hud.has_method("set_breach_target"):
		hud.set_breach_target(breach_position, wave_number, true)
	if needs_new_site and hud and hud.has_method("show_notice"):
		var location_text := "surface tunnel" if current_breach_is_surface else "deep tunnel endpoint"
		hud.show_notice("Wave %d breach detected at a %s. Follow the red warning." % [wave_number, location_text], 3.4)

func _show_or_move_breach_marker(wave_number: int) -> void:
	if breach_marker == null or not is_instance_valid(breach_marker):
		breach_marker = Node2D.new()
		breach_marker.name = "EnemyBreachMarker"
		breach_marker.z_index = BREACH_MARKER_Z_INDEX
		var core := Polygon2D.new()
		core.name = "Core"
		core.polygon = PackedVector2Array([Vector2(-25, 0), Vector2(0, -15), Vector2(25, 0), Vector2(0, 15)])
		core.color = Color(0.18, 0.015, 0.01, 0.92)
		breach_marker.add_child(core)
		for points_value in [
			PackedVector2Array([Vector2(-29, -18), Vector2(-10, -4), Vector2(-24, 13)]),
			PackedVector2Array([Vector2(30, -17), Vector2(11, -3), Vector2(26, 15)]),
			PackedVector2Array([Vector2(-5, -26), Vector2(0, -8), Vector2(8, -23)])
		]:
			var crack := Line2D.new()
			crack.width = 4.0
			crack.default_color = Color(1.0, 0.16, 0.06, 0.95)
			crack.points = points_value
			breach_marker.add_child(crack)
		var title := Label.new()
		title.name = "Title"
		title.position = Vector2(-90, -58)
		title.size = Vector2(180, 28)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", Color(1.0, 0.22, 0.1, 1.0))
		title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
		title.add_theme_constant_override("outline_size", 4)
		breach_marker.add_child(title)
		var subtitle := Label.new()
		subtitle.name = "Subtitle"
		subtitle.position = Vector2(-100, 26)
		subtitle.size = Vector2(200, 24)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 11)
		subtitle.add_theme_color_override("font_color", Color(1.0, 0.66, 0.35, 1.0))
		subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		subtitle.add_theme_constant_override("outline_size", 3)
		breach_marker.add_child(subtitle)
		add_child(breach_marker)
	breach_marker.global_position = block_layer.to_global(block_layer.map_to_local(current_breach_cell))
	breach_marker.visible = true
	breach_marker.scale = Vector2.ONE
	if breach_marker_tween and breach_marker_tween.is_running():
		breach_marker_tween.kill()
	breach_marker_tween = create_tween().set_loops()
	breach_marker_tween.tween_property(breach_marker, "scale", Vector2(1.08, 1.08), 0.55).set_trans(Tween.TRANS_SINE)
	breach_marker_tween.tween_property(breach_marker, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)
	_update_breach_marker_text(wave_number, false)

func _update_breach_marker_text(wave_number: int, active: bool) -> void:
	if breach_marker == null or not is_instance_valid(breach_marker):
		return
	var title := breach_marker.get_node_or_null("Title") as Label
	var subtitle := breach_marker.get_node_or_null("Subtitle") as Label
	if title:
		title.text = "ACTIVE BREACH" if active else "WAVE %d  •  %ds" % [wave_number, int(ceil(maxf(wave_timer, 0.0)))]
	if subtitle:
		var location := "SURFACE ENTRANCE" if current_breach_is_surface else "DEEP ENTRANCE"
		subtitle.text = "%s  •  %d WAVE%s" % [location, current_breach_waves_remaining, "" if current_breach_waves_remaining == 1 else "S"]

func _consume_prepared_breach(wave_number: int) -> void:
	current_breach_waves_remaining = maxi(current_breach_waves_remaining - 1, 0)
	prepared_breach_wave = 0
	_update_breach_marker_text(wave_number, true)

func _get_breach_spawn_cells(spawn_count: int) -> Array[Vector2i]:
	var slots: Array[Vector2i] = []
	var queue: Array[Dictionary] = [{"cell": current_breach_cell, "distance": 0}]
	var visited: Dictionary = {current_breach_cell: true}
	var candidates: Array[Dictionary] = []
	var player := get_node_or_null("Player")
	var player_position: Vector2 = player.global_position if player else Vector2.ZERO
	while not queue.is_empty():
		var item: Dictionary = queue.pop_front()
		var cell: Vector2i = item["cell"]
		var distance: int = int(item["distance"])
		var cell_position := block_layer.to_global(block_layer.map_to_local(cell))
		var safety_distance := cell_position.distance_to(player_position) if player else 9999.0
		var score := safety_distance * 0.04 - float(distance * 22)
		candidates.append({"cell": cell, "score": score})
		if distance >= 3:
			continue
		for neighbor in _get_cardinal_neighbors(cell):
			if visited.has(neighbor) or not astar.is_in_bounds(neighbor.x, neighbor.y) or astar.is_point_solid(neighbor):
				continue
			if astar.get_id_path(neighbor, BASE_TARGET_CELL).is_empty():
				continue
			visited[neighbor] = true
			queue.append({"cell": neighbor, "distance": distance + 1})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	for candidate in candidates:
		if slots.size() >= spawn_count:
			break
		slots.append(candidate["cell"])
	if slots.is_empty():
		slots.append(current_breach_cell)
	return slots

func _get_breach_spawn_position(cell: Vector2i, index: int) -> Vector2:
	var center := block_layer.to_global(block_layer.map_to_local(cell))
	var route := astar.get_id_path(cell, BASE_TARGET_CELL)
	var direction := Vector2.RIGHT
	if route.size() > 1:
		var next_position := block_layer.to_global(block_layer.map_to_local(route[1]))
		direction = center.direction_to(next_position)
	var perpendicular := Vector2(-direction.y, direction.x)
	var lane := float((index % 3) - 1) * 9.0
	return center + perpendicular * lane

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
	# Introduce threats in readable tiers. The old fully random table could put
	# a Trogg or Orc into Wave 2, making the prototype's difficulty feel arbitrary.
	var staged_roll: float = randf()
	if wave <= 2:
		return 0 if staged_roll < 0.75 else 1 # Rat / Spider
	if wave <= 4:
		if staged_roll < 0.55:
			return 0
		return 1 if staged_roll < 0.82 else 2 # Add Bat
	if wave <= 7:
		if staged_roll < 0.42:
			return 0
		if staged_roll < 0.70:
			return 1
		return 2 if staged_roll < 0.90 else 3 # Add Trogg
	var roll = staged_roll
	
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

func _spawn_wave_telegraph(spawn_position: Vector2, is_boss: bool) -> void:
	var pulse := CPUParticles2D.new()
	pulse.name = "WaveBreachTelegraph"
	pulse.one_shot = true
	pulse.emitting = false
	pulse.amount = 46 if is_boss else 24
	pulse.lifetime = 0.75
	pulse.explosiveness = 0.9
	pulse.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	pulse.emission_sphere_radius = 18.0 if is_boss else 10.0
	pulse.gravity = Vector2.ZERO
	pulse.initial_velocity_min = 75.0
	pulse.initial_velocity_max = 180.0 if is_boss else 130.0
	pulse.damping_min = 90.0
	pulse.damping_max = 150.0
	pulse.scale_amount_min = 2.0
	pulse.scale_amount_max = 5.5 if is_boss else 4.0
	pulse.color = Color(1.0, 0.12, 0.08, 0.95) if is_boss else Color(1.0, 0.42, 0.12, 0.92)
	pulse.global_position = spawn_position
	pulse.z_index = 18
	add_child(pulse)
	pulse.emitting = true
	var breach_label := Label.new()
	breach_label.text = "BOSS BREACH" if is_boss else "ENEMY BREACH"
	breach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breach_label.position = spawn_position - Vector2(90, 48)
	breach_label.size = Vector2(180, 30)
	breach_label.z_index = 24
	breach_label.add_theme_font_size_override("font_size", 16)
	breach_label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.16, 1.0))
	breach_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
	breach_label.add_theme_constant_override("outline_size", 4)
	add_child(breach_label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(breach_label, "position", breach_label.position + Vector2(0, -24), 0.9)
	tween.tween_property(breach_label, "modulate", Color(1, 1, 1, 0), 0.9)
	tween.chain().tween_callback(breach_label.queue_free)
	get_tree().create_timer(1.0).timeout.connect(pulse.queue_free)

func spawn_wave(wave_number: int) -> void:
	_prepare_breach_for_wave(wave_number)
	var target_cell := current_breach_cell
	var spawn_pos := block_layer.to_global(block_layer.map_to_local(target_cell))
	var is_boss := wave_number % 10 == 0
	var hud := get_node_or_null("HUD")
	var spawn_count: int = 1 if is_boss else enemies_per_wave
	var spawn_cells := _get_breach_spawn_cells(spawn_count)
	if hud and hud.has_method("notify_wave_started"):
		hud.notify_wave_started(is_boss, wave_number)
	_spawn_wave_telegraph(spawn_pos, is_boss)
	await get_tree().create_timer(0.85).timeout
	
	for i in range(spawn_count):
		var enemy := ENEMY_SCENE.instantiate()
		add_child(enemy)
		var spawn_cell: Vector2i = spawn_cells[i % spawn_cells.size()]
		enemy.global_position = _get_breach_spawn_position(spawn_cell, i)
		if enemy.has_method("initialize"):
			# The first breach is a readable scout rat, not a random high-damage
			# enemy that can punish a player before they understand combat.
			var e_type: int = 0 if wave_number == 1 else get_random_enemy_type(wave_number)
			enemy.initialize(wave_number, is_boss, e_type)
		if enemy.has_method("begin_breach_emergence"):
			enemy.begin_breach_emergence(0.55 if not is_boss else 0.85)
		await get_tree().create_timer(0.4).timeout
	_consume_prepared_breach(wave_number)
	set_meta("wave_spawning", false)


func update_front_wall(cell: Vector2i) -> void:
	# The legacy square FrontWallLayer is intentionally disabled. The generated
	# renderer derives a shallow wall from the exact rounded edge-atlas alpha,
	# so convex ends and neighbouring materials share the terrain silhouette.
	front_layer.erase_cell(cell + Vector2i.DOWN)
	if front_extrusion_renderer != null:
		front_extrusion_renderer.call("refresh_around", cell)
	if gem_blocks.has(cell):
		_refresh_gem_indicator(cell)

func _normalize_gem_indicator_sprites() -> void:
	for raw_cell: Variant in gem_blocks.keys():
		var cell: Vector2i = raw_cell
		var sprites: Dictionary = gem_blocks[cell]
		var top_sprite: Sprite2D = sprites.get("top") as Sprite2D
		var front_sprite: Sprite2D = sprites.get("front") as Sprite2D
		if is_instance_valid(top_sprite):
			if top_sprite.get_parent() != self:
				top_sprite.reparent(self, true)
			top_sprite.texture = gem_top_texture
			top_sprite.region_enabled = false
			top_sprite.offset = Vector2.ZERO
			top_sprite.scale = GEM_INDICATOR_TOP_SCALE
			top_sprite.z_index = FRONT_GEM_Z_INDEX
			top_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if is_instance_valid(front_sprite):
			front_sprite.texture = gem_front_texture
			front_sprite.region_enabled = false
			front_sprite.offset = Vector2.ZERO
			front_sprite.scale = GEM_INDICATOR_FRONT_SCALE
			front_sprite.z_index = FRONT_GEM_Z_INDEX
			front_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_refresh_gem_indicator(cell)

func _refresh_gem_indicator(cell: Vector2i) -> void:
	if not gem_blocks.has(cell):
		return
	var sprites: Dictionary = gem_blocks[cell]
	var top_sprite: Sprite2D = sprites.get("top") as Sprite2D
	var front_sprite: Sprite2D = sprites.get("front") as Sprite2D
	var solid: bool = block_layer.get_cell_source_id(cell) != -1
	var top_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x, cell.y - 1)) == -1
	var right_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x + 1, cell.y)) == -1
	var bottom_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x, cell.y + 1)) == -1
	var left_open: bool = solid and block_layer.get_cell_source_id(Vector2i(cell.x - 1, cell.y)) == -1
	var show_front: bool = bottom_open
	var show_edge: bool = solid and not show_front and (top_open or right_open or left_open)

	if is_instance_valid(top_sprite):
		top_sprite.visible = show_edge
		if show_edge:
			top_sprite.global_position = block_layer.to_global(block_layer.map_to_local(cell))
			if top_open:
				top_sprite.rotation_degrees = 0.0
			elif left_open and not right_open:
				top_sprite.rotation_degrees = -90.0
			else:
				top_sprite.rotation_degrees = 90.0

	if is_instance_valid(front_sprite):
		_position_front_gem_sprite(front_sprite, cell)
		front_sprite.visible = show_front

func _position_front_gem_sprite(sprite: Sprite2D, cell: Vector2i) -> void:
	var below_cell = Vector2i(cell.x, cell.y + 1)
	sprite.global_position = front_layer.to_global(front_layer.map_to_local(below_cell))
	sprite.global_position.y += 1.0

func spawn_mining_feedback(world_position: Vector2, strong := false, gem_reveal := false, impact_direction := Vector2.ZERO) -> void:
	var burst := CPUParticles2D.new()
	burst.name = "MiningBreakFeedback" if strong else "MiningImpactFeedback"
	burst.add_to_group("polish_feedback")
	burst.one_shot = true
	burst.emitting = false
	burst.amount = 26 if strong else 9
	burst.lifetime = 0.55 if strong else 0.24
	burst.explosiveness = 0.95
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 7.0 if strong else 3.0
	burst.gravity = Vector2(0, 160)
	burst.initial_velocity_min = 80.0 if strong else 36.0
	burst.initial_velocity_max = 190.0 if strong else 90.0
	burst.damping_min = 90.0
	burst.damping_max = 170.0
	burst.scale_amount_min = 2.0 if strong else 1.2
	burst.scale_amount_max = 5.5 if strong else 2.8
	burst.color = Color(0.95, 0.82, 0.56, 0.95) if strong else Color(0.72, 0.58, 0.42, 0.82)
	if impact_direction.length_squared() > 0.01:
		# Spawn from the edge of the block and throw chips away from the
		# contact surface. This makes the dust read as a pick impact instead
		# of a generic burst at the tile centre.
		burst.direction = impact_direction.normalized()
		burst.spread = 72.0 if not strong else 105.0
	burst.global_position = world_position
	burst.z_index = 8
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(burst.lifetime + 0.15).timeout.connect(burst.queue_free)
	if gem_reveal:
		_spawn_feedback_label(world_position + Vector2(0, -24), "GEM REVEALED", Color(0.3, 1.0, 0.95), 1.05)
		var gem_flash := PointLight2D.new()
		gem_flash.name = "GemRevealFlash"
		gem_flash.add_to_group("polish_feedback")
		gem_flash.energy = 2.2
		gem_flash.texture_scale = 0.45
		gem_flash.color = Color(0.25, 1.0, 0.9)
		gem_flash.global_position = world_position
		add_child(gem_flash)
		var flash_tween := create_tween()
		flash_tween.tween_property(gem_flash, "energy", 0.0, 0.32)
		flash_tween.tween_callback(gem_flash.queue_free)

func spawn_gem_pickup_feedback(world_position: Vector2) -> void:
	_spawn_resource_burst(world_position, Color(0.25, 0.95, 1.0, 0.95), "GemPickupFeedback")
	_spawn_feedback_label(world_position + Vector2(0, -20), "PICKED UP", Color(0.55, 1.0, 1.0), 0.7)

func spawn_gem_deposit_feedback(world_position: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	_spawn_resource_burst(world_position, Color(1.0, 0.82, 0.25, 0.98), "GemDepositFeedback", 34)
	_spawn_feedback_label(world_position + Vector2(0, -34), "DEPOSITED", Color(1.0, 0.9, 0.45), 0.95)

func spawn_gold_pickup_feedback(world_position: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	_spawn_resource_burst(world_position, Color(1.0, 0.72, 0.16, 0.98), "GoldPickupFeedback", 22)
	_spawn_feedback_label(world_position + Vector2(0, -24), "+%d GOLD" % amount, Color(1.0, 0.86, 0.35), 0.9)

func spawn_xp_pickup_feedback(world_position: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	_spawn_resource_burst(world_position, Color(0.35, 0.95, 0.45, 0.96), "XPPickupFeedback", 18)
	_spawn_feedback_label(world_position + Vector2(0, -24), "+%d XP" % amount, Color(0.55, 1.0, 0.62), 0.82)

func spawn_cave_reward_reveal_feedback(world_position: Vector2) -> void:
	_spawn_resource_burst(world_position, Color(1.0, 0.62, 0.16, 0.98), "CaveRewardRevealFeedback", 28)
	_spawn_feedback_label(world_position + Vector2(0, -30), "SATCHEL FOUND", Color(1.0, 0.78, 0.3), 1.2)

func spawn_cave_reward_pickup_feedback(world_position: Vector2) -> void:
	_spawn_resource_burst(world_position, Color(1.0, 0.82, 0.32, 0.98), "CaveRewardPickupFeedback", 24)
	_spawn_feedback_label(world_position + Vector2(0, -24), "+1 FREE CARRY", Color(1.0, 0.9, 0.48), 1.0)

func _spawn_resource_burst(world_position: Vector2, burst_color: Color, effect_name: String, particle_count := 18) -> void:
	var burst := CPUParticles2D.new()
	burst.name = effect_name
	burst.add_to_group("polish_feedback")
	burst.one_shot = true
	burst.emitting = false
	burst.amount = particle_count
	burst.lifetime = 0.45
	burst.explosiveness = 0.92
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 8.0
	burst.gravity = Vector2(0, 70)
	burst.initial_velocity_min = 70.0
	burst.initial_velocity_max = 160.0
	burst.damping_min = 100.0
	burst.damping_max = 180.0
	burst.scale_amount_min = 1.8
	burst.scale_amount_max = 4.5
	burst.color = burst_color
	burst.global_position = world_position
	burst.z_index = 9
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.65).timeout.connect(burst.queue_free)

func _spawn_feedback_label(world_position: Vector2, text: String, text_color: Color, duration: float) -> void:
	var label := Label.new()
	label.name = "FeedbackLabel"
	label.add_to_group("polish_feedback")
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	label.position = world_position - Vector2(70, 14)
	label.size = Vector2(140, 28)
	label.z_index = 12
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -30), duration)
	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), duration)
	tween.chain().tween_callback(label.queue_free)

func _refresh_navigation_weights_around(center: Vector2i, radius: int = 2) -> void:
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			update_astar_weight(Vector2i(x, y))

func get_open_neighbor_count(cell: Vector2i) -> int:
	var count := 0
	for direction_value in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var direction: Vector2i = direction_value
		var neighbor: Vector2i = cell + direction
		if astar.is_in_bounds(neighbor.x, neighbor.y) and not astar.is_point_solid(neighbor):
			count += 1
	return count

func get_enemy_open_space_factor(world_position: Vector2) -> float:
	var cell := block_layer.local_to_map(block_layer.to_local(world_position))
	return clampf(float(get_open_neighbor_count(cell) - 2) / 2.0, 0.0, 1.0)

func update_astar_weight(cell: Vector2i) -> void:
	if not astar.is_in_bounds(cell.x, cell.y) or astar.is_point_solid(cell):
		return
	var solid_neighbors := 0
	for direction_value in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var direction: Vector2i = direction_value
		var neighbor: Vector2i = cell + direction
		if not astar.is_in_bounds(neighbor.x, neighbor.y) or astar.is_point_solid(neighbor):
			solid_neighbors += 1
	var cell_below := cell + Vector2i.DOWN
	var is_grounded := not astar.is_in_bounds(cell_below.x, cell_below.y) or astar.is_point_solid(cell_below)
	# Ground enemies prefer floors and tunnel edges. Fully open cavern centers are
	# still traversable, but cost enough that paths bend toward readable lanes.
	var weight := 1.0
	if is_grounded:
		weight *= 0.72
	else:
		weight *= 1.55
	match solid_neighbors:
		0:
			weight *= 2.4
		1:
			weight *= 0.95
		2:
			weight *= 0.76
		_:
			weight *= 0.68
	astar.set_point_weight_scale(cell, clampf(weight, 0.5, 4.5))

func update_rail_autotile(cell: Vector2i) -> void:
	if not has_node("RailLayer"): return
	var rail_layer = get_node("RailLayer")
	
	if rail_layer.get_cell_source_id(cell) == -1: return
	if block_layer.get_cell_source_id(cell) != -1:
		rail_layer.erase_cell(cell)
		return
	
	var up_cell = Vector2i(cell.x, cell.y - 1)
	var right_cell = Vector2i(cell.x + 1, cell.y)
	var down_cell = Vector2i(cell.x, cell.y + 1)
	var left_cell = Vector2i(cell.x - 1, cell.y)
	var up = rail_layer.get_cell_source_id(up_cell) != -1 and block_layer.get_cell_source_id(up_cell) == -1
	var right = rail_layer.get_cell_source_id(right_cell) != -1 and block_layer.get_cell_source_id(right_cell) == -1
	var down = rail_layer.get_cell_source_id(down_cell) != -1 and block_layer.get_cell_source_id(down_cell) == -1
	var left = rail_layer.get_cell_source_id(left_cell) != -1 and block_layer.get_cell_source_id(left_cell) == -1
	
	var mask = 0
	if up: mask |= 1
	if right: mask |= 2
	if down: mask |= 4
	if left: mask |= 8
	if mask == 0:
		mask = 5
	var atlas_coords = Vector2i(mask % 4, int(mask / 4))
		
	rail_layer.set_cell(cell, 15, atlas_coords)

func refresh_minecart_paths() -> void:
	for cart in get_tree().get_nodes_in_group("minecarts"):
		if is_instance_valid(cart) and cart.has_method("refresh_rail_path"):
			cart.refresh_rail_path()
