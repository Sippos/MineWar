extends "res://gem.gd"

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
			rail_layer.set_cell(cell, 15, Vector2i(0, 0))
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
