extends Node2D

const GEM_SCENE: PackedScene = preload("res://scenes/entities/collectibles/gems/gem.tscn")
const GEM_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/stats/StatRessources.png")
const MINECART_TEXTURE: Texture2D = preload("res://character_sprites/minecart_spritesheet_25d.png")
const PEON_TEXTURE: Texture2D = preload("res://character_sprites/peon_walk_spritesheet_25d.png")

const VEIN_POSITION := Vector2(-390.0, 54.0)
const RECEIVER_POSITION := Vector2(-292.0, 54.0)
const DIG_RADIUS := 78.0
const RECEIVER_RADIUS := 86.0
const LOST_GEM_RESET_TIME := 24.0
const DELIVERY_DURATION := 4.0

enum PracticeState { VEIN_READY, GEM_ACTIVE, DELIVERY }

var world: Node2D
var player: CharacterBody2D
var state := PracticeState.VEIN_READY
var dig_progress := 0.0
var practice_gem: Node2D
var loose_gem_timer := 0.0
var delivery_timer := 0.0
var receiver_registered := false

var vein_root: Node2D
var vein_body: StaticBody2D
var vein_collision: CollisionShape2D
var vein_block: Polygon2D
var vein_crystal: Sprite2D
var crack_lines: Line2D
var progress_back: Line2D
var progress_fill: Line2D
var vein_label: Label
var hint_label: Label
var cart_sprite: Sprite2D
var peon_sprite: Sprite2D
var peon_gem: Sprite2D
var platform_glow: Polygon2D
var cart_path := PackedVector2Array()
var cart_path_distances: Array[float] = []
var cart_path_length := 0.0

func _ready() -> void:
	world = get_parent() as Node2D
	if world == null:
		queue_free()
		return
	player = world.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		queue_free()
		return
	name = "StrongholdPracticeYard"
	z_index = 9
	process_priority = 310
	_build_station()
	_set_state(PracticeState.VEIN_READY)

func _exit_tree() -> void:
	_unregister_receiver()
	_cleanup_practice_gem()

func _process(delta: float) -> void:
	if world == null or player == null or not is_instance_valid(world) or not is_instance_valid(player):
		queue_free()
		return
	if not bool(world.get_meta("single_player_hub_active", false)):
		queue_free()
		return
	match state:
		PracticeState.VEIN_READY:
			_process_vein(delta)
		PracticeState.GEM_ACTIVE:
			_process_active_gem(delta)
		PracticeState.DELIVERY:
			_process_delivery(delta)
	_update_hint()

func load_gem(gem: Node, carrier: Node = null) -> bool:
	if state != PracticeState.GEM_ACTIVE or gem == null or not is_instance_valid(gem):
		return false
	if not bool(gem.get_meta("stronghold_practice_gem", false)):
		return false
	if carrier != null and carrier != player:
		return false
	if gem.has_method("untether"):
		gem.call("untether")
	practice_gem = null
	gem.queue_free()
	_unregister_receiver()
	_set_state(PracticeState.DELIVERY)
	return true

func get_practice_vein_position() -> Vector2:
	return vein_root.global_position if vein_root != null else VEIN_POSITION

func get_practice_receiver_position() -> Vector2:
	return RECEIVER_POSITION

func get_practice_state_name() -> String:
	match state:
		PracticeState.VEIN_READY:
			return "vein_ready"
		PracticeState.GEM_ACTIVE:
			return "gem_active"
		_:
			return "delivery"

func _process_vein(delta: float) -> void:
	var near_vein: bool = player.global_position.distance_to(get_practice_vein_position()) <= DIG_RADIUS
	if near_vein and _is_pressing_toward_vein():
		dig_progress = minf(1.0, dig_progress + delta / _current_dig_duration())
		_update_dig_visuals()
		if dig_progress >= 1.0:
			_break_practice_vein()
	else:
		dig_progress = maxf(0.0, dig_progress - delta * 1.8)
		_update_dig_visuals()

func _is_pressing_toward_vein() -> bool:
	var player_number := maxi(1, int(player.get("player_id")))
	var input_direction := Vector2(
		Input.get_axis("p%d_left" % player_number, "p%d_right" % player_number),
		Input.get_axis("p%d_up" % player_number, "p%d_down" % player_number)
	)
	if input_direction.length_squared() < 0.04:
		return false
	var toward_vein := player.global_position.direction_to(get_practice_vein_position())
	return input_direction.normalized().dot(toward_vein) >= 0.45

func _process_active_gem(delta: float) -> void:
	if practice_gem == null or not is_instance_valid(practice_gem):
		_set_state(PracticeState.VEIN_READY)
		return
	var tethered: Variant = practice_gem.get("tethered_to")
	if tethered == player:
		loose_gem_timer = 0.0
	else:
		loose_gem_timer += delta
		if practice_gem.global_position.distance_to(VEIN_POSITION) > 620.0 or loose_gem_timer >= LOST_GEM_RESET_TIME:
			_cleanup_practice_gem()
			_set_state(PracticeState.VEIN_READY)
			return
	_update_receiver_registration(tethered == player)

func _process_delivery(delta: float) -> void:
	delivery_timer += delta
	var normalized := clampf(delivery_timer / DELIVERY_DURATION, 0.0, 1.0)
	var peon_phase := clampf(normalized / 0.38, 0.0, 1.0)
	peon_sprite.position = RECEIVER_POSITION.lerp(VEIN_POSITION + Vector2(44.0, 8.0), peon_phase)
	peon_gem.visible = normalized < 0.44
	peon_gem.position = peon_sprite.position + Vector2(0.0, -28.0)
	var cart_phase := clampf((normalized - 0.18) / 0.70, 0.0, 1.0)
	cart_sprite.position = _sample_cart_path(cart_phase)
	_animate_worker_sprites(delta)
	if delivery_timer >= DELIVERY_DURATION:
		_spawn_reset_burst()
		_set_state(PracticeState.VEIN_READY)

func _set_state(next_state: PracticeState) -> void:
	state = next_state
	match state:
		PracticeState.VEIN_READY:
			dig_progress = 0.0
			if vein_collision != null:
				vein_collision.set_deferred("disabled", false)
			loose_gem_timer = 0.0
			delivery_timer = 0.0
			vein_root.visible = true
			cart_sprite.position = RECEIVER_POSITION
			peon_sprite.position = RECEIVER_POSITION + Vector2(-48.0, 8.0)
			peon_gem.visible = false
			platform_glow.color = Color(0.18, 0.42, 0.58, 0.22)
			_unregister_receiver()
			_update_dig_visuals()
		PracticeState.GEM_ACTIVE:
			vein_root.visible = false
			if vein_collision != null:
				vein_collision.set_deferred("disabled", true)
			loose_gem_timer = 0.0
			platform_glow.color = Color(0.22, 0.86, 1.0, 0.34)
		PracticeState.DELIVERY:
			vein_root.visible = false
			if vein_collision != null:
				vein_collision.set_deferred("disabled", true)
			delivery_timer = 0.0
			platform_glow.color = Color(1.0, 0.66, 0.18, 0.48)
			peon_sprite.position = RECEIVER_POSITION + Vector2(-48.0, 8.0)
			peon_gem.visible = true

func _break_practice_vein() -> void:
	_spawn_break_burst()
	var gem := GEM_SCENE.instantiate() as Node2D
	gem.name = "DensePracticeGem"
	gem.set_meta("stronghold_practice_gem", true)
	gem.set_meta("practice_carry_weight", _practice_carry_weight())
	gem.set_meta("tutorial_emphasis", true)
	gem.position = VEIN_POSITION + Vector2(0.0, -12.0)
	world.add_child(gem)
	if gem.has_method("set_tutorial_emphasis"):
		gem.call("set_tutorial_emphasis", true)
	practice_gem = gem
	_set_state(PracticeState.GEM_ACTIVE)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx != null and sound_fx.has_method("play_block_break"):
		sound_fx.call("play_block_break", true)

func _practice_carry_weight() -> int:
	var allowance := 1
	if player.has_method("get_free_carry_allowance"):
		allowance = maxi(1, int(player.call("get_free_carry_allowance")))
	return allowance + 1

func _current_dig_duration() -> float:
	var duration := maxf(0.12, float(player.get("base_dig_time")))
	var rpg := player.get_node_or_null("HeroRPGController")
	if rpg != null and rpg.has_method("get_dig_time_multiplier"):
		duration *= float(rpg.call("get_dig_time_multiplier"))
	else:
		duration *= pow(0.975, maxi(0, int(player.get("agility")) - 1))
	if player.has_method("_get_shaman_dig_time_multiplier"):
		duration *= float(player.call("_get_shaman_dig_time_multiplier"))
	if str(player.get("current_hero_name")) == "Druid" and bool(player.get("druid_mole_active")):
		duration *= 0.55
	var hardness := 1.0
	if player.has_method("get_block_hardness_multiplier"):
		hardness = float(player.call("get_block_hardness_multiplier", 2))
	if rpg != null and rpg.has_method("get_mining_force_multiplier"):
		hardness *= float(rpg.call("get_mining_force_multiplier", 2))
	return clampf(duration * hardness, 0.18, 2.8)

func _update_receiver_registration(is_carried: bool) -> void:
	var should_register := is_carried and player.global_position.distance_to(RECEIVER_POSITION) <= RECEIVER_RADIUS
	if should_register and not receiver_registered:
		player.call("add_nearby_gem", self)
		receiver_registered = true
	elif not should_register and receiver_registered:
		_unregister_receiver()

func _unregister_receiver() -> void:
	if receiver_registered and player != null and is_instance_valid(player) and player.has_method("remove_nearby_gem"):
		player.call("remove_nearby_gem", self)
	receiver_registered = false

func _cleanup_practice_gem() -> void:
	if player != null and is_instance_valid(player):
		var carried_value: Variant = player.get("carried_gems")
		if carried_value is Array and practice_gem != null:
			(carried_value as Array).erase(practice_gem)
	if practice_gem != null and is_instance_valid(practice_gem):
		practice_gem.queue_free()
	practice_gem = null

func _update_hint() -> void:
	if hint_label == null or player == null:
		return
	match state:
		PracticeState.VEIN_READY:
			var near: bool = player.global_position.distance_to(get_practice_vein_position()) <= DIG_RADIUS
			var seconds: float = _current_dig_duration()
			hint_label.text = ("HOLD TOWARD VEIN • %.2fs dense-stone test" % seconds) if near else "PRACTICE VEIN • Test mining speed"
		PracticeState.GEM_ACTIVE:
			var carried: bool = practice_gem != null and is_instance_valid(practice_gem) and practice_gem.get("tethered_to") == player
			if carried:
				var penalty := int(round(float(player.call("get_weight_penalty")) * 100.0)) if player.has_method("get_weight_penalty") else 0
				var drop_action := "DROP AT CART • E / B" if player.global_position.distance_to(RECEIVER_POSITION) <= RECEIVER_RADIUS else "DENSE GEM • %d%% SLOW • Carry it to the cart" % penalty
				hint_label.text = drop_action
			else:
				hint_label.text = "PICK UP • Dense gem simulates one overload slot"
		PracticeState.DELIVERY:
			hint_label.text = "TEST PEON RETURNING GEM • No currency gained"

func _build_station() -> void:
	_build_vein()
	_build_receiver()
	_build_cart_path()

func _build_vein() -> void:
	vein_root = Node2D.new()
	vein_root.name = "PracticeVein"
	vein_root.position = VEIN_POSITION
	add_child(vein_root)

	vein_body = StaticBody2D.new()
	vein_body.name = "PracticeVeinCollision"
	vein_body.collision_layer = 1
	vein_body.collision_mask = 0
	vein_root.add_child(vein_body)
	vein_collision = CollisionShape2D.new()
	var vein_shape := RectangleShape2D.new()
	vein_shape.size = Vector2(58.0, 58.0)
	vein_collision.shape = vein_shape
	vein_body.add_child(vein_collision)

	var shadow := Polygon2D.new()
	shadow.polygon = _rectangle_points(Vector2(60.0, 58.0))
	shadow.position = Vector2(4.0, 7.0)
	shadow.color = Color(0.01, 0.015, 0.025, 0.56)
	vein_root.add_child(shadow)

	vein_block = Polygon2D.new()
	vein_block.polygon = _rectangle_points(Vector2(58.0, 58.0))
	vein_block.color = Color(0.17, 0.10, 0.25, 1.0)
	vein_root.add_child(vein_block)

	var edge := Line2D.new()
	edge.width = 3.0
	edge.default_color = Color(0.55, 0.33, 0.76, 1.0)
	edge.points = _rectangle_loop(Vector2(58.0, 58.0))
	vein_root.add_child(edge)

	vein_crystal = Sprite2D.new()
	vein_crystal.texture = GEM_TEXTURE
	vein_crystal.scale = Vector2(0.92, 0.92)
	vein_crystal.position = Vector2(0.0, -3.0)
	vein_crystal.modulate = Color(0.62, 0.94, 1.0, 1.0)
	vein_root.add_child(vein_crystal)

	crack_lines = Line2D.new()
	crack_lines.width = 2.0
	crack_lines.default_color = Color(0.88, 0.72, 1.0, 0.0)
	crack_lines.points = PackedVector2Array([Vector2(-24, -18), Vector2(-8, -5), Vector2(-20, 8), Vector2(-2, 2), Vector2(8, 22), Vector2(10, 4), Vector2(25, -7)])
	vein_root.add_child(crack_lines)

	progress_back = Line2D.new()
	progress_back.width = 7.0
	progress_back.default_color = Color(0.02, 0.03, 0.05, 0.92)
	progress_back.points = PackedVector2Array([Vector2(-28.0, 38.0), Vector2(28.0, 38.0)])
	vein_root.add_child(progress_back)
	progress_fill = Line2D.new()
	progress_fill.width = 4.0
	progress_fill.default_color = Color(0.28, 0.92, 1.0, 1.0)
	progress_fill.points = PackedVector2Array([Vector2(-27.0, 38.0), Vector2(-27.0, 38.0)])
	vein_root.add_child(progress_fill)

	vein_label = _make_label("PRACTICE VEIN", VEIN_POSITION + Vector2(-54.0, -57.0), Vector2(108.0, 20.0), 9, Color(0.52, 0.94, 1.0, 1.0))

func _build_receiver() -> void:
	platform_glow = Polygon2D.new()
	platform_glow.name = "PracticeCartPlatform"
	platform_glow.position = RECEIVER_POSITION
	platform_glow.polygon = PackedVector2Array([Vector2(-44, -24), Vector2(44, -24), Vector2(52, 18), Vector2(-52, 18)])
	platform_glow.color = Color(0.18, 0.42, 0.58, 0.22)
	add_child(platform_glow)

	var platform_edge := Line2D.new()
	platform_edge.width = 3.0
	platform_edge.default_color = Color(0.42, 0.72, 0.82, 0.88)
	platform_edge.points = PackedVector2Array([RECEIVER_POSITION + Vector2(-44, -24), RECEIVER_POSITION + Vector2(44, -24), RECEIVER_POSITION + Vector2(52, 18), RECEIVER_POSITION + Vector2(-52, 18), RECEIVER_POSITION + Vector2(-44, -24)])
	add_child(platform_edge)

	cart_sprite = Sprite2D.new()
	cart_sprite.name = "PracticeMinecart"
	cart_sprite.texture = MINECART_TEXTURE
	cart_sprite.hframes = 8
	cart_sprite.vframes = 8
	cart_sprite.frame_coords = Vector2i(0, 1)
	cart_sprite.scale = Vector2(0.68, 0.68)
	cart_sprite.position = RECEIVER_POSITION
	cart_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cart_sprite.z_index = 3
	add_child(cart_sprite)

	peon_sprite = Sprite2D.new()
	peon_sprite.name = "PracticePeon"
	peon_sprite.texture = PEON_TEXTURE
	peon_sprite.hframes = 8
	peon_sprite.vframes = 8
	peon_sprite.frame_coords = Vector2i(0, 1)
	peon_sprite.scale = Vector2(0.62, 0.62)
	peon_sprite.position = RECEIVER_POSITION + Vector2(-48.0, 8.0)
	peon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	peon_sprite.z_index = 4
	add_child(peon_sprite)

	peon_gem = Sprite2D.new()
	peon_gem.texture = GEM_TEXTURE
	peon_gem.scale = Vector2(0.42, 0.42)
	peon_gem.visible = false
	peon_gem.z_index = 5
	add_child(peon_gem)

	_make_label("CART + PEON", RECEIVER_POSITION + Vector2(-52.0, -57.0), Vector2(104.0, 20.0), 9, Color(1.0, 0.72, 0.28, 1.0))
	hint_label = _make_label("PRACTICE VEIN • Test mining speed", Vector2(-445.0, 112.0), Vector2(252.0, 38.0), 11, Color(0.88, 0.94, 1.0, 1.0))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_cart_path() -> void:
	cart_path = PackedVector2Array([
		RECEIVER_POSITION,
		RECEIVER_POSITION + Vector2(35.0, -34.0),
		VEIN_POSITION + Vector2(38.0, -38.0),
		VEIN_POSITION + Vector2(-12.0, 26.0),
		RECEIVER_POSITION + Vector2(-16.0, 30.0),
		RECEIVER_POSITION,
	])
	cart_path_distances.clear()
	cart_path_length = 0.0
	cart_path_distances.append(0.0)
	var rail := Line2D.new()
	rail.width = 3.0
	rail.default_color = Color(0.48, 0.50, 0.54, 0.72)
	rail.points = cart_path
	rail.z_index = -1
	add_child(rail)
	for index in range(cart_path.size() - 1):
		cart_path_length += cart_path[index].distance_to(cart_path[index + 1])
		cart_path_distances.append(cart_path_length)

func _sample_cart_path(normalized: float) -> Vector2:
	if cart_path.size() < 2 or cart_path_length <= 0.0:
		return RECEIVER_POSITION
	var target_distance := clampf(normalized, 0.0, 1.0) * cart_path_length
	for index in range(cart_path.size() - 1):
		var start_distance: float = cart_path_distances[index]
		var end_distance: float = cart_path_distances[index + 1]
		if target_distance <= end_distance:
			var segment_ratio := (target_distance - start_distance) / maxf(0.001, end_distance - start_distance)
			return cart_path[index].lerp(cart_path[index + 1], segment_ratio)
	return cart_path[cart_path.size() - 1]

func _animate_worker_sprites(delta: float) -> void:
	var frame := int(floor(delivery_timer * 10.0)) % 8
	peon_sprite.frame_coords = Vector2i(frame, 1 if peon_sprite.position.x <= RECEIVER_POSITION.x else 5)
	cart_sprite.frame_coords = Vector2i(int(floor(delivery_timer * 8.0)) % 8, 1)
	var _unused_delta := delta

func _update_dig_visuals() -> void:
	if vein_root == null:
		return
	var wobble := sin(Time.get_ticks_msec() * 0.035) * dig_progress * 2.0
	vein_root.rotation = deg_to_rad(wobble)
	vein_root.scale = Vector2.ONE * (1.0 + dig_progress * 0.06)
	crack_lines.default_color.a = clampf(dig_progress * 1.15, 0.0, 1.0)
	progress_fill.points = PackedVector2Array([Vector2(-27.0, 38.0), Vector2(-27.0 + 54.0 * dig_progress, 38.0)])
	vein_crystal.modulate = Color(0.62 + dig_progress * 0.38, 0.94, 1.0, 1.0)

func _spawn_break_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.amount = 24
	burst.lifetime = 0.42
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 8.0
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2(0, 100)
	burst.initial_velocity_min = 42.0
	burst.initial_velocity_max = 115.0
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 3.2
	burst.color = Color(0.45, 0.88, 1.0, 0.96)
	burst.position = VEIN_POSITION
	burst.z_index = 8
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.7).timeout.connect(burst.queue_free)

func _spawn_reset_burst() -> void:
	var pulse := Polygon2D.new()
	pulse.position = VEIN_POSITION
	pulse.polygon = _circle_points(12.0, 16)
	pulse.color = Color(0.45, 0.95, 1.0, 0.72)
	pulse.z_index = 8
	add_child(pulse)
	var tween := pulse.create_tween().set_parallel(true)
	tween.tween_property(pulse, "scale", Vector2(4.5, 4.5), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(pulse, "modulate:a", 0.0, 0.34)
	tween.finished.connect(pulse.queue_free)

func _make_label(text_value: String, position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.96))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 9
	add_child(label)
	return label

func _rectangle_points(size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])

func _rectangle_loop(size: Vector2) -> PackedVector2Array:
	var points := _rectangle_points(size)
	points.append(points[0])
	return points

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / float(segments)) * radius)
	return points
