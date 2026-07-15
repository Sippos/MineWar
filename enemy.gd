extends CharacterBody2D

enum EnemyType { RAT, SPIDER, BAT, TROGG, ORC }

const ENEMY_TEXTURES = {
	EnemyType.RAT: preload("res://assets/sprites/enemies/rat/rat_walk_pixelart_spritesheet.png"),
	EnemyType.SPIDER: preload("res://character_sprites/spider_walk_spritesheet.png"),
	EnemyType.BAT: preload("res://character_sprites/bat_fly_spritesheet.png"),
	EnemyType.TROGG: preload("res://character_sprites/trogg_walk_spritesheet.png"),
	EnemyType.ORC: preload("res://character_sprites/orc_walk_pixelart_spritesheet.png")
}
const BOSS_TEXTURE = preload("res://character_sprites/mech_walk_pixelart_spritesheet.png")
const HEALTH_BAR_NEAR_DISTANCE := 170.0
const HEALTH_BAR_HOLD_TIME := 2.8
const HEALTH_BAR_FADE_SPEED := 7.5
const HEALTH_BAR_VALUE_SPEED := 18.0
const HEALTH_BAR_LAG_SPEED := 4.5

var enemy_type: EnemyType = EnemyType.RAT
var speed = 80.0
var damage = 10
var health = 50
var max_health = 50
var gold_drop = 10
var xp_drop = 10
var is_boss_enemy = false
var health_bar_hold_timer := 0.0
var sprite_rest_scale := Vector2.ONE
var sprite_rest_position := Vector2.ZERO
var hit_reaction_tween: Tween

@onready var world = get_parent()
@onready var tile_map = world.get_node("BlockLayer")
@onready var base = world.get_node("Base")
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar_container: Control = $HealthBarContainer
@onready var health_bar: ProgressBar = $HealthBarContainer/Health
@onready var damage_lag_bar: ProgressBar = $HealthBarContainer/DamageLag

var path: Array[Vector2] = []
var current_path_index = 0
var target_base_cell = Vector2i(0, -1)

var path_timer = 0.0
var walk_timer = 0.0
var current_anim_row = 0
var attack_cooldown_timer = 0.0

func _ready():
	sprite_rest_scale = sprite.scale
	sprite_rest_position = sprite.position
	_set_health_bar_values(true)
	health_bar_container.visible = false
	recalculate_path()

func initialize(wave_number: int, is_boss: bool, e_type: int = EnemyType.RAT) -> void:
	is_boss_enemy = is_boss
	enemy_type = e_type as EnemyType
	
	var base_hp = 20
	var base_dmg = 2
	var base_speed = 70.0
	var base_xp = 5
	var base_gold = 3
	var enemy_texture: Texture2D = ENEMY_TEXTURES[EnemyType.RAT]
	
	if is_boss:
		base_hp = 500
		base_dmg = 30
		base_speed = 60.0
		base_xp = 250
		base_gold = 150
		enemy_texture = BOSS_TEXTURE
	else:
		match enemy_type:
			EnemyType.RAT:
				base_hp = 20; base_dmg = 2; base_speed = 70.0; base_xp = 5; base_gold = 3
				enemy_texture = ENEMY_TEXTURES[EnemyType.RAT]
			EnemyType.SPIDER:
				base_hp = 35; base_dmg = 4; base_speed = 75.0; base_xp = 10; base_gold = 6
				enemy_texture = ENEMY_TEXTURES[EnemyType.SPIDER]
			EnemyType.BAT:
				base_hp = 25; base_dmg = 5; base_speed = 95.0; base_xp = 12; base_gold = 8
				enemy_texture = ENEMY_TEXTURES[EnemyType.BAT]
			EnemyType.TROGG:
				base_hp = 60; base_dmg = 7; base_speed = 50.0; base_xp = 15; base_gold = 12
				enemy_texture = ENEMY_TEXTURES[EnemyType.TROGG]
			EnemyType.ORC:
				base_hp = 80; base_dmg = 10; base_speed = 60.0; base_xp = 25; base_gold = 20
				enemy_texture = ENEMY_TEXTURES[EnemyType.ORC]
				
	# Scale by wave
	health = int(base_hp * (1.0 + wave_number * 0.2))
	max_health = health
	damage = int(base_dmg + wave_number * 1.5)
	speed = base_speed * randf_range(0.9, 1.1)
	gold_drop = int(base_gold + wave_number * 0.5)
	xp_drop = int(base_xp + wave_number * 1.0)
	
	if sprite:
		sprite.texture = enemy_texture
		if is_boss:
			sprite.scale = Vector2(2.0, 2.0)
			sprite.modulate = Color.WHITE
			health_bar_container.scale = Vector2(1.35, 1.35)
			Global.mark_monster_seen("Mech")
		else:
			var monster_name = EnemyType.keys()[enemy_type].capitalize()
			Global.mark_monster_seen(monster_name)
		sprite_rest_scale = sprite.scale
		sprite_rest_position = sprite.position
	_set_health_bar_values(true)
	health_bar_hold_timer = HEALTH_BAR_HOLD_TIME if is_boss_enemy else 0.0

func recalculate_path():
	var start_cell = tile_map.local_to_map(tile_map.to_local(global_position))
	if world.astar.is_in_bounds(start_cell.x, start_cell.y) and world.astar.is_in_bounds(target_base_cell.x, target_base_cell.y):
		var id_path = world.astar.get_id_path(start_cell, target_base_cell)
		path.clear()
		for id in id_path:
			path.append(tile_map.to_global(tile_map.map_to_local(id)))
		current_path_index = 0

func _physics_process(delta: float):
	_update_health_bar(delta)
	path_timer += delta
	if path_timer > 1.0:
		recalculate_path()
		path_timer = 0.0
	
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	
	var is_attacking_base = false
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider == base:
			is_attacking_base = true
	
	if base and global_position.distance_to(base.global_position) < 70.0:
		is_attacking_base = true

	if is_attacking_base:
		velocity = Vector2.ZERO
		if sprite:
			walk_timer = 0.0
			sprite.frame = current_anim_row * 8
		
		if attack_cooldown_timer <= 0.0:
			if base.has_method("take_damage"):
				base.take_damage(damage)
			if "spikes_level" in base and base.spikes_level > 0:
				take_damage(15 * base.spikes_level)
			attack_cooldown_timer = 1.0
	elif path.size() > 0 and current_path_index < path.size():
		var target_pos = path[current_path_index]
		var dir = (target_pos - global_position).normalized()
		var dist = global_position.distance_to(target_pos)
		
		if dist < 15.0:
			current_path_index += 1
		else:
			velocity = dir * speed
			move_and_slide()
			
			# Animation logic
			var angle = dir.angle()
			var PI_8 = PI / 8.0
			if angle > -PI_8 and angle <= PI_8:
				current_anim_row = 6 # Right
			elif angle > PI_8 and angle <= 3*PI_8:
				current_anim_row = 7 # Down-Right
			elif angle > 3*PI_8 and angle <= 5*PI_8:
				current_anim_row = 0 # Down
			elif angle > 5*PI_8 and angle <= 7*PI_8:
				current_anim_row = 1 # Down-Left
			elif angle > 7*PI_8 or angle <= -7*PI_8:
				current_anim_row = 2 # Left
			elif angle > -7*PI_8 and angle <= -5*PI_8:
				current_anim_row = 3 # Up-Left
			elif angle > -5*PI_8 and angle <= -3*PI_8:
				current_anim_row = 4 # Up
			elif angle > -3*PI_8 and angle <= -PI_8:
				current_anim_row = 5 # Up-Right
				
			if sprite:
				walk_timer += delta * 12.0
				sprite.frame = current_anim_row * 8 + (int(walk_timer) % 8)
			
			for i in get_slide_collision_count():
				var col = get_slide_collision(i)
				var collider = col.get_collider()
				if collider.name == "Player":
					if collider.has_method("take_damage"):
						collider.take_damage(damage)
	else:
		recalculate_path()
		if sprite:
			walk_timer = 0.0
			sprite.frame = current_anim_row * 8

func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = max(0, health - amount)
	health_bar_hold_timer = HEALTH_BAR_HOLD_TIME
	_set_health_bar_values(false)
	health_bar_container.visible = true
	health_bar_container.modulate.a = 1.0
	_play_hit_reaction()
	if health <= 0:
		die()

func _set_health_bar_values(snap: bool) -> void:
	if not health_bar or not damage_lag_bar:
		return
	health_bar.max_value = max_health
	damage_lag_bar.max_value = max_health
	if snap:
		health_bar.value = health
		damage_lag_bar.value = health

func _update_health_bar(delta: float) -> void:
	if not health_bar_container:
		return
	var nearby_or_targeted := _is_player_near_or_targeted()
	if is_boss_enemy:
		health_bar_hold_timer = HEALTH_BAR_HOLD_TIME
	elif nearby_or_targeted:
		health_bar_hold_timer = max(health_bar_hold_timer, 0.35)
	else:
		health_bar_hold_timer = max(0.0, health_bar_hold_timer - delta)
	var should_show := is_boss_enemy or nearby_or_targeted or health_bar_hold_timer > 0.0
	var target_alpha := 1.0 if should_show else 0.0
	health_bar_container.modulate.a = move_toward(
		health_bar_container.modulate.a,
		target_alpha,
		delta * HEALTH_BAR_FADE_SPEED
	)
	health_bar_container.visible = should_show or health_bar_container.modulate.a > 0.02
	var health_weight := 1.0 - exp(-HEALTH_BAR_VALUE_SPEED * delta)
	var lag_weight := 1.0 - exp(-HEALTH_BAR_LAG_SPEED * delta)
	health_bar.value = lerpf(float(health_bar.value), float(health), health_weight)
	damage_lag_bar.value = lerpf(float(damage_lag_bar.value), float(health), lag_weight)

func _is_player_near_or_targeted() -> bool:
	if not is_instance_valid(world):
		return false
	for candidate in world.get_children():
		if not candidate is CharacterBody2D:
			continue
		if not str(candidate.name).begins_with("Player"):
			continue
		if global_position.distance_to(candidate.global_position) <= HEALTH_BAR_NEAR_DISTANCE:
			return true
		if candidate.get("currently_attacking_enemy") == self:
			return true
	return false

func _play_hit_reaction() -> void:
	if not sprite:
		return
	if hit_reaction_tween and hit_reaction_tween.is_running():
		hit_reaction_tween.kill()
	sprite.scale = sprite_rest_scale * Vector2(1.12, 0.90)
	sprite.position = sprite_rest_position + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
	sprite.modulate = Color(2.4, 2.4, 2.4, 1.0)
	hit_reaction_tween = create_tween()
	hit_reaction_tween.set_parallel(true)
	hit_reaction_tween.tween_property(sprite, "scale", sprite_rest_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hit_reaction_tween.tween_property(sprite, "position", sprite_rest_position, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hit_reaction_tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)
	_spawn_hit_burst()

func _spawn_hit_burst() -> void:
	if not is_instance_valid(world):
		return
	var burst := CPUParticles2D.new()
	burst.amount = 9
	burst.lifetime = 0.24
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 7.0
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2(0, 85)
	burst.initial_velocity_min = 34.0
	burst.initial_velocity_max = 72.0
	burst.scale_amount_min = 1.2
	burst.scale_amount_max = 2.8
	burst.color = Color(1.0, 0.56, 0.18, 0.92)
	burst.global_position = global_position + Vector2(0, 4)
	burst.z_index = 25
	world.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.55).timeout.connect(burst.queue_free)

func die() -> void:
	var coin_scene = preload("res://scenes/entities/collectibles/drops/coin_drop.tscn")
	var coin = coin_scene.instantiate()
	coin.gold_value = gold_drop
	coin.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
	world.call_deferred("add_child", coin)
	
	var xp_scene = preload("res://scenes/entities/collectibles/drops/xp_drop.tscn")
	var xp = xp_scene.instantiate()
	xp.xp_value = xp_drop
	xp.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
	world.call_deferred("add_child", xp)
		
	if is_boss_enemy:
		Global.unlock_hero("Mech")
	
	queue_free()
