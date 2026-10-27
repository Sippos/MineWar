extends CharacterBody2D

const COMBAT_FEEDBACK := preload("res://combat_feedback.gd")
const ENEMY_COMBAT_BEHAVIOR := preload("res://enemy_combat_behavior.gd")

enum EnemyType { RAT, SPIDER, BAT, TROGG, ORC }

const ENEMY_TEXTURES = {
	EnemyType.RAT: preload("res://assets/sprites/enemies/rat/rat_walk_pixelart_spritesheet.png"),
	EnemyType.SPIDER: preload("res://character_sprites/spider_walk_spritesheet.png"),
	EnemyType.BAT: preload("res://character_sprites/bat_fly_spritesheet.png"),
	EnemyType.TROGG: preload("res://character_sprites/trogg_walk_spritesheet.png"),
	EnemyType.ORC: preload("res://character_sprites/orc_walk_pixelart_spritesheet.png")
}
const BOSS_TEXTURE = preload("res://character_sprites/mech_walk_pixelart_spritesheet.png")
const HEALTH_BAR_NEAR_DISTANCE := 115.0
const HEALTH_BAR_HOLD_TIME := 2.5
const HEALTH_BAR_FADE_SPEED := 6.5
const HEALTH_BAR_VALUE_SPEED := 24.0
const HEALTH_BAR_LAG_SPEED := 4.5
const DAMAGE_LAG_DELAY := 0.40
const PATH_REFRESH_INTERVAL := 1.25
const SEPARATION_RADIUS := 54.0
const SEPARATION_STRENGTH := 0.58
const OPEN_SPACE_LANE_STRENGTH := 0.16
const STUCK_CHECK_INTERVAL := 0.75
const STUCK_DISTANCE_THRESHOLD := 5.0

var enemy_type: EnemyType = EnemyType.RAT
var speed = 80.0
var damage = 10
var health = 50
var max_health = 50
var gold_drop = 10
var xp_drop = 10
var is_boss_enemy = false
var health_bar_hold_timer := 0.0
var damage_lag_delay_timer := 0.0
var burn_duration := 0.0
var burn_tick_timer := 0.0
var burn_tick_damage := 0
var burn_particles: CPUParticles2D
var _custom_status_badges: Dictionary = {}
var sprite_rest_scale := Vector2.ONE
var sprite_rest_position := Vector2.ZERO
var hit_reaction_tween: Tween
var emergence_tween: Tween
var emergence_timer := 0.0
var sleep_timer := 0.0
var sleep_particles: CPUParticles2D
var stored_collision_layer := 4
var lane_bias := 0.0
var lane_phase := 0.0
var last_topology_revision := -1
var stuck_check_timer := 0.0
var last_stuck_check_position := Vector2.ZERO
var combat_behavior: Node

@onready var world = get_parent()
@onready var tile_map = world.get_node("BlockLayer") if world and world.has_node("BlockLayer") else null
@onready var base = world.get_node("Base") if world and world.has_node("Base") else null
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar_container: Control = get_node_or_null("HealthBarContainer") as Control
@onready var health_bar: ProgressBar = get_node_or_null("HealthBarContainer/Health") as ProgressBar
@onready var damage_lag_bar: ProgressBar = get_node_or_null("HealthBarContainer/DamageLag") as ProgressBar
@onready var status_badge_row: HBoxContainer = get_node_or_null("HealthBarContainer/StatusBadgeRow") as HBoxContainer
@onready var chokepoint_badge: Label = get_node_or_null("HealthBarContainer/StatusBadgeRow/ChokepointBadge") as Label
@onready var burn_badge: Label = get_node_or_null("HealthBarContainer/StatusBadgeRow/BurnBadge") as Label
@onready var sleep_badge: Label = get_node_or_null("HealthBarContainer/StatusBadgeRow/SleepBadge") as Label
@onready var boss_badge: Label = get_node_or_null("HealthBarContainer/StatusBadgeRow/BossBadge") as Label

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
	lane_bias = randf_range(-1.0, 1.0)
	if absf(lane_bias) < 0.25:
		lane_bias = 0.25 if lane_bias >= 0.0 else -0.25
	lane_phase = randf_range(0.0, TAU)
	last_stuck_check_position = global_position
	_ensure_health_bar_nodes()
	_set_health_bar_values(true)
	if health_bar_container:
		health_bar_container.visible = is_boss_enemy
		health_bar_container.modulate.a = 1.0 if is_boss_enemy else 0.0
	combat_behavior = ENEMY_COMBAT_BEHAVIOR.new()
	combat_behavior.name = "CombatBehavior"
	add_child(combat_behavior)
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
	if wave_number == 1 and not is_boss and enemy_type == EnemyType.RAT:
		# Wave one is a combat lesson. It must create urgency without deleting the
		# base while the player is still learning that contact triggers attacks.
		health = 18
		max_health = health
		damage = 1
		speed = minf(speed, 60.0)
		gold_drop = maxi(gold_drop, 5)
		xp_drop = maxi(xp_drop, 15)
	elif not is_boss and wave_number <= 5:
		# Early waves should escalate visibly without deleting the base before the
		# player has time to leave the mine and react to the breach warning.
		var early_damage_cap: int = wave_number + 1
		damage = mini(damage, early_damage_cap)
	
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
	var collision_shape := $CollisionShape2D.shape as RectangleShape2D
	if collision_shape:
		collision_shape.size = Vector2(72, 72) if is_boss else Vector2(40, 40)
	_set_health_bar_values(true)
	health_bar_hold_timer = HEALTH_BAR_HOLD_TIME if is_boss_enemy else 0.0
	if combat_behavior and combat_behavior.has_method("configure"):
		combat_behavior.configure()

func recalculate_path():
	path.clear()
	if tile_map == null or not is_instance_valid(tile_map) or tile_map.tile_set == null:
		return
	if base != null and is_instance_valid(base):
		target_base_cell = tile_map.local_to_map(tile_map.to_local(base.global_position))
	var start_cell = tile_map.local_to_map(tile_map.to_local(global_position))
	if world != null and world.get("astar") != null:
		var astar: AStarGrid2D = world.astar
		if astar.is_in_bounds(target_base_cell.x, target_base_cell.y):
			# If starting inside or on edge of solid point, snap to nearest open cell
			if astar.is_in_bounds(start_cell.x, start_cell.y) and astar.is_point_solid(start_cell):
				var best_cell: Vector2i = start_cell
				var min_dist_sq: float = INF
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						var test_cell := Vector2i(start_cell.x + dx, start_cell.y + dy)
						if astar.is_in_bounds(test_cell.x, test_cell.y) and not astar.is_point_solid(test_cell):
							var d: float = (tile_map.map_to_local(test_cell) - tile_map.to_local(global_position)).length_squared()
							if d < min_dist_sq:
								min_dist_sq = d
								best_cell = test_cell
				if best_cell != start_cell:
					start_cell = best_cell
			if astar.is_in_bounds(start_cell.x, start_cell.y) and not astar.is_point_solid(start_cell):
				var id_path: Array[Vector2i] = astar.get_id_path(start_cell, target_base_cell)
				for id in id_path:
					path.append(tile_map.to_global(tile_map.map_to_local(id)))
				current_path_index = 0
	last_topology_revision = int(world.get("topology_revision")) if world != null and world.get("topology_revision") != null else last_topology_revision

func _physics_process(delta: float):
	_update_health_bar(delta)
	
	# Process Fire DoT ticks
	if burn_duration > 0.0:
		burn_duration = maxf(0.0, burn_duration - delta)
		burn_tick_timer -= delta
		if burn_tick_timer <= 0.0:
			burn_tick_timer = 0.5
			_apply_burn_tick(burn_tick_damage)
		if burn_particles:
			burn_particles.emitting = burn_duration > 0.0
		if burn_duration <= 0.0:
			if burn_particles:
				burn_particles.emitting = false
			_update_status_badges(0.0)
	if emergence_timer > 0.0:
		emergence_timer = maxf(emergence_timer - delta, 0.0)
		velocity = Vector2.ZERO
		if emergence_timer <= 0.0:
			collision_layer = stored_collision_layer
		return
		
	if sleep_timer > 0.0:
		sleep_timer -= delta
		velocity = Vector2.ZERO
		
		# Show sleep particles
		if sleep_particles == null:
			sleep_particles = CPUParticles2D.new()
			sleep_particles.direction = Vector2(0, -1)
			sleep_particles.gravity = Vector2(20, -50)
			sleep_particles.initial_velocity_min = 20.0
			sleep_particles.initial_velocity_max = 40.0
			sleep_particles.scale_amount_min = 3.0
			sleep_particles.scale_amount_max = 5.0
			sleep_particles.color = Color(0.8, 0.8, 1.0, 1.0)
			sleep_particles.lifetime = 1.0
			sleep_particles.amount = 4
			add_child(sleep_particles)
		else:
			sleep_particles.emitting = true
			
		if sleep_timer <= 0.0 and sleep_particles != null:
			sleep_particles.emitting = false
			
		return
	elif sleep_particles != null:
		sleep_particles.emitting = false

	path_timer += delta
	var world_revision := int(world.get("topology_revision")) if world != null and world.get("topology_revision") != null else last_topology_revision
	if world_revision != last_topology_revision:
		last_topology_revision = world_revision
		path_timer = PATH_REFRESH_INTERVAL
	
	if path_timer > PATH_REFRESH_INTERVAL:
		recalculate_path()
		path_timer = 0.0
	
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if combat_behavior and combat_behavior.has_method("process_combat") and bool(combat_behavior.process_combat(delta)):
		_update_stuck_tracking(delta, true)
		return
	
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
		_update_stuck_tracking(delta, true)
		if sprite:
			walk_timer = 0.0
			sprite.frame = current_anim_row * 8
		if attack_cooldown_timer <= 0.0:
			if base.has_method("take_damage"):
				var base_hit_damage := int(get_meta("linewars_leak_damage", damage))
				base.take_damage(base_hit_damage)
				if bool(get_meta("linewars_single_leak", false)):
					queue_free()
					return
			if "spikes_level" in base and base.spikes_level > 0:
				take_damage(15 * base.spikes_level)
			attack_cooldown_timer = 1.0
	elif base != null and tile_map != null and is_instance_valid(tile_map) and tile_map.tile_set != null:
		var current_cell = tile_map.local_to_map(tile_map.to_local(global_position))
		var dir := Vector2.ZERO
		var target_pos := Vector2.ZERO
		
		# Prefer Flow Field if available, otherwise follow AStar path
		var has_flow = world.get("flow_field") != null and world.flow_field.has(current_cell)
		if has_flow:
			dir = world.flow_field[current_cell]
		elif path.size() > 0 and current_path_index < path.size():
			target_pos = path[current_path_index]
			var target_delta := target_pos - global_position
			var dist := target_delta.length()
			if dist < 13.0:
				current_path_index += 1
				velocity = Vector2.ZERO
				_update_stuck_tracking(delta, false)
				return
			else:
				dir = target_delta / maxf(dist, 0.001)
		elif path.size() == 0 and not has_flow:
			recalculate_path()
		
		if dir != Vector2.ZERO:
			var in_chokepoint := bool(world.has_method("is_chokepoint_cell") and world.is_chokepoint_cell(current_cell))
			var open_factor: float = float(world.get_enemy_open_space_factor(global_position)) if world.has_method("get_enemy_open_space_factor") else 0.0
			var lateral: Vector2 = Vector2.ZERO
			var separation: Vector2 = Vector2.ZERO
			if in_chokepoint:
				# Funnel single-file through narrow tunnels without shoving into walls
				separation = _calculate_separation_velocity() * 0.15
			else:
				lateral = dir.orthogonal() * lane_bias * speed * OPEN_SPACE_LANE_STRENGTH * open_factor
				separation = _calculate_separation_velocity()
			velocity = dir * speed + lateral + separation
			var max_velocity: float = speed * 1.16
			if velocity.length() > max_velocity:
				velocity = velocity.normalized() * max_velocity
			move_and_slide()
			var movement_direction := velocity.normalized() if velocity.length_squared() > 0.01 else dir
			_update_walk_animation(movement_direction, delta)
			_damage_colliding_players()
		_update_stuck_tracking(delta, false)
	else:
		velocity = Vector2.ZERO
		recalculate_path()
		_update_stuck_tracking(delta, false)
		if sprite:
			walk_timer = 0.0
			sprite.frame = current_anim_row * 8

func begin_breach_emergence(duration: float = 0.55) -> void:
	emergence_timer = maxf(duration, 0.05)
	stored_collision_layer = collision_layer
	collision_layer = 0
	if not sprite:
		return
	if emergence_tween and emergence_tween.is_running():
		emergence_tween.kill()
	sprite.scale = sprite_rest_scale * 0.28
	sprite.position = sprite_rest_position + Vector2(0, 14)
	sprite.modulate = Color(1.8, 0.35, 0.18, 0.0)
	emergence_tween = create_tween().set_parallel(true)
	emergence_tween.tween_property(sprite, "scale", sprite_rest_scale, emergence_timer).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	emergence_tween.tween_property(sprite, "position", sprite_rest_position, emergence_timer).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	emergence_tween.tween_property(sprite, "modulate", Color.WHITE, emergence_timer * 0.72)

func _calculate_separation_velocity() -> Vector2:
	var force := Vector2.ZERO
	for other_value in get_tree().get_nodes_in_group("enemies"):
		var other := other_value as Node2D
		if other == null or other == self or not is_instance_valid(other):
			continue
		if world and not world.is_ancestor_of(other):
			continue
		var away := global_position - other.global_position
		var distance := away.length()
		if distance <= 0.001 or distance >= SEPARATION_RADIUS:
			continue
		force += away.normalized() * (1.0 - distance / SEPARATION_RADIUS)
	if force.length_squared() <= 0.001:
		return Vector2.ZERO
	return force.limit_length(1.0) * speed * SEPARATION_STRENGTH

func _update_stuck_tracking(delta: float, intentionally_stationary: bool) -> void:
	if intentionally_stationary:
		stuck_check_timer = 0.0
		last_stuck_check_position = global_position
		return
	stuck_check_timer += delta
	if stuck_check_timer < STUCK_CHECK_INTERVAL:
		return
	var moved_distance := global_position.distance_to(last_stuck_check_position)
	if moved_distance < STUCK_DISTANCE_THRESHOLD and path.size() > 0:
		lane_bias = -lane_bias
		recalculate_path()
	last_stuck_check_position = global_position
	stuck_check_timer = 0.0

func _update_walk_animation(direction: Vector2, delta: float) -> void:
	var angle := direction.angle()
	var pi_8 := PI / 8.0
	if angle > -pi_8 and angle <= pi_8:
		current_anim_row = 6
	elif angle > pi_8 and angle <= 3.0 * pi_8:
		current_anim_row = 7
	elif angle > 3.0 * pi_8 and angle <= 5.0 * pi_8:
		current_anim_row = 0
	elif angle > 5.0 * pi_8 and angle <= 7.0 * pi_8:
		current_anim_row = 1
	elif angle > 7.0 * pi_8 or angle <= -7.0 * pi_8:
		current_anim_row = 2
	elif angle > -7.0 * pi_8 and angle <= -5.0 * pi_8:
		current_anim_row = 3
	elif angle > -5.0 * pi_8 and angle <= -3.0 * pi_8:
		current_anim_row = 4
	else:
		current_anim_row = 5
	if sprite:
		walk_timer += delta * 12.0
		sprite.frame = current_anim_row * 8 + (int(walk_timer) % 8)

func _damage_colliding_players() -> void:
	# Damage now comes from readable attack states in EnemyCombatBehavior rather
	# than from invisible body contact while an enemy is merely walking.
	return

func is_in_chokepoint() -> bool:
	if tile_map == null or not is_instance_valid(tile_map) or tile_map.tile_set == null or world == null or not is_instance_valid(world):
		return false
	var cell: Vector2i = tile_map.local_to_map(tile_map.to_local(global_position))
	return bool(world.has_method("is_chokepoint_cell") and world.is_chokepoint_cell(cell))

func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	_ensure_health_bar_nodes()
	var in_choke := is_in_chokepoint()
	var final_amount := amount
	if in_choke:
		final_amount = int(round(float(amount) * 1.35))
	health = max(0, health - final_amount)
	health_bar_hold_timer = HEALTH_BAR_HOLD_TIME
	damage_lag_delay_timer = DAMAGE_LAG_DELAY
	_set_health_bar_values(false)
	if health_bar_container:
		health_bar_container.visible = true
		health_bar_container.modulate.a = 1.0

	var tactical_tint := Color.WHITE
	var feedback_tint := Color.TRANSPARENT
	if in_choke:
		tactical_tint = Color(1.0, 0.88, 0.35, 1.0)
		feedback_tint = Color(1.0, 0.84, 0.22, 1.0)
	elif burn_duration > 0.0:
		tactical_tint = Color(1.0, 0.45, 0.15, 1.0)
		feedback_tint = Color(1.0, 0.32, 0.10, 1.0)

	_play_hit_reaction(tactical_tint)
	var feedback: Node = COMBAT_FEEDBACK.ensure(world)
	feedback.play_enemy_hit(global_position + Vector2(0, 4), _feedback_hit_direction(), final_amount, health <= 0, feedback_tint)
	if health <= 0:
		die()

func _set_health_bar_values(snap: bool) -> void:
	if not health_bar or not damage_lag_bar:
		return
	health_bar.max_value = max_health
	damage_lag_bar.max_value = max_health
	if snap:
		damage_lag_delay_timer = 0.0
		health_bar.value = health
		damage_lag_bar.value = health

func _update_health_bar(delta: float) -> void:
	if not health_bar_container:
		return
	var nearby_or_targeted := _is_player_near_or_targeted()
	if is_boss_enemy:
		health_bar_hold_timer = HEALTH_BAR_HOLD_TIME
	elif nearby_or_targeted:
		health_bar_hold_timer = maxf(health_bar_hold_timer, 0.45)
	elif burn_duration > 0.0:
		health_bar_hold_timer = maxf(health_bar_hold_timer, 0.60)
	else:
		health_bar_hold_timer = maxf(0.0, health_bar_hold_timer - delta)

	var should_show := is_boss_enemy or nearby_or_targeted or burn_duration > 0.0 or health_bar_hold_timer > 0.0
	var target_alpha := 1.0 if should_show else 0.0
	health_bar_container.modulate.a = move_toward(
		health_bar_container.modulate.a,
		target_alpha,
		delta * HEALTH_BAR_FADE_SPEED
	)
	health_bar_container.visible = should_show or health_bar_container.modulate.a > 0.02

	# Color fill modulation based on current health %
	if health_bar:
		var hp_percent := float(health) / maxf(float(max_health), 1.0)
		var fill_color := Color(0.2, 0.85, 0.35, 1.0) # Green (healthy)
		if hp_percent <= 0.25:
			fill_color = Color(0.95, 0.22, 0.18, 1.0) # Red (critical)
		elif hp_percent <= 0.50:
			fill_color = Color(0.96, 0.76, 0.16, 1.0) # Amber (warning)
		health_bar.modulate = fill_color

		var health_weight := 1.0 - exp(-HEALTH_BAR_VALUE_SPEED * delta)
		health_bar.value = lerpf(float(health_bar.value), float(health), health_weight)
		if absf(float(health_bar.value) - float(health)) < 0.2:
			health_bar.value = float(health)

	# Damage catch-up white bar with easing delay
	if damage_lag_bar and health_bar:
		if damage_lag_delay_timer > 0.0:
			damage_lag_delay_timer = maxf(0.0, damage_lag_delay_timer - delta)
		else:
			var lag_weight := 1.0 - exp(-HEALTH_BAR_LAG_SPEED * delta)
			damage_lag_bar.value = lerpf(float(damage_lag_bar.value), float(health_bar.value), lag_weight)
			if absf(float(damage_lag_bar.value) - float(health_bar.value)) < 0.4:
				damage_lag_bar.value = health_bar.value

	_update_status_badges(delta)

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
		if candidate.get("currently_attacking_enemy") == self or (candidate.has_meta("currently_attacking_enemy") and candidate.get_meta("currently_attacking_enemy") == self):
			return true
	return false

func _play_hit_reaction(tactical_tint: Color = Color.WHITE) -> void:
	if not sprite:
		return
	if hit_reaction_tween and hit_reaction_tween.is_running():
		hit_reaction_tween.kill()
	sprite.scale = sprite_rest_scale * Vector2(1.12, 0.90)
	sprite.position = sprite_rest_position + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
	var flash_mult := 2.4
	sprite.modulate = Color(
		tactical_tint.r * flash_mult,
		tactical_tint.g * flash_mult,
		tactical_tint.b * flash_mult,
		1.0
	)
	hit_reaction_tween = create_tween()
	hit_reaction_tween.set_parallel(true)
	hit_reaction_tween.tween_property(sprite, "scale", sprite_rest_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hit_reaction_tween.tween_property(sprite, "position", sprite_rest_position, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hit_reaction_tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)

func _ensure_health_bar_nodes() -> void:
	if health_bar_container == null:
		health_bar_container = get_node_or_null("HealthBarContainer") as Control
	if health_bar_container == null:
		health_bar_container = Control.new()
		health_bar_container.name = "HealthBarContainer"
		health_bar_container.z_index = 30
		health_bar_container.offset_left = -32.0
		health_bar_container.offset_top = -45.0
		health_bar_container.offset_right = 32.0
		health_bar_container.offset_bottom = -37.0
		health_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		health_bar_container.visible = false
		health_bar_container.modulate.a = 0.0
		add_child(health_bar_container)

	if damage_lag_bar == null and health_bar_container:
		damage_lag_bar = health_bar_container.get_node_or_null("DamageLag") as ProgressBar
	if damage_lag_bar == null and health_bar_container:
		damage_lag_bar = ProgressBar.new()
		damage_lag_bar.name = "DamageLag"
		damage_lag_bar.layout_mode = 1
		damage_lag_bar.anchors_preset = Control.PRESET_FULL_RECT
		damage_lag_bar.anchor_right = 1.0
		damage_lag_bar.anchor_bottom = 1.0
		damage_lag_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		damage_lag_bar.show_percentage = false
		var lag_fill := StyleBoxFlat.new()
		lag_fill.bg_color = Color(0.98, 0.98, 0.98, 0.95)
		lag_fill.corner_radius_top_left = 1
		lag_fill.corner_radius_top_right = 1
		lag_fill.corner_radius_bottom_right = 1
		lag_fill.corner_radius_bottom_left = 1
		damage_lag_bar.add_theme_stylebox_override("fill", lag_fill)
		var lag_bg := StyleBoxFlat.new()
		lag_bg.bg_color = Color(0.035, 0.04, 0.05, 0.92)
		lag_bg.border_width_left = 1
		lag_bg.border_width_top = 1
		lag_bg.border_width_right = 1
		lag_bg.border_width_bottom = 1
		lag_bg.border_color = Color(0.06, 0.06, 0.07, 1)
		damage_lag_bar.add_theme_stylebox_override("background", lag_bg)
		health_bar_container.add_child(damage_lag_bar)

	if health_bar == null and health_bar_container:
		health_bar = health_bar_container.get_node_or_null("Health") as ProgressBar
	if health_bar == null and health_bar_container:
		health_bar = ProgressBar.new()
		health_bar.name = "Health"
		health_bar.layout_mode = 1
		health_bar.anchors_preset = Control.PRESET_FULL_RECT
		health_bar.anchor_right = 1.0
		health_bar.anchor_bottom = 1.0
		health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		health_bar.show_percentage = false
		var h_fill := StyleBoxFlat.new()
		h_fill.bg_color = Color(1, 1, 1, 1)
		h_fill.corner_radius_top_left = 1
		h_fill.corner_radius_top_right = 1
		h_fill.corner_radius_bottom_right = 1
		h_fill.corner_radius_bottom_left = 1
		health_bar.add_theme_stylebox_override("fill", h_fill)
		health_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		health_bar_container.add_child(health_bar)

	if status_badge_row == null and health_bar_container:
		status_badge_row = health_bar_container.get_node_or_null("StatusBadgeRow") as HBoxContainer
	if status_badge_row == null and health_bar_container:
		status_badge_row = HBoxContainer.new()
		status_badge_row.name = "StatusBadgeRow"
		status_badge_row.layout_mode = 1
		status_badge_row.anchors_preset = Control.PRESET_TOP_WIDE
		status_badge_row.anchor_right = 1.0
		status_badge_row.offset_top = -14.0
		status_badge_row.offset_bottom = -2.0
		status_badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
		status_badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_badge_row.add_theme_constant_override("separation", 3)
		health_bar_container.add_child(status_badge_row)
		health_bar_container.move_child(status_badge_row, 0)

	_ensure_badge_labels()

func _ensure_badge_labels() -> void:
	if not status_badge_row:
		return
	if chokepoint_badge == null:
		chokepoint_badge = status_badge_row.get_node_or_null("ChokepointBadge") as Label
	if chokepoint_badge == null:
		chokepoint_badge = _create_badge_label("ChokepointBadge", "⚔ VULN", Color(0.88, 0.45, 0.08, 0.92), Color(1, 0.65, 0.2, 0.8))
		status_badge_row.add_child(chokepoint_badge)

	if burn_badge == null:
		burn_badge = status_badge_row.get_node_or_null("BurnBadge") as Label
	if burn_badge == null:
		burn_badge = _create_badge_label("BurnBadge", "🔥 BURN", Color(0.92, 0.2, 0.1, 0.92), Color(1, 0.4, 0.2, 0.8))
		status_badge_row.add_child(burn_badge)

	if sleep_badge == null:
		sleep_badge = status_badge_row.get_node_or_null("SleepBadge") as Label
	if sleep_badge == null:
		sleep_badge = _create_badge_label("SleepBadge", "💤 SLEEP", Color(0.2, 0.4, 0.85, 0.92), Color(0.4, 0.65, 1, 0.8))
		status_badge_row.add_child(sleep_badge)

	if boss_badge == null:
		boss_badge = status_badge_row.get_node_or_null("BossBadge") as Label
	if boss_badge == null:
		boss_badge = _create_badge_label("BossBadge", "☠ BOSS", Color(0.65, 0.12, 0.85, 0.92), Color(0.85, 0.4, 1, 0.8))
		status_badge_row.add_child(boss_badge)

func _create_badge_label(badge_name: String, text: String, bg_color: Color, border_color: Color) -> Label:
	var label := Label.new()
	label.name = badge_name
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	style.content_margin_left = 3.0
	style.content_margin_top = 1.0
	style.content_margin_right = 3.0
	style.content_margin_bottom = 1.0
	label.add_theme_stylebox_override("normal", style)
	return label

func _update_status_badges(delta: float = 0.0) -> void:
	if not status_badge_row:
		return

	# Update custom timed status badges
	for badge_id in _custom_status_badges.keys():
		var data: Dictionary = _custom_status_badges[badge_id]
		if data.has("duration") and float(data["duration"]) > 0.0:
			data["duration"] = maxf(0.0, float(data["duration"]) - delta)
			if float(data["duration"]) <= 0.0:
				remove_status_badge(badge_id)

	# Chokepoint vulnerability badge
	var in_choke := is_in_chokepoint()
	if chokepoint_badge:
		chokepoint_badge.visible = in_choke or _custom_status_badges.has("chokepoint")

	# Burn DoT badge
	if burn_badge:
		burn_badge.visible = burn_duration > 0.0 or _custom_status_badges.has("burn")

	# Sleep / Stun badge
	if sleep_badge:
		sleep_badge.visible = sleep_timer > 0.0 or _custom_status_badges.has("sleep")

	# Boss badge
	if boss_badge:
		boss_badge.visible = is_boss_enemy or _custom_status_badges.has("boss")

func apply_burn(duration: float, tick_damage: int = 4) -> void:
	burn_duration = maxf(burn_duration, duration)
	burn_tick_damage = maxi(burn_tick_damage, tick_damage)
	if burn_tick_timer <= 0.0:
		burn_tick_timer = 0.5
	health_bar_hold_timer = maxf(health_bar_hold_timer, duration)
	_ensure_health_bar_nodes()
	_ensure_burn_particles()
	_update_status_badges(0.0)

func _apply_burn_tick(tick_dmg: int) -> void:
	if health <= 0 or tick_dmg <= 0:
		return
	health = max(0, health - tick_dmg)
	health_bar_hold_timer = maxf(health_bar_hold_timer, 1.2)
	damage_lag_delay_timer = DAMAGE_LAG_DELAY * 0.5
	_set_health_bar_values(false)
	if health_bar_container:
		health_bar_container.visible = true
	if sprite:
		var flash_tween := create_tween()
		sprite.modulate = Color(2.2, 1.3, 0.4, 1.0)
		flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.22)
	if health <= 0:
		die()

func _ensure_burn_particles() -> void:
	if burn_particles == null:
		burn_particles = CPUParticles2D.new()
		burn_particles.name = "BurnParticles"
		burn_particles.direction = Vector2(0, -1)
		burn_particles.gravity = Vector2(0, -70)
		burn_particles.spread = 45.0
		burn_particles.initial_velocity_min = 15.0
		burn_particles.initial_velocity_max = 35.0
		burn_particles.scale_amount_min = 2.0
		burn_particles.scale_amount_max = 3.5
		burn_particles.color = Color(1.0, 0.42, 0.12, 0.95)
		burn_particles.lifetime = 0.55
		burn_particles.amount = 6
		burn_particles.z_index = 22
		add_child(burn_particles)
	burn_particles.emitting = true

func apply_status_badge(badge_id: String, duration: float = 0.0, label_text: String = "", bg_color: Color = Color.TRANSPARENT) -> void:
	_ensure_health_bar_nodes()
	_custom_status_badges[badge_id] = {
		"duration": duration,
		"label": label_text,
		"color": bg_color
	}
	if status_badge_row and not status_badge_row.has_node(badge_id.capitalize() + "Badge"):
		if label_text != "":
			var custom_label := _create_badge_label(badge_id.capitalize() + "Badge", label_text, bg_color, Color(1, 1, 1, 0.8))
			status_badge_row.add_child(custom_label)
	_update_status_badges(0.0)

func remove_status_badge(badge_id: String) -> void:
	_custom_status_badges.erase(badge_id)
	if badge_id == "burn":
		burn_duration = 0.0
		if burn_particles:
			burn_particles.emitting = false
	elif badge_id == "sleep":
		sleep_timer = 0.0
	if status_badge_row:
		var custom_node := status_badge_row.get_node_or_null(badge_id.capitalize() + "Badge")
		if custom_node and custom_node != chokepoint_badge and custom_node != burn_badge and custom_node != sleep_badge and custom_node != boss_badge:
			custom_node.queue_free()
	_update_status_badges(0.0)

func has_status_badge(badge_id: String) -> bool:
	match badge_id:
		"chokepoint", "choke", "vulnerable", "vuln":
			return is_in_chokepoint() or _custom_status_badges.has(badge_id)
		"burn", "fire":
			return burn_duration > 0.0 or _custom_status_badges.has(badge_id)
		"sleep", "stun":
			return sleep_timer > 0.0 or _custom_status_badges.has(badge_id)
		"boss":
			return is_boss_enemy or _custom_status_badges.has(badge_id)
		_:
			return _custom_status_badges.has(badge_id)

func get_active_status_badges() -> Array[String]:
	var active: Array[String] = []
	if is_in_chokepoint():
		active.append("chokepoint")
	if burn_duration > 0.0:
		active.append("burn")
	if sleep_timer > 0.0:
		active.append("sleep")
	if is_boss_enemy:
		active.append("boss")
	for id in _custom_status_badges.keys():
		if not active.has(id):
			active.append(str(id))
	return active

func is_health_bar_showing() -> bool:
	return health_bar_container != null and health_bar_container.visible and health_bar_container.modulate.a > 0.05

func get_health_bar_alpha() -> float:
	return health_bar_container.modulate.a if health_bar_container else 0.0

func get_damage_lag_value() -> float:
	return damage_lag_bar.value if damage_lag_bar else 0.0

func get_health_bar_value() -> float:
	return health_bar.value if health_bar else 0.0

func get_damage_lag_delay_remaining() -> float:
	return damage_lag_delay_timer
	hit_reaction_tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)

func _feedback_hit_direction() -> Vector2:
	var nearest_direction := Vector2.RIGHT
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("players"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var delta := global_position - (candidate as Node2D).global_position
		if delta.length_squared() < nearest_distance:
			nearest_distance = delta.length_squared()
			nearest_direction = delta.normalized() if delta.length_squared() > 0.001 else Vector2.RIGHT
	return nearest_direction

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
	if is_boss_enemy and combat_behavior and combat_behavior.has_method("handle_boss_destroyed"):
		if bool(combat_behavior.handle_boss_destroyed()):
			queue_free()
			return

	var in_choke := is_in_chokepoint()
	if in_choke and world and world.has_method("record_chokepoint_kill"):
		world.record_chokepoint_kill()

	var coin_scene = preload("res://scenes/entities/collectibles/drops/coin_drop.tscn")
	var coin = coin_scene.instantiate()
	coin.gold_value = int(round(float(gold_drop) * 1.5)) if in_choke else gold_drop
	coin.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
	world.call_deferred("add_child", coin)
	
	var xp_scene = preload("res://scenes/entities/collectibles/drops/xp_drop.tscn")
	var xp = xp_scene.instantiate()
	xp.xp_value = int(round(float(xp_drop) * 1.5)) if in_choke else xp_drop
	xp.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
	world.call_deferred("add_child", xp)
		
	if str(Global.get("selected_base_id")) == "undead_king_base" and randf() < 0.35:
		var skel_scene = preload("res://scenes/entities/workers/skeleton/skeleton_carrier.tscn")
		var skel = skel_scene.instantiate()
		skel.global_position = global_position
		world.call_deferred("add_child", skel)
		
	if is_boss_enemy:
		Global.unlock_hero("Mech")
	
	queue_free()
