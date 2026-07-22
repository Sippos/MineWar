extends Control

const MAP_SIZE := Vector2i(10, 8)
const CELL_SIZE := 40

var mass_texture: ImageTexture
var top_texture: ImageTexture
var right_texture: ImageTexture
var bottom_texture: ImageTexture
var left_texture: ImageTexture
var bedrock_texture: ImageTexture
var gem_texture: ImageTexture
var show_gem := false
var preview_mode := 0
var focus_component := "mass"

func _ready() -> void:
	custom_minimum_size = Vector2(MAP_SIZE.x * CELL_SIZE, MAP_SIZE.y * CELL_SIZE)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func set_material_images(mass: Image, top: Image, right: Image, bottom: Image, left: Image, bedrock: Image, gem: Image = null, gem_visible := false) -> void:
	mass_texture = _texture_64(mass)
	top_texture = _texture_64(top)
	right_texture = _texture_64(right)
	bottom_texture = _texture_64(bottom)
	left_texture = _texture_64(left)
	bedrock_texture = _texture_64(bedrock)
	gem_texture = _texture_64(gem) if gem != null else null
	show_gem = gem_visible
	queue_redraw()

func set_preview_mode(value: int) -> void:
	preview_mode = clampi(value, 0, 2)
	queue_redraw()

func set_focus_component(value: String) -> void:
	focus_component = value
	queue_redraw()

func _texture_64(image: Image) -> ImageTexture:
	if image == null:
		return null
	var copy := image.duplicate()
	copy.resize(64, 64, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(copy)

func _is_bedrock(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == MAP_SIZE.x - 1 or cell.y == MAP_SIZE.y - 1

func _is_solid(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_SIZE.x or cell.y >= MAP_SIZE.y:
		return true
	if _is_bedrock(cell):
		return true
	match preview_mode:
		0:
			# One-cell solid margin remains between the room and bedrock on every
			# side, so top/right/bottom/left edge workspaces all have examples.
			return not (cell.x >= 3 and cell.x <= 7 and cell.y >= 2 and cell.y <= 5)
		1:
			return not (cell.x >= 4 and cell.x <= 5 and cell.y >= 1 and cell.y <= 5)
		_:
			var open := cell.x >= 2 and cell.x <= 8 and cell.y >= 2 and cell.y <= 5
			if cell == Vector2i(4, 4) or cell == Vector2i(7, 3):
				return true
			return not open

func _rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))

func _uses_focus(cell: Vector2i) -> bool:
	if focus_component == "bedrock":
		return _is_bedrock(cell)
	if not _is_solid(cell) or _is_bedrock(cell):
		return false
	match focus_component:
		"mass": return true
		"top": return not _is_solid(cell + Vector2i.UP)
		"right": return not _is_solid(cell + Vector2i.RIGHT)
		"bottom": return not _is_solid(cell + Vector2i.DOWN)
		"left": return not _is_solid(cell + Vector2i.LEFT)
		"gem": return cell == Vector2i(3, 3)
	return false

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), Color.html("111520ff"))
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			var rect := _rect(cell)
			if not _is_solid(cell):
				draw_rect(rect, Color.html("151925ff"))
				continue
			if _is_bedrock(cell):
				if bedrock_texture != null:
					draw_texture_rect(bedrock_texture, rect, false)
				else:
					draw_rect(rect, Color.html("5a3f78ff"))
				continue
			if mass_texture != null:
				draw_texture_rect(mass_texture, rect, false)
			else:
				draw_rect(rect, Color.html("242030ff"))
			if not _is_solid(cell + Vector2i.UP) and top_texture != null:
				draw_texture_rect(top_texture, rect, false)
			if not _is_solid(cell + Vector2i.RIGHT) and right_texture != null:
				draw_texture_rect(right_texture, rect, false)
			if not _is_solid(cell + Vector2i.DOWN) and bottom_texture != null:
				draw_texture_rect(bottom_texture, rect, false)
			if not _is_solid(cell + Vector2i.LEFT) and left_texture != null:
				draw_texture_rect(left_texture, rect, false)
			if show_gem and gem_texture != null and cell == Vector2i(3, 3):
				draw_texture_rect(gem_texture, rect, false)

	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			if _uses_focus(cell):
				draw_rect(_rect(cell).grow(-3), Color(0.38, 0.93, 1.0, 0.96), false, 2.0)

	for x in range(MAP_SIZE.x + 1):
		var px := float(x * CELL_SIZE)
		draw_line(Vector2(px, 0), Vector2(px, MAP_SIZE.y * CELL_SIZE), Color(0.03, 0.03, 0.06, 0.16), 1)
	for y in range(MAP_SIZE.y + 1):
		var py := float(y * CELL_SIZE)
		draw_line(Vector2(0, py), Vector2(MAP_SIZE.x * CELL_SIZE, py), Color(0.03, 0.03, 0.06, 0.16), 1)
