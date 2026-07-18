extends CharacterBody2D

const MOVE_SPEED := 270.0
const ATTACK_RANGE := 68.0
const ATTACK_INTERVAL := 0.42
const REBUILD_DISTANCE := 82.0
const REBUILD_TIME := 2.2

var controller: Node
var source_player: CharacterBody2D
var player_id := 1
var attack_timer := 0.0
var walk_timer := 0.0
var rebuild_timer := 0.0
var dust_timer := 0.0
var defeated := false
var sprite_rest_scale := Vector2.ONE
var health_background: Line2D
var health_fill: Line2D
var rebuild_background: Line2D
var rebuild_fill: Line2D
var rebuild_label: Label

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	sprite_rest_scale = sprite.scale
	_create_status_bars()

func configure(controller_node: Node, original_player: CharacterBody2D, input_player_id: int) -> void:
	controller = controller_node
	source_player = original_player
	player_id = maxi(1, input_player_id)
	_update_status_bars()

func _physics_process(delta: float) -> void:
	if defeated:
		return
	if source_player == null or not is_instance_valid(source_player):
		queue_free()
		return
	attack_timer = maxf(attack_timer - delta, 0.0)
	dust_timer = maxf(dust_timer - delta, 0.0)
	var direction := Vector2(
		Input.get_axis("p%d_left" % player_id, "p%d_right" % player_id),
		Input.get_axis("p%d_up" % player_id, "p%d_down" % player_id)
	)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	velocity = direction * MOVE_SPEED
	move_and_slide()
	_update_animation(delta)
	_try_attack()
	_process_rebuild(delta)
	_update_status_bars()
	if velocity.length_squared() > 40.0 and dust_timer <= 0.0:
		dust_timer = 0.12
		_spawn_dust()

func _try_attack() -> void:
	if attack_timer > 0.0:
		return
	var nearest: Node2D
	var nearest_distance := ATTACK_RANGE
	for enemy_value in get_tree().get_nodes_in_group("enemies"):
		if not enemy_value is Node2D or not is_instance_valid(enemy_value):
			continue
		var enemy := enemy_value as Node2D
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	if nearest == null:
		return
	attack_timer = ATTACK_INTERVAL
	var strength := maxi(1, int(source_player.get("strength")))
	var hit_damage := 4 + strength * 2
	if nearest.has_method("take_damage"):
		nearest.take_damage(hit_damage)
	var direction := global_position.direction_to(nearest.global_position)
	if direction.length_squared() > 0.001:
		sprite.flip_h = direction.x < 0.0
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", sprite_rest_scale * Vector2(1.24, 0.78), 0.07)
	tween.tween_property(sprite, "scale", sprite_rest_scale, 0.12)
	_spawn_wrench_spark(nearest.global_position)

func _process_rebuild(delta: float) -> void:
	var world := get_parent()
	var base := world.get_node_or_null("Base") as Node2D if world else null
	if base == null or global_position.distance_to(base.global_position) > REBUILD_DISTANCE:
		rebuild_timer = maxf(0.0, rebuild_timer - delta * 1.8)
		_set_rebuild_visible(rebuild_timer > 0.01)
		return
	var rebuild_multiplier := float(base.get_meta("mech_rebuild_multiplier", 1.0))
	rebuild_timer = minf(REBUILD_TIME, rebuild_timer + delta * rebuild_multiplier)
	_set_rebuild_visible(true)
	if rebuild_timer >= REBUILD_TIME and controller and controller.has_method("rebuild_mech"):
		controller.rebuild_mech()

func force_defeat() -> void:
	if defeated:
		return
	defeated = true
	_spawn_defeat_burst()
	if controller and controller.has_method("on_pilot_defeated"):
		controller.on_pilot_defeated()
	else:
		queue_free()

func _update_animation(delta: float) -> void:
	if velocity.length_squared() > 1.0:
		walk_timer += delta * 13.0
		sprite.frame = int(walk_timer) % 4
		if absf(velocity.x) > 2.0:
			sprite.flip_h = velocity.x < 0.0
	else:
		walk_timer = 0.0
		sprite.frame = 0

func _create_status_bars() -> void:
	health_background = Line2D.new()
	health_background.width = 7.0
	health_background.default_color = Color(0.03, 0.04, 0.05, 0.95)
	health_background.points = PackedVector2Array([Vector2(-27, -36), Vector2(27, -36)])
	health_background.z_index = 35
	add_child(health_background)

	health_fill = Line2D.new()
	health_fill.width = 4.0
	health_fill.default_color = Color(0.45, 1.0, 0.24, 1.0)
	health_fill.z_index = 36
	add_child(health_fill)

	rebuild_background = Line2D.new()
	rebuild_background.width = 7.0
	rebuild_background.default_color = Color(0.03, 0.04, 0.05, 0.92)
	rebuild_background.points = PackedVector2Array([Vector2(-31, -48), Vector2(31, -48)])
	rebuild_background.z_index = 35
	rebuild_background.visible = false
	add_child(rebuild_background)

	rebuild_fill = Line2D.new()
	rebuild_fill.width = 4.0
	rebuild_fill.default_color = Color(1.0, 0.62, 0.12, 1.0)
	rebuild_fill.z_index = 36
	rebuild_fill.visible = false
	add_child(rebuild_fill)

	rebuild_label = Label.new()
	rebuild_label.text = "REBUILDING"
	rebuild_label.position = Vector2(-38, -68)
	rebuild_label.size = Vector2(76, 18)
	rebuild_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rebuild_label.add_theme_font_size_override("font_size", 9)
	rebuild_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.24, 1.0))
	rebuild_label.add_theme_color_override("font_outline_color", Color.BLACK)
	rebuild_label.add_theme_constant_override("outline_size", 3)
	rebuild_label.visible = false
	rebuild_label.z_index = 37
	add_child(rebuild_label)

func _update_status_bars() -> void:
	if source_player == null or health_fill == null:
		return
	var health := maxi(0, int(source_player.get("health")))
	var maximum := maxi(1, int(source_player.get("max_health")))
	var ratio := clampf(float(health) / float(maximum), 0.0, 1.0)
	health_fill.points = PackedVector2Array([Vector2(-26, -36), Vector2(-26 + 52.0 * ratio, -36)])
	if rebuild_fill:
		var rebuild_ratio := clampf(rebuild_timer / REBUILD_TIME, 0.0, 1.0)
		rebuild_fill.points = PackedVector2Array([Vector2(-30, -48), Vector2(-30 + 60.0 * rebuild_ratio, -48)])

func _set_rebuild_visible(value: bool) -> void:
	if rebuild_background:
		rebuild_background.visible = value
	if rebuild_fill:
		rebuild_fill.visible = value
	if rebuild_label:
		rebuild_label.visible = value

func _spawn_dust() -> void:
	var world := get_parent()
	if world == null:
		return
	var dust := Polygon2D.new()
	dust.polygon = _circle_points(4.0, 8)
	dust.color = Color(0.55, 0.48, 0.38, 0.5)
	dust.global_position = global_position + Vector2(0, 10)
	dust.z_index = 2
	world.add_child(dust)
	var tween := dust.create_tween().set_parallel(true)
	tween.tween_property(dust, "scale", Vector2(1.9, 1.9), 0.3)
	tween.tween_property(dust, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(dust.queue_free)

func _spawn_wrench_spark(position: Vector2) -> void:
	var world := get_parent()
	if world == null:
		return
	var spark := CPUParticles2D.new()
	spark.amount = 8
	spark.lifetime = 0.2
	spark.one_shot = true
	spark.explosiveness = 1.0
	spark.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	spark.emission_sphere_radius = 4.0
	spark.direction = Vector2.UP
	spark.spread = 180.0
	spark.gravity = Vector2(0, 70)
	spark.initial_velocity_min = 35.0
	spark.initial_velocity_max = 90.0
	spark.scale_amount_min = 1.0
	spark.scale_amount_max = 2.3
	spark.color = Color(1.0, 0.72, 0.18, 0.95)
	spark.global_position = position
	spark.z_index = 25
	world.add_child(spark)
	spark.emitting = true
	get_tree().create_timer(0.45).timeout.connect(spark.queue_free)

func _spawn_defeat_burst() -> void:
	var world := get_parent()
	if world == null:
		return
	var burst := CPUParticles2D.new()
	burst.amount = 24
	burst.lifetime = 0.35
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 7.0
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2(0, 100)
	burst.initial_velocity_min = 45.0
	burst.initial_velocity_max = 120.0
	burst.scale_amount_min = 1.2
	burst.scale_amount_max = 3.0
	burst.color = Color(0.6, 1.0, 0.24, 0.95)
	burst.global_position = global_position
	burst.z_index = 26
	world.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.7).timeout.connect(burst.queue_free)

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / float(segments)) * radius)
	return points
