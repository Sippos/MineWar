extends Node2D

## Runtime light occluders for solid BlockLayer cells that touch open space.
## Polygons follow the EdgeLayer mask silhouette (quarter-circle cutouts on every
## open-side corner) so PointLight shadows match the visual tiles instead of
## hard boxy squares. Modest OVERLAP grows the outer edges just enough to seal
## diagonal corner leaks without making the shadows stick out past the art.
## Border glow remains the rim shader on EdgeLayer / FrontWallLayer.

const TILE_SIZE := 64.0
## Grow past the cell edge so neighbour occluders overlap and seal diagonal gaps.
## Tuned low so the shadow stays inlaid with the visual border instead of
## bleeding outside the tile; still enough for the arcs to seal against each other.
const OVERLAP := 0.0
const CUTOUT_RADIUS := 16.0
const ARC_SEGMENTS := 6

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

func _exposure_flags(cell: Vector2i) -> Dictionary:
	return {
		"up": not _is_solid(cell + Vector2i(0, -1)),
		"right": not _is_solid(cell + Vector2i(1, 0)),
		"down": not _is_solid(cell + Vector2i(0, 1)),
		"left": not _is_solid(cell + Vector2i(-1, 0)),
	}

func _add_occluder(cell: Vector2i) -> void:
	if _occluders.has(cell):
		return
	var oc := LightOccluder2D.new()
	oc.name = "Occluder_%d_%d" % [cell.x, cell.y]
	var poly := OccluderPolygon2D.new()
	poly.polygon = _build_masked_polygon(cell)
	oc.occluder = poly
	oc.position = _block_layer.map_to_local(cell)
	_occluder_parent.add_child(oc)
	_occluders[cell] = oc

func _build_masked_polygon(cell: Vector2i) -> PackedVector2Array:
	var half := TILE_SIZE * 0.5 + OVERLAP
	var r := CUTOUT_RADIUS
	var flags := _exposure_flags(cell)
	var pts: PackedVector2Array = []

	# The front wall extends the visual block down by a full tile, but the occluder 
	# should not, otherwise it blocks the player's PointLight inside the tunnel.
	var bottom_extend = 0.0

	# Walk clockwise from top-left.
	
	# Top-left corner
	if flags.up and flags.left:
		_append_arc(pts, Vector2(-half + r, -half + r), r, PI, PI * 1.5)
	else:
		pts.append(Vector2(-half, -half))

	# Top-right corner
	if flags.up and flags.right:
		_append_arc(pts, Vector2(half - r, -half + r), r, PI * 1.5, TAU)
	else:
		pts.append(Vector2(half, -half))

	# Bottom-right corner
	pts.append(Vector2(half, half + bottom_extend))

	# Bottom-left corner
	pts.append(Vector2(-half, half + bottom_extend))

	return pts

func _append_arc(pts: PackedVector2Array, center: Vector2, radius: float, start_angle: float, end_angle: float) -> void:
	for i in range(ARC_SEGMENTS + 1):
		var t := float(i) / float(ARC_SEGMENTS)
		var a := lerpf(start_angle, end_angle, t)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)

func _remove_occluder(cell: Vector2i) -> void:
	if not _occluders.has(cell):
		return
	var oc: LightOccluder2D = _occluders[cell]
	_occluders.erase(cell)
	if is_instance_valid(oc):
		oc.queue_free()
