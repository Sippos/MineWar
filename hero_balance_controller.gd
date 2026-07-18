extends Node

const ENEMY_STATUS_SCRIPT = preload("res://enemy_status.gd")
const GRAVE_MIGHT_ICON: Texture2D = preload("res://ability_icons/generated/UndeadKing_GraveMight.png")

const HERO_PROFILES := {
	"Dwarf": {"health": 40, "speed": 190.0, "dig_time": 0.36},
	"Mech": {"health": 52, "speed": 176.0, "dig_time": 0.34},
	"Shaman": {"health": 32, "speed": 205.0, "dig_time": 0.42},
	"Nerubian": {"health": 36, "speed": 215.0, "dig_time": 0.46},
	"Druid": {"health": 34, "speed": 210.0, "dig_time": 0.39},
	"Undead King": {"health": 38, "speed": 195.0, "dig_time": 0.43}
}

const HERO_SCALE_MULTIPLIERS := {
	"Dwarf": 1.0,
	"Mech": 1.08,
	"Shaman": 1.0,
	"Nerubian": 1.70,
	"Druid": 1.07,
	"Undead King": 1.02
}

var player: CharacterBody2D
var world: Node
var hero_abilities: Node
var applied_hero := ""

var nerubian_dig_cell = null
var nerubian_dig_timer := 0.0
var nerubian_feedback_timer := 0.0
var venom_attack_counter := 0
var last_attack_timer := 0.0
var last_attack_enemy: Node

var roots_regen_timer := 0.0
var druid_was_mole := false
var druid_mole_speed_bonus := 0.0
var druid_burrow_pulse_timer := 0.0

var grave_might_cooldown := 0.0
var grave_might_duration := 0.0
var grave_might_active := false

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	if player == null:
		queue_free()
		return
	world = player.get_parent()
	process_priority = 200
	_resolve_ability_controller()
	_apply_profile_once()
	_connect_existing_upgrade_menus()
	if world and not world.child_entered_tree.is_connected(_on_world_child_entered):
		world.child_entered_tree.connect(_on_world_child_entered)
	call_deferred("_late_setup")

func _late_setup() -> void:
	_resolve_ability_controller()
	_connect_existing_upgrade_menus()
	_apply_profile_once()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if hero_abilities == null or not is_instance_valid(hero_abilities):
		_resolve_ability_controller()
	_apply_profile_once()
	_apply_visual_fit()
	nerubian_feedback_timer = max(0.0, nerubian_feedback_timer - delta)
	grave_might_cooldown = max(0.0, grave_might_cooldown - delta)
	match _hero_name():
		"Nerubian":
			_process_nerubian(delta)
		"Druid":
			_process_druid(delta)
		"Undead King":
			_process_undead_king(delta)
		_:
			_clear_nerubian_dig()
			_end_druid_mole_bonus()
			_end_grave_might()

func _hero_name() -> String:
	return str(player.get("current_hero_name"))

func _action(suffix: String) -> String:
	return "p%d_%s" % [int(player.get("player_id")), suffix]

func _rpg_controller() -> Node:
	return player.get_node_or_null("HeroRPGController")

func _rpg_spell_damage(value: int) -> int:
	var rpg: Node = _rpg_controller()
	return int(rpg.call("scale_spell_damage", value)) if rpg != null and rpg.has_method("scale_spell_damage") else value

func _rpg_summon_damage(value: int) -> int:
	var rpg: Node = _rpg_controller()
	return int(rpg.call("scale_summon_damage", value)) if rpg != null and rpg.has_method("scale_summon_damage") else value

func _rpg_cooldown(value: float) -> float:
	var rpg: Node = _rpg_controller()
	return float(rpg.call("adjust_cooldown", value)) if rpg != null and rpg.has_method("adjust_cooldown") else value

func _rpg_duration(value: float) -> float:
	var rpg: Node = _rpg_controller()
	return float(rpg.call("adjust_duration", value)) if rpg != null and rpg.has_method("adjust_duration") else value

func _resolve_ability_controller() -> void:
	hero_abilities = player.get_node_or_null("HeroAbilities")

func _apply_profile_once() -> void:
	var hero := _hero_name()
	if hero == "" or hero == applied_hero or not HERO_PROFILES.has(hero):
		return
	var profile: Dictionary = HERO_PROFILES[hero]
	var previous_profile: Dictionary = HERO_PROFILES.get(applied_hero, {})
	var old_max_health := int(player.get("max_health"))
	var target_health := int(profile["health"])
	var can_replace_health: bool = old_max_health <= 30 or (not previous_profile.is_empty() and old_max_health == int(previous_profile.get("health", old_max_health)))
	if can_replace_health:
		var health_ratio: float = clampf(float(player.get("health")) / maxf(1.0, float(old_max_health)), 0.0, 1.0)
		player.set("max_health", target_health)
		player.set("health", maxi(1, int(round(float(target_health) * health_ratio))))
	var current_speed := float(player.get("base_speed"))
	var can_replace_speed: bool = abs(current_speed - 200.0) < 0.1 or (not previous_profile.is_empty() and abs(current_speed - float(previous_profile.get("speed", current_speed))) < 0.1)
	if can_replace_speed:
		player.set("base_speed", float(profile["speed"]))
	var current_dig_time := float(player.get("base_dig_time"))
	var can_replace_dig: bool = abs(current_dig_time - 0.4) < 0.01 or (not previous_profile.is_empty() and abs(current_dig_time - float(previous_profile.get("dig_time", current_dig_time))) < 0.01)
	if can_replace_dig:
		player.set("base_dig_time", float(profile["dig_time"]))
	applied_hero = hero
	_refresh_hud()

func _apply_visual_fit() -> void:
	var sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var hero := _hero_name()
	var multiplier := float(HERO_SCALE_MULTIPLIERS.get(hero, 1.0))
	var offset := Vector2.ZERO
	if hero == "Nerubian":
		offset = Vector2(0, -7)
	elif hero == "Druid" and bool(player.get("druid_mole_active")):
		multiplier = 1.20
		offset = Vector2(0, -3)
	elif hero == "Dwarf" and hero_abilities and bool(hero_abilities.get("avatar_active")):
		multiplier *= 1.18
	var base_scale = player.get("current_sprite_scale")
	if base_scale is Vector2:
		sprite.scale = base_scale * multiplier
	var base_position = player.get("current_sprite_position")
	if base_position is Vector2:
		sprite.position = base_position + offset

func _connect_existing_upgrade_menus() -> void:
	if world == null or hero_abilities == null:
		return
	_connect_upgrade_node(world)
	for node in world.find_children("*", "Node", true, false):
		_connect_upgrade_node(node)

func _connect_upgrade_node(node: Node) -> void:
	if node == null or hero_abilities == null or not node.has_signal("upgrade_selected"):
		return
	var callback := Callable(hero_abilities, "_on_upgrade_selected")
	if not node.is_connected("upgrade_selected", callback):
		node.connect("upgrade_selected", callback)

func _on_world_child_entered(node: Node) -> void:
	_connect_upgrade_node(node)
	if grave_might_active and node != null and node.is_in_group("undead_minions"):
		call_deferred("_buff_grave_minion", node)

# -----------------------------------------------------------------------------
# Nerubian: manual claw mining plus a venom cadence on basic attacks.
# Spiders remain the faster autonomous mining option, but the hero can no longer
# become trapped or feel non-functional when the brood pathing has no target.
# -----------------------------------------------------------------------------

func _process_nerubian(delta: float) -> void:
	_process_nerubian_claw_mining(delta)
	_process_nerubian_venom()

func _process_nerubian_claw_mining(delta: float) -> void:
	if bool(player.get("is_dead")) or world == null:
		_clear_nerubian_dig()
		return
	var active_ray = _active_mining_ray()
	if active_ray == null or not active_ray.is_colliding() or active_ray.get_collider() != _block_layer():
		_clear_nerubian_dig()
		return
	if Vector2(player.get("velocity")).length() >= 20.0:
		_clear_nerubian_dig()
		return
	var point: Vector2 = active_ray.get_collision_point()
	point += active_ray.target_position.normalized() * 5.0
	var block_layer := _block_layer()
	var cell := block_layer.local_to_map(block_layer.to_local(point))
	var source_id := block_layer.get_cell_source_id(cell)
	if source_id == -1 or _is_protected_cell(cell, source_id):
		_clear_nerubian_dig()
		return
	if nerubian_dig_cell == null or nerubian_dig_cell != cell:
		_clear_nerubian_dig()
		nerubian_dig_cell = cell
		nerubian_dig_timer = 0.0
	nerubian_dig_timer += delta
	player.set("nerubian_cast_timer", max(0.16, float(player.get("nerubian_cast_timer"))))
	var target_time := _nerubian_target_dig_time(source_id)
	_update_nerubian_damage_overlay(cell, nerubian_dig_timer / max(0.01, target_time))
	if nerubian_feedback_timer <= 0.0 and world.has_method("spawn_mining_feedback"):
		world.call("spawn_mining_feedback", block_layer.to_global(block_layer.map_to_local(cell)))
		nerubian_feedback_timer = 0.30
	if nerubian_dig_timer >= target_time:
		_finish_nerubian_dig(cell)

func _active_mining_ray():
	if Input.is_action_pressed(_action("right")):
		return player.get("ray_right")
	if Input.is_action_pressed(_action("left")):
		return player.get("ray_left")
	if Input.is_action_pressed(_action("down")):
		return player.get("ray_down")
	if Input.is_action_pressed(_action("up")):
		return player.get("ray_up")
	return null

func _nerubian_target_dig_time(source_id: int) -> float:
	var brood_rank := int(hero_abilities.get("brood_level")) if hero_abilities else 1
	var target_time: float = float(player.get("base_dig_time")) * 1.15
	var rpg: Node = _rpg_controller()
	if rpg != null and rpg.has_method("get_dig_time_multiplier"):
		target_time *= float(rpg.call("get_dig_time_multiplier"))
	target_time *= max(0.80, 1.0 - float(max(0, brood_rank - 1)) * 0.07)
	if source_id == 2:
		target_time *= 2.0
	elif source_id == 3:
		target_time *= 4.0
	return max(0.18, target_time)

func _update_nerubian_damage_overlay(cell: Vector2i, ratio: float) -> void:
	var damage_layer := _damage_layer()
	var front_damage_layer := _front_damage_layer()
	var front_layer := world.get_node_or_null("FrontWallLayer") as TileMapLayer
	if damage_layer:
		damage_layer.set_cell(cell, 7 if ratio < 0.66 else 8, Vector2i.ZERO)
	var below := Vector2i(cell.x, cell.y + 1)
	if front_damage_layer and front_layer and front_layer.get_cell_source_id(below) != -1:
		front_damage_layer.set_cell(below, 13 if ratio < 0.66 else 14, Vector2i.ZERO)

func _finish_nerubian_dig(cell: Vector2i) -> void:
	var block_layer := _block_layer()
	var damage_layer := _damage_layer()
	var front_damage_layer := _front_damage_layer()
	var below := Vector2i(cell.x, cell.y + 1)
	var had_gem := bool(world.call("has_gem", cell)) if world.has_method("has_gem") else false
	block_layer.erase_cell(cell)
	if damage_layer:
		damage_layer.erase_cell(cell)
	if front_damage_layer:
		front_damage_layer.erase_cell(below)
	if world.has_method("notify_tutorial_cell_dug"):
		world.call("notify_tutorial_cell_dug", cell, had_gem)
	if world.has_method("try_spawn_cave_reward"):
		world.call("try_spawn_cave_reward", cell)
	if world.has_method("spawn_mining_feedback"):
		world.call("spawn_mining_feedback", block_layer.to_global(block_layer.map_to_local(cell)), true, had_gem)
	if world.has_method("on_cell_dug"):
		world.call("on_cell_dug", cell)
	if had_gem and player.has_method("_spawn_dug_gems"):
		player.call("_spawn_dug_gems", cell, 1)
	_spawn_burst(block_layer.to_global(block_layer.map_to_local(cell)), Color(0.58, 0.24, 0.82, 0.9), 20)
	nerubian_dig_cell = null
	nerubian_dig_timer = 0.0

func _clear_nerubian_dig() -> void:
	if nerubian_dig_cell != null:
		var damage_layer := _damage_layer()
		var front_damage_layer := _front_damage_layer()
		if damage_layer:
			damage_layer.erase_cell(nerubian_dig_cell)
		if front_damage_layer:
			front_damage_layer.erase_cell(Vector2i(nerubian_dig_cell.x, nerubian_dig_cell.y + 1))
	nerubian_dig_cell = null
	nerubian_dig_timer = 0.0

func _process_nerubian_venom() -> void:
	var attack_timer := float(player.get("attack_timer"))
	var enemy = player.get("currently_attacking_enemy")
	if is_instance_valid(enemy):
		var completed: bool = enemy == last_attack_enemy and last_attack_timer > 0.02 and attack_timer <= 0.001
		if completed:
			venom_attack_counter += 1
			if venom_attack_counter >= 3:
				venom_attack_counter = 0
				_apply_venom_bite(enemy)
	last_attack_timer = attack_timer
	last_attack_enemy = enemy

func _apply_venom_bite(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	var intelligence := int(player.get("intelligence"))
	var web_rank := int(hero_abilities.get("web_level")) if hero_abilities else 0
	var damage: int = _rpg_spell_damage(10 + intelligence * 5 + web_rank * 6)
	if enemy.has_method("take_damage"):
		enemy.call("take_damage", damage)
	_apply_enemy_slow(enemy, 1.5 + web_rank * 0.25, max(0.45, 0.68 - web_rank * 0.06))
	_spawn_burst(enemy.global_position, Color(0.68, 0.30, 0.92, 0.9), 18)
	_show_notice("Venom Bite!", 0.65)

# -----------------------------------------------------------------------------
# Druid: Deep Roots now actually regenerates, while Mole Form gains a readable
# speed burst and an entry pulse that roots nearby threats.
# -----------------------------------------------------------------------------

func _process_druid(delta: float) -> void:
	var mole_active := bool(player.get("druid_mole_active"))
	if mole_active and not druid_was_mole:
		_begin_druid_mole_bonus()
	elif not mole_active and druid_was_mole:
		_end_druid_mole_bonus()
	druid_was_mole = mole_active
	if mole_active:
		druid_burrow_pulse_timer -= delta
		if druid_burrow_pulse_timer <= 0.0 and Vector2(player.get("velocity")).length() > 24.0:
			druid_burrow_pulse_timer = 0.9
			_druid_burrow_pulse()
	else:
		druid_burrow_pulse_timer = 0.0
	var roots_level := int(hero_abilities.get("deep_roots_level")) if hero_abilities else 0
	if roots_level <= 0:
		roots_regen_timer = 0.0
		return
	roots_regen_timer -= delta
	if roots_regen_timer > 0.0:
		return
	roots_regen_timer = max(0.55, 1.1 - roots_level * 0.12)
	var health := int(player.get("health"))
	var max_health := int(player.get("max_health"))
	if health < max_health:
		var heal := 1 + roots_level
		if Vector2(player.get("velocity")).length() < 8.0:
			heal += roots_level
		player.set("health", min(max_health, health + heal))
		_refresh_hud()

func _begin_druid_mole_bonus() -> void:
	if druid_mole_speed_bonus > 0.0:
		return
	var mole_rank := int(hero_abilities.get("mole_level")) if hero_abilities else 1
	druid_mole_speed_bonus = 28.0 + mole_rank * 10.0
	player.set("base_speed", float(player.get("base_speed")) + druid_mole_speed_bonus)
	var radius := 90.0 + mole_rank * 24.0
	var damage: int = _rpg_spell_damage(8 + mole_rank * 6 + int(player.get("intelligence")) * 4)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or player.global_position.distance_to(enemy.global_position) > radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", damage)
		_apply_enemy_stun(enemy, 0.35 + mole_rank * 0.12)
		_apply_enemy_slow(enemy, 2.0 + mole_rank * 0.3, 0.55)
	_spawn_burst(player.global_position, Color(0.28, 0.82, 0.36, 0.9), 30)
	_show_notice("Verdant Burrow!", 0.9)

func _druid_burrow_pulse() -> void:
	var mole_rank := int(hero_abilities.get("mole_level")) if hero_abilities else 1
	var radius := 62.0 + float(mole_rank) * 12.0
	var damage: int = _rpg_spell_damage(4 + mole_rank * 4 + int(player.get("intelligence")) * 2)
	var hit_any := false
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_2d := enemy as Node2D
		if player.global_position.distance_to(enemy_2d.global_position) > radius:
			continue
		hit_any = true
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", damage)
		_apply_enemy_slow(enemy, 1.0 + float(mole_rank) * 0.2, 0.68)
	if hit_any:
		_spawn_burst(player.global_position, Color(0.42, 0.78, 0.28, 0.72), 14)

func _end_druid_mole_bonus() -> void:
	if druid_mole_speed_bonus <= 0.0 or not is_instance_valid(player):
		druid_was_mole = false
		return
	player.set("base_speed", max(1.0, float(player.get("base_speed")) - druid_mole_speed_bonus))
	druid_mole_speed_bonus = 0.0
	druid_was_mole = false

# -----------------------------------------------------------------------------
# Undead King: Grave Might remains a permanent minion upgrade, but also becomes
# a real F/RB command ability. It empowers the army and detonates a grave pulse
# around each minion, giving the hero an active mid-cooldown combat decision.
# -----------------------------------------------------------------------------

func _process_undead_king(delta: float) -> void:
	if Input.is_action_just_pressed(_action("secondary")):
		_try_grave_might()
	if grave_might_active:
		grave_might_duration = max(0.0, grave_might_duration - delta)
		for minion in _owned_undead_minions():
			_buff_grave_minion(minion)
		if grave_might_duration <= 0.0:
			_end_grave_might()
	_update_grave_might_hud()

func _try_grave_might() -> void:
	if hero_abilities == null:
		return
	var level := int(hero_abilities.get("grave_might_level"))
	if level <= 0:
		_show_notice("Learn Grave Might at the next level up")
		return
	if grave_might_cooldown > 0.0:
		_show_notice("Grave Might ready in %.1fs" % grave_might_cooldown, 0.8)
		return
	var minions := _owned_undead_minions()
	if minions.is_empty() and hero_abilities.has_method("_try_summon_undead_minion"):
		hero_abilities.call("_try_summon_undead_minion")
		minions = _owned_undead_minions()
	if minions.is_empty():
		_show_notice("Raise a minion before commanding the grave", 0.9)
		return
	grave_might_active = true
	grave_might_duration = _rpg_duration(5.0 + level)
	grave_might_cooldown = _rpg_cooldown(max(8.0, 14.0 - level * 1.5))
	var hit_enemies := []
	for minion in minions:
		_buff_grave_minion(minion)
		minion.set("lifetime", min(float(minion.get("max_lifetime")), float(minion.get("lifetime")) + 8.0 + level * 2.0))
		_spawn_burst(minion.global_position, Color(0.52, 0.18, 0.78, 0.92), 24)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or hit_enemies.has(enemy):
				continue
			if minion.global_position.distance_to(enemy.global_position) <= 95.0 + level * 10.0:
				hit_enemies.append(enemy)
				if enemy.has_method("take_damage"):
					enemy.call("take_damage", _rpg_summon_damage(18 + level * 14 + int(player.get("intelligence")) * 4))
				_apply_enemy_stun(enemy, 0.25 + level * 0.12)
	_show_notice("GRAVE MIGHT!", 1.1)

func _buff_grave_minion(minion: Node) -> void:
	if not grave_might_active or not is_instance_valid(minion):
		return
	var level := int(hero_abilities.get("grave_might_level")) if hero_abilities else 1
	if not minion.has_meta("grave_might_base_speed"):
		minion.set_meta("grave_might_base_speed", float(minion.get("speed")))
		minion.set_meta("grave_might_base_damage", int(minion.get("attack_damage")))
		minion.set_meta("grave_might_base_interval", float(minion.get("attack_interval")))
	minion.set("speed", float(minion.get_meta("grave_might_base_speed")) * (1.25 + level * 0.08))
	minion.set("attack_damage", int(round(float(minion.get_meta("grave_might_base_damage")) * (1.22 + level * 0.10))))
	minion.set("attack_interval", max(0.28, float(minion.get_meta("grave_might_base_interval")) * (0.86 - level * 0.05)))

func _end_grave_might() -> void:
	if not grave_might_active:
		return
	grave_might_active = false
	grave_might_duration = 0.0
	for minion in _owned_undead_minions():
		if minion.has_meta("grave_might_base_speed"):
			minion.set("speed", float(minion.get_meta("grave_might_base_speed")))
			minion.set("attack_damage", int(minion.get_meta("grave_might_base_damage")))
			minion.set("attack_interval", float(minion.get_meta("grave_might_base_interval")))
			minion.remove_meta("grave_might_base_speed")
			minion.remove_meta("grave_might_base_damage")
			minion.remove_meta("grave_might_base_interval")

func _owned_undead_minions() -> Array:
	var result := []
	for minion in get_tree().get_nodes_in_group("undead_minions"):
		if is_instance_valid(minion) and minion.get("owner_player") == player:
			result.append(minion)
	return result

func _update_grave_might_hud() -> void:
	if hero_abilities == null:
		return
	var slots = hero_abilities.get("ability_slots")
	if not (slots is Dictionary):
		return
	var slot = slots.get("grave_might")
	if slot == null or not is_instance_valid(slot):
		return
	var level := int(hero_abilities.get("grave_might_level"))
	slot.tooltip_text = "Grave Might — command and empower all undead minions"
	var icon := slot.get_node_or_null("Root/Icon") as TextureRect
	var key_label := slot.get_node_or_null("Root/Key") as Label
	var overlay := slot.get_node_or_null("Root/CooldownOverlay") as ColorRect
	var timer := slot.get_node_or_null("Root/Timer") as Label
	var level_label := slot.get_node_or_null("Root/Level") as Label
	if icon:
		icon.texture = GRAVE_MIGHT_ICON
		icon.modulate = Color(1.2, 0.88, 1.35, 1.0) if grave_might_active else (Color(0.38, 0.38, 0.38, 0.85) if level <= 0 else Color.WHITE)
	if key_label:
		key_label.text = "F / RB"
	if overlay:
		var maximum: float = maxf(8.0, 14.0 - float(level) * 1.5)
		overlay.anchor_top = 1.0 - clamp(grave_might_cooldown / maximum, 0.0, 1.0)
		overlay.visible = grave_might_cooldown > 0.0 and not grave_might_active
	if timer:
		if level <= 0:
			timer.text = "LOCKED"
		elif grave_might_active:
			timer.text = "%.1f" % grave_might_duration
		elif grave_might_cooldown > 0.0:
			timer.text = "%d" % ceil(grave_might_cooldown)
		else:
			timer.text = ""
	if level_label:
		level_label.text = "L%d" % level if level > 0 else ""

# -----------------------------------------------------------------------------
# Shared helpers
# -----------------------------------------------------------------------------

func _block_layer() -> TileMapLayer:
	return world.get_node_or_null("BlockLayer") as TileMapLayer if world else null

func _damage_layer() -> TileMapLayer:
	return world.get_node_or_null("DamageLayer") as TileMapLayer if world else null

func _front_damage_layer() -> TileMapLayer:
	return world.get_node_or_null("FrontDamageLayer") as TileMapLayer if world else null

func _is_protected_cell(cell: Vector2i, source_id: int) -> bool:
	if (cell.y <= 1 and cell.x != 0) or cell.y < 0:
		return true
	return false

func _enemy_status(enemy: Node) -> Node:
	if not is_instance_valid(enemy):
		return null
	var status := enemy.get_node_or_null("HeroStatus")
	if status:
		return status
	status = Node.new()
	status.name = "HeroStatus"
	status.set_script(ENEMY_STATUS_SCRIPT)
	enemy.add_child(status)
	return status

func _apply_enemy_stun(enemy: Node, duration: float) -> void:
	var status := _enemy_status(enemy)
	if status and status.has_method("apply_stun"):
		status.call("apply_stun", duration, Vector2.ZERO)

func _apply_enemy_slow(enemy: Node, duration: float, factor: float) -> void:
	var status := _enemy_status(enemy)
	if status and status.has_method("apply_slow"):
		status.call("apply_slow", duration, factor)

func _spawn_burst(position: Vector2, color: Color, amount: int) -> void:
	if world == null:
		return
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.amount = amount
	burst.lifetime = 0.42
	burst.explosiveness = 0.95
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 10.0
	burst.initial_velocity_min = 65.0
	burst.initial_velocity_max = 165.0
	burst.damping_min = 130.0
	burst.damping_max = 240.0
	burst.scale_amount_min = 1.8
	burst.scale_amount_max = 4.5
	burst.color = color
	burst.global_position = position
	burst.z_index = 16
	world.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.8).timeout.connect(burst.queue_free)

func _show_notice(text: String, duration: float = 1.4) -> void:
	if world == null:
		return
	var hud := world.get_node_or_null("HUD")
	if hud and hud.has_method("show_notice"):
		hud.call("show_notice", text, duration)

func _refresh_hud() -> void:
	if world == null:
		return
	var hud := world.get_node_or_null("HUD")
	if hud and hud.has_method("update_player_health"):
		hud.call("update_player_health", int(player.get("health")), int(player.get("max_health")))
	if hud and hud.has_method("update_stats"):
		hud.call("update_stats", int(player.get("strength")), int(player.get("agility")), int(player.get("intelligence")))
