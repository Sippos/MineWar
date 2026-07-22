extends Control

signal stroke_started(cell: Vector2i, mouse_button: int)
signal stroke_moved(cell: Vector2i, mouse_button: int)
signal stroke_finished
signal hover_changed(cell: Vector2i)

const LOGICAL_SIZE: int = 32
const BOARD_SIZE: int = 384
const DEFAULT_PIXEL_SCALE: int = 12

var base_texture: ImageTexture
var edit_texture: ImageTexture
var edit_region: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))
var show_grid: bool = true
var is_drawing: bool = false
var active_button: int = MOUSE_BUTTON_LEFT
var last_cell: Vector2i = Vector2i(-1, -1)
var hovered_cell: Vector2i = Vector2i(-1, -1)
var workspace_label: String = ""
var read_only: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(BOARD_SIZE, BOARD_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func set_workspace_images(edit_image: Image, base_image: Image, region: Rect2i, label: String) -> void:
	edit_texture = ImageTexture.create_from_image(edit_image)
	base_texture = ImageTexture.create_from_image(base_image) if base_image != null else null
	edit_region = region
	workspace_label = label
	hovered_cell = Vector2i(-1, -1)
	queue_redraw()

func set_read_only(value: bool) -> void:
	read_only = value
	queue_redraw()

func set_grid_visible(value: bool) -> void:
	show_grid = value
	queue_redraw()

func _focus_region() -> bool:
	# Edge Joint is a top-left patch and benefits from zoom. Hole Corner lives at
	# bottom-right of a full dirt tile, so keep the whole 32x32 tile visible.
	return edit_region.position == Vector2i.ZERO and edit_region.size.x <= 16 and edit_region.size.y <= 16

func _display_columns() -> int:
	return edit_region.size.x if _focus_region() else LOGICAL_SIZE

func _display_rows() -> int:
	return edit_region.size.y if _focus_region() else LOGICAL_SIZE

func _display_scale() -> Vector2:
	return Vector2(float(BOARD_SIZE) / float(_display_columns()), float(BOARD_SIZE) / float(_display_rows()))

func _draw() -> void:
	var board_rect := Rect2(Vector2.ZERO, Vector2(BOARD_SIZE, BOARD_SIZE))
	var checker_a := Color.html("211d2cff")
	var checker_b := Color.html("302940ff")
	var scale := _display_scale()

	for local_y in range(_display_rows()):
		for local_x in range(_display_columns()):
			var checker: Color = checker_a if ((local_x + local_y) & 1) == 0 else checker_b
			draw_rect(Rect2(Vector2(local_x, local_y) * scale, scale), checker)

	if _focus_region():
		var source_rect := Rect2(Vector2(edit_region.position), Vector2(edit_region.size))
		if base_texture != null:
			draw_texture_rect_region(base_texture, board_rect, source_rect)
		if edit_texture != null:
			draw_texture_rect_region(edit_texture, board_rect, source_rect)
	else:
		if base_texture != null:
			draw_texture_rect(base_texture, board_rect, false)
		if edit_texture != null:
			draw_texture_rect(edit_texture, board_rect, false)
		var region_rect := Rect2(Vector2(edit_region.position) * DEFAULT_PIXEL_SCALE, Vector2(edit_region.size) * DEFAULT_PIXEL_SCALE)
		if edit_region.size != Vector2i(LOGICAL_SIZE, LOGICAL_SIZE):
			var locked_color := Color(0.02, 0.025, 0.045, 0.72)
			if edit_region.position.y > 0:
				draw_rect(Rect2(0, 0, BOARD_SIZE, float(edit_region.position.y * DEFAULT_PIXEL_SCALE)), locked_color)
			if edit_region.end.y < LOGICAL_SIZE:
				draw_rect(Rect2(0, float(edit_region.end.y * DEFAULT_PIXEL_SCALE), BOARD_SIZE, float((LOGICAL_SIZE - edit_region.end.y) * DEFAULT_PIXEL_SCALE)), locked_color)
			if edit_region.position.x > 0:
				draw_rect(Rect2(0, float(edit_region.position.y * DEFAULT_PIXEL_SCALE), float(edit_region.position.x * DEFAULT_PIXEL_SCALE), float(edit_region.size.y * DEFAULT_PIXEL_SCALE)), locked_color)
			if edit_region.end.x < LOGICAL_SIZE:
				draw_rect(Rect2(float(edit_region.end.x * DEFAULT_PIXEL_SCALE), float(edit_region.position.y * DEFAULT_PIXEL_SCALE), float((LOGICAL_SIZE - edit_region.end.x) * DEFAULT_PIXEL_SCALE), float(edit_region.size.y * DEFAULT_PIXEL_SCALE)), locked_color)
		draw_rect(region_rect, Color.html("5de4ffff"), false, 3.0)

	if show_grid:
		var grid_color := Color(0.05, 0.04, 0.09, 0.46)
		for x_index in range(_display_columns() + 1):
			var x_offset := float(x_index) * scale.x
			draw_line(Vector2(x_offset, 0), Vector2(x_offset, BOARD_SIZE), grid_color, 1.0)
		for y_index in range(_display_rows() + 1):
			var y_offset := float(y_index) * scale.y
			draw_line(Vector2(0, y_offset), Vector2(BOARD_SIZE, y_offset), grid_color, 1.0)

	if _focus_region():
		draw_rect(board_rect, Color.html("5de4ffff"), false, 3.0)

	if _in_bounds(hovered_cell):
		var local_cell := hovered_cell - edit_region.position if _focus_region() else hovered_cell
		var hover_color := Color(1, 1, 1, 0.82) if edit_region.has_point(hovered_cell) else Color(1, 0.35, 0.35, 0.72)
		draw_rect(Rect2(Vector2(local_cell) * scale, scale), hover_color, false, 2.0)

	draw_rect(board_rect, Color.html("a69bc6ff"), false, 2.0)
	if not workspace_label.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(8, 18), workspace_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.html("9ff1ffff"))
	if _focus_region():
		var footer := "DERIVED PREVIEW • edit Edge Joint" if read_only else "FULL CANVAS IS EDITABLE • right-click erases"
		draw_string(ThemeDB.fallback_font, Vector2(8, BOARD_SIZE - 8), footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.html("9ff1ffff"))

func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < LOGICAL_SIZE and cell.y < LOGICAL_SIZE

func _cell_from_position(position: Vector2) -> Vector2i:
	var scale := _display_scale()
	if _focus_region():
		return edit_region.position + Vector2i(
			clampi(floori(position.x / scale.x), 0, edit_region.size.x - 1),
			clampi(floori(position.y / scale.y), 0, edit_region.size.y - 1)
		)
	return Vector2i(
		clampi(floori(position.x / DEFAULT_PIXEL_SCALE), 0, LOGICAL_SIZE - 1),
		clampi(floori(position.y / DEFAULT_PIXEL_SCALE), 0, LOGICAL_SIZE - 1)
	)

func _gui_input(event: InputEvent) -> void:
	if read_only:
		accept_event()
		return
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
