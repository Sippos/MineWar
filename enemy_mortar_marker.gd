extends Node2D

const POISON_POOL_SCRIPT := preload("res://enemy_poison_pool.gd")

var world: Node
var blast_radius := 62.0
var delay := 0.8
var damage := 8
var creates_poison := false
var configured := false
var ring: Line2D
var fill: Polygon2D
var initial_delay := 0.8

func configure(owner_world: Node, world_position: Vector2, hit_damage: int, radius_value: float = 62.0, delay_value: float = 0.8, poison: bool = false) -> void:
	world = owner_world
	global_position = world_position
	damage = maxi(1, hit_damage)
	blast_radius = maxf(20.0, radius_value)
	delay = maxf(0.15, delay_value)
	initial_delay = delay
	creates_poison = poison
	configured = true
	z_index = 6
	_create_visuals()

func _process(delta: float) -> void:
	if not configured:
		return
	if world == null or not is_instance_valid(world):
		queue_free()
		return
	delay -= delta
	var progress := 1.0 - clampf(delay / initial_delay, 0.0, 1.0)
	if ring:
		ring.scale = Vector2.ONE * lerpf(1.0, 0.72, progress)
		ring.default_color = Color(1.0, lerpf(0.7, 0.18, progress), 0.08, 0.96)
	if fill:
		fill.modulate.a = lerpf(0.12, 0.48, progress)
	if delay <= 0.0:
		_detonate()

func _create_visuals() -> void:
	fill = Polygon2D.new()
	fill.polygon = _circle_points(blast_radius, 30)
	fill.color = Color(1.0, 0.22, 0.06, 0.28)
	add_child(fill)

	ring = Line2D.new()
	ring.width = 4.0
	ring.default_color = Color(1.0, 0.65, 0.1, 0.96)
	ring.points = _circle_points(blast_radius, 30, true)
	add_child(ring)

	var cross := Line2D.new()
	cross.width = 3.0
	cross.default_color = Color(1.0, 0.85, 0.3, 0.8)
	cross.points = PackedVector2Array([
		Vector2(-blast_radius * 0.45, 0), Vector2(blast_radius * 0.45, 0),
		Vector2.ZERO, Vector2(0, -blast_radius * 0.45), Vector2(0, blast_radius * 0.45)
	])
	add_child(cross)

func _detonate() -> void:
	for child in world.get_children():
		if not child is Node2D or not is_instance_valid(child):
			continue
		var target := child as Node2D
		var is_player := str(target.name).begins_with("Player")
		var is_base := str(target.name) == "Base"
		if not is_player and not is_base:
			continue
		if global_position.distance_to(target.global_position) <= blast_radius and target.has_method("take_damage"):
			target.take_damage(damage if is_player else maxi(1, int(ceil(float(damage) * 0.7))))

	var burst := CPUParticles2D.new()
	burst.amount = 34
	burst.lifetime = 0.5
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 12.0
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2(0, 130)
	burst.initial_velocity_min = 65.0
	burst.initial_velocity_max = 180.0
	burst.scale_amount_min = 1.8
	burst.scale_amount_max = 5.0
	burst.color = Color(1.0, 0.34, 0.08, 0.95)
	burst.global_position = global_position
	burst.z_index = 25
	world.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.9).timeout.connect(burst.queue_free)

	if creates_poison:
		var pool := POISON_POOL_SCRIPT.new()
		world.add_child(pool)
		pool.configure(world, global_position, blast_radius * 0.72, 2.4, 1)
	queue_free()

func _circle_points(circle_radius: float, segments: int, close_loop: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := segments + 1 if close_loop else segments
	for index in range(count):
		points.append(Vector2.RIGHT.rotated(TAU * float(index % segments) / float(segments)) * circle_radius)
	return points
