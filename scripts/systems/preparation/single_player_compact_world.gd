extends "res://scripts/systems/preparation/preparation_fast_world.gd"

# Single-player Hub shares the same room with MineWars. The Hub is a small
# bedrock-walled cave with the base at center. Walking through the single 1×1
# entrance at the bottom starts MineWars in-place — no scene reload. When
# MineWars activates, an enemy tunnel is carved to the right of the hub room.

# Room tiers based on progression
enum HubTier { BURROW, CAVE, STRONGHOLD }

const TIER_LAYOUTS := {
	HubTier.BURROW:     { "half_w": 2, "half_h": 2, "entrance_y": 3, "zoom": 1.4, "cam_y": 32 },
	HubTier.CAVE:       { "half_w": 3, "half_h": 3, "entrance_y": 4, "zoom": 1.1, "cam_y": 32 },
	HubTier.STRONGHOLD: { "half_w": 4, "half_h": 4, "entrance_y": 5, "zoom": 0.9, "cam_y": 32 },
}

# World bounds — kept wide enough for the mine below the hub.
const COMPACT_PLAYABLE_RECT := Rect2i(-20, -8, 40, 38)
const WORLD_X_MIN := -20
const WORLD_X_MAX := 19
const WORLD_Y_MIN := -8
const WORLD_Y_MAX := 29

# Enemy tunnel carved to the right when MineWars activates.
const ENEMY_TUNNEL_Y := 0
const ENEMY_TUNNEL_X_MIN := 5
const ENEMY_TUNNEL_X_MAX := 12
const ENEMY_TUNNEL_HALF_HEIGHT := 1

func get_playable_map_rect() -> Rect2i:
	return COMPACT_PLAYABLE_RECT

func get_hub_tier() -> HubTier:
	if Global.unlocked_heroes.size() >= 5:
		return HubTier.STRONGHOLD
	elif Global.unlocked_heroes.size() >= 2:
		return HubTier.CAVE
	return HubTier.BURROW

func get_minewars_entrance() -> Vector2i:
	var layout: Dictionary = TIER_LAYOUTS[get_hub_tier()]
	return Vector2i(0, int(layout["entrance_y"]))

func get_top_tunnel_entrance() -> Vector2i:
	var layout: Dictionary = TIER_LAYOUTS[get_hub_tier()]
	return Vector2i(0, -int(layout["entrance_y"]))

func is_top_tunnel_unlocked() -> bool:
	return get_hub_tier() == HubTier.STRONGHOLD and Global.minewars_runs_completed >= 3

func get_hub_camera_zoom() -> Vector2:
	var layout: Dictionary = TIER_LAYOUTS[get_hub_tier()]
	var z: float = layout["zoom"]
	return Vector2(z, z)

func get_hub_camera_pos() -> Vector2:
	var layout: Dictionary = TIER_LAYOUTS[get_hub_tier()]
	return Vector2(0, float(layout["cam_y"]))

func generate_initial_world() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.1

	var entrance_y: int = get_minewars_entrance().y
	var layout: Dictionary = TIER_LAYOUTS[get_hub_tier()]
	var half_w: int = layout["half_w"]
	var half_h: int = layout["half_h"]

	# Fill the entire world with blocks. The hub room area gets bedrock borders;
	# the mine below gets noise-based rock types for MineWars gameplay.
	for x in range(WORLD_X_MIN, WORLD_X_MAX + 1):
		for y in range(WORLD_Y_MIN, WORLD_Y_MAX + 1):
			var cell := Vector2i(x, y)
			var block_type := 16  # Default: bedrock (unminable)

			# The mine area below the hub entrance gets varied rock types.
			if y > entrance_y and x > WORLD_X_MIN and x < WORLD_X_MAX and y < WORLD_Y_MAX:
				var depth_factor := float(y - entrance_y) / float(WORLD_Y_MAX - entrance_y)
				var score := depth_factor + noise.get_noise_2d(x, y) * 0.5
				if score > 0.8:
					block_type = 3  # Hard
				elif score > 0.4:
					block_type = 2  # Medium
				else:
					block_type = 1  # Easy

			block_layer.set_cell(cell, block_type, Vector2i.ZERO)
			if astar.is_in_bounds(cell.x, cell.y):
				astar.set_point_solid(cell, true)

			# Scatter gems in the mine area below the hub.
			if y > entrance_y and block_type in [1, 2, 3] and randf() < 0.10:
				block_layer.set_cell(cell, BLOCK_GEM, Vector2i.ZERO)

	_ensure_tutorial_gem()

	# Carve the hub room interior (floor tiles, not bedrock).
	_carve_compact_rect(-half_w, half_w, -half_h, half_h)

	# Carve the single 1×1 entrance at bottom center.
	on_cell_dug(get_minewars_entrance())
	
	# Carve top tunnel if unlocked
	if is_top_tunnel_unlocked():
		on_cell_dug(get_top_tunnel_entrance())
		for y in range(get_top_tunnel_entrance().y - 3, get_top_tunnel_entrance().y):
			on_cell_dug(Vector2i(0, y))

	# Update visual layers for every cell.
	for x in range(WORLD_X_MIN, WORLD_X_MAX + 1):
		for y in range(WORLD_Y_MIN, WORLD_Y_MAX + 1):
			var cell := Vector2i(x, y)
			update_fog_mask(cell)
			update_front_wall(cell)
			update_inside_corners(cell)
			update_astar_weight(cell)

func _carve_compact_rect(x_min: int, x_max: int, y_min: int, y_max: int) -> void:
	for x in range(x_min, x_max + 1):
		for y in range(y_min, y_max + 1):
			on_cell_dug(Vector2i(x, y))

## Called by the world controller when MineWars mode activates. Carves a tunnel
## to the right of the hub room for enemies to approach through.
func activate_minewars_tunnel() -> void:
	var previous_flag: bool = world_generation_in_progress
	world_generation_in_progress = true

	# Carve the approach tunnel to the right (3 tiles high, extending right).
	for x in range(ENEMY_TUNNEL_X_MIN, ENEMY_TUNNEL_X_MAX + 1):
		for y in range(ENEMY_TUNNEL_Y - ENEMY_TUNNEL_HALF_HEIGHT, ENEMY_TUNNEL_Y + ENEMY_TUNNEL_HALF_HEIGHT + 1):
			var cell := Vector2i(x, y)
			if block_layer.get_cell_source_id(cell) != -1:
				on_cell_dug(cell)

	var layout: Dictionary = TIER_LAYOUTS[get_hub_tier()]
	var half_w: int = layout["half_w"]

	# Also carve the wall between hub room and tunnel.
	for y in range(ENEMY_TUNNEL_Y - ENEMY_TUNNEL_HALF_HEIGHT, ENEMY_TUNNEL_Y + ENEMY_TUNNEL_HALF_HEIGHT + 1):
		for x in range(half_w + 1, ENEMY_TUNNEL_X_MIN):
			var cell := Vector2i(x, y)
			if block_layer.get_cell_source_id(cell) != -1:
				on_cell_dug(cell)

	var entrance_y: int = get_minewars_entrance().y
	# Carve a short path below the hub entrance into the mine.
	for y in range(entrance_y + 1, entrance_y + 4):
		on_cell_dug(Vector2i(0, y))

	world_generation_in_progress = previous_flag
	topology_revision += 1

func is_dig_cell_protected(cell: Vector2i) -> bool:
	if bool(get_meta("single_player_hub_active", false)):
		return true
	return super.is_dig_cell_protected(cell)

func get_protected_dig_message(_cell: Vector2i) -> String:
	if bool(get_meta("single_player_hub_active", false)):
		return "The stronghold walls are protected. Walk through the entrance below."
	return super.get_protected_dig_message(_cell)
