extends Control

signal stroke_started(cell: Vector2i, mouse_button: int)
signal stroke_moved(cell: Vector2i, mouse_button: int)
signal stroke_finished
signal hover_changed(cell: Vector2i)

const LOGICAL_SIZE := 32
const PIXEL_SCALE := 11

var preview_image: Image
var preview_texture: ImageTexture
var show_grid := true
var is_drawing := false
var active_button := MOUSE_BUTTON_LEFT
var last_cell := Vector2i(-1, -1)
var hovered_cell := Vector2i(-1, -1)
var edit_region := Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))
var region_label := "FULL TILE"

func _ready() -> void:
	custom_minimum_size = Vector2(LOGICAL_SIZE * PIXEL_SCALE, LOGICAL_SIZE * PIXEL_SCALE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func set_preview_image(image: Image) -> void:
	preview_image = image
	preview_texture = ImageTexture.create_from_image(preview_image)
	queue_redraw()

func set_grid_visible(value: bool) -> void:
	show_grid = value
	queue_redraw()

func set_edit_region(region: Rect2i, label_text: String) -> void:
	edit_region = region.intersection(Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE)))
	region_label = label_text
	queue_redraw()

func is_cell_editable(cell: Vector2i) -> bool:
	return _in_bounds(cell) and edit_region.has_point(cell)

func _draw() -> void:
	var board_size := float(LOGICAL_SIZE * PIXEL_SCALE)
	var board_rect := Rect2(Vector2.ZERO, Vector2(board_size, board_size))
	for y in range(LOGICAL_SIZE):
		for x in range(LOGICAL_SIZE):
			var checker := Color.html("251f32ff") if ((x + y) & 1) == 0 else Color.html("352d46ff")
			draw_rect(Rect2(Vector2(x, y) * PIXEL_SCALE, Vector2(PIXEL_SCALE, PIXEL_SCALE)), checker)
	if preview_texture != null:
		draw_texture_rect(preview_texture, board_rect, false)

	_draw_locked_area(board_rect)

	if show_grid:
		var grid_color := Color(0.05, 0.04, 0.09, 0.38)
		for index in range(LOGICAL_SIZE + 1):
			var offset := float(index * PIXEL_SCALE)
			draw_line(Vector2(offset, 0), Vector2(offset, board_size), grid_color, 1.0)
			draw_line(Vector2(0, offset), Vector2(board_size, offset), grid_color, 1.0)

	var region_rect := Rect2(Vector2(edit_region.position * PIXEL_SCALE), Vector2(edit_region.size * PIXEL_SCALE))
	draw_rect(region_rect, Color.html("70e7ffff"), false, 3.0)
	if edit_region.size != Vector2i(LOGICAL_SIZE, LOGICAL_SIZE):
		var label_position := Vector2(8, board_size - 10)
		if edit_region.position.y > 0:
			label_position = Vector2(8, 18)
		draw_string(ThemeDB.fallback_font, label_position, "%s — paint only inside cyan box" % region_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.html("a9f4ffff"))

	if _in_bounds(hovered_cell):
		var hover_color := Color(1, 1, 1, 0.72) if is_cell_editable(hovered_cell) else Color(1.0, 0.25, 0.25, 0.82)
		draw_rect(Rect2(Vector2(hovered_cell) * PIXEL_SCALE, Vector2(PIXEL_SCALE, PIXEL_SCALE)), hover_color, false, 2.0)
	draw_rect(board_rect, Color.html("a69bc6ff"), false, 2.0)

func _draw_locked_area(board_rect: Rect2) -> void:
	if edit_region.size == Vector2i(LOGICAL_SIZE, LOGICAL_SIZE):
		return
	var locked := Color(0.02, 0.025, 0.04, 0.72)
	var left_width := float(edit_region.position.x * PIXEL_SCALE)
	var top_height := float(edit_region.position.y * PIXEL_SCALE)
	var right_start := float((edit_region.position.x + edit_region.size.x) * PIXEL_SCALE)
	var bottom_start := float((edit_region.position.y + edit_region.size.y) * PIXEL_SCALE)
	if left_width > 0:
		draw_rect(Rect2(0, 0, left_width, board_rect.size.y), locked)
	if right_start < board_rect.size.x:
		draw_rect(Rect2(right_start, 0, board_rect.size.x - right_start, board_rect.size.y), locked)
	if top_height > 0:
		draw_rect(Rect2(left_width, 0, board_rect.size.x - left_width - (board_rect.size.x - right_start), top_height), locked)
	if bottom_start < board_rect.size.y:
		draw_rect(Rect2(left_width, bottom_start, board_rect.size.x - left_width - (board_rect.size.x - right_start), board_rect.size.y - bottom_start), locked)

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
		if is_drawing and hovered_cell != last_cell and is_cell_editable(hovered_cell):
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
			if not is_cell_editable(cell):
				accept_event()
				return
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
