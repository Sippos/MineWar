extends Area2D

## An ancient biome anomaly shrine discovered within buried sub-surface chambers.
## When unearthed and activated, it channels unique ancient powers, granting
## an expedition modifier or permanent run buff for the remainder of the expedition.

signal activated(anomaly_id: String, modifier_data: Dictionary)

const INTERACT_RADIUS := 36.0

var anomaly_id := "ancient_steam_pump"
var anomaly_title := "ANCIENT STEAM PUMP"
var anomaly_description := "+35 Speed, +25% Dig Cadence"
var accent := Color(0.92, 0.62, 0.22, 1.0)
var modifier_data: Dictionary = {}
var is_active := false
var is_unearthed := false

var _base_pillar: Polygon2D
var _core_rune: Polygon2D
var _glow_halo: Polygon2D
var _title_label: Label
var _desc_label: Label
var _float_tween: Tween

func configure(id: String, title: String, description: String, colour: Color, data: Dictionary = {}) -> void:
	anomaly_id = id
	anomaly_title = title
	anomaly_description = description
	accent = colour
	modifier_data = data.duplicate(true)
	_update_visuals()

func _ready() -> void:
	z_index = 6
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	
	var col_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	col_shape.shape = circle
	add_child(col_shape)
	
	# Ethereal glow halo behind shrine
	_glow_halo = Polygon2D.new()
	var halo_points := PackedVector2Array()
	for i in range(24):
		halo_points.append(Vector2.RIGHT.rotated(TAU * float(i) / 24.0) * 38.0)
	_glow_halo.polygon = halo_points
	_glow_halo.color = Color(accent.r, accent.g, accent.b, 0.14)
	add_child(_glow_halo)
	
	# Ancient carved stone pedestal / apparatus base
	_base_pillar = Polygon2D.new()
	_base_pillar.polygon = PackedVector2Array([
		Vector2(-18, -4), Vector2(0, -16), Vector2(18, -4),
		Vector2(20, 16), Vector2(0, 22), Vector2(-20, 16)
	])
	_base_pillar.color = Color(0.24, 0.22, 0.26, 1.0)
	add_child(_base_pillar)
	
	# Inscribed runic core that levitates & pulses
	_core_rune = Polygon2D.new()
	_core_rune.polygon = PackedVector2Array([
		Vector2(0, -12), Vector2(10, 0), Vector2(0, 12), Vector2(-10, 0)
	])
	_core_rune.color = accent
	add_child(_core_rune)
	
	# Trim band
	var trim := Line2D.new()
	trim.width = 2.5
	trim.default_color = accent.lightened(0.2)
	trim.points = PackedVector2Array([Vector2(-18, 6), Vector2(0, 14), Vector2(18, 6)])
	add_child(trim)
	
	# UI Floating text labels
	_title_label = Label.new()
	_title_label.position = Vector2(-100, -56)
	_title_label.size = Vector2(200, 18)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = anomaly_title
	_title_label.add_theme_font_size_override("font_size", 11)
	_title_label.add_theme_color_override("font_color", accent.lightened(0.35))
	_title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	_title_label.add_theme_constant_override("outline_size", 4)
	add_child(_title_label)
	
	_desc_label = Label.new()
	_desc_label.position = Vector2(-100, -38)
	_desc_label.size = Vector2(200, 16)
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.text = anomaly_description
	_desc_label.add_theme_font_size_override("font_size", 9)
	_desc_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 0.85))
	_desc_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	_desc_label.add_theme_constant_override("outline_size", 3)
	add_child(_desc_label)
	
	# Idle subtle hover & pulse
	_start_idle_animation()
	body_entered.connect(_on_body_entered)

func _update_visuals() -> void:
	if _glow_halo:
		_glow_halo.color = Color(accent.r, accent.g, accent.b, 0.18 if is_active else 0.12)
	if _core_rune:
		_core_rune.color = accent
	if _title_label:
		_title_label.text = anomaly_title
		_title_label.add_theme_color_override("font_color", accent.lightened(0.35))
	if _desc_label:
		_desc_label.text = anomaly_description

func _start_idle_animation() -> void:
	if _float_tween and _float_tween.is_valid():
		_float_tween.kill()
	_float_tween = create_tween().set_loops()
	_float_tween.tween_property(_core_rune, "position:y", -5.0, 1.2).set_trans(Tween.TRANS_SINE)
	_float_tween.tween_property(_core_rune, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	
	var pulse := create_tween().set_loops()
	pulse.tween_property(_glow_halo, "scale", Vector2(1.22, 1.22), 1.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_glow_halo, "scale", Vector2.ONE, 1.5).set_trans(Tween.TRANS_SINE)

func activate() -> bool:
	if is_active:
		return false
	is_active = true
	is_unearthed = true
	
	# Visual activation flare
	if _glow_halo:
		_glow_halo.color = Color(accent.r, accent.g, accent.b, 0.45)
	
	var flare := create_tween()
	flare.tween_property(_core_rune, "scale", Vector2(1.6, 1.6), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flare.tween_property(_core_rune, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_SINE)
	
	_spawn_activation_burst()
	activated.emit(anomaly_id, modifier_data)
	return true

func _on_body_entered(body: Node2D) -> void:
	if is_active or body == null or body.name != "Player":
		return
	activate()

func _spawn_activation_burst() -> void:
	var count := 18
	for i in range(count):
		var spark := Polygon2D.new()
		var points := PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
		spark.polygon = points
		spark.color = accent.lightened(0.2)
		add_child(spark)
		
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(count) + randf_range(-0.2, 0.2))
		var distance := randf_range(35.0, 65.0)
		var burst := create_tween()
		burst.tween_property(spark, "position", dir * distance, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		burst.parallel().tween_property(spark, "modulate:a", 0.0, 0.55)
		burst.tween_callback(spark.queue_free)
