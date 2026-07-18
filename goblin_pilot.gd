extends CharacterBody2D

const COMBAT_FEEDBACK := preload("res://combat_feedback.gd")
const PROJECTILE_SCRIPT := preload("res://enemy_projectile.gd")

var speed := 158.0
var damage := 5
var health := 65
var max_health := 65
var gold_drop := 150
var xp_drop := 250
var is_boss_enemy := true
var attack_timer := 0.65
var walk_timer := 0.0
var zigzag_phase := 0.0
var world: Node2D
var base: Node2D
var health_background: Line2D
var health_fill: Line2D
var hit_tween: Tween
var sprite_rest_scale := Vector2.ONE

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	world = get_parent() as Node2D
	base = world.get_node_or_null("Base") as Node2D if world else null
	sprite_rest_scale = sprite.scale
	_create_health_bar()
	_update_health_bar()

func configure_from_mech(reward_gold: int, reward_xp: int, mech_damage: int) -> void:
	gold_drop = maxi(1, reward_gold)
	xp_drop = maxi(1, reward_xp)
	damage = clampi(int(ceil(float(mech_damage) * 0.42)), 3, 8)
	health = 65
	max_health = health
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if world == null or not is_instance_valid(world):
		queue_free()
		return
	attack_timer = maxf(attack_timer - delta, 0.0)
	zigzag_phase += delta * 5.5
	var player := _nearest_player()
	var desired := Vector2.ZERO
	if player:
		var distance := global_position.distance_to(player.global_position)
		if distance <= 205.0:
			var away := player.global_position.direction_to(global_position)
			desired = (away + away.orthogonal() * sin(zigzag_phase) * 0.92).normalized()
		else:
			desired = global_position.direction_to(base.global_position) if base else Vector2.RIGHT
		if attack_timer <= 0.0 and distance <= 330.0:
			_throw_bomb(player.global_position)
	else:
		desired = global_position.direction_to(base.global_position) if base else Vector2.RIGHT

	if base and global_position.distance_to(base.global_position) <= 72.0:
		desired = global_position.direction_to(base.global_position).orthogonal() * sin(zigzag_phase)
		if attack_timer <= 0.0:
			_throw_bomb(base.global_position)

	velocity = desired * speed
	move_and_slide()
	_update_animation(delta)

func _nearest_player() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for child in world.get_children():
		if not child is Node2D or not is_instance_valid(child):
			continue
		var candidate := child as Node2D
		if not str(candidate.name).begins_with("Player") or bool(candidate.get("is_dead")):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

func _throw_bomb(destination: Vector2) -> void:
	attack_timer = 1.55
	var projectile := PROJECTILE_SCRIPT.new()
	world.add_child(projectile)
	projectile.configure(
		world,
		global_position + Vector2(0, -10),
		destination,
		damage,
		300.0,
		46.0,
		false,
		Color(1.0, 0.52, 0.08, 1.0)
	)
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", sprite_rest_scale * Vector2(0.82, 1.18), 0.09)
	tween.tween_property(sprite, "scale", sprite_rest_scale, 0.16)

func _update_animation(delta: float) -> void:
	if velocity.length_squared() > 1.0:
		walk_timer += delta * 11.0
		sprite.frame = int(walk_timer) % 4
		sprite.flip_h = velocity.x < -2.0
	else:
		walk_timer = 0.0
		sprite.frame = 0

func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = maxi(0, health - amount)
	_update_health_bar()
	_play_hit_reaction()
	var feedback: Node = COMBAT_FEEDBACK.ensure(world)
	feedback.play_enemy_hit(global_position, Vector2.RIGHT, amount, health <= 0)
	if health <= 0:
		die()

func _play_hit_reaction() -> void:
	if hit_tween and hit_tween.is_running():
		hit_tween.kill()
	sprite.scale = sprite_rest_scale * Vector2(1.18, 0.82)
	sprite.modulate = Color(2.2, 2.2, 2.2, 1.0)
	hit_tween = sprite.create_tween().set_parallel(true)
	hit_tween.tween_property(sprite, "scale", sprite_rest_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hit_tween.tween_property(sprite, "modulate", Color(0.72, 1.0, 0.58, 1.0), 0.18)

func _create_health_bar() -> void:
	health_background = Line2D.new()
	health_background.width = 8.0
	health_background.default_color = Color(0.035, 0.04, 0.05, 0.95)
	health_background.points = PackedVector2Array([Vector2(-30, -34), Vector2(30, -34)])
	health_background.z_index = 30
	add_child(health_background)

	health_fill = Line2D.new()
	health_fill.width = 5.0
	health_fill.default_color = Color(0.35, 1.0, 0.22, 1.0)
	health_fill.z_index = 31
	add_child(health_fill)

func _update_health_bar() -> void:
	if health_fill == null:
		return
	var ratio := clampf(float(health) / maxf(1.0, float(max_health)), 0.0, 1.0)
	health_fill.points = PackedVector2Array([Vector2(-29, -34), Vector2(-29 + 58.0 * ratio, -34)])

func die() -> void:
	_spawn_rewards()
	MechUnlockPersistence.mark_defeated()
	if world and world.has_node("HUD"):
		var hud := world.get_node("HUD")
		if hud.has_method("show_notice"):
			hud.show_notice("GOBLIN PILOT DEFEATED — MECH HERO + WORKSHOP UNLOCKED!", 5.0)
	_spawn_defeat_burst()
	queue_free()

func _spawn_rewards() -> void:
	var coin_scene := preload("res://scenes/entities/collectibles/drops/coin_drop.tscn")
	var coin = coin_scene.instantiate()
	coin.gold_value = gold_drop
	coin.global_position = global_position + Vector2(-10, 4)
	world.call_deferred("add_child", coin)

	var xp_scene := preload("res://scenes/entities/collectibles/drops/xp_drop.tscn")
	var xp = xp_scene.instantiate()
	xp.xp_value = xp_drop
	xp.global_position = global_position + Vector2(10, 4)
	world.call_deferred("add_child", xp)

func _spawn_defeat_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.amount = 36
	burst.lifetime = 0.45
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 8.0
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2(0, 110)
	burst.initial_velocity_min = 55.0
	burst.initial_velocity_max = 145.0
	burst.scale_amount_min = 1.4
	burst.scale_amount_max = 3.8
	burst.color = Color(0.75, 1.0, 0.28, 0.95)
	burst.global_position = global_position
	burst.z_index = 26
	world.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.8).timeout.connect(burst.queue_free)
