extends "res://scripts/systems/preparation/preparation_fast_world.gd"

# The shared Single Player world keeps the LineWars layer solid. The inherited
# fast world creates the base and lower mine; this script seals the old prototype
# chamber back into rock and leaves only a tiny entry pocket above the cap.

const EXTENDED_ASTAR_REGION := Rect2i(-30, -40, 60, 80)
const UPPER_ZONE_X_MIN := -10
const UPPER_ZONE_X_MAX := 10
const OLD_CHAMBER_Y_MIN := -14
const OLD_CHAMBER_Y_MAX := -7
const ENTRY_X_MIN := 2
const ENTRY_X_MAX := 4
const ENTRY_Y_MIN := -8
const ENTRY_Y_MAX := -7

func _ready() -> void:
	super._ready()
	_seal_old_line_wars_chamber()
	_rebuild_extended_navigation()

func _seal_old_line_wars_chamber() -> void:
	# Keep only a narrow pocket directly above the breakthrough. The peon begins
	# here with solid rock immediately overhead and must create the maze by digging.
	for x in range(UPPER_ZONE_X_MIN, UPPER_ZONE_X_MAX + 1):
		for y in range(OLD_CHAMBER_Y_MIN, OLD_CHAMBER_Y_MAX + 1):
			var cell := Vector2i(x, y)
			var is_entry_pocket := (
				x >= ENTRY_X_MIN and x <= ENTRY_X_MAX
				and y >= ENTRY_Y_MIN and y <= ENTRY_Y_MAX
			)
			if is_entry_pocket:
				continue
			block_layer.set_cell(cell, 1, Vector2i.ZERO)
			damage_layer.erase_cell(cell)
			edge_layer.erase_cell(cell)
			fog_layer.set_cell(cell, 9, Vector2i.ZERO)

	# Rebuild visible faces after all cells are sealed, not during each mutation.
	for x in range(UPPER_ZONE_X_MIN - 1, UPPER_ZONE_X_MAX + 2):
		for y in range(OLD_CHAMBER_Y_MIN - 1, OLD_CHAMBER_Y_MAX + 2):
			var cell := Vector2i(x, y)
			update_fog_mask(cell)
			update_front_wall(cell)

func _rebuild_extended_navigation() -> void:
	# Enemy.gd uses world.astar. The legacy grid ended at y=-15, which excluded
	# most of the new upper excavation area. Rebuild it over the complete map.
	astar = AStarGrid2D.new()
	astar.region = EXTENDED_ASTAR_REGION
	astar.cell_size = Vector2(64, 64)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for x in range(EXTENDED_ASTAR_REGION.position.x, EXTENDED_ASTAR_REGION.end.x):
		for y in range(EXTENDED_ASTAR_REGION.position.y, EXTENDED_ASTAR_REGION.end.y):
			var cell := Vector2i(x, y)
			astar.set_point_solid(cell, block_layer.get_cell_source_id(cell) != -1)
