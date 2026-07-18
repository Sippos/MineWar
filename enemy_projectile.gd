extends Node2D

const POISON_POOL_SCRIPT := preload("res://enemy_poison_pool.gd")

var world: Node
var target_position := Vector2.ZERO
var travel_speed := 360.0
var damage := 1
var blast_radius := 34.0
var creates_poison := false
var poison_radius := 48.0
var poison_duration := 2.8
var lifetime := 2.2
var configured := false
var visual: Polygon2D
var trail_timer := 0.0
var projectile_color := Color(0.45, 1.0, 0.24, 1.0)

func configure(owner_world: Node, start_position: Vector2, destination: Vector2, hit_damage: int, speed_value: float = 360.0, radius_value: float = 34.0, poison: bool = false, color_value: Color = Color(0.45, 1.0, 0.24, 1.0)) -> void:
	world = owner_world
	global_position = start_position
	target_position = destination
	damage = maxi(1, hit_damage)
	travel_speed = maxf(80.0, speed_value)
	blast_radius = maxf(16.0, radius_value)
	creates_poison = poison
	projectile_color = color_value
	configured = true
	z_index = 24
	_create_visuals()

func _process(delta: float) -> void:
	if not configured:
		return
	if world == null or not is_instance_valid(world):
		queue_free()
		return
	lifetime -= delta
	trail_timer -= delta
	var offset := target_position - global_position
	var distance := offset.length()
	if distance <= maxf(10.0, travel_speed * delta) or lifetime <= 0.0:
		_explode()
		return
	global_position += offset.normalized() * minf(travel_speed * delta, distance)
	rotation += delta * 7.0
	if trail_timer <= 0.0:
		trail_timer = 0.055
		_spawn_trail_dot()

func _create_visuals() -> void:
	visual = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-7, 0), Vector2(-3, -6), Vector2(4, -5),
		Vector2(8, 0), Vector2(4, 5), Vector2(-3, 6)
	])
	visual.color = projectile_color
	add_child(visual)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(0, -3), Vector2(3, 0), Vector2(0, 3)])
	core.color = Color(1.0, 1.0, 0.82, 0.95)
	add_child(core)

func _spawn_trail_dot() -> void:
	var dot := Polygon2D.new()
	dot.polygon = _circle_points(3.5, 8)
	dot.color = Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.52)
	dot.global_position = global_position
	dot.z_index = z_index - 1
	world.add_child(dot)
	var tween := dot.create_tween().set_parallel(true)
	tween.tween_property(dot, "scale", Vector2(0.1, 0.1), 0.22)
	tween.tween_property(dot, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(dot.queue_free)

func _explode() -> void:
	_damage_targets()
	_spawn_burst()
	if creates_poison:
		var pool := POISON_POOL_SCRIPT.new()
		world.add_child(pool)
		pool.configure(world, target_position, poison_radius, poison_duration, maxi(1, int(ceil(float(damage) * 0.22))))
	queue_free()

func _damage_targets() -> void:
	for child in world.get_children():
		if not child is Node2D or not is_instance_valid(child):
			continue
		var target := child as Node2D
		var is_player := str(target.name).begins_with("Player")
		var is_base := str(target.name) == "Base"
		if not is_player and not is_base:
			continue
		if target_position.distance_to(target.global_position) > blast_radius:
			continue
		if target.has_method("take_damage"):
			target.take_damage(damage if is_player else maxi(1, int(ceil(float(damage) * 0.65))))

func _spawn_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.amount = 18
	burst.lifetime = 0.34
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 7.0
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2(0, 70)
	burst.initial_velocity_min = 45.0
	burst.initial_velocity_max = 110.0
	burst.scale_amount_min = 1.4
	burst.scale_amount_max = 3.6
	burst.color = projectile_color
	burst.global_position = target_position
	burst.z_index = 25
	world.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.7).timeout.connect(burst.queue_free)

func _circle_points(circle_radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / float(segments)) * circle_radius)
	return points
