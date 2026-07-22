extends Node

const FINAL_WAVE := 4
const RESULT_OVERLAY_NAME := "MatchResultOverlay"
const PREPARATION_HUB_SCENE := "res://scenes/world/preparation/preparation_hub.tscn"
const MAIN_MENU_SCENE := "res://scenes/menus/main/menu.tscn"
const HERO_SELECTION_SCENE: PackedScene = preload("res://hero_selection_menu.tscn")
const MENU_PANEL_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/MenuPanel.png")
const MENU_BUTTON_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/Button.png")
const STRENGTH_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/stats/Strenght.png")
const AGILITY_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/stats/Agility.png")
const INTELLIGENCE_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/stats/Int.png")
const GEM_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/stats/StatRessources.png")
const GOLD_TEXTURE: Texture2D = preload("res://GoldCoin.png")
const HERO_PORTRAIT_TEXTURES := {
	"Dwarf": preload("res://character_sprites/hero_idle/dwarf_idle_front.png"),
	"Mech": preload("res://character_sprites/hero_idle/mech_idle_front.png"),
	"Shaman": preload("res://character_sprites/hero_idle/shaman_idle_front.png"),
	"Nerubian": preload("res://character_sprites/hero_idle/nerubian_idle_front.png"),
	"Druid": preload("res://character_sprites/hero_idle/druid_idle_front.png"),
	"Undead King": preload("res://character_sprites/hero_idle/undead_king_idle_front.png")
}
const HERO_BASE_TEXTURES := {
	"Dwarf": preload("res://DwarfBase.png"),
	"Shaman": preload("res://ShamanBase.png"),
	"Nerubian": preload("res://NerubianBase.png"),
	"Druid": preload("res://DruidBase.png"),
	"Undead King": preload("res://UndeadKingBase.png")
}

var active_world: Node = null
var result_shown := false
var intro_shown := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	var world := _find_single_player_world()
	if world != active_world:
		_bind_world(world)

	if active_world == null or result_shown:
		return
	if not is_instance_valid(active_world):
		_bind_world(null)
		return

	var base := active_world.get_node_or_null("Base")
	if base:
		# Do not interpret a missing property as zero. A resource/script load
		# failure can leave the Base node present without base.gd attached.
		var current_base_health: Variant = base.get("health")
		if current_base_health != null and int(current_base_health) <= 0:
			_finish_match(false)
			return

	var current_wave := int(active_world.get("current_wave_number"))
	if current_wave > FINAL_WAVE and _count_world_enemies(active_world) == 0:
		_finish_match(true)

func request_defeat(world: Node) -> void:
	# Base.game_over calls this directly through the HUD. This removes the
	# old one-frame flash where HUD and MatchFlow both built different menus.
	if world == null or not is_instance_valid(world):
		return
	if active_world != world:
		_bind_world(world)
	call_deferred("_finish_match", false)

func _bind_world(world: Node) -> void:
	active_world = world
	result_shown = false
	intro_shown = false
	if active_world:
		call_deferred("_show_match_intro")

func _find_single_player_world() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return _find_world_recursive(scene)

func _find_world_recursive(node: Node) -> Node:
	if _is_single_player_world(node):
		return node
	for child in node.get_children():
		var found := _find_world_recursive(child)
		if found:
			return found
	return null

func _is_single_player_world(node: Node) -> bool:
	if not node.has_node("Base") or not node.has_node("HUD"):
		return false
	var wave_number = node.get("current_wave_number")
	if wave_number == null:
		return false
	return node.get("is_vs_mode") != true

func _show_match_intro() -> void:
	if intro_shown or active_world == null or not is_instance_valid(active_world):
		return
	intro_shown = true
	var hud := active_world.get_node_or_null("HUD")
	if hud and hud.has_method("show_notice"):
		hud.show_notice("Complete three expeditions, then defeat the final boss assault.", 3.8)

func _count_world_enemies(world: Node) -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and world.is_ancestor_of(enemy):
			count += 1
	return count

func _finish_match(victory: bool) -> void:
	if result_shown or active_world == null or not is_instance_valid(active_world):
		return
	result_shown = true

	var hud := active_world.get_node_or_null("HUD")
	if hud == null:
		get_tree().paused = true
		return
	var wave_reached := FINAL_WAVE if victory else maxi(1, int(hud.get("last_wave_reached")))
	Global.award_run_legacy_ore(wave_reached, victory)
	Global.record_minewars_result(victory)

	var old_game_over := hud.get_node_or_null("GameOverOverlay")
	if old_game_over:
		hud.remove_child(old_game_over)
		old_game_over.queue_free()
	var old_result := hud.get_node_or_null(RESULT_OVERLAY_NAME)
	if old_result:
		hud.remove_child(old_result)
		old_result.queue_free()
	var old_selector := hud.get_node_or_null("SoloRetrySetup")
	if old_selector:
		hud.remove_child(old_selector)
		old_selector.queue_free()
	var respawn_label := hud.get_node_or_null("RespawnLabel")
	if respawn_label:
		respawn_label.visible = false

	hud.add_child(_build_result_overlay(victory, hud))
	get_tree().paused = true

func _build_result_overlay(victory: bool, hud: Node) -> Control:
	var overlay := Control.new()
	overlay.name = RESULT_OVERLAY_NAME
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.z_index = 500
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 820.0 or viewport_size.y < 570.0
	var panel_width: float = min(viewport_size.x * 0.94, 900.0)
	var panel_height: float = min(viewport_size.y * 0.94, 610.0)
	var panel := Panel.new()
	panel.name = "Panel"
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_bottom = panel_height * 0.5
	panel.add_theme_stylebox_override("panel", _make_texture_style(MENU_PANEL_TEXTURE))
	overlay.add_child(panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 50 if compact else 62
	content.offset_top = 34 if compact else 38
	content.offset_right = -50 if compact else -62
	content.offset_bottom = -34 if compact else -38
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 7 if compact else 9)
	panel.add_child(content)

	var title := Label.new()
	title.text = "VICTORY" if victory else "DEFEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36 if compact else 42)
	title.add_theme_color_override(
		"font_color",
		Color(0.96, 0.76, 0.22, 1.0) if victory else Color(1.0, 0.18, 0.12, 1.0)
	)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "The final assault has been broken." if victory else "The bastion fell, but your legacy remains."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18 if compact else 21)
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72, 1.0))
	content.add_child(subtitle)

	var divider := HSeparator.new()
	divider.custom_minimum_size = Vector2(0, 5)
	content.add_child(divider)

	var body := HBoxContainer.new()
	body.name = "ResultBody"
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16 if compact else 24)
	content.add_child(body)

	body.add_child(_build_hero_result_card(victory, compact))
	body.add_child(_build_run_summary_card(victory, hud, compact))

	var reward_banner := _build_legacy_reward_banner(compact)
	content.add_child(reward_banner)
	var unlock_banner := _build_unlock_reward_banner(compact)
	if unlock_banner != null:
		content.add_child(unlock_banner)

	var buttons := GridContainer.new()
	buttons.name = "Actions"
	buttons.columns = 2 if compact else 4
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.add_theme_constant_override("h_separation", 10)
	buttons.add_theme_constant_override("v_separation", 7)
	content.add_child(buttons)

	var button_width := 220.0 if compact else 176.0
	var retry := _make_result_button("Retry", Callable(self, "_rerun_same_loadout"), button_width)
	retry.name = "RetryButton"
	buttons.add_child(retry)
	var loadout := _make_result_button("Change Loadout", Callable(self, "_open_retry_loadout"), button_width)
	loadout.name = "ChangeLoadoutButton"
	buttons.add_child(loadout)
	var workshop_label := "Stronghold" if Global.is_legacy_workshop_unlocked() else "Return Home"
	var workshop := _make_result_button(workshop_label, Callable(self, "_return_to_preparation"), button_width)
	workshop.name = "WorkshopButton"
	buttons.add_child(workshop)
	var menu := _make_result_button("Main Menu", Callable(self, "_return_to_main_menu"), button_width)
	menu.name = "MainMenuButton"
	buttons.add_child(menu)
	retry.call_deferred("grab_focus")
	return overlay

func _build_hero_result_card(victory: bool, compact: bool) -> PanelContainer:
	var player := active_world.get_node_or_null("Player")
	var hero_name := str(player.get("current_hero_name")) if player else "Hero"
	var hero_level := int(player.get("level")) if player else 1
	var card := PanelContainer.new()
	card.name = "HeroCard"
	card.custom_minimum_size = Vector2(210 if compact else 238, 285)
	card.add_theme_stylebox_override(
		"panel",
		_make_flat_panel_style(Color(0.035, 0.028, 0.025, 0.88), Color(0.58, 0.38, 0.18, 0.9))
	)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)

	var status := Label.new()
	status.text = "EXPEDITION COMPLETE" if victory else "EXPEDITION LOST"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28) if victory else Color(1.0, 0.32, 0.24))
	box.add_child(status)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(128 if compact else 146, 128 if compact else 146)
	portrait_frame.add_theme_stylebox_override(
		"panel",
		_make_flat_panel_style(Color(0.02, 0.024, 0.03, 0.96), Color(0.82, 0.66, 0.28, 0.92) if victory else Color(0.72, 0.18, 0.14, 0.92))
	)
	box.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.name = "HeroPortrait"
	portrait.texture = HERO_PORTRAIT_TEXTURES.get(hero_name, null) as Texture2D
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.modulate = Color.WHITE if victory else Color(0.72, 0.58, 0.58, 1.0)
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 8
	portrait.offset_top = 8
	portrait.offset_right = -8
	portrait.offset_bottom = -8
	portrait_frame.add_child(portrait)

	var name_label := Label.new()
	name_label.text = hero_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20 if compact else 23)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78, 1.0))
	box.add_child(name_label)

	var level_label := Label.new()
	level_label.text = "LEVEL %d" % hero_level
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color(0.76, 0.72, 0.66, 1.0))
	box.add_child(level_label)

	var stat_row := HBoxContainer.new()
	stat_row.name = "HeroStats"
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_row.add_theme_constant_override("separation", 7)
	box.add_child(stat_row)
	stat_row.add_child(_make_hero_stat_chip(STRENGTH_TEXTURE, "Strength", _get_player_stat(player, "strength", 1), Color(1.0, 0.45, 0.28)))
	stat_row.add_child(_make_hero_stat_chip(AGILITY_TEXTURE, "Agility", _get_player_stat(player, "agility", 1), Color(0.42, 1.0, 0.48)))
	stat_row.add_child(_make_hero_stat_chip(INTELLIGENCE_TEXTURE, "Intelligence", _get_player_stat(player, "intelligence", 1), Color(0.48, 0.72, 1.0)))
	return card

func _build_run_summary_card(victory: bool, hud: Node, compact: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "RunSummaryCard"
	card.custom_minimum_size = Vector2(430 if compact else 485, 285)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		_make_flat_panel_style(Color(0.03, 0.025, 0.02, 0.84), Color(0.46, 0.34, 0.22, 0.82))
	)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)

	var heading := Label.new()
	heading.text = "RUN SUMMARY"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", Color(0.96, 0.79, 0.46, 1.0))
	box.add_child(heading)

	var stats := GridContainer.new()
	stats.name = "SummaryRows"
	stats.columns = 3
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_constant_override("h_separation", 12 if compact else 18)
	stats.add_theme_constant_override("v_separation", 4)
	box.add_child(stats)
	_add_result_stats(stats, victory, hud)
	return card

func _build_unlock_reward_banner(compact: bool) -> PanelContainer:
	if Global.last_unlock_rewards.is_empty():
		return null
	var reward: Dictionary = Global.last_unlock_rewards.back()
	var banner := PanelContainer.new()
	banner.name = "MilestoneReward"
	banner.custom_minimum_size = Vector2(0, 48 if compact else 52)
	banner.add_theme_stylebox_override("panel", _make_flat_panel_style(Color(0.035, 0.09, 0.12, 0.96), Color(0.28, 0.82, 1.0, 0.98)))
	var label := Label.new()
	label.text = "STRONGHOLD REWARD  •  %s" % str(reward.get("title", "NEW POWER AWAKENED"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14 if compact else 16)
	label.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0, 1.0))
	banner.add_child(label)
	return banner

func _build_legacy_reward_banner(compact: bool) -> PanelContainer:
	var banner := PanelContainer.new()
	banner.name = "LegacyReward"
	banner.custom_minimum_size = Vector2(0, 40 if compact else 44)
	banner.add_theme_stylebox_override(
		"panel",
		_make_flat_panel_style(Color(0.16, 0.085, 0.02, 0.94), Color(1.0, 0.62, 0.15, 0.98))
	)
	var label := Label.new()
	label.text = "LEGACY ORE  +%d     TOTAL  %d" % [Global.last_run_legacy_ore_earned, Global.legacy_ore]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16 if compact else 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4, 1.0))
	banner.add_child(label)
	return banner

func _add_result_stats(stats: GridContainer, victory: bool, hud: Node) -> void:
	var base := active_world.get_node_or_null("Base")
	var player := active_world.get_node_or_null("Player")
	var wave_reached := FINAL_WAVE if victory else int(hud.get("last_wave_reached"))
	var base_integrity := 0
	if base and base.get("health") != null and base.get("max_health") != null:
		base_integrity = clampi(roundi(float(base.get("health")) / maxf(float(base.get("max_health")), 1.0) * 100.0), 0, 100)
	var hero_name := str(player.get("current_hero_name")) if player else "Dwarf"
	var base_icon := HERO_BASE_TEXTURES.get(hero_name, HERO_BASE_TEXTURES["Dwarf"]) as Texture2D

	_add_result_row(stats, null, "TIME", "Run time", _format_elapsed_time(hud))
	_add_result_row(stats, null, "STAGE", "Stage reached", "%d / %d" % [wave_reached, FINAL_WAVE])
	_add_result_row(stats, base_icon, "", "Base integrity", "%d%%" % base_integrity)
	_add_result_row(stats, GEM_TEXTURE, "", "Gems banked", str(int(hud.get("total_gems"))))
	_add_result_row(stats, GOLD_TEXTURE, "", "Gold banked", str(int(hud.get("total_gold"))))
	_add_result_row(stats, null, "ORE", "Legacy ore earned", "+%d" % Global.last_run_legacy_ore_earned, Color(1.0, 0.76, 0.25))
	_add_result_row(stats, null, "ORE", "Legacy ore total", str(Global.legacy_ore), Color(1.0, 0.88, 0.48))

func _add_result_row(stats: GridContainer, texture: Texture2D, marker: String, stat_name: String, stat_value: String, value_color: Color = Color(1.0, 0.94, 0.82, 1.0)) -> void:
	var icon_cell := Control.new()
	icon_cell.custom_minimum_size = Vector2(30, 30)
	icon_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 2
		icon.offset_top = 2
		icon.offset_right = -2
		icon.offset_bottom = -2
		icon_cell.add_child(icon)
	else:
		var marker_label := Label.new()
		marker_label.text = marker
		marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker_label.add_theme_font_size_override("font_size", 8 if marker.length() > 3 else 10)
		marker_label.add_theme_color_override("font_color", Color(0.95, 0.66, 0.28, 1.0))
		marker_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_cell.add_child(marker_label)
	stats.add_child(icon_cell)

	var name_label := Label.new()
	name_label.text = stat_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.78, 0.7, 0.58, 1.0))
	stats.add_child(name_label)

	var value_label := Label.new()
	value_label.text = stat_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 17)
	value_label.add_theme_color_override("font_color", value_color)
	stats.add_child(value_label)

func _make_hero_stat_chip(texture: Texture2D, tooltip: String, value: int, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(56, 58)
	chip.tooltip_text = tooltip
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.add_theme_stylebox_override("panel", _make_flat_panel_style(Color(0.02, 0.025, 0.03, 0.94), accent.darkened(0.28)))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	chip.add_child(box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var value_label := Label.new()
	value_label.text = str(value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 17)
	value_label.add_theme_color_override("font_color", accent)
	box.add_child(value_label)
	return chip

func _get_player_stat(player: Node, stat_name: String, fallback: int) -> int:
	if player == null:
		return fallback
	var value: Variant = player.get(stat_name)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback

func _format_elapsed_time(hud: Node) -> String:
	var started := int(hud.get("run_started_msec"))
	var elapsed: int = max(0, int((Time.get_ticks_msec() - started) / 1000.0))
	return "%02d:%02d" % [int(elapsed / 60.0), elapsed % 60]

func _make_flat_panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_texture_style(texture: Texture2D) -> StyleBox:
	if texture == null:
		return _make_flat_panel_style(Color(0.12, 0.07, 0.035, 0.97), Color(0.65, 0.44, 0.18, 1.0))
	var style := StyleBoxTexture.new()
	style.texture = texture
	return style

func _make_result_button(text_value: String, callback: Callable, width: float) -> Button:
	var button := Button.new()
	button.text = text_value
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.custom_minimum_size = Vector2(width, 50)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_stylebox_override("normal", _make_texture_style(MENU_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("hover", _make_texture_style(MENU_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("pressed", _make_texture_style(MENU_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(callback)
	return button

func _open_retry_loadout() -> void:
	if active_world == null or not is_instance_valid(active_world):
		return
	var hud := active_world.get_node_or_null("HUD")
	if hud == null or hud.has_node("SoloRetrySetup"):
		return
	var result_overlay := hud.get_node_or_null(RESULT_OVERLAY_NAME) as Control
	if result_overlay:
		result_overlay.visible = false
	var selector := HERO_SELECTION_SCENE.instantiate()
	selector.name = "SoloRetrySetup"
	selector.process_mode = Node.PROCESS_MODE_ALWAYS
	if selector.has_method("setup"):
		selector.setup(0, "solo_retry")
	hud.add_child(selector)
	selector.tree_exited.connect(func():
		if not is_instance_valid(hud):
			return
		var restored_overlay := hud.get_node_or_null(RESULT_OVERLAY_NAME) as Control
		if restored_overlay:
			restored_overlay.visible = true
		var loadout_button := hud.get_node_or_null("%s/Panel/Content/Actions/ChangeLoadoutButton" % RESULT_OVERLAY_NAME) as Button
		if loadout_button:
			loadout_button.grab_focus()
	)

func _rerun_same_loadout() -> void:
	result_shown = false
	intro_shown = false
	active_world = null
	get_tree().paused = false
	Global.apply_selected_loadout()
	get_tree().reload_current_scene()

func _return_to_preparation() -> void:
	result_shown = false
	intro_shown = false
	active_world = null
	get_tree().paused = false
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file(PREPARATION_HUB_SCENE)

func _return_to_main_menu() -> void:
	result_shown = false
	intro_shown = false
	active_world = null
	get_tree().paused = false
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
