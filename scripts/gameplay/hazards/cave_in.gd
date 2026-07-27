extends Node2D

const WARNING_DURATION := 2.5
const FALL_DURATION := 0.3
const DAMAGE := 50
const RADIUS := 120.0
const RUBBLE_RADIUS := 1 # 1 cell radius -> 3x3 rubble

var world: Node2D
var timer := 0.0
var phase := 0 # 0: Warning, 1: Falling, 2: Done

var decal: Sprite2D
var particles: CPUParticles2D
var boulders: Array[Sprite2D] = []

func _ready() -> void:
	z_index = 10
	
	# Create warning decal
	decal = Sprite2D.new()
	# Just draw a simple red circle or use an existing texture
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(128):
		for y in range(128):
			if Vector2(x - 64, y - 64).length() < 60:
				img.set_pixel(x, y, Color(1.0, 0.2, 0.1, 0.4))
	var tex := ImageTexture.create_from_image(img)
	decal.texture = tex
	decal.scale = Vector2((RADIUS * 2) / 128.0, (RADIUS * 2) / 128.0)
	add_child(decal)
	
	# Create dust particles
	particles = CPUParticles2D.new()
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(RADIUS, RADIUS)
	particles.direction = Vector2(0, 1)
	particles.gravity = Vector2(0, 400)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 150.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.3, 0.2, 0.1, 1.0)
	particles.amount = 40
	particles.position = Vector2(0, -300) # Start from above
	add_child(particles)

func _process(delta: float) -> void:
	timer += delta
	
	if phase == 0:
		decal.modulate.a = clampf(timer / WARNING_DURATION, 0.2, 0.8)
		# Rumble camera slightly during warning
		if timer > WARNING_DURATION - 1.0 and world != null:
			var player = world.get_node_or_null("Player")
			if player:
				var cam = player.get_node_or_null("Camera2D")
				if cam:
					cam.offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
		
		if timer >= WARNING_DURATION:
			phase = 1
			timer = 0.0
			particles.emitting = false
			_spawn_boulders()
			
	elif phase == 1:
		var t = timer / FALL_DURATION
		for b in boulders:
			var start_y: float = b.get_meta("start_y", -400.0)
			b.position.y = lerpf(start_y, 0.0, t * t) # Accelerate downwards
			b.scale = Vector2.ONE * lerpf(2.5, 1.0, t) # Shrink as they approach ground
			
		if timer >= FALL_DURATION:
			phase = 2
			_impact()

func _spawn_boulders() -> void:
	for i in range(5):
		var b := Sprite2D.new()
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for x in range(32):
			for y in range(32):
				if Vector2(x - 16, y - 16).length() < 14:
					img.set_pixel(x, y, Color(0.3, 0.3, 0.3, 1.0))
		var tex := ImageTexture.create_from_image(img)
		b.texture = tex
		b.position = Vector2(randf_range(-RADIUS/2, RADIUS/2), -400)
		b.set_meta("start_y", -400 + randf_range(-50, 50))
		add_child(b)
		boulders.append(b)

func _impact() -> void:
	decal.queue_free()
	
	# Massive camera shake
	if world != null:
		var player = world.get_node_or_null("Player")
		if player:
			var cam = player.get_node_or_null("Camera2D")
			if cam:
				var rest = Vector2.ZERO # Usually zero
				var shake = create_tween()
				shake.tween_property(cam, "offset", rest + Vector2(15, -15), 0.06)
				shake.tween_property(cam, "offset", rest + Vector2(-12, 10), 0.06)
				shake.tween_property(cam, "offset", rest + Vector2(8, -6), 0.06)
				shake.tween_property(cam, "offset", rest, 0.1)
				
		# Damage entities in radius
		var hit_count := 0
		if player and player.global_position.distance_to(global_position) <= RADIUS:
			if player.has_method("take_damage"):
				player.take_damage(DAMAGE)
				hit_count += 1
				
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) <= RADIUS:
				if enemy.has_method("take_damage"):
					enemy.take_damage(DAMAGE * 3) # Heavy damage to enemies
					hit_count += 1
		
		# Spawn Rubble
		if world.has_method("spawn_rubble"):
			world.spawn_rubble(global_position, RUBBLE_RADIUS)
			
	var fade = create_tween().set_parallel(true)
	for b in boulders:
		fade.tween_property(b, "modulate:a", 0.0, 0.5)
	fade.chain().tween_callback(self.queue_free)
