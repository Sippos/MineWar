extends Node2D

const MINECART_TEXTURE := preload("res://character_sprites/minecart_spritesheet_25d.png")
const PEON_TEXTURE := preload("res://character_sprites/peon_walk_spritesheet_25d.png")
const SPIDER_TEXTURE := preload("res://character_sprites/spider_walk_spritesheet.png")
const SHAMAN_TOTEM_TEXTURE := preload("res://Shaman_Totem_Radar.png")
const MECH_IDLE_TEXTURE := preload("res://character_sprites/hero_idle/mech_idle_front.png")

var base_id := "default_base"
var dwarf_cart_unlocked := false

var elapsed := 0.0
var walkers: Array[Dictionary] = []
var orbiters: Array[Dictionary] = []
var gear_nodes: Array[Node2D] = []
var crane_hook: Polygon2D
var crane_cable: Line2D
var spark_timer := 0.25

func _ready() -> void:
	z_index = -3
	match base_id:
		"default_base":
			_create_dwarf_ambience()
		"shaman_base":
			_create_shaman_ambience()
		"nerubian_base":
			_create_nerubian_ambience()
		"druid_base":
			_create_druid_ambience()
		"undead_king_base":
			_create_undead_ambience()
		"mech_base":
			_create_mech_ambience()

func _process(delta: float) -> void:
	elapsed += delta
	_update_walkers(delta)
	_update_orbiters()
	if base_id == "mech_base":
		_update_mech_workshop(delta)
	elif base_id == "default_base" and not dwarf_cart_unlocked:
		spark_timer -= delta
		if spark_timer <= 0.0:
			spark_timer = 1.15
			_spawn_sparks(Vector2(72, -12), Color(1.0, 0.7, 0.18, 0.96), 8)

func _create_dwarf_ambience() -> void:
	if dwarf_cart_unlocked:
		var track := PackedVector2Array([
			Vector2(-195, -55), Vector2(-118, -118), Vector2(98, -118), Vector2(195, -45),
			Vector2(195, 50), Vector2(110, 88), Vector2(-112, 88), Vector2(-195, 50)
		])
		_create_rail_loop(track)
		_add_walker("DwarfMinecart", MINECART_TEXTURE, track, Vector2(0.78, 0.78), 92.0, 8.0, Color.WHITE)
	else:
		# Before the railway unlocks, quiet forge sparks make the base feel alive
		# without advertising a missing feature in the middle of the room.
		_create_forge_marker(Vector2(74, -14))
		_create_forge_marker(Vector2(-78, -18))

func _create_shaman_ambience() -> void:
	var totem_positions := [Vector2(-142, -58), Vector2(142, -58), Vector2(-112, 72), Vector2(112, 72)]
	for index in range(totem_positions.size()):
		var totem := Sprite2D.new()
		totem.name = "ShamanTotem%d" % index
		totem.texture = SHAMAN_TOTEM_TEXTURE
		var width := maxf(float(totem.texture.get_width()), 1.0)
		var height := maxf(float(totem.texture.get_height()), 1.0)
		var fit := minf(42.0 / width, 54.0 / height)
		totem.scale = Vector2.ONE * fit
		totem.position = totem_positions[index]
		totem.modulate = Color(0.68, 0.94, 1.0, 0.92)
		totem.z_index = 1 if totem.position.y < 0.0 else 4
		add_child(totem)
		_add_orbiter(totem.position, 22.0, 0.7 + float(index) * 0.09, float(index) * 1.3, Color(0.28, 0.9, 1.0, 0.76), 4.5)
	var patrol := PackedVector2Array([
		Vector2(-150, 42), Vector2(-112, -76), Vector2(0, -106), Vector2(116, -72),
		Vector2(154, 40), Vector2(72, 92), Vector2(-76, 92)
	])
	_add_walker("ShamanPeon", PEON_TEXTURE, patrol, Vector2(0.72, 0.72), 68.0, 9.0, Color(0.88, 1.0, 0.78, 1.0))
	_create_caption("ANCESTRAL PATROL", Vector2(-92, 96), Color(0.48, 0.9, 1.0, 0.88))

func _create_nerubian_ambience() -> void:
	_create_web(Vector2(-152, -88), Vector2(-70, -116))
	_create_web(Vector2(70, -116), Vector2(154, -84))
	_create_web(Vector2(-178, 44), Vector2(-92, 92))
	_create_web(Vector2(92, 92), Vector2(178, 42))
	var paths := [
		PackedVector2Array([Vector2(-174, -26), Vector2(-92, -96), Vector2(24, -110), Vector2(126, -64), Vector2(176, 28), Vector2(78, 86), Vector2(-78, 78)]),
		PackedVector2Array([Vector2(166, 48), Vector2(98, -72), Vector2(-22, -108), Vector2(-144, -50), Vector2(-166, 44), Vector2(-52, 94), Vector2(72, 92)]),
		PackedVector2Array([Vector2(-118, 84), Vector2(-172, 8), Vector2(-98, -82), Vector2(10, -104), Vector2(152, -18), Vector2(116, 72)])
	]
	for index in range(paths.size()):
		_add_walker("NestSpider%d" % index, SPIDER_TEXTURE, paths[index], Vector2(0.48, 0.48), 54.0 + float(index) * 8.0, 10.0, Color(0.9, 0.84, 1.0, 1.0))
	_create_caption("THE BROOD NEVER SLEEPS", Vector2(-116, 98), Color(0.78, 0.72, 1.0, 0.88))

func _create_druid_ambience() -> void:
	var root_color := Color(0.25, 0.56, 0.18, 0.7)
	for offset in [Vector2(-180, 74), Vector2(-124, 96), Vector2(126, 96), Vector2(180, 70)]:
		var root := Line2D.new()
		root.width = 6.0
		root.default_color = root_color
		root.points = PackedVector2Array([offset, offset * 0.58 + Vector2(0, 20), offset * 0.26])
		root.z_index = -1
		add_child(root)
	for index in range(5):
		_add_orbiter(Vector2(0, -8), 86.0 + float(index % 2) * 34.0, 0.34 + float(index) * 0.055, float(index) * 1.21, Color(0.42, 1.0, 0.48, 0.78), 6.0 + float(index % 3))
	_create_caption("THE GROVE BREATHES", Vector2(-98, 98), Color(0.5, 1.0, 0.52, 0.86))

func _create_undead_ambience() -> void:
	for index in range(6):
		_add_orbiter(Vector2(0, -14), 72.0 + float(index % 3) * 28.0, -0.32 - float(index) * 0.045, float(index) * 0.92, Color(0.68, 0.38, 1.0, 0.78), 5.0 + float(index % 2) * 3.0)
	var crown := Line2D.new()
	crown.width = 3.0
	crown.default_color = Color(0.62, 0.34, 1.0, 0.72)
	crown.points = PackedVector2Array([Vector2(-46, -106), Vector2(-24, -126), Vector2(0, -108), Vector2(25, -128), Vector2(48, -106)])
	add_child(crown)
	_create_caption("SOULS ANSWER THE CITADEL", Vector2(-128, 98), Color(0.72, 0.48, 1.0, 0.88))

func _create_mech_ambience() -> void:
	var spare_frame := Sprite2D.new()
	spare_frame.name = "SpareMechFrame"
	spare_frame.texture = MECH_IDLE_TEXTURE
	var width := maxf(float(spare_frame.texture.get_width()), 1.0)
	var height := maxf(float(spare_frame.texture.get_height()), 1.0)
	var fit := minf(86.0 / width, 104.0 / height)
	spare_frame.scale = Vector2.ONE * fit
	spare_frame.position = Vector2(-92, -24)
	spare_frame.modulate = Color(0.92, 0.78, 0.46, 0.92)
	spare_frame.z_index = 1
	add_child(spare_frame)

	var crane_post := Line2D.new()
	crane_post.width = 8.0
	crane_post.default_color = Color(0.48, 0.38, 0.22, 1.0)
	crane_post.points = PackedVector2Array([Vector2(88, 78), Vector2(88, -106), Vector2(-18, -106)])
	crane_post.z_index = 2
	add_child(crane_post)
	crane_cable = Line2D.new()
	crane_cable.width = 3.0
	crane_cable.default_color = Color(0.68, 0.62, 0.5, 0.95)
	crane_cable.z_index = 2
	add_child(crane_cable)
	crane_hook = Polygon2D.new()
	crane_hook.polygon = PackedVector2Array([Vector2(-7, -4), Vector2(7, -4), Vector2(5, 8), Vector2(0, 13), Vector2(-5, 8)])
	crane_hook.color = Color(0.9, 0.58, 0.16, 1.0)
	crane_hook.z_index = 3
	add_child(crane_hook)

	_create_gear(Vector2(132, 38), 25.0, 0.55)
	_create_gear(Vector2(164, 66), 17.0, -0.8)
	_create_gear(Vector2(-150, 62), 20.0, -0.62)
	_create_caption("WORKSHOP ONLINE", Vector2(-84, 99), Color(1.0, 0.7, 0.24, 0.94))

func _update_mech_workshop(delta: float) -> void:
	for gear in gear_nodes:
		gear.rotation += float(gear.get_meta("rotation_speed", 0.5)) * delta
	var hook_position := Vector2(-18.0 + sin(elapsed * 0.55) * 54.0, -40.0 + sin(elapsed * 1.1) * 13.0)
	if crane_hook:
		crane_hook.position = hook_position
	if crane_cable:
		crane_cable.points = PackedVector2Array([Vector2(-18, -106), Vector2(hook_position.x, -106), hook_position + Vector2(0, -5)])
	spark_timer -= delta
	if spark_timer <= 0.0:
		spark_timer = 0.58
		_spawn_sparks(Vector2(-88, -6) + Vector2(randf_range(-22.0, 22.0), randf_range(-26.0, 20.0)), Color(1.0, 0.68, 0.14, 1.0), 11)

func _add_walker(node_name: String, texture: Texture2D, path: PackedVector2Array, scale_value: Vector2, speed: float, fps: float, tint: Color) -> void:
	if path.size() < 2:
		return
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.hframes = 8
	sprite.vframes = 8
	sprite.scale = scale_value
	sprite.modulate = tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	walkers.append({
		"sprite": sprite,
		"path": path,
		"segment": 0,
		"distance": 0.0,
		"speed": speed,
		"fps": fps,
		"animation": randf_range(0.0, 8.0)
	})
	_update_single_walker(walkers.size() - 1, 0.0)

func _update_walkers(delta: float) -> void:
	for index in range(walkers.size()):
		_update_single_walker(index, delta)

func _update_single_walker(index: int, delta: float) -> void:
	var data: Dictionary = walkers[index]
	var sprite := data.get("sprite") as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	var path: PackedVector2Array = data["path"]
	var segment := int(data["segment"])
	var distance := float(data["distance"]) + float(data["speed"]) * delta
	var start := path[segment]
	var finish := path[(segment + 1) % path.size()]
	var segment_length := maxf(start.distance_to(finish), 0.01)
	while distance >= segment_length:
		distance -= segment_length
		segment = (segment + 1) % path.size()
		start = path[segment]
		finish = path[(segment + 1) % path.size()]
		segment_length = maxf(start.distance_to(finish), 0.01)
	var direction := start.direction_to(finish)
	sprite.position = start.lerp(finish, distance / segment_length)
	var row := 1 if direction.x >= 0.0 else 5
	if absf(direction.y) > absf(direction.x):
		row = 3 if direction.y >= 0.0 else 7
	var animation := float(data["animation"]) + delta * float(data["fps"])
	sprite.frame_coords = Vector2i(int(floor(animation)) % 8, row)
	sprite.z_index = -1 if sprite.position.y < -24.0 else 4
	data["segment"] = segment
	data["distance"] = distance
	data["animation"] = animation
	walkers[index] = data

func _add_orbiter(center: Vector2, radius: float, speed: float, phase: float, color: Color, size: float) -> void:
	var orb := Node2D.new()
	orb.z_index = 4
	add_child(orb)
	var glow := Polygon2D.new()
	glow.polygon = _circle_points(size, 14)
	glow.color = color
	orb.add_child(glow)
	var core := Polygon2D.new()
	core.polygon = _circle_points(maxf(2.0, size * 0.38), 10)
	core.color = Color(0.92, 1.0, 0.82, 0.92)
	orb.add_child(core)
	orbiters.append({"node": orb, "center": center, "radius": radius, "speed": speed, "phase": phase, "bob": randf_range(3.0, 8.0)})

func _update_orbiters() -> void:
	for data in orbiters:
		var orb := data.get("node") as Node2D
		if orb == null or not is_instance_valid(orb):
			continue
		var angle := float(data["phase"]) + elapsed * float(data["speed"])
		var center: Vector2 = data["center"]
		var radius := float(data["radius"])
		orb.position = center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.46 + sin(elapsed * 2.2 + angle) * float(data["bob"]))
		orb.scale = Vector2.ONE * (1.0 + sin(elapsed * 3.0 + angle) * 0.12)
		orb.z_index = 0 if orb.position.y < center.y else 5

func _create_rail_loop(points: PackedVector2Array) -> void:
	for index in range(points.size()):
		var start := points[index]
		var finish := points[(index + 1) % points.size()]
		var direction := start.direction_to(finish)
		var normal := Vector2(-direction.y, direction.x)
		var segment_length := start.distance_to(finish)
		var tie_count := maxi(1, int(floor(segment_length / 18.0)))
		for tie_index in range(tie_count + 1):
			var tie_center := start + direction * minf(float(tie_index) * 18.0, segment_length)
			var tie := Line2D.new()
			tie.width = 5.0
			tie.default_color = Color(0.27, 0.16, 0.08, 0.92)
			tie.points = PackedVector2Array([tie_center - normal * 12.0, tie_center + normal * 12.0])
			tie.z_index = -2
			add_child(tie)
		for side in [-1.0, 1.0]:
			var rail := Line2D.new()
			rail.width = 3.0
			rail.default_color = Color(0.58, 0.59, 0.62, 0.96)
			rail.points = PackedVector2Array([start + normal * 7.0 * side, finish + normal * 7.0 * side])
			rail.z_index = -1
			add_child(rail)

func _create_forge_marker(position: Vector2) -> void:
	var anvil := Polygon2D.new()
	anvil.polygon = PackedVector2Array([Vector2(-15, -7), Vector2(16, -7), Vector2(10, 1), Vector2(6, 13), Vector2(-8, 13), Vector2(-11, 1)])
	anvil.color = Color(0.34, 0.35, 0.38, 0.96)
	anvil.position = position
	anvil.z_index = 3
	add_child(anvil)

func _create_web(start: Vector2, finish: Vector2) -> void:
	var center := (start + finish) * 0.5
	var web := Line2D.new()
	web.width = 2.0
	web.default_color = Color(0.78, 0.84, 1.0, 0.52)
	web.points = PackedVector2Array([start, center + Vector2(0, 12), finish])
	web.z_index = -1
	add_child(web)
	for fraction in [0.25, 0.5, 0.75]:
		var anchor := start.lerp(finish, float(fraction))
		var strand := Line2D.new()
		strand.width = 1.0
		strand.default_color = Color(0.82, 0.88, 1.0, 0.42)
		strand.points = PackedVector2Array([center, anchor])
		strand.z_index = -1
		add_child(strand)

func _create_gear(position: Vector2, radius: float, rotation_speed: float) -> void:
	var gear := Node2D.new()
	gear.position = position
	gear.z_index = 3
	gear.set_meta("rotation_speed", rotation_speed)
	add_child(gear)
	gear_nodes.append(gear)
	var ring := Line2D.new()
	ring.width = 5.0
	ring.default_color = Color(0.72, 0.48, 0.18, 0.9)
	ring.points = _circle_points(radius, 20, true)
	gear.add_child(ring)
	for index in range(8):
		var spoke := Line2D.new()
		spoke.width = 4.0
		spoke.default_color = Color(0.62, 0.4, 0.16, 0.9)
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
		spoke.points = PackedVector2Array([direction * radius * 0.28, direction * radius * 1.18])
		gear.add_child(spoke)

func _spawn_sparks(position: Vector2, color: Color, amount: int) -> void:
	var sparks := CPUParticles2D.new()
	sparks.amount = amount
	sparks.lifetime = 0.34
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 5.0
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	sparks.gravity = Vector2(0, 95)
	sparks.initial_velocity_min = 45.0
	sparks.initial_velocity_max = 115.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.8
	sparks.color = color
	sparks.position = position
	sparks.z_index = 6
	add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(0.65).timeout.connect(sparks.queue_free)

func _create_caption(text: String, position: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = Vector2(200, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.z_index = 7
	# Captions disabled by user request
	# add_child(label)
	return label

func _circle_points(radius: float, segments: int, close_loop: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := segments + 1 if close_loop else segments
	for index in range(count):
		var angle := TAU * float(index % segments) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points
