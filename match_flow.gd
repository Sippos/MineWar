extends Node

const FINAL_WAVE := 4
const RESULT_OVERLAY_NAME := "MatchResultOverlay"
const RUN_SUMMARY_SCENE: PackedScene = preload("res://scenes/ui/run_summary_dialog.tscn")
const RUN_SUMMARY_DATA_SCRIPT: GDScript = preload("res://scripts/systems/gameplay/run_summary_data.gd")
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
const MENU_FONT: FontFile = preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")
const DECORATIVE_FONT: FontFile = preload("res://assets/fonts/grenze_gotisch/GrenzeGotisch-Variable.ttf")
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
	var data: RefCounted = _build_run_summary_data(victory, hud)
	var overlay := RUN_SUMMARY_SCENE.instantiate() as Control
	overlay.name = RESULT_OVERLAY_NAME
	if overlay.has_method("setup"):
		overlay.call(
			"setup",
			data,
			Callable(self, "_rerun_same_loadout"),
			Callable(self, "_open_retry_loadout"),
			Callable(self, "_return_to_preparation"),
			Callable(self, "_return_to_main_menu")
		)
	return overlay

func _build_run_summary_data(victory: bool, hud: Node) -> RefCounted:
	var data: RefCounted = RUN_SUMMARY_DATA_SCRIPT.new()
	data.set("victory", victory)

	var base := active_world.get_node_or_null("Base") if active_world else null
	var player := active_world.get_node_or_null("Player") if active_world else null
	var controller := active_world.get_node_or_null("SiegeModeController") if active_world else null

	data.set("hero_name", str(player.get("current_hero_name")) if player else "Dwarf")
	data.set("hero_level", int(player.get("level")) if player else 1)
	data.set("strength", _get_player_stat(player, "strength", 1))
	data.set("agility", _get_player_stat(player, "agility", 1))
	data.set("intelligence", _get_player_stat(player, "intelligence", 1))

	var wave_reached := FINAL_WAVE if victory else maxi(1, int(hud.get("last_wave_reached")))
	data.set("waves_survived", wave_reached)
	data.set("final_wave", FINAL_WAVE)
	data.set("elapsed_time_string", _format_elapsed_time(hud))

	if base and base.get("health") != null and base.get("max_health") != null:
		var integrity_ratio := float(base.get("health")) / maxf(float(base.get("max_health")), 1.0) * 100.0
		data.set("base_integrity", clampi(roundi(integrity_ratio), 0, 100))

	data.set("total_gems", int(hud.get("total_gems")))
	data.set("total_gold", int(hud.get("total_gold")))
	if player and player.has_method("get_total_blocks_mined"):
		data.set("blocks_mined", int(player.call("get_total_blocks_mined")))
	elif hud and hud.get("run_gems_collected") != null:
		data.set("blocks_mined", int(hud.get("run_gems_collected")) * 3)

	if controller and controller.has_method("get_caches_unlocked"):
		data.set("caches_unlocked", int(controller.call("get_caches_unlocked")))
	if active_world and active_world.get("chokepoint_kills") != null:
		data.set("chokepoint_kills", int(active_world.get("chokepoint_kills")))
	elif controller and controller.has_method("get_chokepoint_kills"):
		data.set("chokepoint_kills", int(controller.call("get_chokepoint_kills")))
	if controller and controller.has_method("get_horn_soundings"):
		data.set("horn_soundings", int(controller.call("get_horn_soundings")))
	if controller and controller.has_method("get_horn_greed_multiplier"):
		data.set("horn_greed_multiplier", float(controller.call("get_horn_greed_multiplier")))
	if controller and controller.has_method("get_total_horn_ore_bonus"):
		data.set("horn_bonus_ore", int(controller.call("get_total_horn_ore_bonus")))

	data.set("base_survival_ore", maxi(1, int(ceil(float(maxi(wave_reached, 1)) / 3.0))))
	data.set("victory_bonus_ore", 3 if victory else 0)
	data.set("legacy_ore_earned", Global.last_run_legacy_ore_earned)
	data.set("total_legacy_ore", Global.legacy_ore)

	if not Global.last_unlock_rewards.is_empty():
		var reward: Dictionary = Global.last_unlock_rewards.back()
		data.set("milestone_title", str(reward.get("title", "")))

	# Retrospective ledger values reported to player:
	# "Legacy ore earned": data.legacy_ore_earned
	# "Legacy ore total": data.total_legacy_ore
	if data.has_method("calculate_score"):
		data.call("calculate_score")
	Global.record_run_summary(data)
	return data

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
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
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
	button.custom_minimum_size = Vector2(width, 42)
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_font_size_override("font_size", 17)
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
