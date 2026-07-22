extends Control

const MAP_SIZE := Vector2i(9, 7)
const CELL_SIZE := 40
const SOURCE_SIZE := 64
const BASE_PATH := "res://assets/sprites/world/terrain/bricks/Easy_Brick.png"
const EDGE_PATH := "res://assets/sprites/world/terrain/edges/Easy_Edge_Atlas.png"

var base_texture: Texture2D
var edge_texture: Texture2D
var front_texture: Texture2D
var preview_mode := 0

func _ready() -> void:
	custom_minimum_size = Vector2(MAP_SIZE.x * CELL_SIZE, MAP_SIZE.y * CELL_SIZE)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(BASE_PATH):
		base_texture = load(BASE_PATH) as Texture2D
	if ResourceLoader.exists(EDGE_PATH):
		edge_texture = load(EDGE_PATH) as Texture2D
	queue_redraw()

func set_front_image(image: Image) -> void:
	var export_image := image.duplicate()
	export_image.resize(SOURCE_SIZE, SOURCE_SIZE, Image.INTERPOLATE_NEAREST)
	front_texture = ImageTexture.create_from_image(export_image)
	queue_redraw()

func set_preview_mode(value: int) -> void:
	preview_mode = clampi(value, 0, 2)
	queue_redraw()

func _is_solid(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_SIZE.x or cell.y >= MAP_SIZE.y:
		return true
	match preview_mode:
		0:
			# Wide room.
			return not (cell.x >= 2 and cell.x <= 6 and cell.y >= 2 and cell.y <= 5)
		1:
			# Narrow shaft.
			return not (cell.x >= 4 and cell.x <= 5 and cell.y >= 1 and cell.y <= 5)
		_:
			# Overhang and pillar stress test.
			var open := cell.x >= 1 and cell.x <= 7 and cell.y >= 2 and cell.y <= 5
			if cell == Vector2i(3, 4) or cell == Vector2i(6, 3):
				return true
			return not open

func _mask(cell: Vector2i) -> int:
	if not _is_solid(cell):
		return 0
	var mask := 0
	if not _is_solid(cell + Vector2i.UP): mask |= 1
	if not _is_solid(cell + Vector2i.RIGHT): mask |= 2
	if not _is_solid(cell + Vector2i.DOWN): mask |= 4
	if not _is_solid(cell + Vector2i.LEFT): mask |= 8
	return mask

func _rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), Color.html("111520ff"))
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			var rect := _rect(cell)
			if _is_solid(cell):
				var mask := _mask(cell)
				if base_texture != null:
					draw_texture_rect(base_texture, rect, false, Color(0.55, 0.58, 0.72, 1.0) if mask != 0 else Color(0.28, 0.30, 0.40, 1.0))
				else:
					draw_rect(rect, Color.html("3c3752ff"))
				if mask != 0 and edge_texture != null:
					var atlas := Vector2i(mask % 4, mask / 4) * SOURCE_SIZE
					draw_texture_rect_region(edge_texture, rect, Rect2(Vector2(atlas), Vector2(SOURCE_SIZE, SOURCE_SIZE)), Color(0.78, 0.80, 0.94, 1.0))
			else:
				draw_rect(rect, Color.html("171b27ff"))

	# Front faces are owned by the solid block above but visually project into air.
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			if not _is_solid(cell) or _is_solid(cell + Vector2i.DOWN):
				continue
			if front_texture == null:
				continue
			var below_rect := _rect(cell + Vector2i.DOWN)
			var projected := Rect2(below_rect.position + Vector2(0, -CELL_SIZE * 0.5), below_rect.size)
			draw_texture_rect(front_texture, projected, false, Color(0.78, 0.80, 0.94, 1.0))

	for x in range(MAP_SIZE.x + 1):
		var px := float(x * CELL_SIZE)
		draw_line(Vector2(px, 0), Vector2(px, MAP_SIZE.y * CELL_SIZE), Color(0.04, 0.03, 0.08, 0.30), 1)
	for y in range(MAP_SIZE.y + 1):
		var py := float(y * CELL_SIZE)
		draw_line(Vector2(0, py), Vector2(MAP_SIZE.x * CELL_SIZE, py), Color(0.04, 0.03, 0.08, 0.30), 1)
