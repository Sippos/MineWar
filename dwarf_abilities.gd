extends Node

const HERO_NAME := "Dwarf"
const HAMMER_MAX_LEVEL := 3
const BASH_MAX_LEVEL := 3
const AVATAR_REQUIRED_LEVEL := 6
const HAMMER_BASE_COOLDOWN := 9.0
const AVATAR_COOLDOWN := 60.0
const AVATAR_DURATION := 12.0
const AVATAR_SPEED_BONUS := 45.0
const AVATAR_HEALTH_BONUS := 50
const ICON_SIZE := Vector2(68, 68)

const ICON_FALLBACKS = {
	"stomp": "res://ability_icons/placeholder_stomp.svg",
	"hammer": "res://ability_icons/placeholder_hammer.svg",
	"bash": "res://ability_icons/placeholder_bash.svg",
	"avatar": "res://ability_icons/placeholder_avatar.svg"
}

const STOMP_KNOWN_PATHS = [
	"res://StompSprite.png",
	"res://StompSprite.webp",
	"res://StompSprite.svg",
	"res://StompSprite.tres",
	"res://stomp_sprite.png",
	"res://stomp_icon.png",
	"res://sprites/StompSprite.png",
	"res://assets/StompSprite.png"
]

var player
var world
var tile_map
var damage_layer
var front_damage_layer
var front_layer

var hammer_level := 0
var bash_level := 0
var avatar_level := 0
var hammer_cooldown_timer := 0.0
var avatar_cooldown_timer := 0.0
var avatar_duration_timer := 0.0
var avatar_active := false
var avatar_strength_bonus := 0
var avatar_health_bonus := 0
var avatar_aura: CPUParticles2D
var avatar_auto_dig_timer := 0.0

var bash_counter := 0
var facing_direction := Vector2.DOWN
var last_attack_timer := 0.0
var last_attacking_enemy
var last_digging_cell = null
var last_digging_source := -1
var last_stomp_cooldown := 0.0

var ability_bar: HBoxContainer
var ability_slots := {}
var icon_cache := {}

func _ready() -> void:
	player = get_parent()
	if player == null:
		queue_free()
		return
	world = player.get_parent()
	tile_map = world.get_node_or_null("BlockLayer") if world else null
	damage_layer = world.get_node_or_null("DamageLayer") if world else null
	front_damage_layer = world.get_node_or_null("FrontDamageLayer") if world else null
	front_layer = world.get_node_or_null("FrontWallLayer") if world else null
	process_priority = 100
	_ensure_ability_inputs()
	if world:
		world.child_entered_tree.connect(_on_world_child_entered)
		for child in world.get_children():
			_try_connect_level_menu(child)
	call_deferred("_ensure_hud")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_ensure_hud()
	var is_dwarf = str(player.get("current_hero_name")) == HERO_NAME
	if ability_bar:
		ability_bar.visible = is_dwarf
	_hide_legacy_stomp_slot()
	if not is_dwarf:
		if avatar_active:
			_end_avatar()
		return
	if bool(player.get("is_dead")):
		if avatar_active:
			_end_avatar()
		_update_ability_hud()
		return

	_update_facing_direction()
	hammer_cooldown_timer = max(0.0, hammer_cooldown_timer - delta)
	avatar_cooldown_timer = max(0.0, avatar_cooldown_timer - delta)
	avatar_auto_dig_timer = max(0.0, avatar_auto_dig_timer - delta)
	if avatar_active:
		avatar_duration_timer = max(0.0, avatar_duration_timer - delta)
		_apply_avatar_visuals()
		_try_avatar_auto_dig()
		if avatar_duration_timer <= 0.0:
			_end_avatar()

	if Input.is_action_just_pressed(_action_name("hammer")):
		_try_throw_hammer()
	if Input.is_action_just_pressed(_action_name("avatar")):
		_try_activate_avatar()

	_track_melee_bash()
	_track_mining_bash()
	_track_stomp_cast()
	_update_ability_hud()

func _action_name(ability: String) -> String:
	return "p%d_%s" % [int(player.get("player_id")), ability]

func _ensure_ability_inputs() -> void:
	var player_id = int(player.get("player_id"))
	var joy_device = max(0, player_id - 1)
	var hammer_key = KEY_F if player_id == 1 else KEY_KP_1
	var avatar_key = KEY_T if player_id == 1 else KEY_KP_2
	_ensure_input_action(_action_name("hammer"), hammer_key, JOY_BUTTON_RIGHT_SHOULDER, joy_device)
	_ensure_input_action(_action_name("avatar"), avatar_key, JOY_BUTTON_LEFT_SHOULDER, joy_device)

func _ensure_input_action(action_name: String, keycode: Key, joy_button: JoyButton, joy_device: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var has_key := false
	var has_button := false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			has_key = true
		elif event is InputEventJoypadButton and event.button_index == joy_button and event.device == joy_device:
			has_button = true
	if not has_key:
		var key_event = InputEventKey.new()
		key_event.physical_keycode = keycode
		InputMap.action_add_event(action_name, key_event)
	if not has_button:
		var joy_event = InputEventJoypadButton.new()
		joy_event.button_index = joy_button
		joy_event.device = joy_device
		InputMap.action_add_event(action_name, joy_event)

func _update_facing_direction() -> void:
	var velocity: Vector2 = player.get("velocity")
	if velocity.length() > 12.0:
		facing_direction = velocity.normalized()
		return
	var player_id = int(player.get("player_id"))
	var input_dir = Vector2(
		Input.get_axis("p%d_left" % player_id, "p%d_right" % player_id),
		Input.get_axis("p%d_up" % player_id, "p%d_down" % player_id)
	)
	if input_dir.length() > 0.2:
		facing_direction = input_dir.normalized()

func _cardinal_direction() -> Vector2:
	if abs(facing_direction.x) > abs(facing_direction.y):
		return Vector2(sign(facing_direction.x), 0)
	return Vector2(0, sign(facing_direction.y) if facing_direction.y != 0.0 else 1.0)

func _cardinal_cell_step() -> Vector2i:
	var direction = _cardinal_direction()
	return Vector2i(int(direction.x), int(direction.y))

func _try_throw_hammer() -> void:
	if hammer_level <= 0:
		_show_notice("Learn Throwing Hammer at the next level up")
		return
	if hammer_cooldown_timer > 0.0:
		_show_notice("Hammer ready in %.1fs" % hammer_cooldown_timer, 0.8)
		return
	var direction = _cardinal_direction()
	var max_cooldown = _hammer_max_cooldown()
	hammer_cooldown_timer = max_cooldown
	var range_value = 240.0 + hammer_level * 45.0
	var origin = player.global_position + Vector2(0, -24)
	var end_position = origin + direction * range_value
	_spawn_hammer_visual(origin, end_position)
	_hit_enemies_with_hammer(origin, direction, range_value)
	_break_hammer_tiles(direction)
	_show_notice("Throwing Hammer!")

func _hammer_max_cooldown() -> float:
	return max(4.5, HAMMER_BASE_COOLDOWN - hammer_level * 0.75 - (int(player.get("intelligence")) - 1) * 0.08)

func _hit_enemies_with_hammer(origin: Vector2, direction: Vector2, range_value: float) -> void:
	var candidates = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_center = enemy.global_position + Vector2(0, 8)
		var to_enemy = enemy_center - origin
		var forward_distance = to_enemy.dot(direction)
		var side_distance = abs(to_enemy.cross(direction))
		if forward_distance >= 0.0 and forward_distance <= range_value and side_distance <= 42.0:
			candidates.append({"enemy": enemy, "distance": forward_distance})
	candidates.sort_custom(func(a, b): return float(a["distance"]) < float(b["distance"]))
	var hit_limit = 3 if avatar_active else 1
	var damage = 70 + hammer_level * 55 + int(player.get("strength")) * 16
	for i in range(min(hit_limit, candidates.size())):
		var enemy = candidates[i]["enemy"]
		if enemy.has_method("apply_stun"):
			enemy.apply_stun(0.75 + hammer_level * 0.2, direction * (150.0 + hammer_level * 20.0))
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)

func _break_hammer_tiles(direction: Vector2) -> void:
	if tile_map == null:
		return
	var origin_cell: Vector2i = tile_map.local_to_map(tile_map.to_local(player.global_position))
	var step = Vector2i(int(direction.x), int(direction.y))
	var tiles_to_break = hammer_level + (2 if avatar_active else 0)
	var broken := 0
	for distance in range(1, tiles_to_break + 5):
		var cell = origin_cell + step * distance
		var source_id = tile_map.get_cell_source_id(cell)
		if source_id == -1:
			continue
		if _is_protected_hammer_tile(cell, source_id):
			break
		if _break_soft_tile(cell):
			broken += 1
		if broken >= tiles_to_break:
			break

func _is_protected_hammer_tile(cell: Vector2i, source_id: int) -> bool:
	if (cell.y <= 1 and cell.x != 0) or cell.y < 0:
		return true
	return source_id == 2 or source_id == 3

func _break_soft_tile(cell: Vector2i) -> bool:
	if tile_map == null:
		return false
	var source_id = tile_map.get_cell_source_id(cell)
	if source_id == -1 or _is_protected_hammer_tile(cell, source_id):
		return false
	tile_map.erase_cell(cell)
	if damage_layer:
		damage_layer.erase_cell(cell)
	var below_cell = Vector2i(cell.x, cell.y + 1)
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

func _spawn_hammer_visual(origin: Vector2, end_position: Vector2) -> void:
	if world == null:
		return
	var sprite = Sprite2D.new()
	sprite.name = "ThrownHammer"
	sprite.texture = _get_ability_icon("hammer")
	sprite.global_position = origin
	sprite.scale = Vector2(0.62, 0.62)
	sprite.z_index = 20
	world.add_child(sprite)
	var tween = sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "global_position", end_position, 0.28)
	tween.tween_property(sprite, "rotation", TAU * 3.0, 0.28)
	tween.tween_property(sprite, "scale", Vector2(0.38, 0.38), 0.28)
	tween.set_parallel(false)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.08)
	tween.tween_callback(sprite.queue_free)

func _track_melee_bash() -> void:
	var attack_timer = float(player.get("attack_timer"))
	var attacking_enemy = player.get("currently_attacking_enemy")
	if bash_level > 0 and is_instance_valid(attacking_enemy):
		var attack_completed = attacking_enemy == last_attacking_enemy and last_attack_timer > 0.02 and attack_timer <= 0.001
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
		var was_dug = last_digging_source != -1 and tile_map.get_cell_source_id(last_digging_cell) == -1
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

func _register_bash_attack(primary_enemy) -> void:
	if not _advance_bash_counter():
		return
	var bonus_damage = 25 + bash_level * 25 + int(player.get("strength")) * 8
	var knockback = player.global_position.direction_to(primary_enemy.global_position) * (115.0 + bash_level * 25.0)
	if primary_enemy.has_method("apply_stun"):
		primary_enemy.apply_stun(0.35 + bash_level * 0.2, knockback)
	if primary_enemy.has_method("take_damage"):
		primary_enemy.take_damage(bonus_damage)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == primary_enemy or not is_instance_valid(enemy):
			continue
		if primary_enemy.global_position.distance_to(enemy.global_position) <= 78.0:
			if enemy.has_method("take_damage"):
				enemy.take_damage(int(bonus_damage * 0.5))
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(0.18 + bash_level * 0.08, knockback * 0.45)
	_spawn_bash_burst(primary_enemy.global_position)
	_show_notice("Dwarven Bash!")

func _register_bash_mining(dug_cell: Vector2i) -> void:
	if not _advance_bash_counter():
		return
	var target_cell = dug_cell + _cardinal_cell_step()
	if _break_soft_tile(target_cell):
		_spawn_bash_burst(tile_map.to_global(tile_map.map_to_local(target_cell)))
		_show_notice("Bash smashed the next block!")

func _spawn_bash_burst(position: Vector2) -> void:
	if world == null:
		return
	var burst = CPUParticles2D.new()
	burst.one_shot = true
	burst.amount = 22
	burst.lifetime = 0.35
	burst.explosiveness = 0.95
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 8.0
	burst.initial_velocity_min = 80.0
	burst.initial_velocity_max = 180.0
	burst.damping_min = 160.0
	burst.damping_max = 240.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 5.0
	burst.color = Color(1.0, 0.72, 0.2, 0.9)
	burst.global_position = position
	burst.z_index = 15
	world.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.7).timeout.connect(burst.queue_free)

func _try_activate_avatar() -> void:
	if avatar_level <= 0 or int(player.get("level")) < AVATAR_REQUIRED_LEVEL:
		_show_notice("Avatar unlocks at hero level 6")
		return
	if avatar_cooldown_timer > 0.0:
		_show_notice("Avatar ready in %.1fs" % avatar_cooldown_timer, 0.8)
		return
	if avatar_active:
		return
	avatar_active = true
	avatar_duration_timer = AVATAR_DURATION
	avatar_cooldown_timer = AVATAR_COOLDOWN
	var strength = int(player.get("strength"))
	avatar_strength_bonus = max(2, int(ceil(strength * 0.5)))
	avatar_health_bonus = AVATAR_HEALTH_BONUS
	player.set("strength", strength + avatar_strength_bonus)
	player.set("base_speed", float(player.get("base_speed")) + AVATAR_SPEED_BONUS)
	player.set("max_health", int(player.get("max_health")) + avatar_health_bonus)
	player.set("health", int(player.get("health")) + avatar_health_bonus)
	_spawn_avatar_aura()
	_refresh_player_health_hud()
	_show_notice("AVATAR OF THE MOUNTAIN!")

func _end_avatar() -> void:
	if not avatar_active:
		return
	avatar_active = false
	player.set("strength", max(1, int(player.get("strength")) - avatar_strength_bonus))
	player.set("base_speed", max(1.0, float(player.get("base_speed")) - AVATAR_SPEED_BONUS))
	player.set("max_health", max(1, int(player.get("max_health")) - avatar_health_bonus))
	player.set("health", min(int(player.get("health")), int(player.get("max_health"))))
	avatar_strength_bonus = 0
	avatar_health_bonus = 0
	if is_instance_valid(avatar_aura):
		avatar_aura.queue_free()
	avatar_aura = null
	var sprite = player.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color.WHITE
		var normal_scale = player.get("current_sprite_scale")
		if normal_scale is Vector2:
			sprite.scale = normal_scale
	_refresh_player_health_hud()
	_show_notice("Avatar faded", 0.8)

func _apply_avatar_visuals() -> void:
	var sprite = player.get_node_or_null("Sprite2D")
	if sprite:
		var normal_scale = player.get("current_sprite_scale")
		if normal_scale is Vector2:
			sprite.scale = normal_scale * 1.18
		sprite.modulate = Color(1.25, 1.02, 0.52, 1.0)

func _spawn_avatar_aura() -> void:
	avatar_aura = CPUParticles2D.new()
	avatar_aura.name = "AvatarAura"
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
	if avatar_auto_dig_timer > 0.0 or tile_map == null:
		return
	var velocity: Vector2 = player.get("velocity")
	if velocity.length() < 20.0:
		return
	var origin_cell: Vector2i = tile_map.local_to_map(tile_map.to_local(player.global_position))
	var target_cell = origin_cell + _cardinal_cell_step()
	if _break_soft_tile(target_cell):
		avatar_auto_dig_timer = 0.24

func _track_stomp_cast() -> void:
	var current_cooldown = float(player.get("stomp_cooldown_timer"))
	var stomp_cast = current_cooldown > last_stomp_cooldown + 0.45
	if stomp_cast and int(player.get("stomp_level")) > 0:
		var stomp_level = int(player.get("stomp_level"))
		var base_radius = 100.0 + stomp_level * 20.0
		var radius = base_radius + (55.0 if avatar_active else 0.0)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			var distance = player.global_position.distance_to(enemy.global_position)
			if distance <= radius:
				var push = player.global_position.direction_to(enemy.global_position) * 80.0
				if enemy.has_method("apply_stun"):
					enemy.apply_stun(0.45 + stomp_level * 0.18, push)
				if avatar_active and distance > base_radius and enemy.has_method("take_damage"):
					enemy.take_damage(12 * stomp_level * int(player.get("strength")))
	last_stomp_cooldown = current_cooldown

func _on_world_child_entered(node: Node) -> void:
	_try_connect_level_menu(node)

func _try_connect_level_menu(node: Node) -> void:
	if node == null or not node.has_signal("upgrade_selected"):
		return
	var callable = Callable(self, "_on_upgrade_selected")
	if not node.is_connected("upgrade_selected", callable):
		node.connect("upgrade_selected", callable)

func _on_upgrade_selected(upgrade_type: String) -> void:
	if str(player.get("current_hero_name")) != HERO_NAME:
		return
	match upgrade_type:
		"hammer":
			if hammer_level < HAMMER_MAX_LEVEL:
				hammer_level += 1
				_show_notice("Throwing Hammer level %d" % hammer_level)
		"bash":
			if bash_level < BASH_MAX_LEVEL:
				bash_level += 1
				bash_counter = 0
				_show_notice("Dwarven Bash level %d" % bash_level)
		"avatar":
			if avatar_level == 0 and int(player.get("level")) >= AVATAR_REQUIRED_LEVEL:
				avatar_level = 1
				_show_notice("Avatar of the Mountain learned!")
	_update_ability_hud()

func _ensure_hud() -> void:
	if ability_bar != null and is_instance_valid(ability_bar):
		return
	if world == null:
		return
	var hud = world.get_node_or_null("HUD")
	if hud == null:
		return
	ability_bar = HBoxContainer.new()
	ability_bar.name = "DwarfAbilityBar"
	ability_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ability_bar.offset_left = -326.0
	ability_bar.offset_top = -96.0
	ability_bar.offset_right = -20.0
	ability_bar.offset_bottom = -20.0
	ability_bar.add_theme_constant_override("separation", 8)
	hud.add_child(ability_bar)
	ability_slots["stomp"] = _create_ability_slot("stomp", "Ground Stomp", "R / X")
	ability_slots["hammer"] = _create_ability_slot("hammer", "Throwing Hammer", "F / RB")
	ability_slots["bash"] = _create_ability_slot("bash", "Dwarven Bash", "PASSIVE")
	ability_slots["avatar"] = _create_ability_slot("avatar", "Avatar", "T / LB")
	_update_ability_hud()

func _create_ability_slot(ability: String, display_name: String, key_text: String) -> PanelContainer:
	var slot = PanelContainer.new()
	slot.name = "%sSlot" % ability.capitalize()
	slot.custom_minimum_size = ICON_SIZE
	slot.tooltip_text = display_name
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.055, 0.05, 0.92)
	style.border_color = Color(0.62, 0.47, 0.25, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	slot.add_theme_stylebox_override("panel", style)
	var root = Control.new()
	root.name = "Root"
	root.custom_minimum_size = ICON_SIZE
	slot.add_child(root)
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.texture = _get_ability_icon(ability)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 5
	icon.offset_top = 5
	icon.offset_right = -5
	icon.offset_bottom = -5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	var overlay = ColorRect.new()
	overlay.name = "CooldownOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 1.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	var timer = Label.new()
	timer.name = "Timer"
	timer.set_anchors_preset(Control.PRESET_FULL_RECT)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer.add_theme_font_size_override("font_size", 13)
	timer.add_theme_color_override("font_color", Color.WHITE)
	timer.add_theme_color_override("font_shadow_color", Color.BLACK)
	timer.add_theme_constant_override("shadow_offset_x", 1)
	timer.add_theme_constant_override("shadow_offset_y", 1)
	timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(timer)
	var key_label = Label.new()
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
	var level_label = Label.new()
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
	var stomp_level = int(player.get("stomp_level"))
	var stomp_max = max(1.0, 5.0 - stomp_level * 0.5)
	_update_slot("stomp", stomp_level, float(player.get("stomp_cooldown_timer")), stomp_max, "LOCKED" if stomp_level <= 0 else "")
	_update_slot("hammer", hammer_level, hammer_cooldown_timer, _hammer_max_cooldown(), "LOCKED" if hammer_level <= 0 else "")
	var bash_status = "LOCKED" if bash_level <= 0 else "%d/%d" % [bash_counter, _bash_threshold()]
	_update_slot("bash", bash_level, 0.0, 1.0, bash_status)
	var avatar_status := ""
	if avatar_level <= 0:
		avatar_status = "LVL 6" if int(player.get("level")) < AVATAR_REQUIRED_LEVEL else "LOCKED"
	elif avatar_active:
		avatar_status = "%.1f" % avatar_duration_timer
	_update_slot("avatar", avatar_level, avatar_cooldown_timer, AVATAR_COOLDOWN, avatar_status, avatar_active)

func _update_slot(ability: String, level_value: int, cooldown: float, max_cooldown: float, override_text: String = "", active: bool = false) -> void:
	var slot = ability_slots.get(ability)
	if slot == null:
		return
	var icon = slot.get_node_or_null("Root/Icon")
	var overlay = slot.get_node_or_null("Root/CooldownOverlay")
	var timer = slot.get_node_or_null("Root/Timer")
	var level_label = slot.get_node_or_null("Root/Level")
	var locked = level_value <= 0
	if icon:
		icon.modulate = Color(1.2, 0.92, 0.42, 1.0) if active else (Color(0.38, 0.38, 0.38, 0.85) if locked else Color.WHITE)
	if overlay:
		var ratio = clamp(cooldown / max(max_cooldown, 0.01), 0.0, 1.0)
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
	var hud = world.get_node_or_null("HUD")
	if hud:
		var legacy = hud.get_node_or_null("StompContainer")
		if legacy:
			legacy.visible = false

func _get_ability_icon(ability: String) -> Texture2D:
	if icon_cache.has(ability):
		return icon_cache[ability]
	var texture: Texture2D = null
	if ability == "stomp":
		for path in STOMP_KNOWN_PATHS:
			if ResourceLoader.exists(path):
				var resource = load(path)
				if resource is Texture2D:
					texture = resource
					break
		if texture == null:
			texture = _scan_for_texture("res://", "stomp", 0)
	if texture == null:
		var fallback_path = str(ICON_FALLBACKS.get(ability, ""))
		if fallback_path != "" and ResourceLoader.exists(fallback_path):
			texture = load(fallback_path) as Texture2D
	icon_cache[ability] = texture
	return texture

func _scan_for_texture(directory_path: String, keyword: String, depth: int) -> Texture2D:
	if depth > 5:
		return null
	for file_name in DirAccess.get_files_at(directory_path):
		var lower = file_name.to_lower()
		var extension = file_name.get_extension().to_lower()
		if lower.contains(keyword) and not lower.contains("placeholder") and extension in ["png", "webp", "svg", "tres"]:
			var path = directory_path.path_join(file_name)
			var resource = load(path)
			if resource is Texture2D:
				return resource
	for child_dir in DirAccess.get_directories_at(directory_path):
		if child_dir.begins_with("."):
			continue
		var found = _scan_for_texture(directory_path.path_join(child_dir), keyword, depth + 1)
		if found:
			return found
	return null

func _refresh_player_health_hud() -> void:
	if world == null:
		return
	var hud = world.get_node_or_null("HUD")
	if hud and hud.has_method("update_player_health"):
		hud.update_player_health(int(player.get("health")), int(player.get("max_health")))
	if hud and hud.has_method("update_stats"):
		hud.update_stats(int(player.get("strength")), int(player.get("agility")), int(player.get("intelligence")))

func _show_notice(text: String, duration: float = 1.5) -> void:
	if world == null:
		return
	var hud = world.get_node_or_null("HUD")
	if hud and hud.has_method("show_notice"):
		hud.show_notice(text, duration)
