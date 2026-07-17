extends Node2D

signal nest_damaged(current_health: int, maximum_health: int)
signal nest_destroyed

var nest_name := "Nest"
var zone := 1
var health := 100
var max_health := 100
var destroyed := false
var pulse_time := 0.0
var status_label: Label
var core: Polygon2D

func setup(display_name: String, depth_zone: int, maximum_health: int) -> void:
	nest_name = display_name
	zone = depth_zone
	max_health = maximum_health
	health = max_health
	set_meta("exploration_nest", true)
	add_to_group("enemies")
	_build_visual()
	_update_label()

func _process(delta: float) -> void:
	pulse_time += delta
	if core != null and is_instance_valid(core):
		var pulse := 0.92 + sin(pulse_time * 3.2) * 0.08
		core.scale = Vector2(pulse, 1.0 / maxf(pulse, 0.1))

func take_damage(amount: int) -> void:
	if destroyed:
		return
	var applied := maxi(amount, 1)
	health = maxi(health - applied, 0)
	nest_damaged.emit(health, max_health)
	_update_label()
	_hit_feedback()
	if health <= 0:
		_die()

func _build_visual() -> void:
	z_index = 8
	var colors := [Color(0.75, 0.22, 0.1, 1.0), Color(0.64, 0.1, 0.48, 1.0), Color(0.28, 0.04, 0.42, 1.0)]
	core = Polygon2D.new()
	core.name = "Core"
	core.polygon = _circle_points(28.0 + zone * 2.0, 16)
	core.color = colors[clampi(zone - 1, 0, colors.size() - 1)]
	add_child(core)

	for angle in [0.15, 1.2, 2.2, 3.25, 4.25, 5.35]:
		var tendril := Line2D.new()
		tendril.width = 7.0
		tendril.default_color = Color(core.color, 0.95)
		var direction := Vector2.RIGHT.rotated(float(angle))
		tendril.points = PackedVector2Array([
			direction * 13.0,
			direction * 31.0 + direction.orthogonal() * 8.0,
			direction * 45.0,
		])
		add_child(tendril)

	var eye := Polygon2D.new()
	eye.name = "Eye"
	eye.polygon = PackedVector2Array([Vector2(-13, 0), Vector2(0, -9), Vector2(13, 0), Vector2(0, 9)])
	eye.color = Color(1.0, 0.72, 0.12, 1.0)
	add_child(eye)
	var pupil := Polygon2D.new()
	pupil.polygon = PackedVector2Array([Vector2(-3, -7), Vector2(3, -7), Vector2(3, 7), Vector2(-3, 7)])
	pupil.color = Color(0.08, 0.01, 0.015, 1.0)
	add_child(pupil)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.position = Vector2(-112, -76)
	status_label.size = Vector2(224, 52)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48, 1.0))
	status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	status_label.add_theme_constant_override("outline_size", 4)
	add_child(status_label)

func _update_label() -> void:
	if status_label != null and is_instance_valid(status_label):
		status_label.text = "%s\nATTACK  %d/%d" % [nest_name.to_upper(), health, max_health]

func _hit_feedback() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.18, 0.78), 0.07)
	tween.tween_property(self, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _die() -> void:
	if destroyed:
		return
	destroyed = true
	remove_from_group("enemies")
	nest_destroyed.emit()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.55, 0.12), 0.3)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.chain().tween_callback(queue_free)

func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / float(count)) * radius)
	return points
