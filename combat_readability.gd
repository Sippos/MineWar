extends Node

const OVERLAY_NAME := "CombatReadabilityOverlay"
const ENEMY_BAR_NAME := "ReadabilityHealthBar"
const ENEMY_NAME_LABEL := "ReadabilityName"
const ATTACK_TELEGRAPH_NAME := "BaseAttackTelegraph"
const ENEMY_BAR_WIDTH := 72.0
const BOSS_BAR_WIDTH := 142.0
const BASE_MAX_HEALTH := 100.0

var active_world: Node = null
var overlay: Control = null
var wave_label: Label = null
var objective_label: Label = null
var ability_label: Label = null
var worker_label: Label = null
var threat_label: Label = null
var base_label: Label = null
var base_bar: ProgressBar = null
var boss_container: VBoxContainer = null
var boss_label: Label = null
var boss_bar: ProgressBar = null
var announcement_label: Label = null
var damage_vignette: ColorRect = null
var announcement_tween: Tween = null
var vignette_tween: Tween = null

var enemy_cache: Dictionary = {}
var reconcile_timer := 0.0
var last_enemy_count := 0
var last_announced_wave := 0
var last_base_health := -1
var last_player_health := -1
var last_ability_key := ""
var last_ability_ready := false
var last_boss_countdown_second := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	var world := _find_single_player_world()
	if world != active_world:
		_bind_world(world)
	if active_world == null or not is_instance_valid(active_world):
		return
	
	reconcile_timer -= delta
	if reconcile_timer <= 0.0:
		reconcile_timer = 0.08
		_reconcile_combat_state(delta)
	_update_telegraph_motion(delta)

func _bind_world(world: Node) -> void:
	_clear_overlay()
	active_world = world
	enemy_cache.clear()
	last_enemy_count = 0
	last_announced_wave = 0
	last_base_health = -1
	last_player_health = -1
	last_ability_key = ""
	last_ability_ready = false
	last_boss_countdown_second = -1
	if active_world == null:
		return
	var hud := active_world.get_node_or_null("HUD")
	if hud:
		_build_overlay(hud)

func _find_single_player_world() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return _find_world_recursive(scene)

func _find_world_recursive(node: Node) -> Node:
	if node.has_node("Base") and node.has_node("HUD") and node.get("current_wave_number") != null:
		if not bool(node.get("is_vs_mode")):
			return node
	for child in node.get_children():
		var found := _find_world_recursive(child)
		if found:
			return found
	return null

func _build_overlay(hud: Node) -> void:
	var old_overlay := hud.get_node_or_null(OVERLAY_NAME)
	if old_overlay:
		old_overlay.queue_free()
	
	overlay = Control.new()
	overlay.name = OVERLAY_NAME
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 420
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(overlay)
	
	damage_vignette = ColorRect.new()
	damage_vignette.name = "DamageVignette"
	damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_vignette.color = Color(0.75, 0.03, 0.01, 0.0)
	overlay.add_child(damage_vignette)
	
	var top_panel := PanelContainer.new()
	top_panel.name = "CombatSummary"
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.anchor_left = 0.5
	top_panel.anchor_right = 0.5
	top_panel.offset_left = -275.0
	top_panel.offset_right = 275.0
	top_panel.offset_top = 12.0
	top_panel.offset_bottom = 116.0
	top_panel.add_theme_stylebox_override("panel", _make_panel_style())
	overlay.add_child(top_panel)
	
	var top_content := VBoxContainer.new()
	top_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_content.add_theme_constant_override("separation", 2)
	top_panel.add_child(top_content)
	
	wave_label = _make_center_label(22, Color(1.0, 0.88, 0.58, 1.0))
	wave_label.text = "PREPARING MINE"
	top_content.add_child(wave_label)
	
	objective_label = _make_center_label(15, Color(0.9, 0.9, 0.86, 1.0))
	objective_label.text = "Survive the waves and protect the base"
	top_content.add_child(objective_label)
	
	var base_row := HBoxContainer.new()
	base_row.alignment = BoxContainer.ALIGNMENT_CENTER
	base_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_row.add_theme_constant_override("separation", 8)
	top_content.add_child(base_row)
	
	base_label = Label.new()
	base_label.text = "BASE 100%"
	base_label.custom_minimum_size = Vector2(92, 20)
	base_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	base_label.add_theme_font_size_override("font_size", 14)
	base_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 1.0))
	base_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_row.add_child(base_label)
	
	base_bar = ProgressBar.new()
	base_bar.custom_minimum_size = Vector2(260, 14)
	base_bar.min_value = 0.0
	base_bar.max_value = BASE_MAX_HEALTH
	base_bar.value = BASE_MAX_HEALTH
	base_bar.show_percentage = false
	base_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_bar.add_theme_stylebox_override("background", _make_bar_background())
	base_bar.add_theme_stylebox_override("fill", _make_bar_fill(Color(0.2, 0.72, 0.95, 1.0)))
	base_row.add_child(base_bar)
	
	ability_label = _make_center_label(13, Color(0.72, 0.9, 1.0, 1.0))
	ability_label.text = ""
	top_content.add_child(ability_label)
	
	worker_label = _make_center_label(12, Color(0.78, 0.78, 0.72, 0.92))
	worker_label.text = ""
	worker_label.anchor_left = 0.0
	worker_label.anchor_right = 0.0
	worker_label.offset_left = 18.0
	worker_label.offset_top = 122.0
	worker_label.offset_right = 330.0
	worker_label.offset_bottom = 146.0
	overlay.add_child(worker_label)
	
	threat_label = _make_center_label(20, Color(1.0, 0.28, 0.16, 1.0))
	threat_label.anchor_left = 0.5
	threat_label.anchor_right = 0.5
	threat_label.offset_left = -260.0
	threat_label.offset_right = 260.0
	threat_label.offset_top = 124.0
	threat_label.offset_bottom = 156.0
	threat_label.visible = false
	overlay.add_child(threat_label)
	
	boss_container = VBoxContainer.new()
	boss_container.name = "BossStatus"
	boss_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_container.anchor_left = 0.5
	boss_container.anchor_right = 0.5
	boss_container.offset_left = -240.0
	boss_container.offset_right = 240.0
	boss_container.offset_top = 164.0
	boss_container.offset_bottom = 214.0
	boss_container.add_theme_constant_override("separation", 2)
	boss_container.visible = false
	overlay.add_child(boss_container)
	
	boss_label = _make_center_label(17, Color(1.0, 0.32, 0.18, 1.0))
	boss_label.text = "MECH BOSS"
	boss_container.add_child(boss_label)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(480, 18)
	boss_bar.min_value = 0.0
	boss_bar.show_percentage = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.add_theme_stylebox_override("background", _make_bar_background())
	boss_bar.add_theme_stylebox_override("fill", _make_bar_fill(Color(0.9, 0.12, 0.06, 1.0)))
	boss_container.add_child(boss_bar)
	
	announcement_label = _make_center_label(42, Color(1.0, 0.83, 0.34, 1.0))
	announcement_label.anchor_left = 0.5
	announcement_label.anchor_top = 0.38
	announcement_label.anchor_right = 0.5
	announcement_label.anchor_bottom = 0.38
	announcement_label.offset_left = -360.0
	announcement_label.offset_right = 360.0
	announcement_label.offset_top = -60.0
	announcement_label.offset_bottom = 60.0
	announcement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcement_label.visible = false
	overlay.add_child(announcement_label)

func _clear_overlay() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	wave_label = null
	objective_label = null
	ability_label = null
	worker_label = null
	threat_label = null
	base_label = null
	base_bar = null
	boss_container = null
	boss_label = null
	boss_bar = null
	announcement_label = null
	damage_vignette = null

func _reconcile_combat_state(delta: float) -> void:
	if overlay == null or not is_instance_valid(overlay):
		var hud := active_world.get_node_or_null("HUD")
		if hud:
			_build_overlay(hud)
		else:
			return
	
	var enemies := _get_world_group_nodes("enemies")
	_reconcile_enemies(enemies, delta)
	_update_wave_display(enemies)
	_update_base_display(enemies)
	_update_player_feedback()
	_update_ability_display()
	_update_worker_summary()
	last_enemy_count = enemies.size()

func _get_world_group_nodes(group_name: String) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(node) and active_world.is_ancestor_of(node):
			result.append(node)
	return result

func _reconcile_enemies(enemies: Array[Node], delta: float) -> void:
	var live_ids := {}
	var player := active_world.get_node_or_null("Player")
	var base := active_world.get_node_or_null("Base")
	var boss_enemy: Node = null
	
	for enemy in enemies:
		var enemy_id := enemy.get_instance_id()
		live_ids[enemy_id] = true
		if not enemy_cache.has(enemy_id):
			_register_enemy(enemy)
		var data: Dictionary = enemy_cache[enemy_id]
		var current_health := max(0, int(enemy.get("health")))
		var previous_health := int(data.get("last_health", current_health))
		var max_health := max(int(data.get("max_health", current_health)), current_health, 1)
		data["max_health"] = max_health
		
		var bar := data.get("bar") as ProgressBar
		if bar and is_instance_valid(bar):
			bar.max_value = max_health
			bar.value = current_health
		
		if current_health < previous_health:
			var damage_done := previous_health - current_health
			data["show_timer"] = 2.4
			_spawn_damage_number(enemy, damage_done, bool(enemy.get("is_boss_enemy")))
			_play_enemy_hit_punch(enemy)
		else:
			data["show_timer"] = max(0.0, float(data.get("show_timer", 0.0)) - delta)
		
		var near_player := player != null and enemy.global_position.distance_to(player.global_position) < 260.0
		var near_base := base != null and enemy.global_position.distance_to(base.global_position) < 220.0
		var is_boss := bool(enemy.get("is_boss_enemy"))
		if bar and is_instance_valid(bar):
			bar.visible = is_boss or current_health < max_health or near_player or near_base or float(data.get("show_timer", 0.0)) > 0.0
		
		var telegraph := data.get("telegraph") as Line2D
		if telegraph and is_instance_valid(telegraph):
			var cooldown_value = enemy.get("attack_cooldown_timer")
			var cooldown := float(cooldown_value) if cooldown_value != null else 1.0
			telegraph.visible = base != null and enemy.global_position.distance_to(base.global_position) < 92.0 and cooldown <= 0.34
		
		data["last_health"] = current_health
		enemy_cache[enemy_id] = data
		if is_boss:
			boss_enemy = enemy
	
	for cached_id in enemy_cache.keys():
		if not live_ids.has(cached_id):
			enemy_cache.erase(cached_id)
	
	_update_boss_bar(boss_enemy)

func _register_enemy(enemy: Node) -> void:
	var current_health := max(1, int(enemy.get("health")))
	var is_boss := bool(enemy.get("is_boss_enemy"))
	var width := BOSS_BAR_WIDTH if is_boss else ENEMY_BAR_WIDTH
	var bar := ProgressBar.new()
	bar.name = ENEMY_BAR_NAME
	bar.position = Vector2(-width * 0.5, -104.0 if is_boss else -62.0)
	bar.size = Vector2(width, 9.0 if is_boss else 6.0)
	bar.min_value = 0.0
	bar.max_value = current_health
	bar.value = current_health
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.z_index = 50
	bar.add_theme_stylebox_override("background", _make_bar_background())
	bar.add_theme_stylebox_override("fill", _make_bar_fill(_enemy_bar_color(enemy)))
	enemy.add_child(bar)
	
	if is_boss:
		var name_label := Label.new()
		name_label.name = ENEMY_NAME_LABEL
		name_label.position = Vector2(-80.0, -128.0)
		name_label.size = Vector2(160.0, 24.0)
		name_label.text = "MECH BOSS"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.32, 0.16, 1.0))
		name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		name_label.add_theme_constant_override("shadow_offset_x", 1)
		name_label.add_theme_constant_override("shadow_offset_y", 1)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.z_index = 51
		enemy.add_child(name_label)
	
	var telegraph := _create_attack_telegraph()
	enemy.add_child(telegraph)
	
	enemy_cache[enemy.get_instance_id()] = {
		"node": enemy,
		"last_health": current_health,
		"max_health": current_health,
		"show_timer": 0.0,
		"bar": bar,
		"telegraph": telegraph
	}

func _enemy_bar_color(enemy: Node) -> Color:
	if bool(enemy.get("is_boss_enemy")):
		return Color(0.92, 0.1, 0.04, 1.0)
	var enemy_type_value = enemy.get("enemy_type")
	var enemy_type := int(enemy_type_value) if enemy_type_value != null else 0
	if enemy_type >= 3:
		return Color(0.95, 0.55, 0.1, 1.0)
	return Color(0.25, 0.86, 0.28, 1.0)

func _create_attack_telegraph() -> Line2D:
	var telegraph := Line2D.new()
	telegraph.name = ATTACK_TELEGRAPH_NAME
	telegraph.closed = true
	telegraph.width = 2.0
	telegraph.default_color = Color(1.0, 0.12, 0.04, 0.86)
	telegraph.position = Vector2(0, 8)
	telegraph.z_index = -1
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(Vector2(cos(angle), sin(angle) * 0.45) * 35.0)
	telegraph.points = points
	telegraph.visible = false
	return telegraph

func _update_telegraph_motion(delta: float) -> void:
	for data_value in enemy_cache.values():
		var data: Dictionary = data_value
		var telegraph := data.get("telegraph") as Line2D
		if telegraph and is_instance_valid(telegraph) and telegraph.visible:
			telegraph.rotation += delta * 2.2
			telegraph.modulate.a = 0.62 + sin(Time.get_ticks_msec() * 0.018) * 0.28

func _spawn_damage_number(enemy: Node, amount: int, is_boss: bool) -> void:
	if amount <= 0 or active_world == null:
		return
	var popup := Label.new()
	popup.text = "-%d" % amount
	popup.custom_minimum_size = Vector2(70, 28)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 24 if is_boss else 17)
	popup.add_theme_color_override("font_color", Color(1.0, 0.9, 0.46, 1.0) if is_boss else Color(1.0, 1.0, 1.0, 1.0))
	popup.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	popup.add_theme_constant_override("shadow_offset_x", 2)
	popup.add_theme_constant_override("shadow_offset_y", 2)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 120
	active_world.add_child(popup)
	popup.global_position = enemy.global_position + Vector2(randf_range(-34.0, -4.0), -88.0 if is_boss else -62.0)
	var target := popup.global_position + Vector2(randf_range(-12.0, 12.0), -36.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "global_position", target, 0.48)
	tween.tween_property(popup, "modulate:a", 0.0, 0.48)
	tween.chain().tween_callback(popup.queue_free)

func _play_enemy_hit_punch(enemy: Node) -> void:
	var sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var original_scale := sprite.scale
	sprite.scale = original_scale * 1.07
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", original_scale, 0.12)

func _update_boss_bar(boss_enemy: Node) -> void:
	if boss_container == null:
		return
	if boss_enemy == null or not is_instance_valid(boss_enemy):
		boss_container.visible = false
		return
	boss_container.visible = true
	var data: Dictionary = enemy_cache.get(boss_enemy.get_instance_id(), {})
	var max_health := max(1, int(data.get("max_health", boss_enemy.get("health"))))
	var current_health := max(0, int(boss_enemy.get("health")))
	boss_bar.max_value = max_health
	boss_bar.value = current_health
	boss_label.text = "MECH BOSS   %d / %d" % [current_health, max_health]

func _update_wave_display(enemies: Array[Node]) -> void:
	if wave_label == null:
		return
	var enemy_count := enemies.size()
	var current_wave := max(1, int(active_world.get("current_wave_number")))
	var wave_timer_value = active_world.get("wave_timer")
	var wave_timer := max(0.0, float(wave_timer_value)) if wave_timer_value != null else 0.0
	var active_wave := current_wave
	if enemy_count > 0 and current_wave > 1:
		active_wave = current_wave - 1
	
	if enemy_count > 0:
		wave_label.text = "WAVE %d   •   %d %s REMAIN" % [active_wave, enemy_count, "ENEMY" if enemy_count == 1 else "ENEMIES"]
		objective_label.text = "Defeat the wave before it reaches your base"
		if last_enemy_count == 0 and active_wave != last_announced_wave:
			last_announced_wave = active_wave
			var boss_wave := _find_boss(enemies) != null or active_wave % 10 == 0
			_show_announcement("BOSS WAVE %d\nDEFEND THE BASE" % active_wave if boss_wave else "WAVE %d" % active_wave, boss_wave)
	else:
		wave_label.text = "NEXT WAVE %d   •   %ds" % [current_wave, int(ceil(wave_timer))]
		objective_label.text = "Mine, invest, and prepare your tunnels"
		if current_wave == 10 and wave_timer <= 10.0:
			var countdown_second := int(ceil(wave_timer))
			threat_label.visible = true
			threat_label.text = "BOSS ARRIVES IN %d" % countdown_second
			if countdown_second != last_boss_countdown_second and countdown_second in [10, 5, 3, 2, 1]:
				last_boss_countdown_second = countdown_second
				if countdown_second == 10 or countdown_second == 5:
					_show_announcement("BOSS IN %d" % countdown_second, true)

func _find_boss(enemies: Array[Node]) -> Node:
	for enemy in enemies:
		if bool(enemy.get("is_boss_enemy")):
			return enemy
	return null

func _update_base_display(enemies: Array[Node]) -> void:
	var base := active_world.get_node_or_null("Base")
	if base == null:
		return
	var health := clamp(int(base.get("health")), 0, int(BASE_MAX_HEALTH))
	if last_base_health < 0:
		last_base_health = health
	if health < last_base_health:
		_play_base_damage_feedback(base, last_base_health - health)
	last_base_health = health
	
	if base_bar:
		base_bar.value = health
	if base_label:
		base_label.text = "BASE %d%%" % health
		if health <= 25:
			base_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.12, 1.0))
		elif health <= 50:
			base_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2, 1.0))
		else:
			base_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 1.0))
	
	var attackers := 0
	var approaching := 0
	for enemy in enemies:
		var distance := enemy.global_position.distance_to(base.global_position)
		if distance < 94.0:
			attackers += 1
		elif distance < 270.0:
			approaching += 1
	
	var boss_countdown_active := enemies.size() == 0 and int(active_world.get("current_wave_number")) == 10 and float(active_world.get("wave_timer")) <= 10.0
	if threat_label and not boss_countdown_active:
		if attackers > 0:
			threat_label.visible = true
			threat_label.text = "BASE UNDER ATTACK   •   %d %s" % [attackers, "ATTACKER" if attackers == 1 else "ATTACKERS"]
			threat_label.modulate.a = 0.72 + sin(Time.get_ticks_msec() * 0.012) * 0.25
		elif approaching > 0:
			threat_label.visible = true
			threat_label.text = "%d %s APPROACHING BASE" % [approaching, "ENEMY" if approaching == 1 else "ENEMIES"]
			threat_label.modulate.a = 0.9
		else:
			threat_label.visible = false

func _play_base_damage_feedback(base: Node, amount: int) -> void:
	var sprite := base.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		var original_scale := sprite.scale
		var original_modulate := sprite.modulate
		sprite.scale = original_scale * 1.08
		sprite.modulate = Color(1.0, 0.22, 0.12, 1.0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "scale", original_scale, 0.18)
		tween.tween_property(sprite, "modulate", original_modulate, 0.22)
	_spawn_world_warning(base.global_position + Vector2(-70, -112), "BASE -%d" % amount, Color(1.0, 0.18, 0.08, 1.0), 24)
	_flash_vignette(Color(0.9, 0.12, 0.02, 0.24))

func _update_player_feedback() -> void:
	var player := active_world.get_node_or_null("Player")
	if player == null:
		return
	var health := int(player.get("health"))
	if last_player_health < 0:
		last_player_health = health
	if health < last_player_health:
		_flash_vignette(Color(0.72, 0.02, 0.01, 0.18))
	last_player_health = health

func _flash_vignette(color: Color) -> void:
	if damage_vignette == null:
		return
	if vignette_tween and vignette_tween.is_running():
		vignette_tween.kill()
	damage_vignette.color = color
	vignette_tween = create_tween()
	vignette_tween.tween_property(damage_vignette, "color:a", 0.0, 0.32)

func _spawn_world_warning(position_value: Vector2, text_value: String, color: Color, font_size: int) -> void:
	var popup := Label.new()
	popup.text = text_value
	popup.custom_minimum_size = Vector2(140, 32)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", font_size)
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	popup.add_theme_constant_override("shadow_offset_x", 2)
	popup.add_theme_constant_override("shadow_offset_y", 2)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 130
	active_world.add_child(popup)
	popup.global_position = position_value
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "global_position", position_value + Vector2(0, -42), 0.65)
	tween.tween_property(popup, "modulate:a", 0.0, 0.65)
	tween.chain().tween_callback(popup.queue_free)

func _update_ability_display() -> void:
	if ability_label == null:
		return
	var player := active_world.get_node_or_null("Player")
	if player == null:
		ability_label.text = ""
		return
	var hero_name := str(player.get("current_hero_name"))
	var ability_key := ""
	var ability_name := ""
	var cooldown := 0.0
	var available := true
	
	match hero_name:
		"Shaman":
			ability_key = "E"
			ability_name = "TOTEM"
			cooldown = max(0.0, float(player.get("shaman_spell_cooldown_timer")))
		"Nerubian":
			ability_key = "E"
			ability_name = "BROOD SPIDER"
			cooldown = max(0.0, float(player.get("nerubian_spawn_cooldown_timer")))
		_:
			var stomp_level := int(player.get("stomp_level"))
			if stomp_level <= 0:
				ability_label.text = "LEVEL UP TO UNLOCK A COMBAT ABILITY"
				ability_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.62, 0.9))
				last_ability_key = ""
				last_ability_ready = false
				return
			ability_key = "R"
			ability_name = "STOMP"
			cooldown = max(0.0, float(player.get("stomp_cooldown_timer")))
	
	available = cooldown <= 0.0 and not bool(player.get("is_dead"))
	var state_key := "%s:%s" % [hero_name, ability_name]
	if available:
		ability_label.text = "%s  %s READY" % [ability_key, ability_name]
		ability_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.48, 1.0))
	else:
		ability_label.text = "%s  %s   %.1fs" % [ability_key, ability_name, cooldown]
		ability_label.add_theme_color_override("font_color", Color(0.62, 0.72, 0.82, 0.95))
	
	if state_key != last_ability_key:
		last_ability_key = state_key
		last_ability_ready = available
	elif available and not last_ability_ready:
		var hud := active_world.get_node_or_null("HUD")
		if hud and hud.has_method("show_notice"):
			hud.show_notice("%s ready" % ability_name.capitalize(), 1.1)
	last_ability_ready = available

func _update_worker_summary() -> void:
	if worker_label == null:
		return
	var peons := _get_world_group_nodes("peons")
	if peons.size() == 0:
		worker_label.text = ""
		return
	var mining := 0
	var delivering := 0
	var searching := 0
	var player := active_world.get_node_or_null("Player")
	for peon in peons:
		match str(peon.get("state")):
			"MOVE_TO_GEM": mining += 1
			"RETURN_TO_BASE": delivering += 1
			_: searching += 1
		var status_label := peon.get_node_or_null("JobStatus") as Label
		if status_label:
			if peons.size() <= 3 or player == null:
				status_label.visible = true
			else:
				status_label.visible = peon.global_position.distance_to(player.global_position) < 190.0
	worker_label.text = "PEONS %d   •   %d MINING   •   %d DELIVERING   •   %d SEARCHING" % [peons.size(), mining, delivering, searching]

func _show_announcement(text_value: String, boss: bool) -> void:
	if announcement_label == null:
		return
	if announcement_tween and announcement_tween.is_running():
		announcement_tween.kill()
	announcement_label.text = text_value
	announcement_label.visible = true
	announcement_label.modulate = Color(1, 1, 1, 1)
	announcement_label.scale = Vector2(0.82, 0.82)
	announcement_label.pivot_offset = announcement_label.size * 0.5
	announcement_label.add_theme_font_size_override("font_size", 50 if boss else 42)
	announcement_label.add_theme_color_override("font_color", Color(1.0, 0.24, 0.12, 1.0) if boss else Color(1.0, 0.83, 0.34, 1.0))
	announcement_tween = create_tween()
	announcement_tween.set_trans(Tween.TRANS_BACK)
	announcement_tween.set_ease(Tween.EASE_OUT)
	announcement_tween.tween_property(announcement_label, "scale", Vector2.ONE, 0.22)
	announcement_tween.tween_interval(1.0 if boss else 0.7)
	announcement_tween.tween_property(announcement_label, "modulate:a", 0.0, 0.42)
	announcement_tween.tween_callback(func(): announcement_label.visible = false)

func _make_center_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.045, 0.035, 0.88)
	style.border_color = Color(0.58, 0.42, 0.2, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style

func _make_bar_background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.025, 0.022, 0.92)
	style.border_color = Color(0.12, 0.09, 0.07, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style

func _make_bar_fill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style
