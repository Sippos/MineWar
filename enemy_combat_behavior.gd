extends Node

const PROJECTILE_SCRIPT := preload("res://enemy_projectile.gd")
const POISON_POOL_SCRIPT := preload("res://enemy_poison_pool.gd")
const MORTAR_MARKER_SCRIPT := preload("res://enemy_mortar_marker.gd")
const GOBLIN_PILOT_SCENE := preload("res://goblin_pilot.tscn")

enum CombatState { IDLE, WINDUP, RECOVERY, DASH, EXHAUST }

enum EnemyKind { RAT, SPIDER, BAT, TROGG, ORC }

var enemy: CharacterBody2D
var world: Node2D
var configured := false
var state := CombatState.IDLE
var state_timer := 0.0
var attack_timer := 0.0
var current_attack := ""
var locked_target: Node2D
var locked_position := Vector2.ZERO
var dash_direction := Vector2.RIGHT
var dash_speed := 0.0
var dash_hit_ids: Dictionary = {}
var exhaust_drop_timer := 0.0
var boss_attack_index := 0
var boss_phase := 1
var telegraph: Node2D
var telegraph_line: Line2D
var telegraph_ring: Line2D
var base_sprite_modulate := Color.WHITE

func _ready() -> void:
	enemy = get_parent() as CharacterBody2D
	if enemy != null:
		world = enemy.get_parent() as Node2D
		var sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
		if sprite:
			base_sprite_modulate = sprite.modulate

func configure() -> void:
	if enemy == null:
		enemy = get_parent() as CharacterBody2D
	if enemy == null:
		return
	world = enemy.get_parent() as Node2D
	configured = world != null
	state = CombatState.IDLE
	state_timer = 0.0
	attack_timer = randf_range(0.15, 0.55)
	boss_attack_index = 0
	boss_phase = 1
	_clear_telegraph()

func process_combat(delta: float) -> bool:
	if not configured or enemy == null or not is_instance_valid(enemy):
		return false
	if int(enemy.get("health")) <= 0:
		return false
	attack_timer = maxf(attack_timer - delta, 0.0)
	if bool(enemy.get("is_boss_enemy")):
		_update_boss_phase()
	if state != CombatState.IDLE:
		return _process_active_state(delta)

	var enemy_kind := int(enemy.get("enemy_type"))
	match enemy_kind:
		EnemyKind.RAT:
			return _process_rat()
		EnemyKind.SPIDER:
			return _process_spider()
		EnemyKind.BAT:
			return _process_bat()
		EnemyKind.TROGG:
			return _process_trogg()
		EnemyKind.ORC:
			if bool(enemy.get("is_boss_enemy")):
				return _process_boss()
			return _process_orc()
	return false

func handle_boss_destroyed() -> bool:
	if enemy == null or world == null or not bool(enemy.get("is_boss_enemy")):
		return false
	_clear_telegraph()
	_spawn_mech_break_burst()
	var pilot := GOBLIN_PILOT_SCENE.instantiate()
	world.add_child(pilot)
	pilot.global_position = enemy.global_position
	if pilot.has_method("configure_from_mech"):
		pilot.configure_from_mech(int(enemy.get("gold_drop")), int(enemy.get("xp_drop")), int(enemy.get("damage")))
	if world.has_node("HUD"):
		var hud := world.get_node("HUD")
		if hud.has_method("show_notice"):
			hud.show_notice("MECH DESTROYED — the goblin pilot is escaping!", 3.5)
	Global.mark_monster_seen("Goblin Pilot")
	return true

func _process_rat() -> bool:
	var target := _select_target(58.0)
	if target == null:
		return false
	_hold_position()
	if attack_timer <= 0.0:
		_begin_windup("rat_bite", target, 0.22, 54.0, Color(1.0, 0.72, 0.22, 0.9))
	return true

func _process_spider() -> bool:
	var target := _select_target(270.0)
	if target == null:
		return false
	var distance := enemy.global_position.distance_to(target.global_position)
	if attack_timer <= 0.0:
		_begin_windup("spider_spit", target, 0.5, 38.0, Color(0.34, 1.0, 0.24, 0.9), true)
		return true
	if distance < 92.0:
		var away := target.global_position.direction_to(enemy.global_position)
		enemy.velocity = away * float(enemy.get("speed")) * 0.72
		enemy.move_and_slide()
		return true
	_hold_position()
	return true

func _process_bat() -> bool:
	var target := _select_target(205.0)
	if target == null:
		return false
	if attack_timer <= 0.0:
		_begin_windup("bat_swoop", target, 0.34, 42.0, Color(0.72, 0.82, 1.0, 0.92), true)
		return true
	var to_target := enemy.global_position.direction_to(target.global_position)
	var lateral := to_target.orthogonal() * sin(Time.get_ticks_msec() * 0.006) * float(enemy.get("speed")) * 0.55
	enemy.velocity = lateral - to_target * float(enemy.get("speed")) * 0.12
	enemy.move_and_slide()
	return true

func _process_trogg() -> bool:
	var target := _select_target(102.0)
	if target == null:
		return false
	_hold_position()
	if attack_timer <= 0.0:
		_begin_windup("trogg_smash", target, 0.72, 88.0, Color(1.0, 0.34, 0.12, 0.92))
	return true

func _process_orc() -> bool:
	var target := _base_if_in_range(100.0)
	if target == null:
		target = _select_target(92.0)
	if target == null:
		return false
	_hold_position()
	if attack_timer <= 0.0:
		_begin_windup("orc_cleave", target, 0.48, 72.0, Color(1.0, 0.52, 0.12, 0.94))
	return true

func _process_boss() -> bool:
	var target := _select_target(430.0)
	if target == null:
		return false
	var distance := enemy.global_position.distance_to(target.global_position)
	if attack_timer > 0.0:
		if distance < 92.0:
			_hold_position()
			return true
		return false

	var attack_choice := boss_attack_index % 3
	boss_attack_index += 1
	if attack_choice == 0:
		_begin_windup("boss_charge", target, 0.82 if boss_phase == 1 else (0.62 if boss_phase == 2 else 0.50), 54.0, Color(1.0, 0.16, 0.08, 0.96), true)
	elif attack_choice == 1:
		_begin_windup("boss_mortar", target, 0.76 if boss_phase == 1 else (0.64 if boss_phase == 2 else 0.54), 62.0, Color(1.0, 0.58, 0.08, 0.96))
	else:
		_begin_windup("boss_exhaust", target, 0.56, 86.0, Color(0.36, 1.0, 0.24, 0.9))
	return true

func _process_active_state(delta: float) -> bool:
	match state:
		CombatState.WINDUP:
			_hold_position()
			state_timer -= delta
			_update_windup_visual()
			if state_timer <= 0.0:
				_execute_current_attack()
			return true
		CombatState.RECOVERY:
			_hold_position()
			state_timer -= delta
			if state_timer <= 0.0:
				state = CombatState.IDLE
				current_attack = ""
				_restore_sprite_tint()
			return true
		CombatState.DASH:
			state_timer -= delta
			enemy.velocity = dash_direction * dash_speed
			enemy.move_and_slide()
			_damage_dash_contacts()
			if current_attack == "boss_charge" and boss_phase >= 2:
				exhaust_drop_timer -= delta
				if exhaust_drop_timer <= 0.0:
					exhaust_drop_timer = 0.282
					_spawn_poison_pool(enemy.global_position, 38.0, 1.8, 1)
			if state_timer <= 0.0:
				state = CombatState.RECOVERY
				state_timer = 0.42 if current_attack == "bat_swoop" else 0.62
				enemy.velocity = Vector2.ZERO
			return true
		CombatState.EXHAUST:
			_hold_position()
			state_timer -= delta
			exhaust_drop_timer -= delta
			if exhaust_drop_timer <= 0.0:
				exhaust_drop_timer = 0.28
				var angle := randf_range(0.0, TAU)
				var offset := Vector2.RIGHT.rotated(angle) * randf_range(36.0, 82.0)
				_spawn_poison_pool(enemy.global_position + offset, 42.0, 2.3, 1)
			if state_timer <= 0.0:
				state = CombatState.RECOVERY
				state_timer = 0.48
			return true
	return false

func _begin_windup(attack_name: String, target: Node2D, duration: float, radius: float, color: Color, line_telegraph: bool = false) -> void:
	current_attack = attack_name
	locked_target = target
	locked_position = target.global_position
	state = CombatState.WINDUP
	state_timer = duration
	_hold_position()
	_clear_telegraph()
	if line_telegraph:
		telegraph_line = Line2D.new()
		telegraph_line.width = 5.0 if attack_name == "boss_charge" else 3.0
		telegraph_line.default_color = color
		telegraph_line.points = PackedVector2Array([enemy.global_position, locked_position])
		telegraph_line.z_index = 22
		world.add_child(telegraph_line)
		telegraph = telegraph_line
	else:
		telegraph = Node2D.new()
		telegraph.global_position = enemy.global_position if attack_name != "boss_mortar" else locked_position
		telegraph.z_index = 22
		world.add_child(telegraph)
		telegraph_ring = Line2D.new()
		telegraph_ring.width = 4.0
		telegraph_ring.default_color = color
		telegraph_ring.points = _circle_points(radius, 28, true)
		telegraph.add_child(telegraph_ring)
	_set_sprite_tint(Color(1.5, 0.72, 0.42, 1.0) if attack_name != "spider_spit" and attack_name != "boss_exhaust" else Color(0.65, 1.45, 0.55, 1.0))

func _update_windup_visual() -> void:
	if is_instance_valid(locked_target) and current_attack in ["rat_bite", "trogg_smash", "orc_cleave"]:
		locked_position = locked_target.global_position
	if telegraph_line:
		telegraph_line.points = PackedVector2Array([enemy.global_position, locked_position])
		telegraph_line.modulate.a = 0.65 + sin(Time.get_ticks_msec() * 0.025) * 0.25
	if telegraph and telegraph != telegraph_line:
		if current_attack != "boss_mortar":
			telegraph.global_position = enemy.global_position
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.025) * 0.08
		telegraph.scale = Vector2.ONE * pulse

func _execute_current_attack() -> void:
	_clear_telegraph()
	var base_damage := maxi(1, int(enemy.get("damage")))
	match current_attack:
		"rat_bite":
			_damage_locked_target(base_damage, 66.0)
			_finish_attack(0.34, 0.78)
		"spider_spit":
			_spawn_projectile(locked_position, maxi(1, base_damage - 1), 330.0, 34.0, true, Color(0.36, 1.0, 0.22, 1.0))
			_finish_attack(0.38, 1.85)
		"bat_swoop":
			_start_dash(locked_position, float(enemy.get("speed")) * 4.6, 0.36, 1.35)
		"trogg_smash":
			_damage_targets_at(enemy.global_position, 92.0, base_damage, 1.0)
			_spawn_impact_burst(enemy.global_position, Color(1.0, 0.3, 0.08, 0.95), 30)
			_finish_attack(0.68, 1.55)
		"orc_cleave":
			_damage_targets_at(enemy.global_position, 78.0, base_damage, 1.45)
			_spawn_impact_burst(enemy.global_position, Color(1.0, 0.55, 0.1, 0.95), 22)
			_finish_attack(0.54, 1.18)
		"boss_charge":
			_start_dash(locked_position, 390.0 + float(boss_phase - 1) * 55.0, 0.64, _boss_cooldown())
		"boss_mortar":
			_spawn_boss_mortars(locked_position, base_damage)
			_finish_attack(0.36, _boss_cooldown())
		"boss_exhaust":
			state = CombatState.EXHAUST
			state_timer = 0.9 if boss_phase == 1 else 1.15
			exhaust_drop_timer = 0.0
			attack_timer = _boss_cooldown()
		_:
			_finish_attack(0.25, 1.0)

func _finish_attack(recovery: float, cooldown: float) -> void:
	state = CombatState.RECOVERY
	state_timer = recovery
	attack_timer = cooldown

func _start_dash(destination: Vector2, speed_value: float, duration: float, cooldown: float) -> void:
	dash_direction = enemy.global_position.direction_to(destination)
	if dash_direction.length_squared() <= 0.001:
		dash_direction = Vector2.RIGHT
	dash_speed = speed_value
	state = CombatState.DASH
	state_timer = duration
	attack_timer = cooldown
	dash_hit_ids.clear()
	exhaust_drop_timer = 0.0

func _damage_dash_contacts() -> void:
	var hit_radius := 52.0 if current_attack == "bat_swoop" else 76.0
	var hit_damage := maxi(1, int(enemy.get("damage")))
	if current_attack == "boss_charge":
		hit_damage = int(ceil(float(hit_damage) * 1.25))
	for target in _all_damage_targets():
		if not is_instance_valid(target):
			continue
		var id := target.get_instance_id()
		if dash_hit_ids.has(id):
			continue
		if enemy.global_position.distance_to(target.global_position) <= hit_radius:
			dash_hit_ids[id] = true
			if target.has_method("take_damage"):
				target.take_damage(hit_damage)

func _spawn_projectile(destination: Vector2, hit_damage: int, speed_value: float, radius: float, poison: bool, color: Color) -> void:
	var projectile := PROJECTILE_SCRIPT.new()
	world.add_child(projectile)
	projectile.configure(world, enemy.global_position + Vector2(0, -4), destination, hit_damage, speed_value, radius, poison, color)

func _spawn_boss_mortars(center: Vector2, hit_damage: int) -> void:
	var offsets := [Vector2.ZERO, Vector2(86, 34), Vector2(-82, -36)]
	if boss_phase >= 3:
		offsets.append(Vector2(20, -96))
	for index in range(offsets.size()):
		var marker := MORTAR_MARKER_SCRIPT.new()
		world.add_child(marker)
		marker.configure(world, center + offsets[index], maxi(2, int(ceil(float(hit_damage) * 0.55))), 50.0, 0.90 + float(index) * 0.16, boss_phase >= 2 and index == offsets.size() - 1)

func _spawn_poison_pool(position: Vector2, radius: float, lifetime: float, tick_damage: int) -> void:
	var pool := POISON_POOL_SCRIPT.new()
	world.add_child(pool)
	pool.configure(world, position, radius, lifetime, tick_damage)

func _damage_locked_target(hit_damage: int, maximum_distance: float) -> void:
	if not is_instance_valid(locked_target):
		return
	if enemy.global_position.distance_to(locked_target.global_position) > maximum_distance:
		return
	if locked_target.has_method("take_damage"):
		locked_target.take_damage(hit_damage)

func _damage_targets_at(center: Vector2, radius: float, hit_damage: int, base_multiplier: float) -> void:
	for target in _all_damage_targets():
		if not is_instance_valid(target) or center.distance_to(target.global_position) > radius:
			continue
		if not target.has_method("take_damage"):
			continue
		var applied := hit_damage
		if str(target.name) == "Base":
			applied = maxi(1, int(ceil(float(hit_damage) * base_multiplier)))
		target.take_damage(applied)

func _select_target(maximum_range: float) -> Node2D:
	var nearest: Node2D
	var nearest_distance := maximum_range
	for child in world.get_children():
		if not child is Node2D or not is_instance_valid(child):
			continue
		var candidate := child as Node2D
		if not str(candidate.name).begins_with("Player"):
			continue
		if bool(candidate.get("is_dead")):
			continue
		var distance := enemy.global_position.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest = candidate
			nearest_distance = distance
	if nearest != null:
		return nearest
	return _base_if_in_range(maximum_range)

func _base_if_in_range(maximum_range: float) -> Node2D:
	# LineWars resolves a survivor as one discrete leak when it physically reaches
	# the base. Special attacks must not repeatedly chip the base beforehand.
	if bool(enemy.get_meta("linewars_single_leak", false)):
		return null
	var base := world.get_node_or_null("Base") as Node2D
	if base and enemy.global_position.distance_to(base.global_position) <= maximum_range:
		return base
	return null

func _all_damage_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for child in world.get_children():
		if child is Node2D and is_instance_valid(child):
			var candidate := child as Node2D
			var is_player := str(candidate.name).begins_with("Player")
			var is_base := str(candidate.name) == "Base" and not bool(enemy.get_meta("linewars_single_leak", false))
			if is_player or is_base:
				targets.append(candidate)
	return targets

func _hold_position() -> void:
	enemy.velocity = Vector2.ZERO

func _update_boss_phase() -> void:
	var maximum := maxf(1.0, float(enemy.get("max_health")))
	var ratio := float(enemy.get("health")) / maximum
	var new_phase := 1
	if ratio <= 0.34:
		new_phase = 3
	elif ratio <= 0.68:
		new_phase = 2
	if new_phase == boss_phase:
		return
	boss_phase = new_phase
	boss_attack_index += 1
	_spawn_phase_burst()
	# MineWars has its own phase ceremony and reinforcement announcements.
	# Other modes still receive the self-contained boss warning.
	if not bool(enemy.get_meta("minewars_boss", false)) and world.has_node("HUD"):
		var hud := world.get_node("HUD")
		if hud.has_method("show_notice"):
			hud.show_notice("MECH OVERDRIVE — attack pattern intensified!" if boss_phase == 2 else "MECH CRITICAL — pilot override engaged!", 3.0)

func _boss_cooldown() -> float:
	match boss_phase:
		1: return 1.55
		2: return 1.18
		_: return 0.92

func _spawn_phase_burst() -> void:
	_spawn_impact_burst(enemy.global_position, Color(1.0, 0.18, 0.05, 1.0), 46)
	var sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		var tween := sprite.create_tween()
		tween.tween_property(sprite, "modulate", Color(1.7, 0.35, 0.22, 1.0), 0.12)
		tween.tween_property(sprite, "modulate", base_sprite_modulate, 0.35)

func _spawn_impact_burst(position: Vector2, color: Color, amount: int) -> void:
	var burst := CPUParticles2D.new()
	burst.amount = amount
	burst.lifetime = 0.42
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 10.0
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2(0, 105)
	burst.initial_velocity_min = 55.0
	burst.initial_velocity_max = 150.0
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 4.2
	burst.color = color
	burst.global_position = position
	burst.z_index = 26
	world.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.8).timeout.connect(burst.queue_free)

func _spawn_mech_break_burst() -> void:
	_spawn_impact_burst(enemy.global_position, Color(1.0, 0.42, 0.08, 1.0), 72)
	for offset in [Vector2(-24, 8), Vector2(18, -10), Vector2(8, 20)]:
		var smoke := Polygon2D.new()
		smoke.polygon = _circle_points(10.0, 12)
		smoke.color = Color(0.18, 0.18, 0.2, 0.82)
		smoke.global_position = enemy.global_position + offset
		smoke.z_index = 23
		world.add_child(smoke)
		var tween := smoke.create_tween().set_parallel(true)
		tween.tween_property(smoke, "global_position", smoke.global_position + Vector2(0, -48), 0.8)
		tween.tween_property(smoke, "scale", Vector2(2.2, 2.2), 0.8)
		tween.tween_property(smoke, "modulate:a", 0.0, 0.8)
		tween.chain().tween_callback(smoke.queue_free)

func _set_sprite_tint(color: Color) -> void:
	var sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.modulate = color

func _restore_sprite_tint() -> void:
	var sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.modulate = base_sprite_modulate

func _clear_telegraph() -> void:
	if telegraph and is_instance_valid(telegraph):
		telegraph.queue_free()
	telegraph = null
	telegraph_line = null
	telegraph_ring = null

func _circle_points(radius: float, segments: int, close_loop: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := segments + 1 if close_loop else segments
	for index in range(count):
		points.append(Vector2.RIGHT.rotated(TAU * float(index % segments) / float(segments)) * radius)
	return points

func _exit_tree() -> void:
	_clear_telegraph()
