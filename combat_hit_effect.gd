extends Node2D

var _elapsed := 0.0
var _duration := 0.24
var _direction := Vector2.RIGHT
var _power := 1.0
var _death_burst := false
var _tint := Color(1.0, 0.55, 0.16, 1.0)
var _spark_directions: Array[Vector2] = []
var _spark_lengths: Array[float] = []

func configure(hit_direction: Vector2, power: float = 1.0, death_burst: bool = false, tint: Color = Color(1.0, 0.55, 0.16, 1.0)) -> void:
	_direction = hit_direction.normalized() if hit_direction.length_squared() > 0.001 else Vector2.RIGHT
	_power = clampf(power, 0.7, 2.4)
	_death_burst = death_burst
	_tint = tint
	_duration = 0.34 if death_burst else 0.24
	_build_sparks()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 90
	if _spark_directions.is_empty():
		_build_sparks()
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _duration:
		queue_free()

func _build_sparks() -> void:
	_spark_directions.clear()
	_spark_lengths.clear()
	var count := 12 if _death_burst else 7
	var base_angle := _direction.angle()
	for i in count:
		var spread_angle := TAU * float(i) / float(count)
		var directional_bias := lerpf(spread_angle, base_angle, 0.22 if not _death_burst else 0.08)
		var jitter := sin(float(i) * 12.9898 + global_position.x * 0.031) * 0.18
		_spark_directions.append(Vector2.RIGHT.rotated(directional_bias + jitter))
		_spark_lengths.append((12.0 + float((i * 7) % 9)) * _power * (1.35 if _death_burst else 1.0))

func _draw() -> void:
	var progress := clampf(_elapsed / maxf(_duration, 0.001), 0.0, 1.0)
	var fade := 1.0 - progress
	var tangent := _direction.orthogonal()
	var flash_scale := (1.0 - progress * 0.42) * _power
	var core_size := (7.0 if _death_burst else 5.0) * flash_scale
	var white := Color(1.0, 1.0, 1.0, fade)
	var warm := Color(_tint.r, _tint.g, _tint.b, fade * 0.96)
	var dim := Color(_tint.r * 0.72, _tint.g * 0.72, _tint.b * 0.72, fade * 0.72)

	# A hard-edged diamond reads much more cleanly in pixel art than a soft particle blob.
	var diamond := PackedVector2Array([
		Vector2(0.0, -core_size),
		Vector2(core_size, 0.0),
		Vector2(0.0, core_size),
		Vector2(-core_size, 0.0)
	])
	draw_colored_polygon(diamond, white)

	# Short crossing slash marks make the exact contact point immediately readable.
	var slash_length := (18.0 if _death_burst else 13.0) * _power * fade
	draw_line(-_direction * slash_length, _direction * slash_length, warm, 3.0 if _death_burst else 2.0, false)
	draw_line(-tangent * slash_length * 0.72, tangent * slash_length * 0.72, white, 2.0, false)

	# Expanding ring: one clean secondary shape instead of a cloud of circular dots.
	var ring_radius := lerpf(4.0, 24.0 if _death_burst else 15.0, progress) * _power
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 16, dim, 2.0, false)

	# Deterministic line sparks keep the effect crisp and cheap.
	for i in _spark_directions.size():
		var spark_dir := _spark_directions[i]
		var travel := _spark_lengths[i] * progress
		var spark_length := (7.0 if _death_burst else 5.0) * _power * fade
		var start := (spark_dir * travel).round()
		var finish := (spark_dir * (travel + spark_length)).round()
		draw_line(start, finish, warm if i % 2 == 0 else white, 2.0 if _death_burst else 1.0, false)
