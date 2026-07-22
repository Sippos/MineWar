extends Node

const ENEMY_STATUS_SCRIPT := preload("res://enemy_status.gd")

const DWARF_CARRY_BONUS := 1
const DWARF_ASSAULT_REPAIR := 8
const SHAMAN_PROSPECT_INTERVAL := 11.0
const SHAMAN_HEAL_INTERVAL := 2.4
const DRUID_SAFE_REGEN_INTERVAL := 2.0
const DRUID_ROOT_INTERVAL := 7.0
const NERUBIAN_WARNING_BONUS := 3.0
const NERUBIAN_WEB_COUNT := 3
const UNDEAD_SOUL_THRESHOLD := 4
const MECH_BASE_HEALTH_BONUS := 15
const MECH_TURRET_INTERVAL := 3.2

var base: Node2D
var world: Node2D
var player: CharacterBody2D
var base_id := ""
var active_run := false
var previous_phase := ""
var previous_stage := -1
var applied_health_bonus := 0
var announced_identity := ""

var prospect_timer := 2.5
var shaman_heal_timer := 0.8
var druid_regen_timer := 0.0
var druid_root_timer := 1.8
var mech_turret_timer := 1.2
var nerubian_webbed_count := 0
var soul_charges := 0
var observed_enemies: Dictionary = {}

func _ready() -> void:
	process_priority = 230
	call_deferred("_late_setup")

func _late_setup() -> void:
	_resolve_nodes()
	_refresh_identity(true)

func _process(delta: float) -> void:
	if base == null or not is_instance_valid(base) or world == null or not is_instance_valid(world):
		_resolve_nodes()
		if base == null or world == null:
			return
	var desired_id := str(Global.selected_base_id)
	var desired_run_state := _is_run_active()
	if desired_id != base_id or desired_run_state != active_run:
		_refresh_identity(true)
	if not active_run:
		return

	_track_enemies()
	var phase := str(world.get_meta("minewars_phase", ""))
	var stage := int(world.get_meta("minewars_stage_number", world.get_meta("active_wave_number", -1)))
	if phase != previous_phase or stage != previous_stage:
		_on_phase_changed(previous_phase, phase, previous_stage, stage)
		previous_phase = phase
		previous_stage = stage

	match base_id:
		"shaman_base":
			_process_shaman(delta, phase)
		"druid_base":
			_process_druid(delta, phase)
		"nerubian_base":
			_process_nerubian(phase, stage)
		"undead_king_base":
			_process_undead(phase)
		"mech_base":
			_process_mech(delta, phase)

func _resolve_nodes() -> void:
	base = get_parent() as Node2D
	world = base.get_parent() as Node2D if base else null
	player = world.get_node_or_null("Player") as CharacterBody2D if world else null

func _is_run_active() -> bool:
	if world == null or bool(world.get_meta("single_player_hub_active", false)):
		return false
	var preparation_value: Variant = world.get("preparation_active")
	if preparation_value != null and bool(preparation_value):
		return false
	return player != null and is_instance_valid(player)

func _refresh_identity(force: bool = false) -> void:
	_resolve_nodes()
	if base == null or world == null:
		return
	var desired_id := str(Global.selected_base_id)
	var desired_run_state := _is_run_active()
	if not force and desired_id == base_id and desired_run_state == active_run:
		return
	_clear_runtime_effects()
	base_id = desired_id
	active_run = desired_run_state
	previous_phase = ""
	previous_stage = -1
	prospect_timer = 2.5
	shaman_heal_timer = 0.8
	druid_regen_timer = 0.0
	druid_root_timer = 1.8
	mech_turret_timer = 1.2
	nerubian_webbed_count = 0
	soul_charges = 0
	observed_enemies.clear()
	world.set_meta("active_base_id", base_id)
	_apply_base_visual_tint()
	if not active_run:
		return

	match base_id:
		"default_base":
			player.set_meta("base_carry_bonus", DWARF_CARRY_BONUS)
			world.set_meta("base_identity_passive", "+1 free gem carry")
		"shaman_base":
			world.set_meta("base_identity_passive", "Prospector pulses reveal nearby crystals")
		"druid_base":
			world.set_meta("base_identity_passive", "Safe regeneration while away from enemies")
		"nerubian_base":
			world.set_meta("base_identity_passive", "+3 seconds assault warning")
		"undead_king_base":
			world.set_meta("base_identity_passive", "Enemy deaths charge soul energy")
		"mech_base":
			_apply_mech_base_bonus()
			world.set_meta("base_identity_passive", "+15 base health and faster Mech rebuilding")
	_announce_base_identity()

func _clear_runtime_effects() -> void:
	if player != null and is_instance_valid(player):
		player.set_meta("base_carry_bonus", 0)
	if base != null and is_instance_valid(base):
		base.remove_meta("mech_rebuild_multiplier")
		if applied_health_bonus > 0:
			var maximum := maxi(1, int(base.get("max_health")) - applied_health_bonus)
			base.set("max_health", maximum)
			base.set("health", mini(int(base.get("health")), maximum))
			applied_health_bonus = 0
	if world != null and is_instance_valid(world):
		world.remove_meta("base_identity_passive")

func _apply_mech_base_bonus() -> void:
	if applied_health_bonus > 0:
		return
	applied_health_bonus = MECH_BASE_HEALTH_BONUS
	base.set("max_health", int(base.get("max_health")) + applied_health_bonus)
	base.set("health", int(base.get("health")) + applied_health_bonus)
	base.set_meta("mech_rebuild_multiplier", 1.45)
	_refresh_base_hud()

func _apply_base_visual_tint() -> void:
	if base == null:
		return
	var sprite := base.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	sprite.modulate = Color(1.16, 0.84, 0.5, 1.0) if base_id == "mech_base" else Color.WHITE

func _announce_base_identity() -> void:
	if announced_identity == base_id:
		return
	announced_identity = base_id
	var notices := {
		"default_base": "DWARF BASTION — +1 free carry. Repairs after every assault.",
		"shaman_base": "SHAMAN LODGE — crystal pulses and a healing defence totem are active.",
		"druid_base": "DRUID GROVE — safe regeneration and defensive root pulses are active.",
		"nerubian_base": "NERUBIAN NEST — earlier warnings and breach webs are active.",
		"undead_king_base": "SOUL CITADEL — fallen enemies now charge defensive soul energy.",
		"mech_base": "GOBLIN WORKSHOP — reinforced core, auto-turret, and rapid Mech rebuilding active."
	}
	_show_notice(str(notices.get(base_id, "Base identity active.")), 4.0)

func _on_phase_changed(old_phase: String, new_phase: String, _old_stage: int, new_stage: int) -> void:
	if old_phase == "attack" and new_phase != "attack" and base_id == "default_base":
		if int(base.get("health")) < int(base.get("max_health")):
			base.call("repair", DWARF_ASSAULT_REPAIR)
			_spawn_world_ring(base.global_position, 94.0, Color(1.0, 0.72, 0.24, 0.92), 0.75)
			_show_notice("DWARVEN REPAIRS — bastion restored by %d HP." % DWARF_ASSAULT_REPAIR, 2.4)
	if new_phase == "attack":
		nerubian_webbed_count = 0
		druid_root_timer = 1.8
		mech_turret_timer = 1.0
		if base_id == "nerubian_base":
			var controller := world.get_node_or_null("SiegeModeController")
			if controller != null:
				var current_muster := float(controller.get("assault_muster_timer"))
				controller.set("assault_muster_timer", current_muster + NERUBIAN_WARNING_BONUS)
				_show_notice("BROOD SENSE — assault detected %.0f seconds earlier." % NERUBIAN_WARNING_BONUS, 2.6)
	if new_stage != previous_stage:
		world.set_meta("base_identity_stage", new_stage)

func _process_shaman(delta: float, phase: String) -> void:
	prospect_timer -= delta
	if phase != "attack" and prospect_timer <= 0.0:
		prospect_timer = SHAMAN_PROSPECT_INTERVAL
		_pulse_prospecting()
	if phase != "attack":
		return
	shaman_heal_timer -= delta
	if shaman_heal_timer > 0.0:
		return
	shaman_heal_timer = SHAMAN_HEAL_INTERVAL
	if player.global_position.distance_to(base.global_position) > 230.0:
		return
	_heal_player(2)
	_spawn_world_ring(base.global_position, 118.0, Color(0.28, 0.88, 1.0, 0.8), 0.55)

func _pulse_prospecting() -> void:
	var block_layer := world.get_node_or_null("BlockLayer") as TileMapLayer
	if block_layer == null or player == null:
		return
	var player_cell := block_layer.local_to_map(block_layer.to_local(player.global_position))
	var candidates: Array[Dictionary] = []
	var gem_cells := block_layer.get_used_cells_by_id(21)
	for cell in gem_cells:
		var distance := Vector2(player_cell).distance_to(Vector2(cell))
		if distance <= 9.5:
			candidates.append({"cell": cell, "distance": distance})
	candidates.sort_custom(_sort_candidate_distance)
	var reveal_count := mini(3, candidates.size())
	for index in range(reveal_count):
		var cell: Vector2i = candidates[index]["cell"]
		var world_position := block_layer.to_global(block_layer.map_to_local(cell))
		_spawn_prospect_marker(world_position)
	if reveal_count > 0:
		_show_notice("ANCESTRAL PROSPECT — %d nearby crystal seam%s revealed." % [reveal_count, "s" if reveal_count != 1 else ""], 2.2)

func _sort_candidate_distance(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("distance", 9999.0)) < float(b.get("distance", 9999.0))

func _spawn_prospect_marker(position: Vector2) -> void:
	var marker := Node2D.new()
	marker.name = "ShamanProspectPulse"
	marker.global_position = position
	marker.z_index = 24
	world.add_child(marker)
	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = Color(0.22, 0.9, 1.0, 0.96)
	ring.points = _circle_points(25.0, 24, true)
	marker.add_child(ring)
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([Vector2(0, -9), Vector2(7, 0), Vector2(0, 9), Vector2(-7, 0)])
	diamond.color = Color(0.52, 1.0, 1.0, 0.82)
	marker.add_child(diamond)
	var tween := marker.create_tween().set_parallel(true)
	tween.tween_property(marker, "scale", Vector2(1.7, 1.7), 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(marker, "modulate:a", 0.0, 1.15)
	tween.chain().tween_callback(marker.queue_free)

func _process_druid(delta: float, phase: String) -> void:
	if phase == "attack":
		druid_root_timer -= delta
		if druid_root_timer <= 0.0:
			druid_root_timer = DRUID_ROOT_INTERVAL
			_release_root_pulse()
		return
	if _enemy_near_player(185.0):
		druid_regen_timer = 0.0
		return
	druid_regen_timer += delta
	if druid_regen_timer >= DRUID_SAFE_REGEN_INTERVAL:
		druid_regen_timer = 0.0
		_heal_player(1)

func _release_root_pulse() -> void:
	var hit_count := 0
	for enemy_value in get_tree().get_nodes_in_group("enemies"):
		if not enemy_value is Node2D or not is_instance_valid(enemy_value) or not world.is_ancestor_of(enemy_value):
			continue
		var enemy := enemy_value as Node2D
		if base.global_position.distance_to(enemy.global_position) > 200.0:
			continue
		_apply_enemy_slow(enemy, 2.8, 0.55)
		hit_count += 1
		_spawn_root_line(base.global_position, enemy.global_position)
	if hit_count > 0:
		_spawn_world_ring(base.global_position, 200.0, Color(0.34, 1.0, 0.38, 0.88), 0.7)
		_show_notice("GROVE ROOTS — %d enem%s entangled." % [hit_count, "y" if hit_count == 1 else "ies"], 2.0)

func _process_nerubian(phase: String, stage: int) -> void:
	if phase != "attack" or nerubian_webbed_count >= NERUBIAN_WEB_COUNT:
		return
	for enemy_value in get_tree().get_nodes_in_group("enemies"):
		if nerubian_webbed_count >= NERUBIAN_WEB_COUNT:
			break
		if not enemy_value is Node2D or not is_instance_valid(enemy_value) or not world.is_ancestor_of(enemy_value):
			continue
		var enemy := enemy_value as Node2D
		if base.global_position.distance_to(enemy.global_position) > 255.0:
			continue
		if int(enemy.get_meta("nerubian_web_stage", -999)) == stage:
			continue
		enemy.set_meta("nerubian_web_stage", stage)
		_apply_enemy_slow(enemy, 4.0, 0.5)
		nerubian_webbed_count += 1
		_spawn_web_visual(enemy.global_position)
		if nerubian_webbed_count == 1:
			_show_notice("BREACH WEBS — the first %d attackers are trapped." % NERUBIAN_WEB_COUNT, 2.4)

func _process_undead(_phase: String) -> void:
	if soul_charges < UNDEAD_SOUL_THRESHOLD:
		return
	_release_soul_energy()

func _process_mech(delta: float, phase: String) -> void:
	if phase != "attack":
		return
	mech_turret_timer -= delta
	if mech_turret_timer > 0.0:
		return
	mech_turret_timer = MECH_TURRET_INTERVAL
	_fire_workshop_turret()

func _track_enemies() -> void:
	for enemy_value in get_tree().get_nodes_in_group("enemies"):
		if not enemy_value is Node or not is_instance_valid(enemy_value) or not world.is_ancestor_of(enemy_value):
			continue
		var enemy := enemy_value as Node
		var enemy_id := enemy.get_instance_id()
		if observed_enemies.has(enemy_id):
			continue
		observed_enemies[enemy_id] = true
		enemy.tree_exiting.connect(_on_enemy_exiting.bind(enemy), CONNECT_ONE_SHOT)

func _on_enemy_exiting(enemy: Node) -> void:
	if enemy != null:
		observed_enemies.erase(enemy.get_instance_id())
	if not active_run or base_id != "undead_king_base" or enemy == null:
		return
	var health_value: Variant = enemy.get("health")
	if health_value == null or int(health_value) > 0:
		return
	soul_charges += 1
	_spawn_soul_wisp((enemy as Node2D).global_position if enemy is Node2D else base.global_position)
	world.set_meta("soul_citadel_charges", soul_charges)

func _release_soul_energy() -> void:
	soul_charges -= UNDEAD_SOUL_THRESHOLD
	world.set_meta("soul_citadel_charges", soul_charges)
	var targets: Array[Node2D] = []
	for enemy_value in get_tree().get_nodes_in_group("enemies"):
		if enemy_value is Node2D and is_instance_valid(enemy_value) and world.is_ancestor_of(enemy_value):
			var enemy := enemy_value as Node2D
			if base.global_position.distance_to(enemy.global_position) <= 310.0:
				targets.append(enemy)
	if targets.is_empty():
		base.call("repair", 6)
		_show_notice("SOUL MEND — the Citadel restores 6 bastion HP.", 2.2)
	else:
		for enemy in targets:
			if enemy.has_method("take_damage"):
				var hit_damage := 7 if bool(enemy.get("is_boss_enemy")) else 12
				enemy.take_damage(hit_damage)
		_show_notice("SOUL NOVA — %d enem%s struck." % [targets.size(), "y" if targets.size() == 1 else "ies"], 2.2)
	_spawn_world_ring(base.global_position, 310.0, Color(0.62, 0.34, 1.0, 0.94), 0.85)

func _fire_workshop_turret() -> void:
	var target: Node2D
	var best_score := -INF
	for enemy_value in get_tree().get_nodes_in_group("enemies"):
		if not enemy_value is Node2D or not is_instance_valid(enemy_value) or not world.is_ancestor_of(enemy_value):
			continue
		var enemy := enemy_value as Node2D
		var distance := base.global_position.distance_to(enemy.global_position)
		if distance > 430.0:
			continue
		var health_score := float(enemy.get("health")) if enemy.get("health") != null else 1.0
		var damage_score := float(enemy.get("damage")) * 5.0 if enemy.get("damage") != null else 0.0
		var score := health_score + damage_score - distance * 0.04
		if score > best_score:
			best_score = score
			target = enemy
	if target == null:
		return
	if target.has_method("take_damage"):
		target.take_damage(8)
	_spawn_turret_beam(base.global_position + Vector2(0, -44), target.global_position)

func _enemy_near_player(radius: float) -> bool:
	for enemy_value in get_tree().get_nodes_in_group("enemies"):
		if enemy_value is Node2D and is_instance_valid(enemy_value) and world.is_ancestor_of(enemy_value):
			if player.global_position.distance_to((enemy_value as Node2D).global_position) <= radius:
				return true
	return false

func _enemy_status(enemy: Node) -> Node:
	if not is_instance_valid(enemy):
		return null
	var status := enemy.get_node_or_null("HeroStatus")
	if status != null:
		return status
	status = Node.new()
	status.name = "HeroStatus"
	status.set_script(ENEMY_STATUS_SCRIPT)
	enemy.add_child(status)
	return status

func _apply_enemy_slow(enemy: Node, duration: float, factor: float) -> void:
	var status := _enemy_status(enemy)
	if status != null and status.has_method("apply_slow"):
		status.call("apply_slow", duration, factor)

func _heal_player(amount: int) -> void:
	if player == null or bool(player.get("is_dead")):
		return
	var health := int(player.get("health"))
	var maximum := int(player.get("max_health"))
	if health >= maximum:
		return
	player.set("health", mini(maximum, health + amount))
	var hud := world.get_node_or_null("HUD")
	if hud != null and hud.has_method("update_player_health"):
		hud.update_player_health(int(player.get("health")), maximum)

func _refresh_base_hud() -> void:
	var hud := world.get_node_or_null("HUD") if world else null
	if hud != null and hud.has_method("update_base_health"):
		hud.update_base_health(int(base.get("health")), int(base.get("max_health")))

func _show_notice(text: String, duration: float) -> void:
	var hud := world.get_node_or_null("HUD") if world else null
	if hud != null and hud.has_method("show_notice"):
		hud.show_notice(text, duration)

func _spawn_world_ring(position: Vector2, radius: float, color: Color, lifetime: float) -> void:
	if world == null:
		return
	var ring := Line2D.new()
	ring.width = 5.0
	ring.default_color = color
	ring.points = _circle_points(radius, 32, true)
	ring.global_position = position
	ring.z_index = 23
	world.add_child(ring)
	ring.scale = Vector2(0.3, 0.3)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, lifetime)
	tween.chain().tween_callback(ring.queue_free)

func _spawn_root_line(from_position: Vector2, to_position: Vector2) -> void:
	var line := Line2D.new()
	line.width = 6.0
	line.default_color = Color(0.3, 0.82, 0.22, 0.82)
	line.points = PackedVector2Array([from_position, (from_position + to_position) * 0.5 + Vector2(0, 18), to_position])
	line.z_index = 21
	world.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.8)
	tween.tween_callback(line.queue_free)

func _spawn_web_visual(position: Vector2) -> void:
	var web := Node2D.new()
	web.global_position = position
	web.z_index = 22
	world.add_child(web)
	for angle_index in range(4):
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color(0.82, 0.9, 1.0, 0.82)
		var direction := Vector2.RIGHT.rotated(TAU * float(angle_index) / 4.0)
		line.points = PackedVector2Array([-direction * 28.0, direction * 28.0])
		web.add_child(line)
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(0.82, 0.9, 1.0, 0.72)
	ring.points = _circle_points(22.0, 20, true)
	web.add_child(ring)
	var tween := web.create_tween().set_parallel(true)
	tween.tween_property(web, "scale", Vector2(1.45, 1.45), 0.7)
	tween.tween_property(web, "modulate:a", 0.0, 1.2)
	tween.chain().tween_callback(web.queue_free)

func _spawn_soul_wisp(position: Vector2) -> void:
	var wisp := Polygon2D.new()
	wisp.polygon = _circle_points(7.0, 12)
	wisp.color = Color(0.68, 0.38, 1.0, 0.86)
	wisp.global_position = position
	wisp.z_index = 24
	world.add_child(wisp)
	var tween := wisp.create_tween().set_parallel(true)
	tween.tween_property(wisp, "global_position", base.global_position + Vector2(0, -38), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(wisp, "scale", Vector2(0.35, 0.35), 0.65)
	tween.tween_property(wisp, "modulate:a", 0.0, 0.65)
	tween.chain().tween_callback(wisp.queue_free)

func _spawn_turret_beam(from_position: Vector2, to_position: Vector2) -> void:
	var beam := Line2D.new()
	beam.width = 5.0
	beam.default_color = Color(1.0, 0.68, 0.16, 0.96)
	beam.points = PackedVector2Array([from_position, to_position])
	beam.z_index = 26
	world.add_child(beam)
	var spark := CPUParticles2D.new()
	spark.amount = 12
	spark.lifetime = 0.22
	spark.one_shot = true
	spark.explosiveness = 1.0
	spark.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	spark.emission_sphere_radius = 5.0
	spark.direction = Vector2.UP
	spark.spread = 180.0
	spark.initial_velocity_min = 40.0
	spark.initial_velocity_max = 100.0
	spark.color = Color(1.0, 0.72, 0.18, 1.0)
	spark.global_position = to_position
	spark.z_index = 27
	world.add_child(spark)
	spark.emitting = true
	var tween := beam.create_tween()
	tween.tween_property(beam, "modulate:a", 0.0, 0.18)
	tween.tween_callback(beam.queue_free)
	get_tree().create_timer(0.5).timeout.connect(spark.queue_free)

func get_identity_snapshot() -> Dictionary:
	return {
		"base_id": base_id,
		"active_run": active_run,
		"passive": str(world.get_meta("base_identity_passive", "")) if world else "",
		"carry_bonus": int(player.get_meta("base_carry_bonus", 0)) if player else 0,
		"base_health_bonus": applied_health_bonus,
		"soul_charges": soul_charges,
		"webbed_count": nerubian_webbed_count
	}

func _circle_points(radius: float, segments: int, close_loop: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := segments + 1 if close_loop else segments
	for index in range(count):
		var angle := TAU * float(index % segments) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points
