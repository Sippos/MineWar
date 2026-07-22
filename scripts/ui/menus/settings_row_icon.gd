extends Control

@export_enum("Display", "Resolution", "VSync", "FPS", "Volume") var icon_type: int = 0

const GOLD := Color(0.96, 0.82, 0.42, 1.0)
const BLUE := Color(0.48, 0.85, 1.0, 1.0)
const OUTLINE := Color(0.08, 0.035, 0.015, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var scale_value: float = minf(size.x, size.y) / 32.0
	if scale_value <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_value, scale_value))
	match icon_type:
		0: _draw_display()
		1: _draw_resolution()
		2: _draw_vsync()
		3: _draw_fps()
		4: _draw_volume()


func _line(points: PackedVector2Array, color: Color, width: float, closed: bool = false) -> void:
	draw_polyline(points, OUTLINE, width + 3.0, true)
	draw_polyline(points, color, width, true)
	if closed and points.size() > 1:
		draw_line(points[points.size() - 1], points[0], OUTLINE, width + 3.0, true)
		draw_line(points[points.size() - 1], points[0], color, width, true)


func _draw_display() -> void:
	draw_rect(Rect2(4.0, 5.0, 24.0, 17.0), OUTLINE, false, 5.0)
	draw_rect(Rect2(4.0, 5.0, 24.0, 17.0), GOLD, false, 2.5)
	_line(PackedVector2Array([Vector2(13.0, 22.0), Vector2(13.0, 27.0), Vector2(9.0, 27.0), Vector2(23.0, 27.0), Vector2(19.0, 27.0), Vector2(19.0, 22.0)]), GOLD, 2.3)


func _draw_resolution() -> void:
	_line(PackedVector2Array([Vector2(4.0, 12.0), Vector2(4.0, 4.0), Vector2(12.0, 4.0)]), BLUE, 2.4)
	_line(PackedVector2Array([Vector2(20.0, 4.0), Vector2(28.0, 4.0), Vector2(28.0, 12.0)]), BLUE, 2.4)
	_line(PackedVector2Array([Vector2(28.0, 20.0), Vector2(28.0, 28.0), Vector2(20.0, 28.0)]), BLUE, 2.4)
	_line(PackedVector2Array([Vector2(12.0, 28.0), Vector2(4.0, 28.0), Vector2(4.0, 20.0)]), BLUE, 2.4)
	_line(PackedVector2Array([Vector2(10.0, 16.0), Vector2(22.0, 16.0)]), GOLD, 2.0)
	_line(PackedVector2Array([Vector2(16.0, 10.0), Vector2(16.0, 22.0)]), GOLD, 2.0)


func _draw_vsync() -> void:
	draw_arc(Vector2(16.0, 16.0), 10.0, 3.55, 6.0, 18, OUTLINE, 5.0, true)
	draw_arc(Vector2(16.0, 16.0), 10.0, 3.55, 6.0, 18, BLUE, 2.5, true)
	draw_arc(Vector2(16.0, 16.0), 10.0, 0.4, 2.85, 18, OUTLINE, 5.0, true)
	draw_arc(Vector2(16.0, 16.0), 10.0, 0.4, 2.85, 18, BLUE, 2.5, true)
	_line(PackedVector2Array([Vector2(24.0, 5.0), Vector2(27.0, 10.0), Vector2(21.0, 10.0)]), GOLD, 2.0, true)
	_line(PackedVector2Array([Vector2(8.0, 27.0), Vector2(5.0, 22.0), Vector2(11.0, 22.0)]), GOLD, 2.0, true)


func _draw_fps() -> void:
	draw_arc(Vector2(16.0, 20.0), 11.0, 3.2, 6.22, 24, OUTLINE, 5.0, true)
	draw_arc(Vector2(16.0, 20.0), 11.0, 3.2, 6.22, 24, GOLD, 2.5, true)
	_line(PackedVector2Array([Vector2(16.0, 20.0), Vector2(23.0, 11.0)]), BLUE, 2.5)
	draw_circle(Vector2(16.0, 20.0), 2.4, OUTLINE)
	draw_circle(Vector2(16.0, 20.0), 1.3, BLUE)
	_line(PackedVector2Array([Vector2(7.0, 25.0), Vector2(25.0, 25.0)]), GOLD, 2.0)


func _draw_volume() -> void:
	var speaker := PackedVector2Array([Vector2(4.0, 12.0), Vector2(10.0, 12.0), Vector2(17.0, 7.0), Vector2(17.0, 25.0), Vector2(10.0, 20.0), Vector2(4.0, 20.0)])
	_line(speaker, GOLD, 2.2, true)
	draw_arc(Vector2(17.0, 16.0), 7.0, -0.75, 0.75, 12, OUTLINE, 5.0, true)
	draw_arc(Vector2(17.0, 16.0), 7.0, -0.75, 0.75, 12, BLUE, 2.5, true)
	draw_arc(Vector2(17.0, 16.0), 12.0, -0.75, 0.75, 14, OUTLINE, 5.0, true)
	draw_arc(Vector2(17.0, 16.0), 12.0, -0.75, 0.75, 14, BLUE, 2.5, true)
