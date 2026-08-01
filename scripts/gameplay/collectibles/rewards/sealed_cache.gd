extends Area2D

## One of three sealed caches that open in the seam when a stage objective
## completes. The stage reward used to be handed over the moment the last crystal
## broke, which made the objective a thing that happened to the player rather
## than a thing they decided. Three caches spread through the mine turn the same
## reward into a route choice made with the hero's legs, under the dig clock:
## claiming one collapses the other two.

signal claimed(reward_id: String)

const CLAIM_RADIUS := 30.0

var reward_id := ""
var reward_title := ""
var accent := Color(1.0, 0.78, 0.32, 1.0)
var claimable := false
var collapsing := false

var _body: Polygon2D
var _glow: Polygon2D
var _label: Label

func configure(id: String, title: String, colour: Color) -> void:
	reward_id = id
	reward_title = title
	accent = colour
	if _label != null and is_instance_valid(_label):
		_label.text = reward_title
		_label.add_theme_color_override("font_color", accent.lightened(0.25))

func _ready() -> void:
	z_index = 6
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = CLAIM_RADIUS
	shape.shape = circle
	add_child(shape)

	_glow = Polygon2D.new()
	var glow_points := PackedVector2Array()
	for index in range(25):
		glow_points.append(Vector2.RIGHT.rotated(TAU * float(index) / 24.0) * 34.0)
	_glow.polygon = glow_points
	_glow.color = Color(accent.r, accent.g, accent.b, 0.12)
	add_child(_glow)

	_body = Polygon2D.new()
	_body.polygon = PackedVector2Array([
		Vector2(-16, -6), Vector2(0, -15), Vector2(16, -6),
		Vector2(16, 10), Vector2(0, 18), Vector2(-16, 10)
	])
	_body.color = Color(0.30, 0.22, 0.13, 1.0)
	add_child(_body)

	var band := Line2D.new()
	band.width = 3.0
	band.default_color = accent
	band.points = PackedVector2Array([Vector2(-16, 2), Vector2(0, 10), Vector2(16, 2)])
	add_child(band)

	_label = Label.new()
	_label.position = Vector2(-84, -76)
	_label.size = Vector2(168, 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.text = reward_title
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", accent.lightened(0.25))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.96))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)

	scale = Vector2.ZERO
	var appear := create_tween()
	appear.tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var pulse := create_tween().set_loops()
	pulse.tween_property(_glow, "scale", Vector2(1.16, 1.16), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_glow, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)

	# A cache that spawns under the hero's feet must not claim itself before the
	# player has seen the other two.
	await get_tree().create_timer(0.45).timeout
	claimable = true
	body_entered.connect(_on_body_entered)
	for body in get_overlapping_bodies():
		_on_body_entered(body)

func _on_body_entered(body: Node2D) -> void:
	if not claimable or collapsing or body == null or body.name != "Player":
		return
	claimable = false
	claimed.emit(reward_id)
	_burst(accent, 22)
	var open := create_tween()
	open.tween_property(self, "scale", Vector2(1.35, 1.35), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0), 0.22)
	open.tween_callback(queue_free)

## The caches the player did not take crumble, so the choice is visibly spent.
func collapse() -> void:
	if collapsing:
		return
	collapsing = true
	claimable = false
	_burst(Color(0.42, 0.36, 0.30, 1.0), 10)
	var fall := create_tween()
	fall.tween_property(self, "position:y", position.y + 10.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(self, "scale", Vector2(0.82, 0.5), 0.30)
	fall.parallel().tween_property(self, "modulate", Color(0.5, 0.5, 0.5, 0.0), 0.30)
	fall.tween_callback(queue_free)

func _burst(colour: Color, amount: int) -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = 0.55
	particles.explosiveness = 0.92
	particles.spread = 180.0
	particles.gravity = Vector2(0, 120)
	particles.initial_velocity_min = 45.0
	particles.initial_velocity_max = 135.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = colour
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
