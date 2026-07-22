extends Node2D

const PLAYER_TWO_SCENE := preload("res://local_coop_player.tscn")
const MAIN_MENU_PATH := "res://scenes/menus/main/menu.tscn"
const GEM_ICON := preload("res://assets/sprites/ui/common/stats/StatRessources.png")
const GOLD_ICON := preload("res://GoldCoin.png")

const HERO_PORTRAITS := {
	"Dwarf": preload("res://character_sprites/hero_idle/dwarf_idle_front.png"),
	"Shaman": preload("res://character_sprites/hero_idle/shaman_idle_front.png"),
	"Nerubian": preload("res://character_sprites/hero_idle/nerubian_idle_front.png"),
	"Druid": preload("res://character_sprites/hero_idle/druid_idle_front.png"),
	"Undead King": preload("res://character_sprites/hero_idle/undead_king_idle_front.png"),
	"Mech": preload("res://character_sprites/hero_idle/mech_idle_front.png"),
}
const P1_ACCENT := Color(0.26, 0.86, 1.0, 1.0)
const P2_ACCENT := Color(1.0, 0.68, 0.22, 1.0)

@onready var level: Node2D = $Level
@onready var shared_camera: Camera2D = $SharedCamera
@onready var coop_hud: CanvasLayer = $CoopHUD
@onready var exit_button: Button = $CoopHUD/ExitButton

var player_one: CharacterBody2D
var player_two: CharacterBody2D
var base: Node2D
var support_timer := 0.0
var hud_layout_timer := 0.0

var p1_ui: Dictionary = {}
var p2_ui: Dictionary = {}
var base_ui: Dictionary = {}
var distance_hint: Label

func _ready() -> void:
	GameMode.set_mode(GameMode.Mode.EXPLORATION)
	exit_button.pressed.connect(_return_to_menu)
	_configure_exit_button()
	var legacy_panel := coop_hud.get_node_or_null("P2Panel") as Control
	if legacy_panel != null:
		legacy_panel.visible = false
	await get_tree().process_frame
	player_one = level.get_node_or_null("Player") as CharacterBody2D
	base = level.get_node_or_null("Base") as Node2D
	if player_one == null:
		push_error("Local co-op could not find Player 1 in the exploration level.")
		return
	player_one.set("player_id", 1)
	player_one.add_to_group("coop_players")
	var player_one_camera := player_one.get_node_or_null("Camera2D") as Camera2D
	if player_one_camera != null:
		player_one_camera.enabled = false

	player_two = PLAYER_TWO_SCENE.instantiate() as CharacterBody2D
	player_two.name = "Player2"
	player_two.position = player_one.position + Vector2(64.0, 0.0)
	level.add_child(player_two)
	player_two.set("player_id", 2)
	player_two.add_to_group("coop_players")
	shared_camera.global_position = (player_one.global_position + player_two.global_position) * 0.5
	shared_camera.enabled = true

	_build_coop_hud()
	_hide_single_player_hud()
	await get_tree().process_frame
	_layout_dynamic_hero_hud()
	_update_coop_hud()

func _process(delta: float) -> void:
	if not is_instance_valid(player_one) or not is_instance_valid(player_two):
		return
	var midpoint := (player_one.global_position + player_two.global_position) * 0.5 + Vector2(0.0, -24.0)
	var camera_weight := 1.0 - exp(-6.0 * delta)
	shared_camera.global_position = shared_camera.global_position.lerp(midpoint, camera_weight)
	var separation := player_one.global_position.distance_to(player_two.global_position)
	var desired_zoom_value := clampf(1.5 - maxf(0.0, separation - 180.0) / 760.0, 0.68, 1.5)
	var desired_zoom := Vector2(desired_zoom_value, desired_zoom_value)
	shared_camera.zoom = shared_camera.zoom.lerp(desired_zoom, 1.0 - exp(-4.0 * delta))

	support_timer += delta
	hud_layout_timer += delta
	if support_timer >= 0.12:
		support_timer = 0.0
		_support_player_two()
		_update_coop_hud()
	if hud_layout_timer >= 0.5:
		hud_layout_timer = 0.0
		_hide_single_player_hud()
		_layout_dynamic_hero_hud()

func _build_coop_hud() -> void:
	p1_ui = _create_player_panel(1, true, P1_ACCENT)
	p2_ui = _create_player_panel(2, false, P2_ACCENT)
	base_ui = _create_base_panel()

	distance_hint = null

func _create_player_panel(player_id: int, left_side: bool, accent: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "Player%dHeroPanel" % player_id
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 35
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if left_side else Control.PRESET_BOTTOM_RIGHT)
	if left_side:
		panel.offset_left = 18.0
		panel.offset_top = -92.0
		panel.offset_right = 410.0
		panel.offset_bottom = -14.0
	else:
		panel.offset_left = -410.0
		panel.offset_top = -92.0
		panel.offset_right = -18.0
		panel.offset_bottom = -14.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.02, 0.032, 0.95), accent, 2, 10))
	coop_hud.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)

	var portrait_stack := Control.new()
	portrait_stack.custom_minimum_size = Vector2(66, 66)
	row.add_child(portrait_stack)

	var portrait_frame := PanelContainer.new()
	portrait_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.035, 0.05, 1.0), accent, 2, 8))
	portrait_stack.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_frame.add_child(portrait)

	var level_badge := PanelContainer.new()
	level_badge.name = "LevelBadge"
	level_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	level_badge.offset_left = -25.0
	level_badge.offset_top = -25.0
	level_badge.offset_right = 1.0
	level_badge.offset_bottom = 1.0
	level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_badge.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.025, 0.015, 0.98), accent, 2, 13))
	portrait_stack.add_child(level_badge)
	var level_label := Label.new()
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_label.add_theme_color_override("font_outline_color", Color.BLACK)
	level_label.add_theme_constant_override("outline_size", 3)
	level_badge.add_child(level_label)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var header := HBoxContainer.new()
	info.add_child(header)
	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", accent)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 4)
	header.add_child(name_label)
	var hp_label := Label.new()
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.94, 0.9, 0.8, 1.0))
	header.add_child(hp_label)

	var health_bar := ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(0, 14)
	health_bar.show_percentage = false
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.add_theme_stylebox_override("background", _panel_style(Color(0.06, 0.025, 0.025, 0.95), Color(0.2, 0.12, 0.12, 1.0), 1, 4))
	health_bar.add_theme_stylebox_override("fill", _panel_style(Color(0.64, 0.12, 0.10, 1.0), Color(1.0, 0.4, 0.24, 1.0), 1, 4))
	info.add_child(health_bar)

	var resources := HBoxContainer.new()
	resources.add_theme_constant_override("separation", 6)
	info.add_child(resources)
	var gem_icon := TextureRect.new()
	gem_icon.custom_minimum_size = Vector2(20, 20)
	gem_icon.texture = GEM_ICON
	gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resources.add_child(gem_icon)
	var gem_value := Label.new()
	gem_value.add_theme_font_size_override("font_size", 12)
	gem_value.add_theme_color_override("font_color", Color(0.82, 0.72, 1.0, 1.0))
	resources.add_child(gem_value)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 10.0
	resources.add_child(spacer)
	var gold_icon := TextureRect.new()
	gold_icon.custom_minimum_size = Vector2(20, 20)
	gold_icon.texture = GOLD_ICON
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resources.add_child(gold_icon)
	var gold_value := Label.new()
	gold_value.add_theme_font_size_override("font_size", 12)
	gold_value.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32, 1.0))
	resources.add_child(gold_value)

	return {
		"panel": panel,
		"portrait": portrait,
		"level": level_label,
		"name": name_label,
		"hp": hp_label,
		"health": health_bar,
		"gems": gem_value,
		"gold": gold_value,
	}


func _create_base_panel() -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "SharedBasePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 34
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -190.0
	panel.offset_top = 10.0
	panel.offset_right = 190.0
	panel.offset_bottom = 56.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.025, 0.035, 0.96), Color(0.38, 0.88, 0.68, 1.0), 2, 9))
	coop_hud.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	var health_bar := ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(0, 12)
	health_bar.show_percentage = false
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.add_theme_stylebox_override("background", _panel_style(Color(0.025, 0.06, 0.045, 0.95), Color(0.1, 0.26, 0.18, 1.0), 1, 4))
	health_bar.add_theme_stylebox_override("fill", _panel_style(Color(0.12, 0.62, 0.34, 1.0), Color(0.42, 1.0, 0.66, 1.0), 1, 4))
	info.add_child(health_bar)
	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", Color(0.88, 0.92, 0.86, 1.0))
	info.add_child(status)

	return {
		"panel": panel,
		"icon": icon,
		"health": health_bar,
		"status": status,
	}


func _hide_single_player_hud() -> void:
	var hud := level.get_node_or_null("HUD")
	if hud == null:
		return
	var hidden_nodes := [
		"PlayerLabel", "PlayerHealthBar", "HeroPortrait", "StatsBackdrop", "StatsContainer",
		"BaseHealthBar", "BaseLabel", "BaseStatus", "HeroRPGSummaryP1", "HeroRPGSummaryP2",
		"ResourcePanel", "GemIcon", "Label", "GoldIcon", "GoldLabel", "NoticeLabel"
	]
	for node_name in hidden_nodes:
		var item := hud.get_node_or_null(node_name) as CanvasItem
		if item != null:
			item.visible = false
	var exploration_controller := level.get_node_or_null("ExplorationModeController")
	if exploration_controller != null:
		for child in exploration_controller.get_children():
			if child is CanvasLayer:
				(child as CanvasLayer).visible = false

func _layout_dynamic_hero_hud() -> void:
	var hud := level.get_node_or_null("HUD")
	if hud == null:
		return
	var p1_bar := hud.get_node_or_null("HeroAbilityBarP1") as HBoxContainer
	if p1_bar != null:
		p1_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		p1_bar.offset_left = 18.0
		p1_bar.offset_top = -168.0
		p1_bar.offset_right = 344.0
		p1_bar.offset_bottom = -100.0
		p1_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
		p1_bar.z_index = 36
	var p2_bar := hud.get_node_or_null("HeroAbilityBarP2") as HBoxContainer
	if p2_bar != null:
		p2_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		p2_bar.offset_left = -344.0
		p2_bar.offset_top = -168.0
		p2_bar.offset_right = -18.0
		p2_bar.offset_bottom = -100.0
		p2_bar.alignment = BoxContainer.ALIGNMENT_END
		p2_bar.z_index = 36

func _support_player_two() -> void:
	if base == null or not is_instance_valid(player_two):
		return
	var near_base := player_two.global_position.distance_to(base.global_position) <= 105.0
	if not near_base:
		return
	var is_dead_value = player_two.get("is_dead")
	var health_value = player_two.get("health")
	var max_health_value = player_two.get("max_health")
	if is_dead_value != null and not bool(is_dead_value) and health_value != null and max_health_value != null:
		var health := int(health_value)
		var max_health := int(max_health_value)
		if health < max_health:
			player_two.set("health", mini(max_health, health + 1))
	if player_two.has_method("deposit_gems"):
		var deposited := int(player_two.call("deposit_gems"))
		if deposited > 0:
			if base.has_method("_emit_deposit_feedback"):
				base.call("_emit_deposit_feedback", deposited)
			if base.has_signal("gems_deposited"):
				base.emit_signal("gems_deposited", deposited)

func _update_coop_hud() -> void:
	_update_player_panel(p1_ui, player_one, 1, str(Global.hero_p1))
	_update_player_panel(p2_ui, player_two, 2, str(Global.hero_p2))
	_update_base_panel()

func _update_player_panel(ui: Dictionary, target: CharacterBody2D, player_id: int, hero_name: String) -> void:
	if ui.is_empty() or target == null or not is_instance_valid(target):
		return
	var health := int(target.get("health"))
	var max_health := maxi(1, int(target.get("max_health")))
	var carried := int(target.call("get_carry_load")) if target.has_method("get_carry_load") else 0
	var level_value := int(target.get("level")) if target.get("level") != null else 1
	var hud := level.get_node_or_null("HUD")
	var shared_gold := int(hud.get("total_gold")) if hud != null and hud.get("total_gold") != null else 0
	var portrait := ui["portrait"] as TextureRect
	portrait.texture = HERO_PORTRAITS.get(hero_name, HERO_PORTRAITS["Dwarf"]) as Texture2D
	var level_label := ui["level"] as Label
	level_label.text = str(level_value)
	var name_label := ui["name"] as Label
	name_label.text = "PLAYER %d  •  %s" % [player_id, hero_name.to_upper()]
	var hp_label := ui["hp"] as Label
	hp_label.text = "HP %d / %d" % [health, max_health]
	var health_bar := ui["health"] as ProgressBar
	health_bar.max_value = float(max_health)
	health_bar.value = float(health)
	var gem_value := ui["gems"] as Label
	gem_value.text = str(carried)
	var gold_value := ui["gold"] as Label
	gold_value.text = str(shared_gold)


func _update_base_panel() -> void:
	if base_ui.is_empty() or base == null or not is_instance_valid(base):
		return
	var base_entry_value = Global.base_data.get(Global.selected_base_id, {})
	var base_entry: Dictionary = base_entry_value if base_entry_value is Dictionary else {}
	var icon := base_ui["icon"] as TextureRect
	icon.texture = base_entry.get("texture") as Texture2D
	var current_health := int(base.get("health"))
	var maximum_health := maxi(1, int(base.get("max_health")))
	var health_bar := base_ui["health"] as ProgressBar
	health_bar.max_value = float(maximum_health)
	health_bar.value = float(current_health)
	var status := base_ui["status"] as Label
	status.text = "HP %d / %d" % [current_health, maximum_health]

func _configure_exit_button() -> void:
	exit_button.text = ""
	exit_button.tooltip_text = "Return to Modes"
	exit_button.icon = _make_home_icon()
	exit_button.expand_icon = true
	exit_button.offset_left = 18.0
	exit_button.offset_top = 16.0
	exit_button.offset_right = 66.0
	exit_button.offset_bottom = 64.0
	exit_button.add_theme_stylebox_override("normal", _panel_style(Color(0.035, 0.025, 0.02, 0.96), Color(0.8, 0.58, 0.22, 0.95), 2, 9))
	exit_button.add_theme_stylebox_override("hover", _panel_style(Color(0.09, 0.055, 0.025, 0.98), Color(1.0, 0.76, 0.3, 1.0), 2, 9))
	exit_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.02, 0.018, 0.015, 1.0), Color(0.72, 0.45, 0.14, 1.0), 2, 9))


func _make_home_icon() -> Texture2D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var outline := Color(0.24, 0.09, 0.025, 1.0)
	var gold := Color(1.0, 0.78, 0.28, 1.0)
	var warm := Color(0.52, 0.22, 0.07, 1.0)
	for y in range(3, 16):
		var half_width := y - 2
		for x in range(16 - half_width, 17 + half_width):
			if x >= 0 and x < 32:
				image.set_pixel(x, y, outline if x == 16 - half_width or x == 16 + half_width else gold)
	for y in range(14, 29):
		for x in range(6, 27):
			var edge := x <= 7 or x >= 25 or y >= 27
			image.set_pixel(x, y, outline if edge else warm)
	for y in range(20, 29):
		for x in range(13, 20):
			image.set_pixel(x, y, outline if x == 13 or x == 19 or y == 20 else Color(0.12, 0.055, 0.025, 1.0))
	var texture := ImageTexture.create_from_image(image)
	return texture

func _panel_style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.68)
	style.shadow_size = 7
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
