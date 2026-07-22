extends "res://scripts/systems/preparation/preparation_fast_world.gd"

# The shared Single Player world keeps the LineWars layer solid above the Hero
# Hall. Only the three-cell doorway pocket is open; the peon must excavate the
# actual defence field after the player enters the top route.

const CONTINUOUS_PLAYABLE_RECT := Rect2i(-20, -40, 40, 70)
const UPPER_ZONE_X_MIN := -10
const UPPER_ZONE_X_MAX := 10
const OLD_CHAMBER_Y_MIN := -14
const OLD_CHAMBER_Y_MAX := -7
const ENTRY_X_MIN := -1
const ENTRY_X_MAX := 1
const ENTRY_Y_MIN := -7
const ENTRY_Y_MAX := -7

func _ready() -> void:
	super._ready()
	_seal_old_line_wars_chamber()
	_rebuild_extended_navigation()

func get_playable_map_rect() -> Rect2i:
	# MapBounds reads this after generation. It moves the unbreakable ceiling and
	# camera/navigation limits above the complete peon excavation area.
	return CONTINUOUS_PLAYABLE_RECT

func _seal_old_line_wars_chamber() -> void:
	# Keep only the narrow doorway pocket directly above the hub. Everything else
	# remains rock so LineWars begins with an empty canvas the peon must carve.
	for x in range(UPPER_ZONE_X_MIN, UPPER_ZONE_X_MAX + 1):
		for y in range(OLD_CHAMBER_Y_MIN, OLD_CHAMBER_Y_MAX + 1):
			var cell := Vector2i(x, y)
			var is_entry_pocket := (
				x >= ENTRY_X_MIN and x <= ENTRY_X_MAX
				and y >= ENTRY_Y_MIN and y <= ENTRY_Y_MAX
			)
			if is_entry_pocket:
				continue
			if block_layer: block_layer.set_cell(cell, 1, Vector2i.ZERO)
			if damage_layer: damage_layer.erase_cell(cell)
			if crack_overlay_manager:
				crack_overlay_manager.clear_damage(cell, false)
				crack_overlay_manager.clear_damage(cell + Vector2i.DOWN, true)
			if edge_layer: edge_layer.erase_cell(cell)
			if fog_layer: fog_layer.set_cell(cell, 9, Vector2i.ZERO)
			if astar and astar.is_in_bounds(cell.x, cell.y):
				astar.set_point_solid(cell, true)

	# Rebuild visible faces after all cells are sealed, not during each mutation.
	for x in range(UPPER_ZONE_X_MIN - 1, UPPER_ZONE_X_MAX + 2):
		for y in range(OLD_CHAMBER_Y_MIN - 1, OLD_CHAMBER_Y_MAX + 2):
			var cell := Vector2i(x, y)
			update_fog_mask(cell)
			update_front_wall(cell)
			update_inside_corners(cell)

func _rebuild_extended_navigation() -> void:
	# Enemy.gd uses world.astar. Build the same world-specific region that the
	# deferred MapBounds pass will preserve after adding its unbreakable ring.
	astar = AStarGrid2D.new()
	astar.region = CONTINUOUS_PLAYABLE_RECT
	astar.cell_size = Vector2(64, 64)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for x in range(CONTINUOUS_PLAYABLE_RECT.position.x, CONTINUOUS_PLAYABLE_RECT.end.x):
		for y in range(CONTINUOUS_PLAYABLE_RECT.position.y, CONTINUOUS_PLAYABLE_RECT.end.y):
			var cell := Vector2i(x, y)
			astar.set_point_solid(cell, block_layer.get_cell_source_id(cell) != -1)
