extends Node2D

## Runtime light occluders for solid BlockLayer cells that touch open space.
## Full overlapping squares seal diagonal corner leaks. Border glow is handled
## separately by a rim shader on EdgeLayer / FrontWallLayer (not by inset).

const TILE_SIZE := 64.0
## Grow past the cell edge so neighbor occluders overlap and seal diagonal gaps.
const OVERLAP := 2.5

var _occluders: Dictionary = {}  # Vector2i -> LightOccluder2D
var _occluder_parent: Node2D
var _block_layer: TileMapLayer

func setup(block_layer: TileMapLayer) -> void:
	_block_layer = block_layer
	_occluder_parent = Node2D.new()
	_occluder_parent.name = "LightOccluders"
	_occluder_parent.z_index = -1
	add_child(_occluder_parent)

func build_from_solid_cells() -> void:
	if _block_layer == null:
		return
	clear_all()
	for cell in _block_layer.get_used_cells():
		if _is_solid(cell) and _is_exposed(cell):
			_add_occluder(cell)

func on_cell_dug(cell: Vector2i) -> void:
	_remove_occluder(cell)
	for n in _neighbors_of(cell):
		if not _is_solid(n):
			_remove_occluder(n)
			continue
		if _is_exposed(n):
			_add_occluder(n)
		else:
			_remove_occluder(n)

func clear_all() -> void:
	for key in _occluders.keys():
		var node: LightOccluder2D = _occluders[key]
		if is_instance_valid(node):
			node.queue_free()
	_occluders.clear()

func _is_solid(cell: Vector2i) -> bool:
	return _block_layer != null and _block_layer.get_cell_source_id(cell) != -1

func _is_exposed(cell: Vector2i) -> bool:
	for n in _neighbors_of(cell):
		if not _is_solid(n):
			return true
	return false

func _neighbors_of(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i(0, -1),
		cell + Vector2i(1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(-1, 0),
	]

func _add_occluder(cell: Vector2i) -> void:
	if _occluders.has(cell):
		return
	var oc := LightOccluder2D.new()
	oc.name = "Occluder_%d_%d" % [cell.x, cell.y]
	var poly := OccluderPolygon2D.new()
	var half := TILE_SIZE * 0.5 + OVERLAP
	poly.polygon = PackedVector2Array([
		Vector2(-half, -half),
		Vector2( half, -half),
		Vector2( half,  half),
		Vector2(-half,  half)
	])
	oc.occluder = poly
	oc.position = _block_layer.map_to_local(cell)
	_occluder_parent.add_child(oc)
	_occluders[cell] = oc

func _remove_occluder(cell: Vector2i) -> void:
	if not _occluders.has(cell):
		return
	var oc: LightOccluder2D = _occluders[cell]
	_occluders.erase(cell)
	if is_instance_valid(oc):
		oc.queue_free()
