with open('scripts/systems/world_generation/world.gd', 'r') as f:
    content = f.read()

content = content.replace(
"""@onready var inside_corner_tl: TileMapLayer = $InsideCornerTL
@onready var inside_corner_tr: TileMapLayer = $InsideCornerTR
@onready var inside_corner_bl: TileMapLayer = $InsideCornerBL
@onready var inside_corner_br: TileMapLayer = $InsideCornerBR""",
"""@onready var edge_layer: TileMapLayer = $EdgeLayer
@onready var inside_corner_tl: TileMapLayer = $InsideCornerTL
@onready var inside_corner_tr: TileMapLayer = $InsideCornerTR
@onready var inside_corner_bl: TileMapLayer = $InsideCornerBL
@onready var inside_corner_br: TileMapLayer = $InsideCornerBR
@onready var damage_layer: TileMapLayer = $DamageLayer"""
)

# Replace update_front_wall
old_front = """func update_front_wall(cell: Vector2i) -> void:
	# Dome-style terrain uses the bottom bit of the transparent 16-mask edge
	# atlas as its front-facing rim. Keep the legacy layer empty so old callers
	# remain safe without projecting a second full tile into tunnel space.
	var below_cell := cell + Vector2i.DOWN
	front_layer.erase_cell(below_cell)
	if gem_blocks.has(cell):
		_refresh_gem_indicator(cell)"""

new_front = """func update_front_wall(cell: Vector2i) -> void:
	var block_id = block_layer.get_cell_source_id(cell)
	var below_cell = Vector2i(cell.x, cell.y + 1)
	
	if block_id != -1:
		# If cell is solid, check if below is empty
		if block_layer.get_cell_source_id(below_cell) == -1:
			var front_id = 10 # Easy Front
			if block_id == 2: front_id = 11
			elif block_id == 3: front_id = 12
			
			front_layer.set_cell(below_cell, front_id, Vector2i(0, 0))
		else:
			front_layer.erase_cell(below_cell)
	else:
		# If cell is empty, it can't have a front wall projecting down
		front_layer.erase_cell(below_cell)
		
	if gem_blocks.has(cell):
		_refresh_gem_indicator(cell)"""

content = content.replace(old_front, new_front)

# Replace _position_front_gem_sprite
old_pos = """func _position_front_gem_sprite(sprite: Sprite2D, cell: Vector2i) -> void:
	# Bottom-facing veins now live on the solid tile's own thicker lower rim.
	sprite.global_position = block_layer.to_global(block_layer.map_to_local(cell))
	sprite.global_position.y += 8.0"""

new_pos = """func _position_front_gem_sprite(sprite: Sprite2D, cell: Vector2i) -> void:
	var below_cell = Vector2i(cell.x, cell.y + 1)
	sprite.global_position = front_layer.to_global(front_layer.map_to_local(below_cell))
	sprite.global_position.y += 1.0"""

content = content.replace(old_pos, new_pos)

# Add update_inside_corners
inside_corners = """
func _is_solid(cell: Vector2i) -> bool:
	return block_layer.get_cell_source_id(cell) != -1

func _get_inside_corner_source(cell: Vector2i) -> int:
	var id = block_layer.get_cell_source_id(cell)
	if id == 2: return 18
	if id == 3: return 19
	if id == 16: return 20
	return 17

func update_inside_corners(cell: Vector2i) -> void:
	if _is_solid(cell):
		inside_corner_tl.erase_cell(cell)
		inside_corner_tr.erase_cell(cell)
		inside_corner_bl.erase_cell(cell)
		inside_corner_br.erase_cell(cell)
		return

	var tl_solid = _is_solid(cell + Vector2i(-1, -1))
	var tr_solid = _is_solid(cell + Vector2i(1, -1))
	var bl_solid = _is_solid(cell + Vector2i(-1, 1))
	var br_solid = _is_solid(cell + Vector2i(1, 1))
	var top_solid = _is_solid(cell + Vector2i(0, -1))
	var bottom_solid = _is_solid(cell + Vector2i(0, 1))
	var left_solid = _is_solid(cell + Vector2i(-1, 0))
	var right_solid = _is_solid(cell + Vector2i(1, 0))

	if tl_solid and not top_solid and not left_solid:
		inside_corner_tl.set_cell(cell, _get_inside_corner_source(cell + Vector2i(-1, -1)), Vector2i(0, 0))
	else:
		inside_corner_tl.erase_cell(cell)

	if tr_solid and not top_solid and not right_solid:
		inside_corner_tr.set_cell(cell, _get_inside_corner_source(cell + Vector2i(1, -1)), Vector2i(1, 0))
	else:
		inside_corner_tr.erase_cell(cell)

	if bl_solid and not bottom_solid and not left_solid:
		inside_corner_bl.set_cell(cell, _get_inside_corner_source(cell + Vector2i(-1, 1)), Vector2i(0, 1))
	else:
		inside_corner_bl.erase_cell(cell)

	if br_solid and not bottom_solid and not right_solid:
		inside_corner_br.set_cell(cell, _get_inside_corner_source(cell + Vector2i(1, 1)), Vector2i(1, 1))
	else:
		inside_corner_br.erase_cell(cell)
"""

# Append update_inside_corners at the end of the file
content += inside_corners

with open('scripts/systems/world_generation/world.gd', 'w') as f:
    f.write(content)
