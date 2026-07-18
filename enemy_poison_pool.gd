extends Node2D

var world: Node
var radius := 58.0
var duration := 4.0
var tick_damage := 1
var tick_interval := 0.9
var tick_timer := 0.15
var configured := false
var visual: Polygon2D
var ring: Line2D
var elapsed := 0.0

func configure(owner_world: Node, world_position: Vector2, pool_radius: float = 58.0, lifetime: float = 4.0, damage_per_tick: int = 1) -> void:
	world = owner_world
	global_position = world_position
	radius = pool_radius
	duration = lifetime
	tick_damage = maxi(1, damage_per_tick)
	configured = true
	z_index = 4
	_create_visuals()

func _process(delta: float) -> void:
	if not configured:
		return
	if world == null or not is_instance_valid(world):
		queue_free()
		return
	elapsed += delta
	duration -= delta
	tick_timer -= delta
	var pulse := 1.0 + sin(elapsed * 4.5) * 0.055
	scale = Vector2.ONE * pulse
	if visual:
		visual.modulate.a = clampf(duration / 0.7, 0.0, 1.0) * 0.72
	if ring:
		ring.modulate.a = clampf(duration / 0.7, 0.0, 1.0) * 0.9
	if tick_timer <= 0.0:
		tick_timer = tick_interval
		_damage_targets()
	if duration <= 0.0:
		queue_free()

func _create_visuals() -> void:
	visual = Polygon2D.new()
	visual.polygon = _circle_points(radius, 28)
	visual.color = Color(0.12, 0.62, 0.18, 0.5)
	visual.z_index = 0
	add_child(visual)

	ring = Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(0.42, 1.0, 0.28, 0.86)
	ring.points = _circle_points(radius, 28, true)
	ring.z_index = 1
	add_child(ring)

	var inner := Line2D.new()
	inner.width = 2.0
	inner.default_color = Color(0.65, 1.0, 0.42, 0.42)
	inner.points = _circle_points(radius * 0.56, 20, true)
	add_child(inner)

func _circle_points(circle_radius: float, segments: int, close_loop: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := segments + 1 if close_loop else segments
	for index in range(count):
		var angle := TAU * float(index % segments) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * circle_radius)
	return points

func _damage_targets() -> void:
	for child in world.get_children():
		if not child is Node2D or not is_instance_valid(child):
			continue
		var target := child as Node2D
		var is_player := str(target.name).begins_with("Player")
		var is_base := str(target.name) == "Base"
		if not is_player and not is_base:
			continue
		if global_position.distance_to(target.global_position) > radius:
			continue
		if target.has_method("take_damage"):
			target.take_damage(tick_damage if is_player else 1)
