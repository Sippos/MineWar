extends Node

const FINAL_WAVE := 10
const RESULT_OVERLAY_NAME := "MatchResultOverlay"
const MENU_PANEL_TEXTURE := "res://assets/sprites/ui/common/MenuPanel.png"
const MENU_BUTTON_TEXTURE := "res://assets/sprites/ui/common/Button.png"

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
	if base and int(base.get("health")) <= 0:
		_finish_match(false)
		return
	
	var current_wave := int(active_world.get("current_wave_number"))
	if current_wave > FINAL_WAVE and _count_world_enemies(active_world) == 0:
		_finish_match(true)

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
	return not bool(node.get("is_vs_mode"))

func _show_match_intro() -> void:
	if intro_shown or active_world == null or not is_instance_valid(active_world):
		return
	intro_shown = true
	var hud := active_world.get_node_or_null("HUD")
	if hud and hud.has_method("show_notice"):
		hud.show_notice("Survive 10 waves. Defeat the boss to win.", 3.2)

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
	
	var old_game_over := hud.get_node_or_null("GameOverOverlay")
	if old_game_over:
		hud.remove_child(old_game_over)
		old_game_over.queue_free()
	var old_result := hud.get_node_or_null(RESULT_OVERLAY_NAME)
	if old_result:
		hud.remove_child(old_result)
		old_result.queue_free()
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
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := min(viewport_size.x * 0.82, 720.0)
	var panel_height := min(viewport_size.y * 0.86, 570.0)
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
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 72
	content.offset_top = 48
	content.offset_right = -72
	content.offset_bottom = -48
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	
	var title := Label.new()
	title.text = "VICTORY" if victory else "DEFEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override(
		"font_color",
		Color(0.96, 0.76, 0.22, 1.0) if victory else Color(1.0, 0.18, 0.12, 1.0)
	)
	content.add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = "The wave boss has fallen." if victory else "Your base was destroyed."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72, 1.0))
	content.add_child(subtitle)
	
	var divider := HSeparator.new()
	divider.custom_minimum_size = Vector2(0, 8)
	content.add_child(divider)
	
	var stats := GridContainer.new()
	stats.columns = 2
	stats.custom_minimum_size = Vector2(440, 220)
	stats.add_theme_constant_override("h_separation", 36)
	stats.add_theme_constant_override("v_separation", 8)
	content.add_child(stats)
	_add_result_stats(stats, victory, hud)
	
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	content.add_child(buttons)
	
	var replay := _make_result_button("Play Again", Callable(self, "_restart_run"))
	buttons.add_child(replay)
	var menu := _make_result_button("Main Menu", Callable(self, "_return_to_main_menu"))
	buttons.add_child(menu)
	replay.call_deferred("grab_focus")
	return overlay

func _add_result_stats(stats: GridContainer, victory: bool, hud: Node) -> void:
	var base := active_world.get_node_or_null("Base")
	var player := active_world.get_node_or_null("Player")
	var wave_reached := FINAL_WAVE if victory else int(hud.get("last_wave_reached"))
	var base_health := max(0, int(base.get("health"))) if base else 0
	var hero_level := int(player.get("level")) if player else 1
	var hero_name := str(player.get("current_hero_name")) if player else "Hero"
	
	_add_stat_row(stats, "Run time", _format_elapsed_time(hud))
	_add_stat_row(stats, "Wave reached", "%d / %d" % [wave_reached, FINAL_WAVE])
	_add_stat_row(stats, "Hero", "%s — Level %d" % [hero_name, hero_level])
	_add_stat_row(stats, "Base integrity", "%d%%" % base_health)
	_add_stat_row(stats, "Gems banked", str(int(hud.get("total_gems"))))
	_add_stat_row(stats, "Gold banked", str(int(hud.get("total_gold"))))

func _add_stat_row(stats: GridContainer, stat_name: String, stat_value: String) -> void:
	var name_label := Label.new()
	name_label.text = stat_name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.78, 0.7, 0.58, 1.0))
	stats.add_child(name_label)
	
	var value_label := Label.new()
	value_label.text = stat_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82, 1.0))
	stats.add_child(value_label)

func _format_elapsed_time(hud: Node) -> String:
	var started := int(hud.get("run_started_msec"))
	var elapsed := max(0, int((Time.get_ticks_msec() - started) / 1000))
	return "%02d:%02d" % [int(elapsed / 60), elapsed % 60]

func _make_texture_style(texture_path: String) -> StyleBox:
	if not ResourceLoader.exists(texture_path):
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(0.12, 0.07, 0.035, 0.97)
		fallback.border_color = Color(0.65, 0.44, 0.18, 1.0)
		fallback.set_border_width_all(2)
		fallback.set_corner_radius_all(8)
		return fallback
	var style := StyleBoxTexture.new()
	style.texture = load(texture_path)
	return style

func _make_result_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.custom_minimum_size = Vector2(210, 58)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_stylebox_override("normal", _make_texture_style(MENU_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("hover", _make_texture_style(MENU_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("pressed", _make_texture_style(MENU_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(callback)
	return button

func _restart_run() -> void:
	result_shown = false
	intro_shown = false
	active_world = null
	get_tree().paused = false
	get_tree().reload_current_scene()

func _return_to_main_menu() -> void:
	result_shown = false
	intro_shown = false
	active_world = null
	get_tree().paused = false
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://menu.tscn")
