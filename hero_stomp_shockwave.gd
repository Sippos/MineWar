extends Node2D

## Visceral ground-pound shockwave ring for Dwarf War Stomp.
## Features layered concentric shockwave arcs, tapering line thickness,
## seismic ground fissures, and flying radial rock debris.

var _radius: float = 120.0
var _duration: float = 0.38
var _elapsed: float = 0.0
var _is_avatar: bool = false
var _fissure_angles: Array[float] = []
var _fissure_lengths: Array[float] = []
var _rock_particles: Array[Dictionary] = []

func configure(radius: float, is_avatar: bool = false, duration: float = 0.38) -> void:
	_radius = maxf(radius, 40.0)
	_is_avatar = is_avatar
	_duration = maxf(duration, 0.1)
	_build_fissures_and_particles()
	queue_redraw()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 25
	if _fissure_angles.is_empty():
		_build_fissures_and_particles()
	queue_redraw()

func _build_fissures_and_particles() -> void:
	_fissure_angles.clear()
	_fissure_lengths.clear()
	_rock_particles.clear()
	
	var fissure_count := 10
	for i in range(fissure_count):
		var angle := TAU * float(i) / float(fissure_count) + randf_range(-0.14, 0.14)
		_fissure_angles.append(angle)
		_fissure_lengths.append(randf_range(0.48, 0.85) * _radius)
	
	var rock_count := 16 if not _is_avatar else 26
	for i in range(rock_count):
		var p_angle := TAU * float(i) / float(rock_count) + randf_range(-0.12, 0.12)
		var p_speed := randf_range(0.85, 1.28) * _radius
		var p_size := randf_range(2.5, 5.0) if not _is_avatar else randf_range(3.5, 6.5)
		_rock_particles.append({
			"dir": Vector2.RIGHT.rotated(p_angle),
			"dist": p_speed,
			"size": p_size
		})

func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _duration:
		queue_free()

func _draw() -> void:
	var t := clampf(_elapsed / maxf(_duration, 0.001), 0.0, 1.0)
	# Fast initial blast, smooth deceleration at outer edge (cubic ease-out)
	var expansion := 1.0 - pow(1.0 - t, 3.0)
	var current_radius := lerpf(12.0, _radius, expansion)
	var fade := 1.0 - t
	
	# Color palettes
	var ring_color: Color
	var core_color: Color
	var fissure_color: Color
	var rock_color: Color
	
	if _is_avatar:
		# Molten gold / primordial mountain magma
		ring_color = Color(1.0, 0.84, 0.22, fade * 0.96)
		core_color = Color(1.0, 0.97, 0.86, fade * 0.98)
		fissure_color = Color(1.0, 0.44, 0.12, fade * 0.90)
		rock_color = Color(0.96, 0.68, 0.22, fade)
	else:
		# Dense earthen ochre / granite shockwave
		ring_color = Color(0.86, 0.60, 0.30, fade * 0.92)
		core_color = Color(1.0, 0.94, 0.82, fade * 0.92)
		fissure_color = Color(0.48, 0.32, 0.18, fade * 0.82)
		rock_color = Color(0.68, 0.54, 0.38, fade)
	
	# 1. Outer heavy shockwave ring (tapering stroke width)
	var ring_width := lerpf(18.0 if not _is_avatar else 24.0, 2.5, expansion)
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 36, ring_color, ring_width, false)
	
	# 2. Inner high-intensity energy ring
	if t < 0.68:
		var inner_t := t / 0.68
		var inner_expansion := 1.0 - pow(1.0 - inner_t, 2.4)
		var inner_radius := lerpf(6.0, _radius * 0.72, inner_expansion)
		var inner_width := lerpf(9.0 if not _is_avatar else 12.0, 1.5, inner_expansion)
		draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 32, core_color, inner_width, false)
	
	# 3. Jagged seismic fissure lines
	for i in range(_fissure_angles.size()):
		var angle: float = _fissure_angles[i]
		var max_len: float = _fissure_lengths[i]
		var current_len := minf(current_radius * 0.88, max_len * expansion)
		var dir := Vector2.RIGHT.rotated(angle)
		var mid := dir.rotated(0.14) * (current_len * 0.52)
		var finish := dir * current_len
		draw_line(Vector2.ZERO, mid, fissure_color, 2.8, false)
		draw_line(mid, finish, fissure_color, 1.6, false)
	
	# 4. Flying rock debris particles
	for p in _rock_particles:
		var p_dir: Vector2 = p["dir"]
		var travel: float = float(p["dist"]) * expansion
		var pos: Vector2 = p_dir * travel
		var size: float = float(p["size"]) * fade
		var half := size * 0.5
		var diamond := PackedVector2Array([
			pos + Vector2(0.0, -half),
			pos + Vector2(half, 0.0),
			pos + Vector2(0.0, half),
			pos + Vector2(-half, 0.0)
		])
		draw_colored_polygon(diamond, rock_color if randf() > 0.35 else core_color)
