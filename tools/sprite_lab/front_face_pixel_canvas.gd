extends Control

signal stroke_started(cell: Vector2i, mouse_button: int)
signal stroke_moved(cell: Vector2i, mouse_button: int)
signal stroke_finished
signal hover_changed(cell: Vector2i)

const LOGICAL_SIZE := 32
const PIXEL_SCALE := 12
const FRONT_DEPTH_ROW := 17

var preview_image: Image
var preview_texture: ImageTexture
var show_grid := true
var show_depth_guide := true
var is_drawing := false
var active_button := MOUSE_BUTTON_LEFT
var last_cell := Vector2i(-1, -1)
var hovered_cell := Vector2i(-1, -1)

func _ready() -> void:
	custom_minimum_size = Vector2(LOGICAL_SIZE * PIXEL_SCALE, LOGICAL_SIZE * PIXEL_SCALE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func set_preview_image(image: Image) -> void:
	preview_image = image.duplicate()
	preview_texture = ImageTexture.create_from_image(preview_image)
	queue_redraw()

func set_grid_visible(value: bool) -> void:
	show_grid = value
	queue_redraw()

func set_depth_guide_visible(value: bool) -> void:
	show_depth_guide = value
	queue_redraw()

func _draw() -> void:
	var board_size := float(LOGICAL_SIZE * PIXEL_SCALE)
	var board_rect := Rect2(Vector2.ZERO, Vector2(board_size, board_size))
	var checker_a := Color.html("241f32ff")
	var checker_b := Color.html("342d46ff")
	for y in range(LOGICAL_SIZE):
		for x in range(LOGICAL_SIZE):
			var checker := checker_a if ((x + y) & 1) == 0 else checker_b
			draw_rect(Rect2(Vector2(x, y) * PIXEL_SCALE, Vector2(PIXEL_SCALE, PIXEL_SCALE)), checker)
	if preview_texture != null:
		draw_texture_rect(preview_texture, board_rect, false)
	if show_grid:
		var grid_color := Color(0.06, 0.05, 0.10, 0.42)
		for index in range(LOGICAL_SIZE + 1):
			var offset := float(index * PIXEL_SCALE)
			draw_line(Vector2(offset, 0), Vector2(offset, board_size), grid_color, 1.0)
			draw_line(Vector2(0, offset), Vector2(board_size, offset), grid_color, 1.0)
	if show_depth_guide:
		var guide_y := float(FRONT_DEPTH_ROW * PIXEL_SCALE)
		draw_line(Vector2(0, guide_y), Vector2(board_size, guide_y), Color(1.0, 0.76, 0.26, 0.95), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(5, guide_y - 5), "transparent below", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.82, 0.46, 0.95))
	if _in_bounds(hovered_cell):
		draw_rect(Rect2(Vector2(hovered_cell) * PIXEL_SCALE, Vector2(PIXEL_SCALE, PIXEL_SCALE)), Color(1, 1, 1, 0.65), false, 2.0)
	draw_rect(board_rect, Color.html("a69bc6ff"), false, 2.0)

func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < LOGICAL_SIZE and cell.y < LOGICAL_SIZE

func _cell_from_position(position: Vector2) -> Vector2i:
	return Vector2i(
		clampi(floori(position.x / PIXEL_SCALE), 0, LOGICAL_SIZE - 1),
		clampi(floori(position.y / PIXEL_SCALE), 0, LOGICAL_SIZE - 1)
	)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		hovered_cell = _cell_from_position(motion.position)
		hover_changed.emit(hovered_cell)
		if is_drawing and hovered_cell != last_cell:
			last_cell = hovered_cell
			stroke_moved.emit(hovered_cell, active_button)
		queue_redraw()
		accept_event()
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT and mouse.button_index != MOUSE_BUTTON_RIGHT:
			return
		var cell := _cell_from_position(mouse.position)
		if mouse.pressed:
			is_drawing = true
			active_button = mouse.button_index
			last_cell = cell
			stroke_started.emit(cell, active_button)
		else:
			if is_drawing:
				is_drawing = false
				last_cell = Vector2i(-1, -1)
				stroke_finished.emit()
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hovered_cell = Vector2i(-1, -1)
		hover_changed.emit(hovered_cell)
		if is_drawing:
			is_drawing = false
			last_cell = Vector2i(-1, -1)
			stroke_finished.emit()
		queue_redraw()
