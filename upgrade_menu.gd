extends CanvasLayer

signal send_enemy(type: int)
@onready var hud = get_parent().get_node_or_null("HUD")
@onready var player = get_parent().get_node_or_null("Player")
@onready var panel = $Panel

const MENU_ART_CENTER := Vector2(580.0, 323.0)
const MENU_ART_SIZE := Vector2(992.0, 624.0)
const VS_MENU_MARGIN := 16.0
const SINGLE_MENU_MARGIN := 18.0
const SINGLE_MENU_MIN_SCALE := 0.30
const SINGLE_MENU_MAX_SCALE := 0.58
const SINGLE_MENU_MAX_HEIGHT_RATIO := 0.45
const MENU_PANEL_TEXTURE := "res://MenuPanel.png"
const ENEMY_BUTTON_TEXTURE := "res://Button.png"
const GOLD_ICON_TEXTURE := "res://GoldCoin.png"

var healthbar_unlocked = false
var base_health_unlocked = false
var stats_unlocked = false
var wave_timer_unlocked = false
var xp_unlocked = false
var minimap_unlocked = false
var minimap_upgraded = false

func _ready():
	if not $Panel/Close.pressed.is_connected(_on_close_pressed):
		$Panel/Close.pressed.connect(_on_close_pressed)
	hide_menu()


func get_upgrade_cost(stat_level: int) -> int:
	return (stat_level * 2) - 1

func update_button_texts():
	var str_cost = get_upgrade_cost(player.strength)
	$Panel/UpgradeStrength.text = ""
	$Panel/BranchTitle4/BranchTitle4/BranchTitle4/BranchTitle4.text = str(str_cost)
	
	var agi_cost = get_upgrade_cost(player.agility)
	$Panel/UpgradeAgility.text = ""
	$Panel/BranchTitle4/BranchTitle4/BranchTitle4/BranchTitle4/BranchTitle4.text = str(agi_cost)
	
	var int_cost = get_upgrade_cost(player.intelligence)
	$Panel/UpgradeIntelligence.text = ""
	$Panel/BranchTitle4/BranchTitle4/BranchTitle4/BranchTitle4/BranchTitle4/BranchTitle4.text = str(int_cost)
	
	var vs_mode = _is_vs_mode()
	$Panel/UnlockWaveTimer.visible = not vs_mode
	$Panel/UnlockWaveTimer.disabled = vs_mode or wave_timer_unlocked
	$Panel/GoldPileIcon4.visible = not vs_mode
	$Panel/BranchTitle6.visible = not vs_mode
	
	$Panel/UpgradeSpikes.visible = false
	$Panel/UpgradeSpikes.disabled = true
	
	var hero_name = _get_menu_hero()
	var is_dwarf = (hero_name == "Dwarf")
	var is_shaman = (hero_name == "Shaman")
	
	$Panel/SwapHero.visible = false
	$Panel/FactionTitle.visible = is_dwarf or is_shaman
	$Panel/BuyRail.visible = is_dwarf
	$Panel/BuyMinecart.visible = is_dwarf
	$Panel/BuyPeon.visible = is_shaman

var vs_prompt_panel: Panel
var vs_send_panel: Panel

func _is_vs_mode() -> bool:
	var level = get_parent()
	return level != null and bool(level.get("is_vs_mode"))

func _get_menu_hero() -> String:
	if player:
		var hero_name = player.get("current_hero_name")
		if typeof(hero_name) == TYPE_STRING and hero_name != "":
			return hero_name
	var p_id = get_parent().get("player_id")
	if p_id == 2:
		return Global.hero_p2
	return Global.hero_p1

func _get_menu_art_top_left() -> Vector2:
	return MENU_ART_CENTER - MENU_ART_SIZE * 0.5

func _layout_vs_upgrade_panel() -> void:
	var view_size = get_viewport().get_visible_rect().size
	var fit_scale = min(
		(view_size.x - VS_MENU_MARGIN * 2.0) / MENU_ART_SIZE.x,
		(view_size.y - VS_MENU_MARGIN * 2.0) / MENU_ART_SIZE.y
	)
	fit_scale = clamp(fit_scale, 0.42, 0.60)
	var desired_top_left = (view_size - MENU_ART_SIZE * fit_scale) * 0.5
	panel.scale = Vector2(fit_scale, fit_scale)
	panel.position = desired_top_left - _get_menu_art_top_left() * fit_scale

func _layout_single_player_upgrade_panel() -> void:
	var view_size = get_viewport().get_visible_rect().size
	var width_scale = (view_size.x - SINGLE_MENU_MARGIN * 2.0) / MENU_ART_SIZE.x
	var height_scale = (view_size.y * SINGLE_MENU_MAX_HEIGHT_RATIO) / MENU_ART_SIZE.y
	var fit_scale = min(width_scale, height_scale)
	fit_scale = clamp(fit_scale, SINGLE_MENU_MIN_SCALE, SINGLE_MENU_MAX_SCALE)
	var desired_top_left = Vector2(
		(view_size.x - MENU_ART_SIZE.x * fit_scale) * 0.5,
		view_size.y - MENU_ART_SIZE.y * fit_scale - SINGLE_MENU_MARGIN
	)
	panel.scale = Vector2(fit_scale, fit_scale)
	panel.position = desired_top_left - _get_menu_art_top_left() * fit_scale

func _make_texture_style(texture_path: String) -> StyleBoxTexture:
	var stylebox = StyleBoxTexture.new()
	var texture = load(texture_path)
	if texture:
		stylebox.texture = texture
	return stylebox

func _apply_enemy_button_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_texture_style(ENEMY_BUTTON_TEXTURE))
	btn.add_theme_stylebox_override("hover", _make_texture_style(ENEMY_BUTTON_TEXTURE))
	btn.add_theme_stylebox_override("pressed", _make_texture_style(ENEMY_BUTTON_TEXTURE))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _get_stat_upgrade_color(stat_name: String) -> Color:
	match stat_name:
		"Strength":
			return Color(1.0, 0.28, 0.16, 1.0)
		"Agility":
			return Color(0.25, 1.0, 0.35, 1.0)
		"Intelligence":
			return Color(0.25, 0.65, 1.0, 1.0)
	return Color(1.0, 0.9, 0.25, 1.0)

func _play_stat_upgrade_effect(stat_name: String, source_button: Control = null) -> void:
	var color = _get_stat_upgrade_color(stat_name)
	_pulse_upgrade_button(source_button)
	_pulse_player_sprite(color)
	_spawn_stat_upgrade_particles(color)
	_spawn_stat_upgrade_ring(color)
	_spawn_stat_upgrade_popup(stat_name, color)

func _pulse_upgrade_button(source_button: Control) -> void:
	if source_button == null or not is_instance_valid(source_button):
		return
	var original_scale = source_button.scale
	source_button.pivot_offset = source_button.size * 0.5
	source_button.scale = original_scale * 1.14
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(source_button, "scale", original_scale, 0.22)

func _pulse_player_sprite(color: Color) -> void:
	if player == null or not is_instance_valid(player):
		return
	var sprite = player.get_node_or_null("Sprite2D")
	if sprite == null:
		return
	var original_scale = sprite.scale
	var original_modulate = sprite.modulate
	sprite.scale = original_scale * 1.28
	sprite.modulate = color
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", original_scale, 0.28)
	tween.tween_property(sprite, "modulate", original_modulate, 0.28)

func _spawn_stat_upgrade_particles(color: Color) -> void:
	if player == null or not is_instance_valid(player) or get_parent() == null:
		return
	var burst = CPUParticles2D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 46
	burst.lifetime = 0.58
	burst.explosiveness = 0.95
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 14.0
	burst.spread = 180.0
	burst.gravity = Vector2(0, -40)
	burst.initial_velocity_min = 90.0
	burst.initial_velocity_max = 210.0
	burst.damping_min = 90.0
	burst.damping_max = 150.0
	burst.scale_amount_min = 2.2
	burst.scale_amount_max = 5.5
	burst.color = color
	burst.global_position = player.global_position + Vector2(0, -28)
	burst.z_index = 30
	get_parent().add_child(burst)
	burst.emitting = true
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(burst.queue_free)

func _spawn_stat_upgrade_ring(color: Color) -> void:
	if player == null or not is_instance_valid(player) or get_parent() == null:
		return
	var ring = Line2D.new()
	ring.closed = true
	ring.width = 4.0
	ring.default_color = Color(color.r, color.g, color.b, 0.85)
	ring.z_index = 29
	var points = PackedVector2Array()
	for i in range(32):
		var angle = TAU * float(i) / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * 18.0)
	ring.points = points
	ring.global_position = player.global_position + Vector2(0, -28)
	ring.scale = Vector2(0.35, 0.35)
	get_parent().add_child(ring)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.48)
	tween.tween_property(ring, "modulate:a", 0.0, 0.48)
	tween.chain().tween_callback(ring.queue_free)

func _spawn_stat_upgrade_popup(stat_name: String, color: Color) -> void:
	if player == null or not is_instance_valid(player) or get_parent() == null:
		return
	var popup = Label.new()
	popup.text = "+1 %s" % stat_name
	popup.add_theme_font_size_override("font_size", 18)
	popup.add_theme_color_override("font_color", color)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.custom_minimum_size = Vector2(120, 28)
	popup.z_index = 100
	popup.modulate = Color(1, 1, 1, 1)
	get_parent().add_child(popup)
	popup.global_position = player.global_position + Vector2(-60, -86)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "global_position", popup.global_position + Vector2(0, -38), 0.62)
	tween.tween_property(popup, "modulate:a", 0.0, 0.62)
	tween.chain().tween_callback(popup.queue_free)

func _create_enemy_button(enemy_name: String, cost: int, income: int, tex_path: String) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 54)
	btn.tooltip_text = "%s: %d gold, +%d gold income" % [enemy_name, cost, income]
	_apply_enemy_button_style(btn)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 12)
	
	var tex_rect = TextureRect.new()
	var tex = load(tex_path)
	var atlas = AtlasTexture.new()
	if tex:
		atlas.atlas = tex
		var fw = tex.get_width() / 8
		var fh = tex.get_height() / 8
		if fw > 0 and fh > 0:
			atlas.region = Rect2(0, 0, fw, fh)
		tex_rect.texture = atlas
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.custom_minimum_size = Vector2(42, 42)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(tex_rect)
	
	var cost_icon = TextureRect.new()
	cost_icon.texture = load(GOLD_ICON_TEXTURE)
	cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cost_icon.custom_minimum_size = Vector2(22, 22)
	cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(cost_icon)
	
	var lbl_cost = Label.new()
	lbl_cost.text = str(cost)
	lbl_cost.custom_minimum_size = Vector2(28, 0)
	lbl_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl_cost)
	
	var inc_icon = TextureRect.new()
	inc_icon.texture = load(GOLD_ICON_TEXTURE)
	inc_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inc_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inc_icon.custom_minimum_size = Vector2(22, 22)
	inc_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(inc_icon)
	
	var lbl_inc = Label.new()
	lbl_inc.text = "+" + str(income)
	lbl_inc.custom_minimum_size = Vector2(30, 0)
	lbl_inc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_inc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl_inc)
	
	btn.add_child(hbox)
	return btn

func _create_vs_panels():
	if vs_prompt_panel != null and is_instance_valid(vs_prompt_panel):
		return
		
	var menu_stylebox = _make_texture_style(MENU_PANEL_TEXTURE)
		
	vs_prompt_panel = Panel.new()
	vs_prompt_panel.name = "VSPromptPanel"
	vs_prompt_panel.add_theme_stylebox_override("panel", menu_stylebox)
	vs_prompt_panel.anchor_left = 0.5
	vs_prompt_panel.anchor_top = 0.5
	vs_prompt_panel.anchor_right = 0.5
	vs_prompt_panel.anchor_bottom = 0.5
	vs_prompt_panel.offset_left = -150
	vs_prompt_panel.offset_top = -100
	vs_prompt_panel.offset_right = 150
	vs_prompt_panel.offset_bottom = 100
	
	var vbox1 = VBoxContainer.new()
	vbox1.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox1.offset_left = 20
	vbox1.offset_top = 20
	vbox1.offset_right = -20
	vbox1.offset_bottom = -20
	
	var lbl1 = Label.new()
	lbl1.text = "Base Options"
	lbl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox1.add_child(lbl1)
	
	var btn_upgrades = Button.new()
	btn_upgrades.text = "Upgrades"
	btn_upgrades.pressed.connect(Callable(self, "_on_vs_upgrades_pressed"))
	vbox1.add_child(btn_upgrades)
	
	var btn_send = Button.new()
	btn_send.text = "Send Enemies"
	btn_send.pressed.connect(Callable(self, "_on_vs_send_pressed"))
	vbox1.add_child(btn_send)
	
	var btn_close1 = Button.new()
	btn_close1.text = "Close"
	btn_close1.pressed.connect(Callable(self, "_on_close_pressed"))
	vbox1.add_child(btn_close1)
	
	vs_prompt_panel.add_child(vbox1)
	add_child(vs_prompt_panel)
	
	vs_send_panel = Panel.new()
	vs_send_panel.name = "VSSendPanel"
	vs_send_panel.add_theme_stylebox_override("panel", menu_stylebox)
	vs_send_panel.anchor_left = 0.5
	vs_send_panel.anchor_top = 0.5
	vs_send_panel.anchor_right = 0.5
	vs_send_panel.anchor_bottom = 0.5
	vs_send_panel.offset_left = -190
	vs_send_panel.offset_top = -240
	vs_send_panel.offset_right = 190
	vs_send_panel.offset_bottom = 240
	
	var vbox2 = VBoxContainer.new()
	vbox2.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox2.offset_left = 54
	vbox2.offset_top = 50
	vbox2.offset_right = -54
	vbox2.offset_bottom = -50
	vbox2.add_theme_constant_override("separation", 8)
	
	var lbl2 = Label.new()
	lbl2.text = "Send Enemies"
	lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox2.add_child(lbl2)
	
	var btn_rat = _create_enemy_button("Rat", 5, 1, "res://character_sprites/rat_walk_pixelart_spritesheet.png")
	btn_rat.pressed.connect(Callable(self, "_on_send_rat"))
	vbox2.add_child(btn_rat)
	
	var btn_spider = _create_enemy_button("Spider", 10, 2, "res://character_sprites/spider_walk_spritesheet.png")
	btn_spider.pressed.connect(Callable(self, "_on_send_spider"))
	vbox2.add_child(btn_spider)
	
	var btn_bat = _create_enemy_button("Bat", 15, 3, "res://character_sprites/bat_fly_spritesheet.png")
	btn_bat.pressed.connect(Callable(self, "_on_send_bat"))
	vbox2.add_child(btn_bat)
	
	var btn_trogg = _create_enemy_button("Trogg", 20, 4, "res://character_sprites/trogg_walk_spritesheet.png")
	btn_trogg.pressed.connect(Callable(self, "_on_send_trogg"))
	vbox2.add_child(btn_trogg)
	
	var btn_orc = _create_enemy_button("Orc", 25, 5, "res://character_sprites/orc_walk_pixelart_spritesheet.png")
	btn_orc.pressed.connect(Callable(self, "_on_send_orc"))
	vbox2.add_child(btn_orc)
	
	var btn_back = Button.new()
	btn_back.text = "Back"
	btn_back.pressed.connect(Callable(self, "_on_vs_back_pressed"))
	vbox2.add_child(btn_back)
	
	vs_send_panel.add_child(vbox2)
	add_child(vs_send_panel)

func _on_vs_upgrades_pressed():
	vs_prompt_panel.visible = false
	_layout_vs_upgrade_panel()
	panel.visible = true

func _on_vs_send_pressed():
	vs_prompt_panel.visible = false
	vs_send_panel.visible = true

func _on_vs_back_pressed():
	vs_send_panel.visible = false
	vs_prompt_panel.visible = true

func show_menu():
	update_button_texts()
	if player: player.can_move = false
	if _is_vs_mode():
		_create_vs_panels()
		vs_prompt_panel.visible = true
		vs_send_panel.visible = false
		panel.visible = false
		vs_prompt_panel.get_child(0).get_child(1).call_deferred("grab_focus")
	else:
		_layout_single_player_upgrade_panel()
		panel.visible = true
		$Panel/Close.call_deferred("grab_focus")

func hide_menu():
	panel.visible = false
	if player: player.can_move = true
	if vs_prompt_panel: vs_prompt_panel.visible = false
	if vs_send_panel: vs_send_panel.visible = false

func _on_close_pressed():
	hide_menu()

func _on_unlock_healthbar_pressed():
	if not healthbar_unlocked and hud.total_gold >= 10:
		hud.add_gold(-10)
		healthbar_unlocked = true
		hud.unlock_healthbar()
		$Panel/UnlockHealthbar.disabled = true

func _on_unlock_base_health_pressed():
	if not base_health_unlocked and hud.total_gold >= 10:
		hud.add_gold(-10)
		base_health_unlocked = true
		hud.unlock_base_healthbar()
		$Panel/UnlockBaseHealth.disabled = true

func _on_unlock_stats_pressed():
	if not stats_unlocked and hud.total_gold >= 10:
		hud.add_gold(-10)
		stats_unlocked = true
		hud.unlock_stats()
		$Panel/UnlockStats.disabled = true

func _on_unlock_wave_timer_pressed():
	if _is_vs_mode():
		return
	if not wave_timer_unlocked and hud.total_gold >= 10:
		hud.add_gold(-10)
		wave_timer_unlocked = true
		hud.unlock_wave_timer()
		$Panel/UnlockWaveTimer.disabled = true

func _on_unlock_xp_pressed():
	if not xp_unlocked and hud.total_gold >= 10:
		hud.add_gold(-10)
		xp_unlocked = true
		hud.unlock_xp()
		$Panel/UnlockXP.disabled = true

func _on_unlock_minimap_pressed():
	if not minimap_unlocked and hud.total_gold >= 20:
		hud.add_gold(-20)
		minimap_unlocked = true
		hud.unlock_minimap()
		$Panel/UnlockMinimap.disabled = true

func _on_upgrade_minimap_pressed():
	if minimap_unlocked and not minimap_upgraded and hud.total_gold >= 50:
		hud.add_gold(-50)
		minimap_upgraded = true
		hud.upgrade_minimap_enemies()
		$Panel/UpgradeMinimap.disabled = true

func _on_upgrade_max_health_pressed():
	if hud.total_gold >= 15:
		hud.add_gold(-15)
		player.max_health += 20
		player.health += 20
		hud.update_player_health(player.health, player.max_health)

func _on_upgrade_strength_pressed():
	var cost = get_upgrade_cost(player.strength)
	if hud.total_gems >= cost:
		hud.add_gems(-cost)
		player.upgrade_strength()
		hud.update_stats(player.strength, player.agility, player.intelligence)
		_play_stat_upgrade_effect("Strength", $Panel/UpgradeStrength)
		update_button_texts()

func _on_upgrade_agility_pressed():
	var cost = get_upgrade_cost(player.agility)
	if hud.total_gems >= cost:
		hud.add_gems(-cost)
		player.upgrade_agility()
		hud.update_stats(player.strength, player.agility, player.intelligence)
		_play_stat_upgrade_effect("Agility", $Panel/UpgradeAgility)
		update_button_texts()

func _on_upgrade_intelligence_pressed():
	var cost = get_upgrade_cost(player.intelligence)
	if hud.total_gems >= cost:
		hud.add_gems(-cost)
		player.upgrade_intelligence()
		hud.update_stats(player.strength, player.agility, player.intelligence)
		_play_stat_upgrade_effect("Intelligence", $Panel/UpgradeIntelligence)
		update_button_texts()

func _on_upgrade_spikes_pressed():
	if hud.total_gold >= 20:
		hud.add_gold(-20)
		var base = get_parent().get_node_or_null("Base")
		if base:
			base.spikes_level += 1
			update_button_texts()

func _on_swap_hero_pressed():
	if $Panel/SwapHero.visible and Global.unlocked_heroes.size() > 1:
		Global.current_hero = Global.get_next_hero()
		player.update_hero_sprites()
		update_button_texts()

func _on_heal_player_pressed():
	if hud.total_gold >= 10 and player.health < player.max_health:
		hud.add_gold(-10)
		player.health = min(player.health + 20, player.max_health)
		hud.update_player_health(player.health, player.max_health)

func _on_send_rat():
	if hud.total_gold >= 5:
		hud.add_gold(-5)
		emit_signal("send_enemy", 0) # 0 = Rat

func _on_send_spider():
	if hud.total_gold >= 10:
		hud.add_gold(-10)
		emit_signal("send_enemy", 1) # 1 = Spider

func _on_send_bat():
	if hud.total_gold >= 15:
		hud.add_gold(-15)
		emit_signal("send_enemy", 2) # 2 = Bat

func _on_send_trogg():
	if hud.total_gold >= 20:
		hud.add_gold(-20)
		emit_signal("send_enemy", 3) # 3 = Trogg

func _on_send_orc():
	if hud.total_gold >= 25:
		hud.add_gold(-25)
		emit_signal("send_enemy", 4) # 4 = Orc

func _on_buy_rail_pressed():
	if hud.total_gold >= 10:
		hud.add_gold(-10)
		var base = get_parent().get_node_or_null("Base")
		if base and base.has_method("spawn_rail"):
			base.spawn_rail()

func _on_buy_minecart_pressed():
	if hud.total_gold >= 50:
		hud.add_gold(-50)
		var base = get_parent().get_node_or_null("Base")
		if base and base.has_method("spawn_minecart"):
			base.spawn_minecart()

func _on_buy_peon_pressed():
	if hud.total_gold >= 30:
		hud.add_gold(-30)
		var base = get_parent().get_node_or_null("Base")
		if base and base.has_method("spawn_peon"):
			base.spawn_peon()
