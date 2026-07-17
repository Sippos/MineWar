extends CharacterBody2D

var player_id: int = 1 :
	set(val):
		player_id = val
		update_hero_sprites()

var agility = 1
var strength = 1
var intelligence = 1

var base_speed = 200.0
var base_dig_time = 0.4
var base_jetpack_thrust = 1500.0
const JUMP_VELOCITY = -400.0
const AUTO_DEFEND_DISTANCE := 140.0
const MINING_FEEDBACK_INTERVAL := 0.28

const GEM_SCENE = preload("res://scenes/entities/collectibles/gems/gem.tscn")
const SHAMAN_TOTEM_SCENE = preload("res://shaman_totem.tscn")
const SHAMAN_TOTEM_TYPES = ["dig", "heal", "radar", "gem"]
const SHAMAN_TOTEM_COOLDOWN = 6.0
const SPIDER_MINION_SCENE = preload("res://spider_minion.tscn")
const NERUBIAN_SPAWN_COOLDOWN = 3.5
const NERUBIAN_MAX_SPIDERS = 5

var tex_walk: Texture2D
var tex_attack: Texture2D
var tex_druid_mole: Texture2D
var tex_druid_mole_attack: Texture2D
var druid_mole_active := false

var health = 30
var max_health = 30
var is_dead = false
var death_count = 0
var respawn_timer = 0.0
var invulnerability_timer = 0.0

var level = 1
var xp = 0
var max_xp = 100
var stomp_level = 0
var stomp_cooldown_timer = 0.0

var dig_timer = 0.0
var mining_feedback_timer = 0.0
var currently_digging_cell = null
var walk_timer = 0.0
var action_anim_timer = 0.0
var action_anim_active = false
var current_anim_row = 0

var current_hero_name = "Dwarf"
var current_sprite_scale = Vector2(0.85, 0.85)
var current_sprite_position = Vector2(0, -24)

const HERO_ANIMATIONS = {
	"Dwarf": {
		"walk_frames": 8,
		"walk_fps": 12.0,
		"attack_frames": 8,
		"attack_fps": 8.0,
		"attack_hold_frames": 2.0
	},
	"Mech": {
		"walk_frames": 8,
		"walk_fps": 12.0,
		"attack_frames": 8,
		"attack_fps": 12.0
	},
	"Shaman": {
		"walk_frames": 8,
		"walk_fps": 11.0,
		"attack_frames": 8,
		"attack_fps": 8.0,
		"attack_hold_frames": 1.0
	},
	"Nerubian": {
		"walk_frames": 8,
		"walk_fps": 12.0,
		"attack_frames": 8,
		"attack_fps": 8.0
	},
	"Druid": {
		"walk_frames": 8,
		"walk_fps": 10.0,
		"attack_frames": 8,
		"attack_fps": 8.0,
		"attack_hold_frames": 1.0,
		"mole_walk_frames": 8,
		"mole_walk_fps": 10.0,
		"mole_attack_frames": 8,
		"mole_attack_fps": 8.0,
		"mole_attack_hold_frames": 1.0
	},
	"Undead King": {
		"walk_frames": 8,
		"walk_fps": 12.0,
		"attack_frames": 8,
		"attack_fps": 12.0
	}
}

const HERO_VISUALS = {
	"Dwarf": {
		"walk_scale": Vector2(0.85, 0.85),
		# The attack sheet contains a much smaller figure inside each 128 px
		# frame. Scale and anchor it independently so the Dwarf no longer
		# shrinks whenever the hammer swing starts.
		"attack_scale": Vector2(1.12, 1.12),
		"sprite_position": Vector2(0, -24),
		"attack_position": Vector2(0, -26)
	},
	"Mech": {
		"walk_scale": Vector2(0.85, 0.85),
		"attack_scale": Vector2(0.85, 0.85),
		"sprite_position": Vector2(0, -24)
	},
	"Shaman": {
		# Shaman keeps its calibrated humanoid walk fit and uses a dedicated
		# staff-swing attack authored from the Shaman rig; both sheets share the
		# same camera and foot line.
		"walk_scale": Vector2(0.64, 0.64),
		"attack_scale": Vector2(0.64, 0.64),
		"walk_position": Vector2(0, -5),
		"attack_position": Vector2(0, -5),
		"sprite_position": Vector2(0, -5)
	},
	"Nerubian": {
		# The production pair is rendered from the original rig: an eight-pose
		# periodic leg gait for movement and the matching v3 action for attacks.
		"walk_scale": Vector2(0.46, 0.46),
		"attack_scale": Vector2(0.46, 0.46),
		"sprite_position": Vector2(0, -9)
	},
	"Druid": {
		# The humanoid walk source has real movement and a larger silhouette than
		# the restored attack take, so each state needs its own fitted scale.
		"walk_scale": Vector2(0.50, 0.50),
		"attack_scale": Vector2(0.62, 0.62),
		"walk_position": Vector2(0, -7),
		"attack_position": Vector2(0, -4),
		"sprite_position": Vector2(0, -4),
		"mole_scale": Vector2(0.70, 0.70),
		"mole_position": Vector2(0, -10)
	},
	"Undead King": {
		"walk_scale": Vector2(0.85, 0.85),
		"attack_scale": Vector2(0.85, 0.85),
		"sprite_position": Vector2(0, -24)
	}
}

var attack_timer = 0.0
var currently_attacking_enemy = null
var shaman_wheel_open = false
var selected_shaman_totem = "dig"
var shaman_spell_cooldown_timer = 0.0
var magic_orb_last_animation_cycle := -1
var nerubian_spawn_cooldown_timer = 0.0
var nerubian_cast_timer = 0.0
var undead_cast_timer = 0.0

var carried_gems = []
var nearby_gems = []
var cave_reward_ids: Array[String] = []
var cave_reward_carry_bonus := 0

# Carrying stays permissive: Strength and cave rewards grant a small free
# allowance before the existing overload slowdown starts. Every three Strength
# points above the starting value adds another slot without changing pickup or
# deposit rules.
const BASE_FREE_CARRY_ALLOWANCE := 1
const STRENGTH_CARRY_STEP := 3

@onready var tile_map: TileMapLayer = $"../BlockLayer"
@onready var damage_layer: TileMapLayer = $"../DamageLayer"
@onready var front_damage_layer: TileMapLayer = $"../FrontDamageLayer"
@onready var front_layer: TileMapLayer = $"../FrontWallLayer"
var ray_right: RayCast2D
var ray_left: RayCast2D
var ray_down: RayCast2D
var ray_up: RayCast2D

func _ready() -> void:
	collision_mask |= 4 # Collide with enemies (Layer 3)
	ray_right = RayCast2D.new(); ray_right.position = Vector2(0, -24); ray_right.target_position = Vector2(34, 0); ray_right.collision_mask = 5; add_child(ray_right)
	ray_left = RayCast2D.new(); ray_left.position = Vector2(0, -24); ray_left.target_position = Vector2(-34, 0); ray_left.collision_mask = 5; add_child(ray_left)
	ray_down = RayCast2D.new(); ray_down.position = Vector2(0, -24); ray_down.target_position = Vector2(0, 34); ray_down.collision_mask = 5; add_child(ray_down)
	ray_up = RayCast2D.new(); ray_up.position = Vector2(0, -24); ray_up.target_position = Vector2(0, -34); ray_up.collision_mask = 5; add_child(ray_up)
	update_hero_sprites()

func _input(event: InputEvent) -> void:
	if not shaman_wheel_open:
		return
	if event is InputEventMouseMotion:
		_update_shaman_wheel_from_mouse()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_update_shaman_wheel_from_mouse()
		_cast_selected_shaman_totem()

func update_hero_sprites() -> void:
	var h_name = Global.hero_p1
	if player_id == 2:
		h_name = Global.hero_p2
	if Global.hero_data.has(h_name):
		current_hero_name = h_name
		var data = Global.hero_data[h_name]
		tex_walk = data["walk"] as Texture2D
		tex_attack = data["attack"] as Texture2D
		tex_druid_mole = data["mole"] as Texture2D if data.has("mole") else null
		tex_druid_mole_attack = data["mole_attack"] as Texture2D if data.has("mole_attack") else null
		druid_mole_active = false
		if has_node("Sprite2D"):
			$Sprite2D.texture = tex_walk
			_apply_sprite_visuals(false)
			_reset_action_animation()

func _get_hero_animation_settings() -> Dictionary:
	return HERO_ANIMATIONS.get(current_hero_name, HERO_ANIMATIONS["Dwarf"])

func _get_hero_visuals() -> Dictionary:
	return HERO_VISUALS.get(current_hero_name, HERO_VISUALS["Dwarf"])

func _apply_sprite_visuals(is_attack: bool) -> void:
	var visuals := _get_hero_visuals()
	if is_attack:
		current_sprite_scale = visuals.get("attack_scale", Vector2(0.85, 0.85))
		current_sprite_position = visuals.get("attack_position", visuals.get("sprite_position", Vector2(0, -24)))
	else:
		current_sprite_scale = visuals.get("walk_scale", Vector2(0.85, 0.85))
		current_sprite_position = visuals.get("walk_position", visuals.get("sprite_position", Vector2(0, -24)))
	if has_node("Sprite2D"):
		$Sprite2D.scale = current_sprite_scale
		$Sprite2D.position = current_sprite_position

func _get_action_animation_row() -> int:
	# Reviewed action sheets use the same eight-direction row order as walking.
	return current_anim_row

func _uses_mirrored_action_animation() -> bool:
	return false

func _is_currently_performing_action() -> bool:
	if current_hero_name == "Nerubian":
		return currently_attacking_enemy != null or nerubian_cast_timer > 0.0
	return currently_attacking_enemy != null or currently_digging_cell != null

func _use_walk_animation_state() -> void:
	if $Sprite2D.texture != tex_walk:
		$Sprite2D.texture = tex_walk
		_apply_sprite_visuals(false)
	$Sprite2D.flip_h = false

func _use_action_animation_state() -> void:
	if $Sprite2D.texture != tex_attack:
		$Sprite2D.texture = tex_attack
		_apply_sprite_visuals(true)
		_reset_action_animation()

func _use_druid_mole_animation_state(is_attack: bool) -> void:
	var desired_texture: Texture2D = tex_druid_mole_attack if is_attack and tex_druid_mole_attack != null else tex_druid_mole
	if $Sprite2D.texture != desired_texture:
		$Sprite2D.texture = desired_texture
		_apply_druid_mole_visuals()
		_reset_action_animation()
	$Sprite2D.flip_h = false

func _apply_druid_mole_visuals() -> void:
	var visuals := _get_hero_visuals()
	current_sprite_scale = visuals.get("mole_scale", visuals.get("walk_scale", Vector2(0.85, 0.85)))
	current_sprite_position = visuals.get("mole_position", visuals.get("sprite_position", Vector2(0, -24)))
	if has_node("Sprite2D"):
		$Sprite2D.scale = current_sprite_scale
		$Sprite2D.position = current_sprite_position

func get_free_carry_allowance() -> int:
	var strength_bonus: int = maxi(0, floori(float(strength - 1) / float(STRENGTH_CARRY_STEP)))
	var permanent_carry_bonus := 0
	if is_inside_tree():
		var global_state := get_node_or_null("/root/Global")
		if global_state and global_state.has_method("get_permanent_carry_bonus"):
			permanent_carry_bonus = int(global_state.get_permanent_carry_bonus())
	return BASE_FREE_CARRY_ALLOWANCE + strength_bonus + cave_reward_carry_bonus + permanent_carry_bonus

func apply_cave_reward(reward_id: String) -> bool:
	if cave_reward_ids.has(reward_id):
		return false
	match reward_id:
		"miners_satchel":
			cave_reward_carry_bonus += 1
		_:
			return false
	cave_reward_ids.append(reward_id)
	if is_inside_tree():
		var parent_node := get_parent()
		var hud = parent_node.get_node_or_null("HUD") if parent_node else null
		if hud and hud.has_method("add_cave_reward"):
			hud.add_cave_reward(reward_id)
		if hud and hud.has_method("show_notice"):
			hud.show_notice("Miner's Satchel equipped: +1 free gem carry", 2.4)
	return true

func get_carry_load() -> int:
	var carry_load := 0
	for gem in carried_gems:
		if is_instance_valid(gem):
			carry_load += 1
	return carry_load

func get_carry_overload() -> int:
	return max(0, get_carry_load() - get_free_carry_allowance())

func get_weight_penalty() -> float:
	# Preserve the existing 15% per-item overload penalty and 75% cap while
	# making the first allowance of gems (plus Strength thresholds) penalty-free.
	var p := float(get_carry_overload()) * 0.15
	return min(p, 0.75)

func add_nearby_gem(gem) -> void:
	if not nearby_gems.has(gem):
		nearby_gems.append(gem)

func remove_nearby_gem(gem) -> void:
	nearby_gems.erase(gem)

func deposit_gems() -> int:
	var deposited = 0
	var remaining_items = []
	for gem in carried_gems:
		if is_instance_valid(gem):
			if gem.has_method("should_deposit_as_gem") and not gem.should_deposit_as_gem():
				remaining_items.append(gem)
			else:
				gem.queue_free()
				deposited += 1
	carried_gems = remaining_items
	return deposited

func _rpg_controller() -> Node:
	return get_node_or_null("HeroRPGController")

func upgrade_strength() -> void:
	var rpg: Node = _rpg_controller()
	if rpg != null and rpg.has_method("register_stat_bonus"):
		rpg.call("register_stat_bonus", "strength", 1)
	else:
		strength += 1

func upgrade_agility() -> void:
	var rpg: Node = _rpg_controller()
	if rpg != null and rpg.has_method("register_stat_bonus"):
		rpg.call("register_stat_bonus", "agility", 1)
	else:
		agility += 1

func upgrade_intelligence() -> void:
	var rpg: Node = _rpg_controller()
	if rpg != null and rpg.has_method("register_stat_bonus"):
		rpg.call("register_stat_bonus", "intelligence", 1)
	else:
		intelligence += 1

func take_damage(amount: int) -> void:
	if is_dead or invulnerability_timer > 0.0:
		return
	var applied_amount: int = amount
	var rpg: Node = _rpg_controller()
	if rpg != null and rpg.has_method("modify_incoming_damage"):
		applied_amount = int(rpg.call("modify_incoming_damage", amount))
	if applied_amount <= 0:
		return
	invulnerability_timer = 1.0
	health -= applied_amount
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("update_player_health"):
		hud.update_player_health(health, max_health)
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var tween = create_tween()
		sprite.modulate = Color(1, 0, 0, 1)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.2)
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	death_count += 1
	health = 0
	for gem in carried_gems:
		if is_instance_valid(gem) and gem.has_method("untether"):
			gem.untether()
	carried_gems.clear()
	$Sprite2D.visible = false
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	respawn_timer = min(20.0, 3.0 + (death_count - 1) * 3.0)

func respawn() -> void:
	is_dead = false
	health = max_health
	global_position = get_parent().get_node("Base").global_position
	$Sprite2D.visible = true
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("update_player_health"):
		hud.update_player_health(health, max_health)

var can_move = true

func _physics_process(delta: float) -> void:
	mining_feedback_timer = max(mining_feedback_timer - delta, 0.0)
	if shaman_spell_cooldown_timer > 0.0:
		shaman_spell_cooldown_timer -= delta
	if nerubian_spawn_cooldown_timer > 0.0:
		nerubian_spawn_cooldown_timer -= delta
	if nerubian_cast_timer > 0.0:
		nerubian_cast_timer = max(0.0, nerubian_cast_timer - delta)
	if undead_cast_timer > 0.0:
		undead_cast_timer = max(0.0, undead_cast_timer - delta)
	_update_shaman_totem_hud()
	
	if Input.is_action_just_pressed("p%d_interact" % player_id):
		if current_hero_name == "Nerubian":
			_try_spawn_spider_minion()
		else:
			_try_open_shaman_totem_wheel()
	elif shaman_wheel_open and Input.is_action_just_released("p%d_interact" % player_id):
		_cast_selected_shaman_totem()

	if Input.is_action_just_pressed("p%d_grab" % player_id):
		for gem in nearby_gems:
			if is_instance_valid(gem) and not carried_gems.has(gem):
				if gem.has_method("tether_to"):
					var picked_up = gem.tether_to(self)
					if picked_up == false:
						continue
				carried_gems.append(gem)
	elif Input.is_action_just_pressed("p%d_drop" % player_id):
		if carried_gems.size() > 0:
			for nearby in nearby_gems:
				if is_instance_valid(nearby) and nearby.has_method("load_gem"):
					var loaded_any = false
					while carried_gems.size() > 0:
						var loaded_gem = carried_gems.pop_back()
						if nearby.load_gem(loaded_gem, self):
							loaded_any = true
						else:
							carried_gems.append(loaded_gem)
							break
					if loaded_any:
						return
			var gem = carried_gems.pop_back()
			if is_instance_valid(gem) and gem.has_method("untether"):
				gem.untether()
	if invulnerability_timer > 0.0:
		invulnerability_timer -= delta
	if stomp_cooldown_timer > 0.0:
		stomp_cooldown_timer -= delta
	
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("update_stomp_cooldown"):
		var max_cooldown = max(1.0, 5.0 - stomp_level * 0.5)
		hud.update_stomp_cooldown(stomp_level, stomp_cooldown_timer, max_cooldown)
	if Input.is_action_just_pressed("p%d_stomp" % player_id) and stomp_level > 0 and stomp_cooldown_timer <= 0.0:
		perform_stomp()

	if is_dead:
		_hide_shaman_totem_wheel()
		respawn_timer -= delta
		hud = get_parent().get_node_or_null("HUD")
		if hud and hud.has_method("update_respawn_timer"):
			hud.update_respawn_timer(respawn_timer)
		if respawn_timer <= 0:
			respawn()
		return

	if shaman_wheel_open:
		_update_shaman_wheel_from_stick()
		velocity = Vector2.ZERO
		_stop_digging()
		return

	var penalty: float = get_weight_penalty()
	var rpg_movement: Node = _rpg_controller()
	var current_speed: float = base_speed + float(agility - 1) * 3.0
	if rpg_movement != null and rpg_movement.has_method("get_move_speed"):
		current_speed = float(rpg_movement.call("get_move_speed"))
	current_speed *= 1.0 - penalty
	var direction = Vector2.ZERO
	if can_move:
		direction.x = Input.get_axis("p%d_left" % player_id, "p%d_right" % player_id)
		direction.y = Input.get_axis("p%d_up" % player_id, "p%d_down" % player_id)
	
	if direction.length() > 0:
		direction = direction.normalized()
		velocity = direction * current_speed
		_update_direction_row(direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, current_speed)

	var enemy_hit: Node = null
	var closest_enemy_distance: float = INF
	var direction_length: float = direction.length()
	var enemies := get_tree().get_nodes_in_group("enemies")
	var player_center := global_position + Vector2(0, -24)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var e_center: Vector2 = enemy.global_position + Vector2(0, 8)
		var distance_to_enemy: float = player_center.distance_to(e_center)
		var should_auto_defend: bool = direction_length <= 0.001 and distance_to_enemy <= AUTO_DEFEND_DISTANCE
		var is_direction_target: bool = false
		if direction_length > 0.001 and distance_to_enemy < 70.0:
			var dir_to_enemy: Vector2 = player_center.direction_to(e_center)
			is_direction_target = direction.normalized().dot(dir_to_enemy) > 0.3
		if (should_auto_defend or is_direction_target) and distance_to_enemy < closest_enemy_distance:
			enemy_hit = enemy
			closest_enemy_distance = distance_to_enemy

	if enemy_hit:
		var target_center: Vector2 = enemy_hit.global_position + Vector2(0, 8)
		if player_center.distance_to(target_center) < 42.0:
			velocity = Vector2.ZERO

	move_and_slide()
	
	if enemy_hit:
		_stop_digging()
		if currently_attacking_enemy != enemy_hit:
			currently_attacking_enemy = enemy_hit
			attack_timer = 0.0
			_reset_action_animation()
		attack_timer += delta
		var rpg_combat: Node = _rpg_controller()
		var attack_interval: float = base_dig_time * pow(0.965, agility - 1)
		if rpg_combat != null and rpg_combat.has_method("get_attack_interval"):
			attack_interval = float(rpg_combat.call("get_attack_interval"))
		if attack_timer >= attack_interval:
			var damage: int = 10 * strength
			if rpg_combat != null and rpg_combat.has_method("get_basic_attack_damage"):
				damage = int(rpg_combat.call("get_basic_attack_damage"))
			if enemy_hit.has_method("take_damage"):
				enemy_hit.take_damage(damage)
			attack_timer = 0.0
		if current_hero_name == "Druid" and not druid_mole_active:
			_maybe_shoot_magic_orb(enemy_hit.global_position + Vector2(0, 8), true)
	else:
		currently_attacking_enemy = null
		attack_timer = 0.0
		handle_digging(delta)

	if current_hero_name == "Shaman" and currently_digging_cell != null:
		walk_timer = 0.0
		$Sprite2D.frame = current_anim_row * 8

	var is_performing_action := _is_currently_performing_action()

	if druid_mole_active and tex_druid_mole != null:
		var mole_is_attacking := currently_attacking_enemy != null or currently_digging_cell != null
		_use_druid_mole_animation_state(mole_is_attacking)
		if mole_is_attacking:
			_update_mole_attack_animation(delta)
		elif velocity.length() > 0.0:
			_update_mole_walk_animation(delta)
		else:
			walk_timer = 0.0
			action_anim_timer = 0.0
			action_anim_active = false
			$Sprite2D.frame = current_anim_row * int(_get_hero_animation_settings().get("mole_walk_frames", 8))
	elif is_performing_action:
		_use_action_animation_state()
		_update_action_animation(delta)
	else:
		if action_anim_active:
			_reset_action_animation()
		_use_walk_animation_state()
		if velocity.length() > 0.0:
			_update_walk_animation(delta)
		else:
			walk_timer = 0.0
			var walk_frames: int = maxi(1, int(_get_hero_animation_settings().get("walk_frames", 8)))
			$Sprite2D.frame = current_anim_row * walk_frames

func _update_direction_row(direction: Vector2) -> void:
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
	elif angle > -3.0 * pi_8 and angle <= -pi_8:
		current_anim_row = 5

func _update_walk_animation(delta: float) -> void:
	var settings := _get_hero_animation_settings()
	var walk_frames: int = maxi(1, int(settings.get("walk_frames", 8)))
	var walk_fps := float(settings.get("walk_fps", 12.0))
	$Sprite2D.flip_h = false
	walk_timer += delta * walk_fps
	$Sprite2D.frame = current_anim_row * walk_frames + (int(walk_timer) % walk_frames)

func _update_directional_animation(direction: Vector2, delta: float) -> void:
	# Kept as one public animation helper for characterization tests and any
	# external callers; runtime state selection now chooses the walk texture
	# before advancing its frames.
	_update_direction_row(direction)
	_update_walk_animation(delta)

func _update_action_animation(delta: float) -> void:
	var settings := _get_hero_animation_settings()
	var attack_frames: int = maxi(1, int(settings.get("attack_frames", 8)))
	var attack_fps := float(settings.get("attack_fps", 12.0))
	var hold_frames: float = maxf(0.0, float(settings.get("attack_hold_frames", 0.0)))
	var cycle_frames: float = maxf(float(attack_frames), float(attack_frames) + hold_frames)
	action_anim_active = true
	action_anim_timer += delta * attack_fps
	var cycle_position: float = fmod(action_anim_timer, cycle_frames)
	var frame_index: int = mini(int(cycle_position), attack_frames - 1)
	$Sprite2D.flip_h = _uses_mirrored_action_animation()
	$Sprite2D.frame = _get_action_animation_row() * attack_frames + frame_index

func _update_mole_walk_animation(delta: float) -> void:
	var settings := _get_hero_animation_settings()
	var walk_frames: int = maxi(1, int(settings.get("mole_walk_frames", 8)))
	var walk_fps := float(settings.get("mole_walk_fps", 10.0))
	$Sprite2D.flip_h = false
	walk_timer += delta * walk_fps
	$Sprite2D.frame = current_anim_row * walk_frames + (int(walk_timer) % walk_frames)

func _update_mole_attack_animation(delta: float) -> void:
	# Mole digging/attacking uses the reviewed action sheet while preserving
	# the same direction-row and frame cadence as the restored crawl state.
	var settings := _get_hero_animation_settings()
	var attack_frames: int = maxi(1, int(settings.get("mole_attack_frames", 8)))
	var attack_fps := float(settings.get("mole_attack_fps", 8.0))
	action_anim_active = true
	action_anim_timer += delta * attack_fps
	$Sprite2D.flip_h = false
	$Sprite2D.frame = current_anim_row * attack_frames + (int(action_anim_timer) % attack_frames)

func _reset_action_animation() -> void:
	action_anim_timer = 0.0
	action_anim_active = false
	magic_orb_last_animation_cycle = -1
	if has_node("Sprite2D"):
		var settings := _get_hero_animation_settings()
		if $Sprite2D.texture == tex_attack:
			var attack_frames: int = maxi(1, int(settings.get("attack_frames", 8)))
			$Sprite2D.flip_h = _uses_mirrored_action_animation()
			$Sprite2D.frame = _get_action_animation_row() * attack_frames
		elif druid_mole_active and $Sprite2D.texture == tex_druid_mole_attack:
			var mole_attack_frames: int = maxi(1, int(settings.get("mole_attack_frames", 8)))
			$Sprite2D.flip_h = false
			$Sprite2D.frame = current_anim_row * mole_attack_frames
		else:
			var walk_frames: int = maxi(1, int(settings.get("walk_frames", 8)))
			if druid_mole_active and $Sprite2D.texture == tex_druid_mole:
				walk_frames = maxi(1, int(settings.get("mole_walk_frames", 8)))
			$Sprite2D.flip_h = false
			$Sprite2D.frame = current_anim_row * walk_frames

func handle_digging(delta: float) -> void:
	if current_hero_name == "Nerubian":
		_stop_digging()
		return
	
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("p%d_right" % player_id): input_dir.x += 1
	elif Input.is_action_pressed("p%d_left" % player_id): input_dir.x -= 1
	elif Input.is_action_pressed("p%d_down" % player_id): input_dir.y += 1
	elif Input.is_action_pressed("p%d_up" % player_id): input_dir.y -= 1
	
	var active_ray: RayCast2D = null
	if velocity.length() < 20.0:
		if input_dir.x > 0:
			active_ray = ray_right
		elif input_dir.x < 0:
			active_ray = ray_left
		elif input_dir.y > 0:
			active_ray = ray_down
		elif input_dir.y < 0:
			active_ray = ray_up
	
	if active_ray and active_ray.is_colliding():
		var collider = active_ray.get_collider()
		if collider == tile_map:
			var point = active_ray.get_collision_point()
			point += active_ray.target_position.normalized() * 5.0
			var cell = tile_map.local_to_map(tile_map.to_local(point))
			if tile_map.get_cell_source_id(cell) != -1:
				var world := get_parent()
				var protected := false
				if world and world.has_method("is_dig_cell_protected"):
					protected = bool(world.call("is_dig_cell_protected", cell))
				else:
					protected = (cell.y <= 1 and cell.x != 0) or cell.y < 0
				if protected:
					_show_protected_dig_feedback(cell)
					_stop_digging()
					return
				if currently_digging_cell == cell:
					dig_timer += delta
					if mining_feedback_timer <= 0.0 and get_parent().has_method("spawn_mining_feedback"):
						var impact_position = tile_map.to_global(tile_map.map_to_local(cell))
						get_parent().spawn_mining_feedback(impact_position)
						var sound_fx := get_node_or_null("/root/SoundFX")
						if sound_fx:
							sound_fx.play_dig_hit(tile_map.get_cell_source_id(cell))
						mining_feedback_timer = MINING_FEEDBACK_INTERVAL
					var calculated_dig_time: float = base_dig_time
					var rpg_mining: Node = _rpg_controller()
					if rpg_mining != null and rpg_mining.has_method("get_dig_time_multiplier"):
						calculated_dig_time *= float(rpg_mining.call("get_dig_time_multiplier"))
					else:
						calculated_dig_time *= pow(0.975, agility - 1)
					calculated_dig_time *= _get_shaman_dig_time_multiplier()
					if current_hero_name == "Druid" and druid_mole_active:
						calculated_dig_time *= 0.55
					var current_target_dig_time = calculated_dig_time
					var block_id = tile_map.get_cell_source_id(cell)
					if block_id == 2: current_target_dig_time = calculated_dig_time * 2.0
					elif block_id == 3: current_target_dig_time = calculated_dig_time * 4.0
					var damage_progress = dig_timer / current_target_dig_time
					var source_id = 7 if damage_progress < 0.66 else 8
					damage_layer.set_cell(cell, source_id, Vector2i(0, 0))
					var below_cell = Vector2i(cell.x, cell.y + 1)
					if front_layer.get_cell_source_id(below_cell) != -1:
						var front_source_id = 13 if damage_progress < 0.66 else 14
						front_damage_layer.set_cell(below_cell, front_source_id, Vector2i(0, 0))
					if dig_timer >= current_target_dig_time:
						tile_map.erase_cell(cell)
						damage_layer.erase_cell(cell)
						front_damage_layer.erase_cell(below_cell)
						var cell_had_gem = get_parent().has_gem(cell)
						if get_parent().has_method("notify_tutorial_cell_dug"):
							get_parent().notify_tutorial_cell_dug(cell, cell_had_gem)
						if get_parent().has_method("try_spawn_cave_reward"):
							get_parent().try_spawn_cave_reward(cell)
						if get_parent().has_method("spawn_mining_feedback"):
							var break_position = tile_map.to_global(tile_map.map_to_local(cell))
							get_parent().spawn_mining_feedback(break_position, true, cell_had_gem)
						var break_sound_fx := get_node_or_null("/root/SoundFX")
						if break_sound_fx:
							break_sound_fx.play_block_break(cell_had_gem)
						get_parent().on_cell_dug(cell)
						var gems_to_spawn = 1 if cell_had_gem else 0
						if _roll_shaman_gem_bonus():
							gems_to_spawn += 1
						_spawn_dug_gems(cell, gems_to_spawn)
						currently_digging_cell = null
						dig_timer = 0.0
				else:
					_stop_digging()
					currently_digging_cell = cell
					dig_timer = 0.0
					action_anim_timer = 0.0
					action_anim_active = true
					magic_orb_last_animation_cycle = -1
			else:
				_stop_digging()
	else:
		_stop_digging()

	if currently_digging_cell != null and active_ray:
		if current_hero_name == "Shaman":
			_maybe_shoot_magic_orb(active_ray.get_collision_point())
		elif current_hero_name == "Druid" and not druid_mole_active:
			_maybe_shoot_magic_orb(active_ray.get_collision_point(), true)

func _show_protected_dig_feedback(cell: Vector2i) -> void:
	var now_msec := Time.get_ticks_msec()
	var last_feedback_msec := int(get_meta("last_protected_dig_feedback_msec", -10000))
	if now_msec - last_feedback_msec < 1150:
		return
	set_meta("last_protected_dig_feedback_msec", now_msec)
	var world := get_parent()
	var message := "The surface supports are protected. Dig down through the central shaft."
	if world and world.has_method("get_protected_dig_message"):
		message = str(world.call("get_protected_dig_message", cell))
	elif cell.y < 0:
		message = "You cannot mine upward into the base floor. Continue deeper or return through the shaft."
	var world_position := tile_map.to_global(tile_map.map_to_local(cell))
	if world and world.has_method("notify_protected_dig"):
		world.notify_protected_dig(world_position, message)
	else:
		var hud := world.get_node_or_null("HUD") if world else null
		if hud and hud.has_method("show_notice"):
			hud.show_notice(message, 1.8)

func _stop_digging() -> void:
	if currently_digging_cell != null:
		damage_layer.erase_cell(currently_digging_cell)
		var below_cell = Vector2i(currently_digging_cell.x, currently_digging_cell.y + 1)
		front_damage_layer.erase_cell(below_cell)
		currently_digging_cell = null
		dig_timer = 0.0

func _try_spawn_spider_minion() -> void:
	if current_hero_name != "Nerubian" or is_dead:
		return
	var base = get_parent().get_node_or_null("Base")
	if base and base.get("player_in_zone") == true:
		return
	var hud = get_parent().get_node_or_null("HUD")
	if nerubian_spawn_cooldown_timer > 0.0:
		if hud and hud.has_method("show_notice"):
			hud.show_notice("Spider brood ready in %.1fs" % nerubian_spawn_cooldown_timer, 0.8)
		return
	var owned_spiders = 0
	for spider in get_tree().get_nodes_in_group("nerubian_spiders"):
		if is_instance_valid(spider) and spider.get("owner_player") == self:
			owned_spiders += 1
	if owned_spiders >= NERUBIAN_MAX_SPIDERS:
		if hud and hud.has_method("show_notice"):
			hud.show_notice("Spider brood limit reached", 0.8)
		return
	var spider = SPIDER_MINION_SCENE.instantiate()
	spider.owner_player = self
	spider.global_position = global_position + Vector2(randf_range(-18, 18), randf_range(-10, 10))
	get_parent().add_child(spider)
	nerubian_cast_timer = 1.0
	_reset_action_animation()
	nerubian_spawn_cooldown_timer = max(1.25, NERUBIAN_SPAWN_COOLDOWN - (intelligence - 1) * 0.2)
	if hud and hud.has_method("show_notice"):
		hud.show_notice("Spawned Brood Spider")

func _try_open_shaman_totem_wheel() -> void:
	if current_hero_name != "Shaman" or is_dead or shaman_spell_cooldown_timer > 0.0:
		if current_hero_name == "Shaman" and shaman_spell_cooldown_timer > 0.0:
			var hud = get_parent().get_node_or_null("HUD")
			if hud and hud.has_method("show_notice"):
				hud.show_notice("Totems ready in %.1fs" % shaman_spell_cooldown_timer, 0.8)
		return
	var base = get_parent().get_node_or_null("Base")
	if base and base.get("player_in_zone") == true:
		return
	shaman_wheel_open = true
	selected_shaman_totem = "dig"
	can_move = false
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("show_totem_wheel"):
		hud.show_totem_wheel(selected_shaman_totem)

func _cast_selected_shaman_totem() -> void:
	if not shaman_wheel_open:
		return
	_hide_shaman_totem_wheel()
	if shaman_spell_cooldown_timer > 0.0:
		return
	var totem = SHAMAN_TOTEM_SCENE.instantiate()
	totem.totem_type = selected_shaman_totem
	if selected_shaman_totem == "dig":
		totem.follow_target = self
	totem.global_position = global_position + Vector2(0, 8)
	get_parent().add_child(totem)
	shaman_spell_cooldown_timer = SHAMAN_TOTEM_COOLDOWN
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("show_notice"):
		hud.show_notice("Summoned %s" % totem.get_display_name())

func _hide_shaman_totem_wheel() -> void:
	if not shaman_wheel_open:
		return
	shaman_wheel_open = false
	can_move = true
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("hide_totem_wheel"):
		hud.hide_totem_wheel()

func _update_shaman_wheel_from_stick() -> void:
	var dir = Vector2(
		Input.get_axis("p%d_left" % player_id, "p%d_right" % player_id),
		Input.get_axis("p%d_up" % player_id, "p%d_down" % player_id)
	)
	if dir.length() >= 0.35:
		_set_selected_shaman_totem(_totem_type_from_direction(dir))

func _update_shaman_wheel_from_mouse() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var dir = get_viewport().get_mouse_position() - viewport_size * 0.5
	if dir.length() >= 24.0:
		_set_selected_shaman_totem(_totem_type_from_direction(dir))

func _totem_type_from_direction(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "heal" if dir.x > 0.0 else "gem"
	return "radar" if dir.y > 0.0 else "dig"

func _set_selected_shaman_totem(totem_type: String) -> void:
	if selected_shaman_totem == totem_type:
		return
	selected_shaman_totem = totem_type
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("update_totem_wheel_selection"):
		hud.update_totem_wheel_selection(selected_shaman_totem)

func _update_shaman_totem_hud() -> void:
	if current_hero_name != "Shaman":
		return
	var statuses = {}
	for type in SHAMAN_TOTEM_TYPES:
		statuses[type] = { "active": 0.0, "cooldown": max(shaman_spell_cooldown_timer, 0.0), "ratio": 0.0 }
	for totem in get_tree().get_nodes_in_group("shaman_totems"):
		if not is_instance_valid(totem):
			continue
		var type = str(totem.get("totem_type"))
		if not statuses.has(type):
			continue
		var lifetime = float(totem.get("lifetime"))
		if lifetime > statuses[type]["active"]:
			statuses[type]["active"] = lifetime
			statuses[type]["ratio"] = totem.get_lifetime_ratio() if totem.has_method("get_lifetime_ratio") else 0.0
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("update_totem_status"):
		hud.update_totem_status(statuses)

func _get_shaman_dig_time_multiplier() -> float:
	if current_hero_name != "Shaman":
		return 1.0
	for totem in get_tree().get_nodes_in_group("shaman_totems"):
		if is_instance_valid(totem) and totem.get("totem_type") == "dig" and totem.affects_player(self):
			return 0.65
	return 1.0

func _roll_shaman_gem_bonus() -> bool:
	if current_hero_name != "Shaman":
		return false
	for totem in get_tree().get_nodes_in_group("shaman_totems"):
		if is_instance_valid(totem) and totem.get("totem_type") == "gem" and totem.affects_player(self):
			return randf() < 0.35
	return false

func _spawn_dug_gems(cell: Vector2i, count: int) -> void:
	if count <= 0:
		return
	var spawn_pos = tile_map.to_global(tile_map.map_to_local(cell))
	for i in range(count):
		var gem = GEM_SCENE.instantiate()
		gem.global_position = spawn_pos + Vector2(randf_range(-12, 12), randf_range(-8, 8))
		if get_parent().has_method("notify_tutorial_gem_spawned"):
			get_parent().notify_tutorial_gem_spawned(gem)
		get_parent().call_deferred("add_child", gem)

func _maybe_shoot_magic_orb(target_pos: Vector2, green_orb := false) -> void:
	var settings = _get_hero_animation_settings()
	var attack_frames = max(1, int(settings.get("attack_frames", 8)))
	var animation_cycle = int(action_anim_timer / float(attack_frames))
	if animation_cycle == magic_orb_last_animation_cycle:
		return
	magic_orb_last_animation_cycle = animation_cycle
	var orb = Sprite2D.new()
	orb.z_index = 7
	orb.texture = _make_magic_orb_texture(green_orb)
	orb.scale = Vector2(0.32, 0.32)
	orb.global_position = global_position + Vector2(0, -24)
	get_parent().add_child(orb)
	var trail = CPUParticles2D.new()
	trail.amount = 16
	trail.lifetime = 0.25
	trail.emitting = true
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 3.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 18.0
	trail.initial_velocity_max = 50.0
	trail.damping_min = 20.0
	trail.damping_max = 40.0
	trail.scale_amount_min = 1.5
	trail.scale_amount_max = 4.0
	trail.color = Color(0.25, 1.0, 0.35, 0.85) if green_orb else Color(0.2, 0.65, 1.0, 0.8)
	orb.add_child(trail)
	var tween = create_tween()
	tween.tween_property(orb, "global_position", target_pos, 0.14)
	tween.parallel().tween_property(orb, "scale", Vector2(0.08, 0.08), 0.14)
	tween.tween_callback(orb.queue_free)

func _make_magic_orb_texture(green_orb := false) -> Texture2D:
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	if green_orb:
		gradient.colors = PackedColorArray([
			Color(0.95, 1.0, 0.9, 1.0),
			Color(0.25, 0.95, 0.35, 0.95),
			Color(0.0, 0.3, 0.05, 0.0)
		])
	else:
		gradient.colors = PackedColorArray([
			Color(0.9, 1.0, 1.0, 1.0),
			Color(0.2, 0.7, 1.0, 0.9),
			Color(0.0, 0.15, 0.8, 0.0)
		])
	var texture = GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.fill = 1
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture

func add_xp(amount: int) -> void:
	xp += amount
	if xp >= max_xp:
		level_up()
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("update_xp"):
		hud.update_xp(level, xp, max_xp)

func level_up() -> void:
	var level_sound_fx := get_node_or_null("/root/SoundFX")
	if level_sound_fx:
		level_sound_fx.play_level_up()
	xp -= max_xp
	level += 1
	max_xp = int(max_xp * 1.5)
	health = max_health
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("update_player_health"):
		hud.update_player_health(health, max_health)
	if hud and hud.has_method("update_xp"):
		hud.update_xp(level, xp, max_xp)
	get_tree().paused = true
	var menu_scene = preload("res://scenes/ui/overlays/level_up/level_up_menu.tscn")
	var menu = menu_scene.instantiate()
	get_parent().add_child(menu)
	if menu.has_method("setup_for_player"):
		menu.setup_for_player(self)
	else:
		menu.setup(stomp_level > 0)
	menu.upgrade_selected.connect(_on_upgrade_selected)

func _on_upgrade_selected(upgrade_type: String) -> void:
	var upgrade_sound_fx := get_node_or_null("/root/SoundFX")
	if upgrade_sound_fx:
		upgrade_sound_fx.play_upgrade()
	if upgrade_type == "stomp":
		stomp_level += 1
	elif upgrade_type == "health":
		var rpg_health: Node = _rpg_controller()
		if rpg_health != null and rpg_health.has_method("register_health_bonus"):
			rpg_health.call("register_health_bonus", 10)
		else:
			max_health += 10
			health += 10
	elif upgrade_type == "damage":
		upgrade_strength()
	var hud = get_parent().get_node_or_null("HUD")
	if hud:
		if hud.has_method("update_player_health"):
			hud.update_player_health(health, max_health)
		if hud.has_method("update_stats"):
			hud.update_stats(strength, agility, intelligence)

func perform_stomp() -> void:
	var rpg_stomp: Node = _rpg_controller()
	var stomp_base_cooldown: float = max(1.0, 5.0 - stomp_level * 0.5)
	stomp_cooldown_timer = float(rpg_stomp.call("adjust_cooldown", stomp_base_cooldown)) if rpg_stomp != null and rpg_stomp.has_method("adjust_cooldown") else stomp_base_cooldown
	var radius = 100.0 + stomp_level * 20.0
	var base_stomp_damage: int = 12 + stomp_level * 18 + strength * 5
	var stomp_damage: int = int(rpg_stomp.call("scale_physical_ability_damage", base_stomp_damage)) if rpg_stomp != null and rpg_stomp.has_method("scale_physical_ability_damage") else base_stomp_damage
	var sprite = $Sprite2D
	if sprite:
		var tween = create_tween()
		sprite.scale = current_sprite_scale * 1.2
		sprite.modulate = Color(1, 1, 0)
		tween.tween_property(sprite, "scale", current_sprite_scale, 0.2)
		tween.parallel().tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)
	var burst = CPUParticles2D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 50
	burst.lifetime = 0.6
	burst.explosiveness = 0.95
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 20.0
	burst.spread = 180.0
	burst.gravity = Vector2(0, 0)
	burst.initial_velocity_min = 150.0
	burst.initial_velocity_max = 280.0
	burst.damping_min = 300.0
	burst.damping_max = 400.0
	burst.scale_amount_min = 3.0
	burst.scale_amount_max = 7.0
	burst.color = Color(0.6, 0.5, 0.4, 0.9)
	burst.global_position = global_position
	burst.z_index = 0
	get_parent().call_deferred("add_child", burst)
	burst.call_deferred("set_emitting", true)
	var t = get_tree().create_timer(1.0)
	t.timeout.connect(burst.queue_free)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(stomp_damage)
