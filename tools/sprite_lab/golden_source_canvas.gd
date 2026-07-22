extends Control

signal stroke_started(cell: Vector2i, mouse_button: int)
signal stroke_moved(cell: Vector2i, mouse_button: int)
signal stroke_finished

const LOGICAL_SIZE: int = 32
const PIXEL_SCALE: int = 16

var preview_image: Image
var preview_texture: ImageTexture
var is_drawing: bool = false
var active_button: int = MOUSE_BUTTON_LEFT
var last_cell: Vector2i = Vector2i(-1, -1)
var show_grid: bool = true

func _ready() -> void:
	custom_minimum_size = Vector2(LOGICAL_SIZE * PIXEL_SCALE, LOGICAL_SIZE * PIXEL_SCALE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process_unhandled_input(true)

func set_preview_image(image: Image) -> void:
	preview_image = image.duplicate()
	preview_texture = ImageTexture.create_from_image(preview_image)
	queue_redraw()

func set_grid_visible(value: bool) -> void:
	show_grid = value
	queue_redraw()

func _draw() -> void:
	var board_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(LOGICAL_SIZE * PIXEL_SCALE, LOGICAL_SIZE * PIXEL_SCALE))
	draw_rect(board_rect, Color.html("15131fff"), true)
	if preview_texture != null:
		draw_texture_rect(preview_texture, board_rect, false)
	if show_grid:
		var grid_color: Color = Color(0.08, 0.07, 0.12, 0.42)
		for index: int in range(LOGICAL_SIZE + 1):
			var offset: float = float(index * PIXEL_SCALE)
			draw_line(Vector2(offset, 0.0), Vector2(offset, float(LOGICAL_SIZE * PIXEL_SCALE)), grid_color, 1.0)
			draw_line(Vector2(0.0, offset), Vector2(float(LOGICAL_SIZE * PIXEL_SCALE), offset), grid_color, 1.0)
	draw_rect(board_rect, Color.html("a69bc6ff"), false, 2.0)

func _cell_from_position(position: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(position.x) / PIXEL_SCALE, 0, LOGICAL_SIZE - 1),
		clampi(int(position.y) / PIXEL_SCALE, 0, LOGICAL_SIZE - 1)
	)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index != MOUSE_BUTTON_LEFT and mouse_event.button_index != MOUSE_BUTTON_RIGHT:
			return
		var cell: Vector2i = _cell_from_position(mouse_event.position)
		if mouse_event.pressed:
			is_drawing = true
			active_button = mouse_event.button_index
			last_cell = cell
			stroke_started.emit(cell, active_button)
		else:
			if is_drawing:
				is_drawing = false
				last_cell = Vector2i(-1, -1)
				stroke_finished.emit()
		accept_event()
	elif event is InputEventMouseMotion and is_drawing:
		var motion_event: InputEventMouseMotion = event
		var cell: Vector2i = _cell_from_position(motion_event.position)
		if cell != last_cell:
			last_cell = cell
			stroke_moved.emit(cell, active_button)
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and is_drawing:
		is_drawing = false
		last_cell = Vector2i(-1, -1)
		stroke_finished.emit()
