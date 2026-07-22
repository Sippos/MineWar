with open('scripts/systems/world_generation/world.gd', 'r') as f:
    content = f.read()

content = content.replace(
"""	if tl_solid and not top_solid and not left_solid:
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
		inside_corner_br.erase_cell(cell)""",
"""	if tl_solid and top_solid and left_solid:
		inside_corner_tl.set_cell(cell, _get_inside_corner_source(cell + Vector2i(-1, -1)), Vector2i(0, 0))
	else:
		inside_corner_tl.erase_cell(cell)

	if tr_solid and top_solid and right_solid:
		inside_corner_tr.set_cell(cell, _get_inside_corner_source(cell + Vector2i(1, -1)), Vector2i(1, 0))
	else:
		inside_corner_tr.erase_cell(cell)

	if bl_solid and bottom_solid and left_solid:
		inside_corner_bl.set_cell(cell, _get_inside_corner_source(cell + Vector2i(-1, 1)), Vector2i(0, 1))
	else:
		inside_corner_bl.erase_cell(cell)

	if br_solid and bottom_solid and right_solid:
		inside_corner_br.set_cell(cell, _get_inside_corner_source(cell + Vector2i(1, 1)), Vector2i(1, 1))
	else:
		inside_corner_br.erase_cell(cell)""")

with open('scripts/systems/world_generation/world.gd', 'w') as f:
    f.write(content)
