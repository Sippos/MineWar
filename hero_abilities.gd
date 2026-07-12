extends Node

const HERO_DWARF := "Dwarf"
const HERO_SHAMAN := "Shaman"
const HERO_NERUBIAN := "Nerubian"
const HERO_DRUID := "Druid"
const HERO_UNDEAD_KING := "Undead King"

const SHAMAN_TOTEM_SCENE = preload("res://shaman_totem.tscn")
const SPIDER_MINION_SCENE = preload("res://spider_minion.tscn")
const UNDEAD_MINION_SCENE = preload("res://undead_minion.tscn")
const UNDEAD_MINION_LIMIT := 3
const ENEMY_STATUS_SCRIPT = preload("res://enemy_status.gd")

const MAX_BASIC_LEVEL := 3
const ULTIMATE_REQUIRED_LEVEL := 6
const ICON_SIZE := Vector2(68, 68)

const ICON_PATHS := {
	"stomp": "res://ability_icons/placeholder_stomp.svg",
	"hammer": "res://ability_icons/placeholder_hammer.svg",
	"bash": "res://ability_icons/placeholder_bash.svg",
	"avatar": "res://ability_icons/placeholder_avatar.svg",
	"totem": "res://ability_icons/placeholder_totem.svg",
	"chain": "res://ability_icons/placeholder_chain.svg",
	"wisdom": "res://ability_icons/placeholder_wisdom.svg",
	"ascendance": "res://ability_icons/placeholder_ascendance.svg",
	"brood": "res://ability_icons/placeholder_brood.svg",
	"web": "res://ability_icons/placeholder_web.svg",
	"carapace": "res://ability_icons/placeholder_carapace.svg",
	"broodmother": "res://ability_icons/placeholder_broodmother.svg",
	"mole": "res://ability_icons/placeholder_avatar.svg",
	"raise_dead": "res://ability_icons/placeholder_brood.svg"
}

const STOMP_KNOWN_PATHS := [
	"res://StompSprite.png",
	"res://StompSprite.webp",
	"res://StompSprite.svg",
	"res://StompSprite.tres",
	"res://stomp_sprite.png",
	"res://stomp_icon.png",
	"res://sprites/StompSprite.png",
	"res://assets/StompSprite.png"
]

var player: CharacterBody2D
var world: Node
var tile_map: TileMapLayer
var damage_layer: TileMapLayer
var front_damage_layer: TileMapLayer

var hammer_level := 0
var bash_level := 0
var avatar_level := 0
var hammer_cooldown := 0.0
var avatar_cooldown := 0.0
var avatar_duration := 0.0
var avatar_active := false
var avatar_strength_bonus := 0
var avatar_health_bonus := 0
var avatar_speed_bonus := 0.0
var avatar_aura: CPUParticles2D
var avatar_dig_timer := 0.0
var bash_counter := 0
var last_attack_timer := 0.0
var last_attacking_enemy: Node
var last_digging_cell = null
var last_digging_source := -1
var last_stomp_cooldown := 0.0

var totem_level := 0
var chain_level := 0
var wisdom_level := 0
var ascendance_level := 0
var chain_cooldown := 0.0
var ascendance_cooldown := 0.0
var ascendance_duration := 0.0
var ascendance_active := false
var ascendance_int_bonus := 0
var ascendance_speed_bonus := 0.0
var shaman_support_tick := 0.0

var brood_level := 0
var web_level := 0
var carapace_level := 0
var broodmother_level := 0
var brood_cooldown := 0.0
var web_cooldown := 0.0
var broodmother_cooldown := 0.0
var broodmother_duration := 0.0
var broodmother_active := false
var carapace_regen_tick := 0.0

var mole_level := 1
var mole_cooldown := 0.0
var mole_duration := 0.0
var mole_active := false

var undead_summon_level := 1
var undead_summon_cooldown := 0.0

var facing_direction := Vector2.DOWN
var ability_bar: HBoxContainer
var ability_slots := {}
var icon_cache := {}
var current_hud_hero := ""
var configured_input_player_id := 0

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	if player == null:
		queue_free()
		return
	world = player.get_parent()
	tile_map = world.get_node_or_null("BlockLayer") if world else null
	damage_layer = world.get_node_or_null("DamageLayer") if world else null
	front_damage_layer = world.get_node_or_null("FrontDamageLayer") if world else null
	process_priority = 100
	_ensure_inputs()
	_initialize_starting_skill()
	if world:
		world.child_entered_tree.connect(_on_world_child_entered)
		for child in world.get_children():
			_configure_world_child(child)
	call_deferred("_ensure_hud")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if configured_input_player_id != _player_id():
		_ensure_inputs()
	_ensure_hud()
	_update_facing_direction()
	_tick_cooldowns(delta)
	var hero := _hero_name()
	if hero != current_hud_hero:
		_rebuild_hud()
	if bool(player.get("is_dead")):
		_cancel_temporary_forms()
		_update_ability_hud()
		return
	match hero:
		HERO_DWARF:
			_process_dwarf(delta)
		HERO_SHAMAN:
			_process_shaman(delta)
		HERO_NERUBIAN:
			_process_nerubian(delta)
		HERO_DRUID:
			_process_druid()
		HERO_UNDEAD_KING:
			_process_undead_king()
	_update_ability_hud()

func _hero_name() -> String:
	return str(player.get("current_hero_name"))

func _player_id() -> int:
	return int(player.get("player_id"))

func _action(suffix: String) -> String:
	return "p%d_%s" % [_player_id(), suffix]

func _ensure_inputs() -> void:
	var current_player_id := _player_id()
	var secondary_key: Key = KEY_F if current_player_id == 1 else KEY_KP_1
	var ultimate_key: Key = KEY_T if current_player_id == 1 else KEY_KP_2
	_ensure_input_action(_action("secondary"), secondary_key, JOY_BUTTON_RIGHT_SHOULDER)
	_ensure_input_action(_action("ultimate"), ultimate_key, JOY_BUTTON_LEFT_SHOULDER)
	configured_input_player_id = current_player_id

func _ensure_input_action(action_name: String, keycode: Key, joy_button: JoyButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var has_key := false
	var has_button := false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			has_key = true
		elif event is InputEventJoypadButton and event.button_index == joy_button:
			has_button = true
	if not has_key:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = keycode
		InputMap.action_add_event(action_name, key_event)
	if not has_button:
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = joy_button
		joy_event.device = max(0, _player_id() - 1)
		InputMap.action_add_event(action_name, joy_event)

func _initialize_starting_skill() -> void:
	match _hero_name():
		HERO_DWARF:
			if int(player.get("stomp_level")) <= 0:
				player.set("stomp_level", 1)
		HERO_SHAMAN:
			totem_level = 1
		HERO_NERUBIAN:
			brood_level = 1

func _tick_cooldowns(delta: float) -> void:
	hammer_cooldown = max(0.0, hammer_cooldown - delta)
	avatar_cooldown = max(0.0, avatar_cooldown - delta)
	avatar_dig_timer = max(0.0, avatar_dig_timer - delta)
	chain_cooldown = max(0.0, chain_cooldown - delta)
	ascendance_cooldown = max(0.0, ascendance_cooldown - delta)
	brood_cooldown = max(0.0, brood_cooldown - delta)
	web_cooldown = max(0.0, web_cooldown - delta)
	broodmother_cooldown = max(0.0, broodmother_cooldown - delta)
	mole_cooldown = max(0.0, mole_cooldown - delta)
	undead_summon_cooldown = max(0.0, undead_summon_cooldown - delta)
	if mole_active:
		mole_duration = max(0.0, mole_duration - delta)
		if mole_duration <= 0.0:
			_end_mole_form()
	if avatar_active:
		avatar_duration = max(0.0, avatar_duration - delta)
		if avatar_duration <= 0.0:
			_end_avatar()
	if ascendance_active:
		ascendance_duration = max(0.0, ascendance_duration - delta)
		if ascendance_duration <= 0.0:
			_end_ascendance()
	if broodmother_active:
		broodmother_duration = max(0.0, broodmother_duration - delta)
		if broodmother_duration <= 0.0:
			_end_broodmother()

func _update_facing_direction() -> void:
	var velocity_value = player.get("velocity")
	if velocity_value is Vector2 and velocity_value.length() > 12.0:
		facing_direction = velocity_value.normalized()
		return
	var input_dir := Vector2(
		Input.get_axis(_action("left"), _action("right")),
		Input.get_axis(_action("up"), _action("down"))
	)
	if input_dir.length() > 0.2:
		facing_direction = input_dir.normalized()

func _cardinal_direction() -> Vector2:
	if abs(facing_direction.x) > abs(facing_direction.y):
		return Vector2(sign(facing_direction.x), 0.0)
	return Vector2(0.0, sign(facing_direction.y) if facing_direction.y != 0.0 else 1.0)

func _cardinal_cell_step() -> Vector2i:
	var direction := _cardinal_direction()
	return Vector2i(int(direction.x), int(direction.y))

func _process_dwarf(_delta: float) -> void:
	if Input.is_action_just_pressed(_action("secondary")):
		_try_throw_hammer()
	if Input.is_action_just_pressed(_action("ultimate")):
		_try_activate_avatar()
	_track_melee_bash()
	_track_mining_bash()
	_track_stomp_cast()
	if avatar_active:
		_apply_avatar_visuals()
		_try_avatar_auto_dig()

func _try_throw_hammer() -> void:
	if hammer_level <= 0:
		_show_notice("Learn Throwing Hammer at the next level up")
		return
	if hammer_cooldown > 0.0:
		_show_notice("Hammer ready in %.1fs" % hammer_cooldown, 0.8)
		return
	hammer_cooldown = _hammer_max_cooldown()
	var direction := _cardinal_direction()
	var range_value := 240.0 + hammer_level * 45.0
	var origin := player.global_position + Vector2(0, -24)
	var end_position := origin + direction * range_value
	_spawn_hammer_visual(origin, end_position)
	_hit_enemies_with_hammer(origin, direction, range_value)
	_break_hammer_tiles(direction)
	_show_notice("Throwing Hammer!")

func _hammer_max_cooldown() -> float:
	return max(4.5, 9.0 - hammer_level * 0.75 - (int(player.get("intelligence")) - 1) * 0.08)

func _hit_enemies_with_hammer(origin: Vector2, direction: Vector2, range_value: float) -> void:
	var candidates := []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_center: Vector2 = enemy.global_position + Vector2(0, 8)
		var to_enemy := enemy_center - origin
		var forward_distance := to_enemy.dot(direction)
		var side_distance: float = abs(to_enemy.cross(direction))
		if forward_distance >= 0.0 and forward_distance <= range_value and side_distance <= 42.0:
			candidates.append({"enemy": enemy, "distance": forward_distance})
	candidates.sort_custom(func(a, b): return float(a["distance"]) < float(b["distance"]))
	var hit_limit := 3 if avatar_active else 1
	var damage_value := 70 + hammer_level * 55 + int(player.get("strength")) * 16
	for i in range(min(hit_limit, candidates.size())):
		var enemy = candidates[i]["enemy"]
		_apply_enemy_stun(enemy, 0.75 + hammer_level * 0.2, direction * (150.0 + hammer_level * 20.0))
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage_value)

func _break_hammer_tiles(direction: Vector2) -> void:
	if tile_map == null:
		return
	var origin_cell := tile_map.local_to_map(tile_map.to_local(player.global_position))
	var step := Vector2i(int(direction.x), int(direction.y))
	var tiles_to_break := hammer_level + (2 if avatar_active else 0)
	var broken := 0
	for distance in range(1, tiles_to_break + 5):
		var cell := origin_cell + step * distance
		var source_id := tile_map.get_cell_source_id(cell)
		if source_id == -1:
			continue
		if _is_protected_tile(cell, source_id):
			break
		if _break_soft_tile(cell):
			broken += 1
		if broken >= tiles_to_break:
			break

func _spawn_hammer_visual(origin: Vector2, end_position: Vector2) -> void:
	if world == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = _get_icon("hammer")
	sprite.global_position = origin
	sprite.scale = Vector2(0.62, 0.62)
	sprite.z_index = 20
	world.add_child(sprite)
	var tween := sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "global_position", end_position, 0.28)
	tween.tween_property(sprite, "rotation", TAU * 3.0, 0.28)
	tween.tween_property(sprite, "scale", Vector2(0.38, 0.38), 0.28)
	tween.set_parallel(false)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.08)
	tween.tween_callback(sprite.queue_free)

func _track_melee_bash() -> void:
	var attack_timer := float(player.get("attack_timer"))
	var attacking_enemy = player.get("currently_attacking_enemy")
	if bash_level > 0 and is_instance_valid(attacking_enemy):
		var attack_completed: bool = attacking_enemy == last_attacking_enemy and last_attack_timer > 0.02 and attack_timer <= 0.001
		if attack_completed:
			_register_bash_attack(attacking_enemy)
	last_attack_timer = attack_timer
	last_attacking_enemy = attacking_enemy

func _track_mining_bash() -> void:
	if tile_map == null:
		return
	var digging_cell = player.get("currently_digging_cell")
	if digging_cell != null:
		if last_digging_cell == null or digging_cell != last_digging_cell:
			last_digging_cell = digging_cell
			last_digging_source = tile_map.get_cell_source_id(digging_cell)
	elif last_digging_cell != null:
		var was_dug := last_digging_source != -1 and tile_map.get_cell_source_id(last_digging_cell) == -1
		if bash_level > 0 and was_dug:
			_register_bash_mining(last_digging_cell)
		last_digging_cell = null
		last_digging_source = -1

func _bash_threshold() -> int:
	return 2 if avatar_active else 3

func _advance_bash_counter() -> bool:
	bash_counter += 1
	if bash_counter >= _bash_threshold():
		bash_counter = 0
		return true
	return false

func _register_bash_attack(primary_enemy: Node) -> void:
	if not _advance_bash_counter():
		return
	var bonus_damage := 25 + bash_level * 25 + int(player.get("strength")) * 8
	var knockback := player.global_position.direction_to(primary_enemy.global_position) * (115.0 + bash_level * 25.0)
	_apply_enemy_stun(primary_enemy, 0.35 + bash_level * 0.2, knockback)
	if primary_enemy.has_method("take_damage"):
		primary_enemy.take_damage(bonus_damage)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == primary_enemy or not is_instance_valid(enemy):
			continue
		if primary_enemy.global_position.distance_to(enemy.global_position) <= 78.0:
			if enemy.has_method("take_damage"):
				enemy.take_damage(int(bonus_damage * 0.5))
			_apply_enemy_stun(enemy, 0.18 + bash_level * 0.08, knockback * 0.45)
	_spawn_burst(primary_enemy.global_position, Color(1.0, 0.72, 0.2, 0.9), 22)
	_show_notice("Dwarven Bash!")

func _register_bash_mining(dug_cell: Vector2i) -> void:
	if not _advance_bash_counter():
		return
	var target_cell := dug_cell + _cardinal_cell_step()
	if _break_soft_tile(target_cell):
		_spawn_burst(tile_map.to_global(tile_map.map_to_local(target_cell)), Color(1.0, 0.72, 0.2, 0.9), 22)
		_show_notice("Bash smashed the next block!")

func _track_stomp_cast() -> void:
	var current_cooldown := float(player.get("stomp_cooldown_timer"))
	var stomp_cast := current_cooldown > last_stomp_cooldown + 0.45
	if stomp_cast and int(player.get("stomp_level")) > 0:
		var stomp_rank := int(player.get("stomp_level"))
		var base_radius := 100.0 + stomp_rank * 20.0
		var radius := base_radius + (55.0 if avatar_active else 0.0)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			var distance := player.global_position.distance_to(enemy.global_position)
			if distance <= radius:
				var push := player.global_position.direction_to(enemy.global_position) * 80.0
				_apply_enemy_stun(enemy, 0.45 + stomp_rank * 0.18, push)
				if avatar_active and distance > base_radius and enemy.has_method("take_damage"):
					enemy.take_damage(12 * stomp_rank * int(player.get("strength")))
	last_stomp_cooldown = current_cooldown

func _try_activate_avatar() -> void:
	if avatar_level <= 0 or int(player.get("level")) < ULTIMATE_REQUIRED_LEVEL:
		_show_notice("Avatar unlocks at hero level 6")
		return
	if avatar_cooldown > 0.0:
		_show_notice("Avatar ready in %.1fs" % avatar_cooldown, 0.8)
		return
	if avatar_active:
		return
	avatar_active = true
	avatar_duration = 12.0
	avatar_cooldown = 60.0
	avatar_strength_bonus = max(2, int(ceil(int(player.get("strength")) * 0.5)))
	avatar_health_bonus = 50
	avatar_speed_bonus = 45.0
	player.set("strength", int(player.get("strength")) + avatar_strength_bonus)
	player.set("base_speed", float(player.get("base_speed")) + avatar_speed_bonus)
	player.set("max_health", int(player.get("max_health")) + avatar_health_bonus)
	player.set("health", int(player.get("health")) + avatar_health_bonus)
	_spawn_avatar_aura()
	_refresh_stats_hud()
	_show_notice("AVATAR OF THE MOUNTAIN!")

func _end_avatar() -> void:
	if not avatar_active:
		return
	avatar_active = false
	player.set("strength", max(1, int(player.get("strength")) - avatar_strength_bonus))
	player.set("base_speed", max(1.0, float(player.get("base_speed")) - avatar_speed_bonus))
	player.set("max_health", max(1, int(player.get("max_health")) - avatar_health_bonus))
	player.set("health", min(int(player.get("health")), int(player.get("max_health"))))
	avatar_strength_bonus = 0
	avatar_health_bonus = 0
	avatar_speed_bonus = 0.0
	if is_instance_valid(avatar_aura):
		avatar_aura.queue_free()
	avatar_aura = null
	var sprite := player.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color.WHITE
		var normal_scale = player.get("current_sprite_scale")
		if normal_scale is Vector2:
			sprite.scale = normal_scale
	_refresh_stats_hud()

func _apply_avatar_visuals() -> void:
	var sprite := player.get_node_or_null("Sprite2D")
	if sprite:
		var normal_scale = player.get("current_sprite_scale")
		if normal_scale is Vector2:
			sprite.scale = normal_scale * 1.18
		sprite.modulate = Color(1.25, 1.02, 0.52, 1.0)

func _spawn_avatar_aura() -> void:
	avatar_aura = CPUParticles2D.new()
	avatar_aura.amount = 34
	avatar_aura.lifetime = 0.9
	avatar_aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	avatar_aura.emission_sphere_radius = 28.0
	avatar_aura.direction = Vector2(0, -1)
	avatar_aura.spread = 180.0
	avatar_aura.gravity = Vector2(0, -20)
	avatar_aura.initial_velocity_min = 10.0
	avatar_aura.initial_velocity_max = 45.0
	avatar_aura.scale_amount_min = 1.5
	avatar_aura.scale_amount_max = 4.0
	avatar_aura.color = Color(1.0, 0.68, 0.16, 0.75)
	avatar_aura.position = Vector2(0, -22)
	avatar_aura.z_index = 12
	player.add_child(avatar_aura)
	avatar_aura.emitting = true

func _try_avatar_auto_dig() -> void:
	if avatar_dig_timer > 0.0 or tile_map == null:
		return
	var velocity_value = player.get("velocity")
	if not (velocity_value is Vector2) or velocity_value.length() < 20.0:
		return
	var origin_cell := tile_map.local_to_map(tile_map.to_local(player.global_position))
	if _break_soft_tile(origin_cell + _cardinal_cell_step()):
		avatar_dig_timer = 0.24

func _process_shaman(delta: float) -> void:
	if Input.is_action_just_pressed(_action("stomp")):
		_try_open_totem_wheel()
	elif Input.is_action_just_released(_action("stomp")) and bool(player.get("shaman_wheel_open")):
		player.call("_cast_selected_shaman_totem")
	if Input.is_action_just_pressed(_action("secondary")):
		_try_chain_lightning()
	if Input.is_action_just_pressed(_action("ultimate")):
		_try_ascendance()
	_process_shaman_support(delta)

func _try_open_totem_wheel() -> void:
	if totem_level <= 0:
		_show_notice("Learn Totemic Invocation first")
		return
	player.call("_try_open_shaman_totem_wheel")

func _totem_max_cooldown() -> float:
	var cooldown := 8.0 - totem_level * 0.7 - wisdom_level * 0.45
	if ascendance_active:
		cooldown *= 0.55
	return max(3.0, cooldown)

func _configure_shaman_totem(totem: Node) -> void:
	if _hero_name() != HERO_SHAMAN:
		return
	totem.set_meta("hero_owner_id", player.get_instance_id())
	totem.set_meta("totem_rank", totem_level)
	var lifetime_value := 18.0 + totem_level * 5.0 + wisdom_level * 3.0
	var radius_value := 145.0 + totem_level * 24.0 + wisdom_level * 12.0
	if ascendance_active:
		lifetime_value = max(lifetime_value, ascendance_duration + 3.0)
		radius_value += 55.0
	totem.set("lifetime", lifetime_value)
	totem.set("aura_radius", radius_value)
	player.set("shaman_spell_cooldown_timer", _totem_max_cooldown())

func _process_shaman_support(delta: float) -> void:
	shaman_support_tick -= delta
	if shaman_support_tick > 0.0:
		return
	shaman_support_tick = 0.5
	var extra_heal: int = max(0, totem_level + wisdom_level - 1)
	for totem in get_tree().get_nodes_in_group("shaman_totems"):
		if not _is_owned_totem(totem):
			continue
		var totem_type := str(totem.get("totem_type"))
		if totem_type == "heal" and extra_heal > 0 and totem.has_method("affects_player") and totem.affects_player(player):
			player.set("health", min(int(player.get("max_health")), int(player.get("health")) + extra_heal))
			_refresh_stats_hud()
		elif totem_type == "radar":
			var radius := float(totem.get("aura_radius"))
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) and totem.global_position.distance_to(enemy.global_position) <= radius:
					_apply_enemy_slow(enemy, 0.75, max(0.45, 0.82 - totem_level * 0.08 - wisdom_level * 0.04))

func _is_owned_totem(totem: Node) -> bool:
	return is_instance_valid(totem) and int(totem.get_meta("hero_owner_id", -1)) == player.get_instance_id()

func _try_chain_lightning() -> void:
	if chain_level <= 0:
		_show_notice("Learn Chain Lightning at the next level up")
		return
	if chain_cooldown > 0.0:
		_show_notice("Chain Lightning ready in %.1fs" % chain_cooldown, 0.8)
		return
	var target := _find_primary_enemy(330.0)
	if target == null:
		_show_notice("No enemy in range", 0.8)
		return
	chain_cooldown = _chain_max_cooldown()
	var hit_enemies := [target]
	var current = target
	var jumps := 1 + chain_level
	for _jump in range(jumps - 1):
		var next_enemy = _nearest_unhit_enemy(current.global_position, hit_enemies, 175.0)
		if next_enemy == null:
			break
		hit_enemies.append(next_enemy)
		current = next_enemy
	var points := PackedVector2Array([player.global_position + Vector2(0, -22)])
	var damage_value := 35 + chain_level * 38 + int(player.get("intelligence")) * 12
	for i in range(hit_enemies.size()):
		var enemy = hit_enemies[i]
		points.append(enemy.global_position + Vector2(0, 4))
		if enemy.has_method("take_damage"):
			enemy.take_damage(int(damage_value * pow(0.82, i)))
		_apply_enemy_stun(enemy, 0.12 + chain_level * 0.05, Vector2.ZERO)
	_spawn_lightning_line(points)
	_show_notice("Chain Lightning!")

func _chain_max_cooldown() -> float:
	var cooldown := 9.0 - chain_level * 0.75 - wisdom_level * 0.3
	if ascendance_active:
		cooldown *= 0.45
	return max(2.5, cooldown)

func _find_primary_enemy(max_range: float) -> Node:
	var origin := player.global_position
	var direction := _cardinal_direction()
	var best: Node = null
	var best_score := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var offset: Vector2 = enemy.global_position - origin
		var distance := offset.length()
		if distance > max_range:
			continue
		var dot := direction.dot(offset.normalized()) if distance > 0.0 else 1.0
		if dot < -0.15:
			continue
		var score := distance - dot * 75.0
		if score < best_score:
			best_score = score
			best = enemy
	return best

func _nearest_unhit_enemy(origin: Vector2, excluded: Array, max_range: float) -> Node:
	var best: Node = null
	var best_distance := max_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or excluded.has(enemy):
			continue
		var distance := origin.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best

func _spawn_lightning_line(points: PackedVector2Array) -> void:
	if world == null or points.size() < 2:
		return
	var line := Line2D.new()
	line.width = 5.0
	line.default_color = Color(0.35, 0.78, 1.0, 0.95)
	line.points = points
	line.z_index = 25
	world.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.22)
	tween.tween_callback(line.queue_free)

func _try_ascendance() -> void:
	if ascendance_level <= 0 or int(player.get("level")) < ULTIMATE_REQUIRED_LEVEL:
		_show_notice("Ascendance unlocks at hero level 6")
		return
	if ascendance_cooldown > 0.0:
		_show_notice("Ascendance ready in %.1fs" % ascendance_cooldown, 0.8)
		return
	if ascendance_active:
		return
	ascendance_active = true
	ascendance_duration = 12.0
	ascendance_cooldown = 65.0
	ascendance_int_bonus = 2 + wisdom_level
	ascendance_speed_bonus = 30.0
	player.set("intelligence", int(player.get("intelligence")) + ascendance_int_bonus)
	player.set("base_speed", float(player.get("base_speed")) + ascendance_speed_bonus)
	chain_cooldown = 0.0
	_spawn_all_totems()
	_spawn_burst(player.global_position, Color(0.25, 0.72, 1.0, 0.9), 44)
	_refresh_stats_hud()
	_show_notice("ANCESTRAL ASCENDANCE!")

func _spawn_all_totems() -> void:
	if world == null:
		return
	var types := ["dig", "heal", "radar", "gem"]
	var offsets := [Vector2(0, -56), Vector2(56, 0), Vector2(0, 56), Vector2(-56, 0)]
	for i in range(types.size()):
		var totem = SHAMAN_TOTEM_SCENE.instantiate()
		totem.set("totem_type", types[i])
		if types[i] == "dig":
			totem.set("follow_target", player)
		totem.global_position = player.global_position + offsets[i]
		world.add_child(totem)

func _end_ascendance() -> void:
	if not ascendance_active:
		return
	ascendance_active = false
	player.set("intelligence", max(1, int(player.get("intelligence")) - ascendance_int_bonus))
	player.set("base_speed", max(1.0, float(player.get("base_speed")) - ascendance_speed_bonus))
	ascendance_int_bonus = 0
	ascendance_speed_bonus = 0.0
	_refresh_stats_hud()

func _process_druid() -> void:
	if Input.is_action_just_pressed(_action("stomp")):
		_try_cast_mole_form()

func _try_cast_mole_form() -> void:
	if mole_cooldown > 0.0:
		_show_notice("Mole Form ready in %.1fs" % mole_cooldown, 0.8)
		return
	mole_active = true
	mole_duration = 6.0 + float(mole_level) * 2.0
	mole_cooldown = max(8.0, 16.0 - float(mole_level))
	player.set("druid_mole_active", true)
	_show_notice("Mole Form!")

func _end_mole_form() -> void:
	if not mole_active:
		return
	mole_active = false
	player.set("druid_mole_active", false)

func _process_undead_king() -> void:
	if Input.is_action_just_pressed(_action("stomp")):
		_try_summon_undead_minion()

func _try_summon_undead_minion() -> void:
	if undead_summon_cooldown > 0.0:
		_show_notice("Raise Dead ready in %.1fs" % undead_summon_cooldown, 0.8)
		return
	if world == null:
		return
	if _owned_undead_minions().size() >= UNDEAD_MINION_LIMIT:
		_show_notice("Undead minion limit reached", 0.8)
		return
	var minion = UNDEAD_MINION_SCENE.instantiate()
	minion.set("owner_player", player)
	minion.set("max_lifetime", 36.0 + float(int(player.get("intelligence")) - 1) * 2.0)
	minion.set("attack_damage", 10 + int(player.get("intelligence")) * 4)
	minion.global_position = player.global_position + _cardinal_direction() * 42.0
	world.add_child(minion)
	player.set("undead_cast_timer", 8.0 / 12.0)
	player.call("_reset_action_animation")
	undead_summon_cooldown = max(5.0, 11.0 - float(int(player.get("intelligence")) - 1) * 0.25)
	_spawn_burst(minion.global_position, Color(0.55, 0.25, 0.8, 0.9), 28)
	_show_notice("Raised Undead Minion!")

func _owned_undead_minions() -> Array:
	var result := []
	for minion in get_tree().get_nodes_in_group("undead_minions"):
		if is_instance_valid(minion) and minion.get("owner_player") == player:
			result.append(minion)
	return result

func _process_nerubian(delta: float) -> void:
	if Input.is_action_just_pressed(_action("stomp")):
		_try_spawn_brood(false)
	if Input.is_action_just_pressed(_action("secondary")):
		_try_web_burst()
	if Input.is_action_just_pressed(_action("ultimate")):
		_try_broodmother()
	_process_carapace(delta)

func _brood_max_count() -> int:
	return 2 + brood_level

func _brood_max_cooldown() -> float:
	return max(2.4, 5.8 - brood_level * 0.75 - carapace_level * 0.15)

func _try_spawn_brood(ignore_limit: bool) -> bool:
	if brood_level <= 0:
		_show_notice("Learn Spawn Brood first")
		return false
	if brood_cooldown > 0.0 and not ignore_limit:
		_show_notice("Brood ready in %.1fs" % brood_cooldown, 0.8)
		return false
	var base = world.get_node_or_null("Base") if world else null
	if base and base.get("player_in_zone") == true and not ignore_limit:
		return false
	if not ignore_limit and _owned_spiders().size() >= _brood_max_count():
		_show_notice("Brood limit reached", 0.8)
		return false
	var spider = SPIDER_MINION_SCENE.instantiate()
	spider.set("owner_player", player)
	_configure_spider(spider)
	spider.global_position = player.global_position + Vector2(randf_range(-20, 20), randf_range(-12, 12))
	world.add_child(spider)
	if not ignore_limit:
		brood_cooldown = _brood_max_cooldown()
		player.set("nerubian_spawn_cooldown_timer", brood_cooldown)
		_show_notice("Spawned Brood Spider")
	return true

func _configure_spider(spider: Node) -> void:
	if spider == null:
		return
	spider.set("max_lifetime", 48.0 + brood_level * 14.0 + carapace_level * 6.0)
	spider.set("lifetime", float(spider.get("max_lifetime")))
	spider.set("speed", 112.0 + brood_level * 17.0)
	spider.set_meta("hero_owner_id", player.get_instance_id())
	if broodmother_active:
		_buff_spider(spider)

func _owned_spiders() -> Array:
	var result := []
	for spider in get_tree().get_nodes_in_group("nerubian_spiders"):
		if is_instance_valid(spider) and spider.get("owner_player") == player:
			result.append(spider)
	return result

func _try_web_burst() -> void:
	if web_level <= 0:
		_show_notice("Learn Web Burst at the next level up")
		return
	if web_cooldown > 0.0:
		_show_notice("Web Burst ready in %.1fs" % web_cooldown, 0.8)
		return
	web_cooldown = max(5.5, 10.5 - web_level * 1.1 - carapace_level * 0.2)
	_cast_web_burst(115.0 + web_level * 35.0, 0.9 + web_level * 0.55, 18 + web_level * 24)
	_show_notice("Web Burst!")

func _cast_web_burst(radius: float, root_duration: float, base_damage: int) -> void:
	var damage_value := base_damage + int(player.get("intelligence")) * 7
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if player.global_position.distance_to(enemy.global_position) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage_value)
			_apply_enemy_stun(enemy, root_duration, Vector2.ZERO)
			_apply_enemy_slow(enemy, root_duration + 1.2, 0.55)
	_spawn_web_visual(radius)

func _spawn_web_visual(radius: float) -> void:
	if world == null:
		return
	var center := player.global_position
	for i in range(8):
		var line := Line2D.new()
		line.width = 2.5
		line.default_color = Color(0.82, 0.9, 1.0, 0.8)
		var angle := TAU * float(i) / 8.0
		line.points = PackedVector2Array([center, center + Vector2.from_angle(angle) * radius])
		line.z_index = 20
		world.add_child(line)
		var tween := line.create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 0.45)
		tween.tween_callback(line.queue_free)

func _process_carapace(delta: float) -> void:
	if carapace_level <= 0:
		return
	carapace_regen_tick -= delta
	if carapace_regen_tick > 0.0:
		return
	carapace_regen_tick = 1.0
	if int(player.get("health")) < int(player.get("max_health")):
		var regen := carapace_level + (2 if broodmother_active else 0)
		player.set("health", min(int(player.get("max_health")), int(player.get("health")) + regen))
		_refresh_stats_hud()

func _try_broodmother() -> void:
	if broodmother_level <= 0 or int(player.get("level")) < ULTIMATE_REQUIRED_LEVEL:
		_show_notice("Broodmother's Call unlocks at hero level 6")
		return
	if broodmother_cooldown > 0.0:
		_show_notice("Broodmother ready in %.1fs" % broodmother_cooldown, 0.8)
		return
	if broodmother_active:
		return
	broodmother_active = true
	broodmother_duration = 14.0
	broodmother_cooldown = 70.0
	for _i in range(3):
		_try_spawn_brood(true)
	for spider in _owned_spiders():
		_buff_spider(spider)
	_cast_web_burst(210.0, 2.0, 55)
	_spawn_burst(player.global_position, Color(0.72, 0.35, 1.0, 0.9), 48)
	_show_notice("BROODMOTHER'S CALL!")

func _buff_spider(spider: Node) -> void:
	if not is_instance_valid(spider):
		return
	if not spider.has_meta("broodmother_base_speed"):
		spider.set_meta("broodmother_base_speed", float(spider.get("speed")))
	spider.set("speed", float(spider.get_meta("broodmother_base_speed")) * 1.45)
	spider.set("lifetime", float(spider.get("lifetime")) + 15.0)

func _end_broodmother() -> void:
	if not broodmother_active:
		return
	broodmother_active = false
	for spider in _owned_spiders():
		if spider.has_meta("broodmother_base_speed"):
			spider.set("speed", float(spider.get_meta("broodmother_base_speed")))
			spider.remove_meta("broodmother_base_speed")

func _on_world_child_entered(node: Node) -> void:
	_configure_world_child(node)
	_try_connect_level_menu(node)

func _configure_world_child(node: Node) -> void:
	if node == null:
		return
	var script = node.get_script()
	var script_path := str(script.resource_path) if script != null else ""
	if script_path == "res://shaman_totem.gd":
		_configure_shaman_totem(node)
	elif script_path == "res://spider_minion.gd" and node.get("owner_player") == player:
		_configure_spider(node)

func _try_connect_level_menu(node: Node) -> void:
	if node == null or not node.has_signal("upgrade_selected"):
		return
	var callable := Callable(self, "_on_upgrade_selected")
	if not node.is_connected("upgrade_selected", callable):
		node.connect("upgrade_selected", callable)

func _is_protected_tile(cell: Vector2i, source_id: int) -> bool:
	if (cell.y <= 1 and cell.x != 0) or cell.y < 0:
		return true
	return source_id == 2 or source_id == 3

func _break_soft_tile(cell: Vector2i) -> bool:
	if tile_map == null:
		return false
	var source_id := tile_map.get_cell_source_id(cell)
	if source_id == -1 or _is_protected_tile(cell, source_id):
		return false
	tile_map.erase_cell(cell)
	if damage_layer:
		damage_layer.erase_cell(cell)
	var below_cell := Vector2i(cell.x, cell.y + 1)
	if front_damage_layer:
		front_damage_layer.erase_cell(below_cell)
	var cell_had_gem := false
	if world and world.has_method("has_gem"):
		cell_had_gem = bool(world.has_gem(cell))
	if world and world.has_method("on_cell_dug"):
		world.on_cell_dug(cell)
	if cell_had_gem and player.has_method("_spawn_dug_gems"):
		player.call("_spawn_dug_gems", cell, 1)
	return true

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

func _apply_enemy_stun(enemy: Node, duration: float, knockback: Vector2) -> void:
	var status := _enemy_status(enemy)
	if status and status.has_method("apply_stun"):
		status.apply_stun(duration, knockback)

func _apply_enemy_slow(enemy: Node, duration: float, factor: float) -> void:
	var status := _enemy_status(enemy)
	if status and status.has_method("apply_slow"):
		status.apply_slow(duration, factor)

func _spawn_burst(position: Vector2, color: Color, amount: int) -> void:
	if world == null:
		return
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.amount = amount
	burst.lifetime = 0.45
	burst.explosiveness = 0.95
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 10.0
	burst.initial_velocity_min = 75.0
	burst.initial_velocity_max = 190.0
	burst.damping_min = 150.0
	burst.damping_max = 250.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 5.0
	burst.color = color
	burst.global_position = position
	burst.z_index = 15
	world.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.8).timeout.connect(burst.queue_free)

func _cancel_temporary_forms() -> void:
	if avatar_active:
		_end_avatar()
	if ascendance_active:
		_end_ascendance()
	if broodmother_active:
		_end_broodmother()
	if mole_active:
		_end_mole_form()

func get_level_up_options() -> Array:
	var options := []
	match _hero_name():
		HERO_DWARF:
			options = [
				_option("stomp", "Ground Stomp", "Area damage and stun", int(player.get("stomp_level")), MAX_BASIC_LEVEL, 0),
				_option("hammer", "Throwing Hammer", "Ranged stun that breaks soft blocks", hammer_level, MAX_BASIC_LEVEL, 0),
				_option("bash", "Dwarven Bash", "Every third attack or mined block is empowered", bash_level, MAX_BASIC_LEVEL, 0),
				_option("avatar", "Avatar of the Mountain", "Transform into a mining and combat powerhouse", avatar_level, 1, ULTIMATE_REQUIRED_LEVEL)
			]
		HERO_SHAMAN:
			options = [
				_option("totem", "Totemic Invocation", "Choose Dig, Heal, Radar, or Gem totem", totem_level, MAX_BASIC_LEVEL, 0),
				_option("chain", "Chain Lightning", "Lightning jumps between nearby enemies", chain_level, MAX_BASIC_LEVEL, 0),
				_option("wisdom", "Ancestral Wisdom", "Improves totems and grants Intelligence", wisdom_level, MAX_BASIC_LEVEL, 0),
				_option("ascendance", "Ancestral Ascendance", "Summon all four totems and empower magic", ascendance_level, 1, ULTIMATE_REQUIRED_LEVEL)
			]
		HERO_NERUBIAN:
			options = [
				_option("brood", "Spawn Brood", "Create autonomous mining spiders", brood_level, MAX_BASIC_LEVEL, 0),
				_option("web", "Web Burst", "Damage, root, and slow nearby enemies", web_level, MAX_BASIC_LEVEL, 0),
				_option("carapace", "Chitinous Carapace", "More health and steady regeneration", carapace_level, MAX_BASIC_LEVEL, 0),
				_option("broodmother", "Broodmother's Call", "Summon and empower a full spider brood", broodmother_level, 1, ULTIMATE_REQUIRED_LEVEL)
			]
	return options

func _option(id: String, title: String, description: String, level_value: int, max_level: int, required_level: int) -> Dictionary:
	var enabled := level_value < max_level and (required_level <= 0 or int(player.get("level")) >= required_level)
	var reason := ""
	if level_value >= max_level:
		reason = "MAX LEVEL"
	elif required_level > int(player.get("level")):
		reason = "REQUIRES HERO LEVEL %d" % required_level
	return {
		"id": id,
		"title": title,
		"description": description,
		"level": level_value,
		"max_level": max_level,
		"enabled": enabled,
		"reason": reason,
		"icon_path": _icon_path(id)
	}

func _on_upgrade_selected(upgrade_type: String) -> void:
	match upgrade_type:
		"hammer":
			hammer_level = min(MAX_BASIC_LEVEL, hammer_level + 1)
		"bash":
			bash_level = min(MAX_BASIC_LEVEL, bash_level + 1)
			bash_counter = 0
		"avatar":
			if int(player.get("level")) >= ULTIMATE_REQUIRED_LEVEL:
				avatar_level = 1
		"totem":
			totem_level = min(MAX_BASIC_LEVEL, totem_level + 1)
		"chain":
			chain_level = min(MAX_BASIC_LEVEL, chain_level + 1)
		"wisdom":
			if wisdom_level < MAX_BASIC_LEVEL:
				wisdom_level += 1
				player.set("intelligence", int(player.get("intelligence")) + 1)
		"ascendance":
			if int(player.get("level")) >= ULTIMATE_REQUIRED_LEVEL:
				ascendance_level = 1
		"brood":
			brood_level = min(MAX_BASIC_LEVEL, brood_level + 1)
		"web":
			web_level = min(MAX_BASIC_LEVEL, web_level + 1)
		"carapace":
			if carapace_level < MAX_BASIC_LEVEL:
				carapace_level += 1
				player.set("max_health", int(player.get("max_health")) + 8)
				player.set("health", int(player.get("health")) + 8)
		"broodmother":
			if int(player.get("level")) >= ULTIMATE_REQUIRED_LEVEL:
				broodmother_level = 1
	_refresh_stats_hud()
	_update_ability_hud()

func _is_mobile_runtime() -> bool:
	var is_mobile := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if OS.has_feature("web"):
		is_mobile = is_mobile or bool(JavaScriptBridge.eval("/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)"))
	return is_mobile

func _ensure_hud() -> void:
	if world == null:
		return
	if ability_bar != null and is_instance_valid(ability_bar):
		return
	var hud := world.get_node_or_null("HUD")
	if hud == null:
		return
	ability_bar = HBoxContainer.new()
	ability_bar.name = "HeroAbilityBarP%d" % _player_id()
	ability_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ability_bar.offset_left = -326.0
	ability_bar.offset_top = -96.0 - (78.0 if _player_id() > 1 else 0.0)
	ability_bar.offset_right = -20.0
	ability_bar.offset_bottom = -20.0 - (78.0 if _player_id() > 1 else 0.0)
	ability_bar.add_theme_constant_override("separation", 8)
	hud.add_child(ability_bar)
	_rebuild_hud()
	_hide_legacy_stomp_slot()

func _rebuild_hud() -> void:
	if ability_bar == null or not is_instance_valid(ability_bar):
		return
	for child in ability_bar.get_children():
		ability_bar.remove_child(child)
		child.queue_free()
	ability_slots.clear()
	current_hud_hero = _hero_name()
	var definitions := []
	match current_hud_hero:
		HERO_DWARF:
			definitions = [
				["stomp", "Ground Stomp", "R / X"],
				["hammer", "Throwing Hammer", "F / RB"],
				["bash", "Dwarven Bash", "PASSIVE"],
				["avatar", "Avatar", "T / LB"]
			]
		HERO_SHAMAN:
			definitions = [
				["totem", "Totem Wheel", "R / X"],
				["chain", "Chain Lightning", "F / RB"],
				["wisdom", "Ancestral Wisdom", "PASSIVE"],
				["ascendance", "Ascendance", "T / LB"]
			]
		HERO_NERUBIAN:
			definitions = [
				["brood", "Spawn Brood", "R / X"],
				["web", "Web Burst", "F / RB"],
				["carapace", "Chitinous Carapace", "PASSIVE"],
				["broodmother", "Broodmother", "T / LB"]
			]
		HERO_DRUID:
			definitions = [
				["mole", "Mole Form", "R / X"]
			]
		HERO_UNDEAD_KING:
			definitions = [
				["raise_dead", "Raise Dead", "R / X"]
			]
	ability_bar.visible = definitions.size() > 0 and not _is_mobile_runtime()
	for definition in definitions:
		ability_slots[definition[0]] = _create_ability_slot(definition[0], definition[1], definition[2])
	_update_ability_hud()

func _create_ability_slot(ability: String, display_name: String, key_text: String) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = ICON_SIZE
	slot.tooltip_text = display_name
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.055, 0.05, 0.92)
	style.border_color = Color(0.62, 0.47, 0.25, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	slot.add_theme_stylebox_override("panel", style)
	var root := Control.new()
	root.name = "Root"
	root.custom_minimum_size = ICON_SIZE
	slot.add_child(root)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = _get_icon(ability)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 5
	icon.offset_top = 5
	icon.offset_right = -5
	icon.offset_bottom = -5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	var overlay := ColorRect.new()
	overlay.name = "CooldownOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 1.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	var timer := Label.new()
	timer.name = "Timer"
	timer.set_anchors_preset(Control.PRESET_FULL_RECT)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer.add_theme_font_size_override("font_size", 12)
	timer.add_theme_color_override("font_color", Color.WHITE)
	timer.add_theme_color_override("font_shadow_color", Color.BLACK)
	timer.add_theme_constant_override("shadow_offset_x", 1)
	timer.add_theme_constant_override("shadow_offset_y", 1)
	timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(timer)
	var key_label := Label.new()
	key_label.name = "Key"
	key_label.anchor_left = 0.0
	key_label.anchor_top = 1.0
	key_label.anchor_right = 1.0
	key_label.anchor_bottom = 1.0
	key_label.offset_top = -17.0
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.text = key_text
	key_label.add_theme_font_size_override("font_size", 9)
	key_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(key_label)
	var level_label := Label.new()
	level_label.name = "Level"
	level_label.offset_left = 4.0
	level_label.offset_top = 2.0
	level_label.offset_right = 30.0
	level_label.offset_bottom = 18.0
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(level_label)
	ability_bar.add_child(slot)
	return slot

func _update_ability_hud() -> void:
	if ability_bar == null or not is_instance_valid(ability_bar):
		return
	match _hero_name():
		HERO_DWARF:
			var stomp_rank := int(player.get("stomp_level"))
			_update_slot("stomp", stomp_rank, float(player.get("stomp_cooldown_timer")), max(1.0, 5.0 - stomp_rank * 0.5))
			_update_slot("hammer", hammer_level, hammer_cooldown, _hammer_max_cooldown())
			_update_slot("bash", bash_level, 0.0, 1.0, "LOCKED" if bash_level <= 0 else "%d/%d" % [bash_counter, _bash_threshold()])
			_update_slot("avatar", avatar_level, avatar_cooldown, 60.0, "LVL 6" if avatar_level <= 0 else ("%.1f" % avatar_duration if avatar_active else ""), avatar_active)
		HERO_SHAMAN:
			_update_slot("totem", totem_level, float(player.get("shaman_spell_cooldown_timer")), _totem_max_cooldown())
			_update_slot("chain", chain_level, chain_cooldown, _chain_max_cooldown())
			_update_slot("wisdom", wisdom_level, 0.0, 1.0, "PASSIVE" if wisdom_level > 0 else "LOCKED")
			_update_slot("ascendance", ascendance_level, ascendance_cooldown, 65.0, "LVL 6" if ascendance_level <= 0 else ("%.1f" % ascendance_duration if ascendance_active else ""), ascendance_active)
		HERO_NERUBIAN:
			_update_slot("brood", brood_level, max(brood_cooldown, float(player.get("nerubian_spawn_cooldown_timer"))), _brood_max_cooldown(), "%d/%d" % [_owned_spiders().size(), _brood_max_count()] if brood_level > 0 else "LOCKED")
			_update_slot("web", web_level, web_cooldown, max(5.5, 10.5 - web_level * 1.1 - carapace_level * 0.2))
			_update_slot("carapace", carapace_level, 0.0, 1.0, "PASSIVE" if carapace_level > 0 else "LOCKED")
			_update_slot("broodmother", broodmother_level, broodmother_cooldown, 70.0, "LVL 6" if broodmother_level <= 0 else ("%.1f" % broodmother_duration if broodmother_active else ""), broodmother_active)
		HERO_DRUID:
			_update_slot("mole", mole_level, mole_cooldown, max(8.0, 16.0 - float(mole_level)), "%.1f" % mole_duration if mole_active else "", mole_active)
		HERO_UNDEAD_KING:
			_update_slot("raise_dead", undead_summon_level, undead_summon_cooldown, max(5.0, 11.0 - float(int(player.get("intelligence")) - 1) * 0.25), "%d/%d" % [_owned_undead_minions().size(), UNDEAD_MINION_LIMIT])

func _update_slot(ability: String, level_value: int, cooldown: float, max_cooldown: float, override_text: String = "", active: bool = false) -> void:
	var slot = ability_slots.get(ability)
	if slot == null:
		return
	var icon: Node = slot.get_node_or_null("Root/Icon")
	var overlay: Node = slot.get_node_or_null("Root/CooldownOverlay")
	var timer: Node = slot.get_node_or_null("Root/Timer")
	var level_label: Node = slot.get_node_or_null("Root/Level")
	var locked := level_value <= 0
	if icon:
		icon.modulate = Color(1.2, 0.92, 0.42, 1.0) if active else (Color(0.38, 0.38, 0.38, 0.85) if locked else Color.WHITE)
	if overlay:
		var ratio: float = clamp(cooldown / max(max_cooldown, 0.01), 0.0, 1.0)
		overlay.anchor_top = 1.0 - ratio
		overlay.visible = cooldown > 0.0 and not active
	if timer:
		if override_text != "":
			timer.text = override_text
		elif cooldown > 0.0:
			timer.text = "%d" % ceil(cooldown)
		else:
			timer.text = ""
	if level_label:
		level_label.text = "L%d" % level_value if level_value > 0 else ""

func _hide_legacy_stomp_slot() -> void:
	if world == null:
		return
	var hud := world.get_node_or_null("HUD")
	if hud:
		var legacy := hud.get_node_or_null("StompContainer")
		if legacy:
			legacy.visible = false

func _icon_path(ability: String) -> String:
	if ability == "stomp":
		for path in STOMP_KNOWN_PATHS:
			if ResourceLoader.exists(path):
				return path
		var scanned := _scan_for_texture_path("res://", "stomp", 0)
		if scanned != "":
			return scanned
	return str(ICON_PATHS.get(ability, ""))

func _scan_for_texture_path(directory_path: String, keyword: String, depth: int) -> String:
	if depth > 5:
		return ""
	for file_name in DirAccess.get_files_at(directory_path):
		var lower := file_name.to_lower()
		var extension := file_name.get_extension().to_lower()
		if lower.contains(keyword) and not lower.contains("placeholder") and extension in ["png", "webp", "svg", "tres"]:
			return directory_path.path_join(file_name)
	for child_dir in DirAccess.get_directories_at(directory_path):
		if child_dir.begins_with("."):
			continue
		var found := _scan_for_texture_path(directory_path.path_join(child_dir), keyword, depth + 1)
		if found != "":
			return found
	return ""

func _get_icon(ability: String) -> Texture2D:
	if icon_cache.has(ability):
		return icon_cache[ability]
	var path := _icon_path(ability)
	var texture: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	icon_cache[ability] = texture
	return texture

func _refresh_stats_hud() -> void:
	if world == null:
		return
	var hud := world.get_node_or_null("HUD")
	if hud and hud.has_method("update_player_health"):
		hud.update_player_health(int(player.get("health")), int(player.get("max_health")))
	if hud and hud.has_method("update_stats"):
		hud.update_stats(int(player.get("strength")), int(player.get("agility")), int(player.get("intelligence")))

func _show_notice(text: String, duration: float = 1.5) -> void:
	if world == null:
		return
	var hud := world.get_node_or_null("HUD")
	if hud and hud.has_method("show_notice"):
		hud.show_notice(text, duration)
