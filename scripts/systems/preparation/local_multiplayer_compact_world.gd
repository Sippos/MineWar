extends "res://scripts/systems/preparation/preparation_fast_world.gd"

# Local co-op deliberately uses a tiny, deterministic preparation cave instead
# of generating the complete persistent single-player mine. Progression may add
# a second hero shrine, but it never expands into a giant selection hall.
const COMPACT_PLAYABLE_RECT := Rect2i(-8, -6, 16, 17)
const COMPACT_FILL_X_MIN := -8
const COMPACT_FILL_X_MAX := 7
const COMPACT_FILL_Y_MIN := -6
const COMPACT_FILL_Y_MAX := 10
const FRESH_ROOM_HALF_WIDTH := 4
const PROGRESSED_ROOM_HALF_WIDTH := 5
const ROOM_Y_MIN := -3
const ROOM_Y_MAX := 3
const TUNNEL_X_MIN := -1
const TUNNEL_X_MAX := 1
const TUNNEL_Y_MIN := 4
const TUNNEL_Y_MAX := 8

func get_playable_map_rect() -> Rect2i:
	return COMPACT_PLAYABLE_RECT

func generate_initial_world() -> void:
	var room_half_width := FRESH_ROOM_HALF_WIDTH
	if Global.unlocked_heroes.size() > 1:
		room_half_width = PROGRESSED_ROOM_HALF_WIDTH

	# A small fixed shell is dramatically cheaper than the 40 x 63 persistent
	# mine and also guarantees that the local hub keeps the same cozy silhouette.
	for x in range(COMPACT_FILL_X_MIN, COMPACT_FILL_X_MAX + 1):
		for y in range(COMPACT_FILL_Y_MIN, COMPACT_FILL_Y_MAX + 1):
			var cell := Vector2i(x, y)
			block_layer.set_cell(cell, 16, Vector2i.ZERO)
			if astar.is_in_bounds(cell.x, cell.y):
				astar.set_point_solid(cell, true)

	_carve_compact_rect(-room_half_width, room_half_width, ROOM_Y_MIN, ROOM_Y_MAX)
	_carve_compact_rect(TUNNEL_X_MIN, TUNNEL_X_MAX, TUNNEL_Y_MIN, TUNNEL_Y_MAX)

	# Rebuild faces only across the compact shell after all carving is complete.
	for x in range(COMPACT_FILL_X_MIN, COMPACT_FILL_X_MAX + 1):
		for y in range(COMPACT_FILL_Y_MIN, COMPACT_FILL_Y_MAX + 1):
			var cell := Vector2i(x, y)
			update_fog_mask(cell)
			update_front_wall(cell)
			update_inside_corners(cell)
			update_astar_weight(cell)

func _carve_compact_rect(x_min: int, x_max: int, y_min: int, y_max: int) -> void:
	for x in range(x_min, x_max + 1):
		for y in range(y_min, y_max + 1):
			on_cell_dug(Vector2i(x, y))

func is_dig_cell_protected(_cell: Vector2i) -> bool:
	# The stronghold is a preparation room, not another mine to accidentally
	# hollow out. The single open tunnel is the only way forward.
	if bool(get_meta("local_multiplayer_hub_active", false)):
		return true
	return super.is_dig_cell_protected(_cell)

func get_protected_dig_message(_cell: Vector2i) -> String:
	return "The co-op stronghold walls are protected. Enter the lower tunnel together."
