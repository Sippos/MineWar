extends CanvasLayer

@onready var label = $Label
@onready var str_label = $StatsContainer/StrLabel
@onready var agi_label = $StatsContainer/AgiLabel
@onready var int_label = $StatsContainer/IntLabel
@onready var gold_label = $GoldLabel
@onready var base_health_bar = $BaseHealthBar
@onready var player_health_bar = $PlayerHealthBar
@onready var minimap = $Minimap
@onready var respawn_label = $RespawnLabel
@onready var wave_label = $WaveLabel
@onready var xp_label = $XPLabel
@onready var xp_bar = $XPBar

var total_gems = 0
var total_gold = 0
var run_started_msec = 0
var run_gems_collected = 0
var run_gold_collected = 0
var last_wave_reached = 1
var minimap_shows_enemies = false

var stomp_container: Control
var stomp_progress: TextureProgressBar
var notice_label: Label
var notice_tween: Tween
var objective_panel: PanelContainer
var objective_step_label: Label
var objective_title_label: Label
var objective_body_label: Label
var objective_tween: Tween
var carry_status_panel: PanelContainer
var carry_status_label: Label
var return_cue: Control
var return_cue_arrow: Label
var return_cue_label: Label
var last_carry_load := -1
var cave_reward_container: HBoxContainer
var cave_reward_slots := {}
var totem_wheel: Control
var totem_wheel_icons := {}
var totem_status_container: Control
var totem_status_slots := {}
var nerubian_status_container: HBoxContainer
var nerubian_spawn_slot: Control
var nerubian_spider_slots := []
var hero_portrait_container: PanelContainer
var hero_portrait_icon: TextureRect
var hero_portrait_dim: ColorRect
var hero_portrait_timer: Label
var hero_portrait_hero_name := ""
var base_status_panel: PanelContainer
var base_status_label: Label
var base_status_icon: TextureRect
var base_status_style: StyleBoxFlat
var base_direction_cue: Control
var base_direction_arrow: Label
var base_direction_label: Label
var breach_direction_cue: Control
var breach_direction_arrow: Label
var breach_direction_label: Label
var breach_target_world_position := Vector2.ZERO
var breach_target_wave := 0
var breach_target_active := false
var base_status_tween: Tween
var base_warning_state := "stable"
var base_warning_health := 100
var base_warning_max_health := 100
var base_hit_notice_cooldown := 0.0
var stats_backdrop: PanelContainer

const TOTEM_TYPES = ["dig", "heal", "radar", "gem"]
const TOTEM_LABELS = {
	"dig": "Dig",
	"heal": "Heal",
	"radar": "Radar",
	"gem": "Gem"
}
const TOTEM_TEXTURES = {
	"dig": preload("res://Shaman_Totem_DigBuff.png"),
	"heal": preload("res://Shaman_Totem_Healing.png"),
	"radar": preload("res://Shaman_Totem_Radar.png"),
	"gem": preload("res://Shaman_Totem_GemBuff.png")
}
const STOMP_SPRITE_TEXTURES = [
	"res://StompSprite.png",
	"res://StompSprite.webp",
	"res://StompSprite.tres",
	"res://stomp_sprite.png",
	"res://sprites/StompSprite.png",
	"res://assets/StompSprite.png"
]
const NERUBIAN_SPIDER_TEXTURE: Texture2D = preload("res://character_sprites/spider_walk_spritesheet.png")
const NERUBIAN_MAX_SPIDER_SLOTS = 5
const NERUBIAN_SPAWN_MAX_COOLDOWN = 3.5
const HUD_STACK_LEFT := 20.0
const HUD_STACK_TOP := 88.0
const HUD_STACK_GAP := 8.0
const HUD_STACK_LABEL_LEFT := 30.0
const HUD_STATS_HEIGHT := 36.0
const HUD_HEALTH_BAR_OFFSET_Y := 18.0
const HUD_HEALTH_MODULE_HEIGHT := 66.0
const MENU_PANEL_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/MenuPanel.png")
const MENU_BUTTON_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/Button.png")
const HERO_PORTRAIT_TEXTURES = {
	"Dwarf": preload("res://character_sprites/hero_idle/dwarf_idle_front.png"),
	"Mech": preload("res://character_sprites/hero_idle/mech_idle_front.png"),
	"Shaman": preload("res://character_sprites/hero_idle/shaman_idle_front.png"),
	"Nerubian": preload("res://character_sprites/hero_idle/nerubian_idle_front.png"),
	"Druid": preload("res://character_sprites/hero_idle/druid_idle_front.png"),
	"Undead King": preload("res://character_sprites/hero_idle/undead_king_idle_front.png")
}
const HERO_PORTRAIT_RECT := Rect2(16.0, 12.0, 68.0, 68.0)
const BASE_DAMAGED_THRESHOLD := 0.70
const BASE_CRITICAL_THRESHOLD := 0.30
const BASE_DIRECTION_DISTANCE := 520.0
const BASE_HIT_NOTICE_COOLDOWN := 6.0
const HERO_BASE_TEXTURES = {
	"Dwarf": preload("res://DwarfBase.png"),
	"Shaman": preload("res://ShamanBase.png"),
	"Nerubian": preload("res://NerubianBase.png"),
	"Druid": preload("res://DruidBase.png"),
	"Undead King": preload("res://UndeadKingBase.png")
}
const BASE_WARNING_COLORS = {
	"stable": Color(0.35, 0.9, 0.55, 1.0),
	"damaged": Color(1.0, 0.72, 0.22, 1.0),
	"critical": Color(1.0, 0.2, 0.16, 1.0)
}

func _ready():
	run_started_msec = Time.get_ticks_msec()
	_setup_hero_portrait_ui()
	_setup_stats_visuals()
	if minimap:
		minimap.draw.connect(_on_minimap_draw)
		
	# Web touch devices are handled by web_ios_lighting_fallback.gd. Keep native mobile
	# controls here so web/iPad cannot create a second overlay.
	var is_native_mobile := OS.has_feature("mobile") and not OS.has_feature("web")
	if is_native_mobile:
		var mobile_controls_scene = load("res://mobile_controls.tscn")
		if mobile_controls_scene:
			var mobile_controls = mobile_controls_scene.instantiate()
			add_child(mobile_controls)
	
	_setup_stomp_ui()
	_setup_notice_ui()
	_setup_objective_ui()
	_setup_carry_status_ui()
	_setup_return_cue_ui()
	_setup_base_warning_ui()
	_setup_breach_direction_cue_ui()
	_setup_cave_reward_ui()
	_setup_totem_wheel_ui()
	_setup_totem_status_ui()
	_setup_nerubian_status_ui()
	get_tree().root.size_changed.connect(_relayout_unlocked_hud)
	_relayout_unlocked_hud()

func _setup_hero_portrait_ui() -> void:
	hero_portrait_container = PanelContainer.new()
	hero_portrait_container.name = "HeroPortrait"
	hero_portrait_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_portrait_container.clip_contents = true
	hero_portrait_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hero_portrait_container.offset_left = HERO_PORTRAIT_RECT.position.x
	hero_portrait_container.offset_top = HERO_PORTRAIT_RECT.position.y
	hero_portrait_container.offset_right = HERO_PORTRAIT_RECT.end.x
	hero_portrait_container.offset_bottom = HERO_PORTRAIT_RECT.end.y

	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.035, 0.045, 0.06, 0.92)
	frame_style.border_color = Color(0.82, 0.68, 0.32, 0.95)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(8)
	frame_style.shadow_color = Color(0, 0, 0, 0.55)
	frame_style.shadow_size = 4
	hero_portrait_container.add_theme_stylebox_override("panel", frame_style)

	var portrait_content = Control.new()
	portrait_content.name = "Content"
	portrait_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_portrait_container.add_child(portrait_content)

	hero_portrait_icon = TextureRect.new()
	hero_portrait_icon.name = "Icon"
	hero_portrait_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_portrait_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_portrait_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_portrait_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	hero_portrait_icon.offset_left = 4
	hero_portrait_icon.offset_top = 4
	hero_portrait_icon.offset_right = -4
	hero_portrait_icon.offset_bottom = -4
	portrait_content.add_child(hero_portrait_icon)

	hero_portrait_dim = ColorRect.new()
	hero_portrait_dim.name = "DeathDim"
	hero_portrait_dim.visible = false
	hero_portrait_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_portrait_dim.color = Color(0.08, 0.08, 0.1, 0.58)
	hero_portrait_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_content.add_child(hero_portrait_dim)

	hero_portrait_timer = Label.new()
	hero_portrait_timer.name = "RespawnTimer"
	hero_portrait_timer.visible = false
	hero_portrait_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_portrait_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_portrait_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_portrait_timer.add_theme_font_size_override("font_size", 25)
	hero_portrait_timer.add_theme_color_override("font_color", Color.WHITE)
	hero_portrait_timer.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	hero_portrait_timer.add_theme_constant_override("outline_size", 5)
	hero_portrait_timer.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_content.add_child(hero_portrait_timer)

	add_child(hero_portrait_container)
	_shift_resource_row_for_portrait()
	_refresh_hero_portrait(true)

func _shift_resource_row_for_portrait() -> void:
	var gem_icon = get_node_or_null("GemIcon") as TextureRect
	var gem_label = get_node_or_null("Label") as Label
	var gold_icon = get_node_or_null("GoldIcon") as TextureRect
	var gold_value = get_node_or_null("GoldLabel") as Label

	var resource_panel = PanelContainer.new()
	resource_panel.name = "ResourcePanel"
	resource_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resource_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	resource_panel.offset_left = 92
	resource_panel.offset_top = 20
	resource_panel.offset_right = 272
	resource_panel.offset_bottom = 58
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.03, 0.04, 0.78)
	panel_style.border_color = Color(0.34, 0.38, 0.46, 0.55)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(7)
	resource_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(resource_panel)
	move_child(resource_panel, hero_portrait_container.get_index())

	if gem_icon:
		gem_icon.position = Vector2(102, 25)
		gem_icon.size = Vector2(28, 28)
		gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gem_icon.move_to_front()
	if gem_label:
		gem_label.position = Vector2(132, 23)
		gem_label.size = Vector2(34, 32)
		gem_label.add_theme_font_size_override("font_size", 18)
		gem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gem_label.move_to_front()
	if gold_icon:
		gold_icon.position = Vector2(171, 25)
		gold_icon.size = Vector2(28, 28)
		gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gold_icon.move_to_front()
	if gold_value:
		gold_value.position = Vector2(201, 23)
		gold_value.size = Vector2(52, 32)
		gold_value.add_theme_font_size_override("font_size", 18)
		gold_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gold_value.move_to_front()

func _setup_stats_visuals() -> void:
	var stats_container := get_node_or_null("StatsContainer") as HBoxContainer
	if stats_container == null:
		return
	stats_container.scale = Vector2.ONE
	stats_container.add_theme_constant_override("separation", 7)

	stats_backdrop = PanelContainer.new()
	stats_backdrop.name = "StatsBackdrop"
	stats_backdrop.visible = stats_container.visible
	stats_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_backdrop.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.03, 0.04, 0.9)
	style.border_color = Color(0.48, 0.4, 0.26, 0.78)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 3
	stats_backdrop.add_theme_stylebox_override("panel", style)
	add_child(stats_backdrop)
	move_child(stats_backdrop, stats_container.get_index())

	var icon_names := ["StrIcon", "AgiIcon", "IntIcon"]
	var icon_tooltips := ["Strength", "Agility", "Intelligence"]
	for index in range(icon_names.size()):
		var icon := stats_container.get_node_or_null(icon_names[index]) as TextureRect
		if icon:
			icon.custom_minimum_size = Vector2(28, 28)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.tooltip_text = icon_tooltips[index]

	var label_names := ["StrLabel", "AgiLabel", "IntLabel"]
	var label_colors := [Color(1.0, 0.46, 0.28), Color(0.45, 1.0, 0.5), Color(0.48, 0.72, 1.0)]
	for index in range(label_names.size()):
		var value_label := stats_container.get_node_or_null(label_names[index]) as Label
		if value_label:
			value_label.custom_minimum_size = Vector2(24, 28)
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			value_label.add_theme_font_size_override("font_size", 18)
			value_label.add_theme_color_override("font_color", label_colors[index])
			value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			value_label.add_theme_constant_override("outline_size", 2)

func _get_active_hero_name_for_portrait() -> String:
	var player = _get_player_node()
	if player and player.is_node_ready():
		var player_hero = player.get("current_hero_name")
		if typeof(player_hero) == TYPE_STRING and player_hero != "":
			return player_hero
	if Global.hero_data.has(Global.hero_p1):
		return Global.hero_p1
	return "Dwarf"

func _refresh_hero_portrait(force := false) -> void:
	if not hero_portrait_icon:
		return
	var hero_name = _get_active_hero_name_for_portrait()
	if not force and hero_name == hero_portrait_hero_name:
		return
	hero_portrait_hero_name = hero_name
	var portrait_texture = HERO_PORTRAIT_TEXTURES.get(hero_name, null) as Texture2D
	if portrait_texture == null:
		portrait_texture = _get_player_portrait_texture()
	hero_portrait_icon.texture = portrait_texture
	hero_portrait_icon.tooltip_text = hero_name
	_refresh_base_status_icon(hero_name)

func _refresh_base_status_icon(hero_name: String = "") -> void:
	if not base_status_icon:
		return
	var active_hero := hero_name if hero_name != "" else _get_active_hero_name_for_portrait()
	base_status_icon.texture = HERO_BASE_TEXTURES.get(active_hero, HERO_BASE_TEXTURES["Dwarf"]) as Texture2D
	base_status_icon.tooltip_text = "%s Base" % active_hero

func _set_hero_portrait_respawn(time_left: float) -> void:
	var respawning = time_left > 0.0
	if hero_portrait_icon:
		hero_portrait_icon.modulate = Color(0.32, 0.32, 0.32, 1.0) if respawning else Color.WHITE
	if hero_portrait_dim:
		hero_portrait_dim.visible = respawning
	if hero_portrait_timer:
		hero_portrait_timer.visible = respawning
		hero_portrait_timer.text = str(int(ceil(time_left))) if respawning else ""

func _load_stomp_texture() -> Texture2D:
	for texture_path in STOMP_SPRITE_TEXTURES:
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			if texture is Texture2D:
				return texture
	return null

func _setup_stomp_ui() -> void:
	stomp_container = Control.new()
	stomp_container.name = "StompContainer"
	stomp_container.visible = false
	stomp_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Keep Stomp in its own row above the hero ability bar.
	# The old bottom-right anchor overlapped the fourth ability card.
	stomp_container.offset_left = -88
	stomp_container.offset_top = -168
	stomp_container.offset_right = -28
	stomp_container.offset_bottom = -108
	
	var stomp_icon = Control.new()
	stomp_icon.name = "StompIcon"
	stomp_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.58)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stomp_icon.add_child(bg)
	
	var icon_texture = _load_stomp_texture()
	if icon_texture:
		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 5
		icon.offset_top = 5
		icon.offset_right = -5
		icon.offset_bottom = -5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stomp_icon.add_child(icon)
	else:
		var stomp_label = Label.new()
		stomp_label.text = "STOMP"
		stomp_label.add_theme_font_size_override("font_size", 12)
		stomp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stomp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stomp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		stomp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stomp_icon.add_child(stomp_label)
	
	stomp_progress = TextureProgressBar.new()
	stomp_progress.name = "StompProgress"
	stomp_progress.set_anchors_preset(Control.PRESET_FULL_RECT)
	stomp_progress.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	stomp_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_tex = GradientTexture2D.new()
	bg_tex.width = 60
	bg_tex.height = 60
	bg_tex.fill_from = Vector2(0, 0)
	bg_tex.fill_to = Vector2(0, 0)
	var grad = Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.68), Color(0, 0, 0, 0.68)])
	bg_tex.gradient = grad
	stomp_progress.texture_progress = bg_tex
	stomp_progress.step = 0.01
	stomp_icon.add_child(stomp_progress)
	
	stomp_container.add_child(stomp_icon)
	add_child(stomp_container)

func _setup_notice_ui() -> void:
	notice_label = Label.new()
	notice_label.name = "NoticeLabel"
	notice_label.visible = false
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 22)
	notice_label.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	notice_label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 0.98))
	notice_label.add_theme_constant_override("outline_size", 4)
	notice_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	notice_label.offset_left = 220
	notice_label.offset_top = 184
	notice_label.offset_right = -220
	notice_label.offset_bottom = 222
	add_child(notice_label)

func _setup_objective_ui() -> void:
	objective_panel = PanelContainer.new()
	objective_panel.name = "FirstRunObjective"
	objective_panel.visible = false
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_panel.offset_left = -300
	objective_panel.offset_top = 76
	objective_panel.offset_right = 300
	objective_panel.offset_bottom = 172
	objective_panel.pivot_offset = Vector2(300, 48)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.035, 0.055, 0.95)
	panel_style.border_color = Color(0.18, 0.78, 1.0, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 9
	panel_style.content_margin_bottom = 9
	panel_style.shadow_color = Color(0, 0, 0, 0.58)
	panel_style.shadow_size = 6
	objective_panel.add_theme_stylebox_override("panel", panel_style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 1)
	objective_panel.add_child(box)
	objective_step_label = Label.new()
	objective_step_label.text = "FIRST RUN"
	objective_step_label.add_theme_font_size_override("font_size", 10)
	objective_step_label.add_theme_color_override("font_color", Color(0.38, 0.82, 1.0, 1.0))
	box.add_child(objective_step_label)
	objective_title_label = Label.new()
	objective_title_label.add_theme_font_size_override("font_size", 20)
	objective_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68, 1.0))
	box.add_child(objective_title_label)
	objective_body_label = Label.new()
	objective_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_body_label.add_theme_font_size_override("font_size", 13)
	objective_body_label.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98, 1.0))
	box.add_child(objective_body_label)
	add_child(objective_panel)

func _setup_carry_status_ui() -> void:
	carry_status_panel = PanelContainer.new()
	carry_status_panel.name = "CarryStatus"
	carry_status_panel.visible = false
	carry_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carry_status_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	carry_status_panel.offset_left = 92
	carry_status_panel.offset_top = 62
	carry_status_panel.offset_right = 430
	carry_status_panel.offset_bottom = 91
	var carry_style := StyleBoxFlat.new()
	carry_style.bg_color = Color(0.02, 0.07, 0.09, 0.92)
	carry_style.border_color = Color(0.2, 0.9, 1.0, 0.82)
	carry_style.set_border_width_all(1)
	carry_style.set_corner_radius_all(7)
	carry_style.content_margin_left = 10
	carry_style.content_margin_right = 10
	carry_status_panel.add_theme_stylebox_override("panel", carry_style)
	carry_status_label = Label.new()
	carry_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carry_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	carry_status_label.add_theme_font_size_override("font_size", 12)
	carry_status_panel.add_child(carry_status_label)
	add_child(carry_status_panel)

func _setup_return_cue_ui() -> void:
	return_cue = Control.new()
	return_cue.name = "GemReturnCue"
	return_cue.visible = false
	return_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return_cue.size = Vector2(154, 44)
	var background := ColorRect.new()
	background.color = Color(0.015, 0.07, 0.085, 0.92)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return_cue.add_child(background)
	return_cue_arrow = Label.new()
	return_cue_arrow.text = "▶"
	return_cue_arrow.position = Vector2(7, 7)
	return_cue_arrow.size = Vector2(30, 30)
	return_cue_arrow.pivot_offset = Vector2(15, 15)
	return_cue_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return_cue_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return_cue_arrow.add_theme_font_size_override("font_size", 24)
	return_cue_arrow.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0, 1.0))
	return_cue.add_child(return_cue_arrow)
	return_cue_label = Label.new()
	return_cue_label.text = "BANK GEMS"
	return_cue_label.position = Vector2(40, 7)
	return_cue_label.size = Vector2(106, 30)
	return_cue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return_cue_label.add_theme_font_size_override("font_size", 14)
	return_cue_label.add_theme_color_override("font_color", Color(0.45, 1.0, 1.0, 1.0))
	return_cue_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	return_cue_label.add_theme_constant_override("outline_size", 3)
	return_cue.add_child(return_cue_label)
	add_child(return_cue)

func show_objective(step_text: String, title_text: String, body_text: String) -> void:
	if not objective_panel:
		return
	objective_step_label.text = step_text
	objective_title_label.text = title_text
	objective_body_label.text = body_text
	objective_panel.visible = true
	if objective_tween and objective_tween.is_running():
		objective_tween.kill()
	objective_panel.scale = Vector2(0.96, 0.96)
	objective_panel.modulate = Color(1.25, 1.25, 1.25, 1.0)
	objective_tween = create_tween().set_parallel(true)
	objective_tween.tween_property(objective_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	objective_tween.tween_property(objective_panel, "modulate", Color.WHITE, 0.28)

func hide_objective() -> void:
	if objective_panel:
		objective_panel.visible = false

func _update_carry_status() -> void:
	if not carry_status_panel or not carry_status_label:
		return
	var player := _get_player_node()
	var carry_load := int(player.get_carry_load()) if player and player.has_method("get_carry_load") else 0
	if carry_load == last_carry_load:
		return
	last_carry_load = carry_load
	carry_status_panel.visible = carry_load > 0
	if carry_load <= 0:
		return
	var allowance := int(player.get_free_carry_allowance()) if player.has_method("get_free_carry_allowance") else 0
	var overload: int = maxi(carry_load - allowance, 0)
	var penalty_percent: int = int(round(float(player.get_weight_penalty()) * 100.0)) if player.has_method("get_weight_penalty") else 0
	if overload > 0:
		carry_status_label.text = "CARRYING %d GEMS  •  SLOWED %d%%  •  RETURN TO BASE" % [carry_load, penalty_percent]
	else:
		carry_status_label.text = "CARRYING %d GEM%s  •  RETURN TO BASE" % [carry_load, "" if carry_load == 1 else "S"]
	carry_status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3, 1.0) if overload > 0 else Color(0.55, 1.0, 1.0, 1.0))

func _update_return_cue() -> void:
	if not return_cue or not return_cue_arrow:
		return
	var world := get_parent()
	var player := world.get_node_or_null("Player") if world else null
	var base := world.get_node_or_null("Base") if world else null
	var carry_load := int(player.get_carry_load()) if player and player.has_method("get_carry_load") else 0
	if not player or not base or carry_load <= 0:
		return_cue.visible = false
		return
	var to_base: Vector2 = base.global_position - player.global_position
	if to_base.length() < 330.0:
		return_cue.visible = false
		return
	var direction := to_base.normalized()
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var half_extent := Vector2(max(viewport_size.x * 0.5 - 90.0, 20.0), max(viewport_size.y * 0.5 - 52.0, 20.0))
	var edge_scale := 1000000.0
	if abs(direction.x) > 0.001:
		edge_scale = min(edge_scale, half_extent.x / abs(direction.x))
	if abs(direction.y) > 0.001:
		edge_scale = min(edge_scale, half_extent.y / abs(direction.y))
	var cue_position := center + direction * edge_scale - return_cue.size * 0.5
	cue_position.x = clamp(cue_position.x, 8.0, max(viewport_size.x - return_cue.size.x - 8.0, 8.0))
	cue_position.y = clamp(cue_position.y, 8.0, max(viewport_size.y - return_cue.size.y - 8.0, 8.0))
	return_cue.position = cue_position
	return_cue_arrow.rotation = direction.angle()
	return_cue.visible = true

func _setup_base_warning_ui() -> void:
	base_status_panel = PanelContainer.new()
	base_status_panel.name = "BaseStatus"
	base_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The base is the opposing top-right HUD anchor; purchased base modules
	# extend downward from it instead of joining the player cluster.
	base_status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	base_status_panel.offset_left = -146
	base_status_panel.offset_top = 14
	base_status_panel.offset_right = -16
	base_status_panel.offset_bottom = 104
	base_status_panel.pivot_offset = Vector2(65, 45)
	base_status_style = StyleBoxFlat.new()
	base_status_style.set_border_width_all(2)
	base_status_style.set_corner_radius_all(9)
	base_status_style.shadow_color = Color(0, 0, 0, 0.55)
	base_status_style.shadow_size = 4
	base_status_panel.add_theme_stylebox_override("panel", base_status_style)

	var content := Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_status_panel.add_child(content)
	base_status_icon = TextureRect.new()
	base_status_icon.name = "Icon"
	base_status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base_status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base_status_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_status_icon.offset_left = 8
	base_status_icon.offset_top = 6
	base_status_icon.offset_right = -8
	base_status_icon.offset_bottom = -6
	base_status_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(base_status_icon)
	_refresh_base_status_icon()

	base_status_label = Label.new()
	base_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	base_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	base_status_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	base_status_label.offset_top = -20
	base_status_label.offset_bottom = -3
	base_status_label.add_theme_font_size_override("font_size", 9)
	base_status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	base_status_label.add_theme_constant_override("outline_size", 2)
	base_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_status_label.visible = false
	content.add_child(base_status_label)
	add_child(base_status_panel)

	base_direction_cue = Control.new()
	base_direction_cue.name = "BaseDirectionCue"
	base_direction_cue.visible = false
	base_direction_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_direction_cue.size = Vector2(116, 44)
	var cue_background = ColorRect.new()
	cue_background.color = Color(0.04, 0.04, 0.05, 0.86)
	cue_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cue_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_direction_cue.add_child(cue_background)
	base_direction_arrow = Label.new()
	base_direction_arrow.text = "▶"
	base_direction_arrow.position = Vector2(7, 7)
	base_direction_arrow.size = Vector2(30, 30)
	base_direction_arrow.pivot_offset = Vector2(15, 15)
	base_direction_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	base_direction_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	base_direction_arrow.add_theme_font_size_override("font_size", 24)
	base_direction_cue.add_child(base_direction_arrow)
	base_direction_label = Label.new()
	base_direction_label.text = "BASE"
	base_direction_label.position = Vector2(40, 7)
	base_direction_label.size = Vector2(68, 30)
	base_direction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	base_direction_label.add_theme_font_size_override("font_size", 16)
	base_direction_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	base_direction_label.add_theme_constant_override("outline_size", 3)
	base_direction_cue.add_child(base_direction_label)
	add_child(base_direction_cue)
	_apply_base_warning_state(false)

func _setup_breach_direction_cue_ui() -> void:
	breach_direction_cue = Control.new()
	breach_direction_cue.name = "BreachDirectionCue"
	breach_direction_cue.visible = false
	breach_direction_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breach_direction_cue.size = Vector2(164, 44)
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.12, 0.015, 0.01, 0.92)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	breach_direction_cue.add_child(background)
	breach_direction_arrow = Label.new()
	breach_direction_arrow.name = "Arrow"
	breach_direction_arrow.text = "▶"
	breach_direction_arrow.position = Vector2(7, 7)
	breach_direction_arrow.size = Vector2(30, 30)
	breach_direction_arrow.pivot_offset = Vector2(15, 15)
	breach_direction_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breach_direction_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	breach_direction_arrow.add_theme_font_size_override("font_size", 24)
	breach_direction_arrow.add_theme_color_override("font_color", Color(1.0, 0.2, 0.08, 1.0))
	breach_direction_arrow.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
	breach_direction_arrow.add_theme_constant_override("outline_size", 3)
	breach_direction_cue.add_child(breach_direction_arrow)
	breach_direction_label = Label.new()
	breach_direction_label.name = "Label"
	breach_direction_label.text = "ENEMY BREACH"
	breach_direction_label.position = Vector2(40, 7)
	breach_direction_label.size = Vector2(116, 30)
	breach_direction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	breach_direction_label.add_theme_font_size_override("font_size", 13)
	breach_direction_label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.3, 1.0))
	breach_direction_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
	breach_direction_label.add_theme_constant_override("outline_size", 3)
	breach_direction_cue.add_child(breach_direction_label)
	add_child(breach_direction_cue)

func set_breach_target(world_position: Vector2, wave_number: int, active: bool = true) -> void:
	breach_target_world_position = world_position
	breach_target_wave = maxi(wave_number, 1)
	breach_target_active = active
	if breach_direction_label:
		breach_direction_label.text = "BREACH  W%d" % breach_target_wave
	if not active and breach_direction_cue:
		breach_direction_cue.visible = false

func clear_breach_target() -> void:
	breach_target_active = false
	if breach_direction_cue:
		breach_direction_cue.visible = false

func _update_breach_direction_cue() -> void:
	if not breach_direction_cue or not breach_direction_arrow:
		return
	var player := _get_player_node()
	if not breach_target_active or not player:
		breach_direction_cue.visible = false
		return
	var to_breach: Vector2 = breach_target_world_position - player.global_position
	if to_breach.length() < 260.0:
		breach_direction_cue.visible = false
		return
	var direction := to_breach.normalized()
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var half_extent := Vector2(max(viewport_size.x * 0.5 - 96.0, 20.0), max(viewport_size.y * 0.5 - 54.0, 20.0))
	var edge_scale := 1000000.0
	if abs(direction.x) > 0.001:
		edge_scale = min(edge_scale, half_extent.x / abs(direction.x))
	if abs(direction.y) > 0.001:
		edge_scale = min(edge_scale, half_extent.y / abs(direction.y))
	var cue_position := center + direction * edge_scale - breach_direction_cue.size * 0.5
	cue_position.x = clamp(cue_position.x, 8.0, max(viewport_size.x - breach_direction_cue.size.x - 8.0, 8.0))
	cue_position.y = clamp(cue_position.y, 8.0, max(viewport_size.y - breach_direction_cue.size.y - 8.0, 8.0))
	breach_direction_cue.position = cue_position
	breach_direction_arrow.rotation = direction.angle()
	breach_direction_cue.visible = true

func _setup_cave_reward_ui() -> void:
	if cave_reward_container:
		return
	cave_reward_container = HBoxContainer.new()
	cave_reward_container.name = "CaveRewards"
	cave_reward_container.visible = false
	cave_reward_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cave_reward_container.add_theme_constant_override("separation", 8)
	cave_reward_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cave_reward_container.offset_left = 366
	cave_reward_container.offset_top = 12
	cave_reward_container.offset_right = 566
	cave_reward_container.offset_bottom = 88
	add_child(cave_reward_container)

func _create_cave_reward_slot(title_text: String, effect_text: String) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(176, 76)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.pivot_offset = Vector2(88, 38)
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0.12, 0.065, 0.025, 0.94)
	slot_style.border_color = Color(0.95, 0.68, 0.22, 0.96)
	slot_style.set_border_width_all(2)
	slot_style.set_corner_radius_all(9)
	slot_style.shadow_color = Color(0, 0, 0, 0.55)
	slot_style.shadow_size = 4
	slot.add_theme_stylebox_override("panel", slot_style)

	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 7)
	slot.add_child(content)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(44, 52)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.38, 0.19, 0.07, 1.0)
	icon_style.border_color = Color(1.0, 0.78, 0.3, 1.0)
	icon_style.set_border_width_all(2)
	icon_style.set_corner_radius_all(7)
	icon_frame.add_theme_stylebox_override("panel", icon_style)
	content.add_child(icon_frame)

	var icon_label := Label.new()
	icon_label.text = "BAG"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 12)
	icon_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48, 1.0))
	icon_label.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.01, 0.95))
	icon_label.add_theme_constant_override("outline_size", 2)
	icon_frame.add_child(icon_label)

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", 2)
	content.add_child(text_box)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(1.0, 0.91, 0.7, 1.0))
	text_box.add_child(title)

	var effect := Label.new()
	effect.text = effect_text
	effect.add_theme_font_size_override("font_size", 10)
	effect.add_theme_color_override("font_color", Color(1.0, 0.72, 0.24, 1.0))
	text_box.add_child(effect)
	return slot

func add_cave_reward(reward_id: String) -> bool:
	if cave_reward_slots.has(reward_id):
		return false
	if not cave_reward_container:
		_setup_cave_reward_ui()
	var slot: PanelContainer
	match reward_id:
		"miners_satchel":
			slot = _create_cave_reward_slot("MINER'S SATCHEL", "+1 FREE CARRY")
		_:
			return false
	slot.name = reward_id.to_pascal_case()
	cave_reward_container.add_child(slot)
	cave_reward_slots[reward_id] = slot
	cave_reward_container.visible = true
	if is_inside_tree():
		slot.scale = Vector2(1.16, 1.16)
		slot.modulate = Color(1.25, 1.25, 1.25, 1.0)
		var reward_tween := create_tween().set_parallel(true)
		reward_tween.tween_property(slot, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reward_tween.tween_property(slot, "modulate", Color.WHITE, 0.32)
	return true

func _set_base_warning_health(current_health: int, maximum_health: int, pulse: bool) -> void:
	base_warning_health = max(current_health, 0)
	base_warning_max_health = max(maximum_health, 1)
	var health_ratio := float(base_warning_health) / float(base_warning_max_health)
	if health_ratio <= BASE_CRITICAL_THRESHOLD:
		base_warning_state = "critical"
	elif health_ratio < BASE_DAMAGED_THRESHOLD:
		base_warning_state = "damaged"
	else:
		base_warning_state = "stable"
	_apply_base_warning_state(pulse)

func _apply_base_warning_state(pulse: bool) -> void:
	if not base_status_panel or not base_status_style:
		return
	var warning_color: Color = BASE_WARNING_COLORS.get(base_warning_state, BASE_WARNING_COLORS["stable"])
	base_status_style.bg_color = Color(0.025, 0.03, 0.04, 0.82)
	base_status_style.border_color = warning_color
	if base_status_icon:
		# The base sprite stays readable; the frame and health bar communicate danger.
		base_status_icon.modulate = Color.WHITE if base_warning_state == "stable" else Color.WHITE.lerp(warning_color, 0.28)
	if base_status_label:
		base_status_label.visible = true
		base_status_label.text = "BASE %d%%" % int(round(float(base_warning_health) / float(max(base_warning_max_health, 1)) * 100.0))
		base_status_label.add_theme_color_override("font_color", warning_color)
	base_status_panel.queue_redraw()
	if base_direction_arrow:
		base_direction_arrow.add_theme_color_override("font_color", warning_color)
	if base_direction_label:
		base_direction_label.add_theme_color_override("font_color", warning_color)
	if pulse:
		if base_status_tween and base_status_tween.is_running():
			base_status_tween.kill()
		base_status_panel.scale = Vector2(1.12, 1.12)
		base_status_panel.modulate = Color(1.35, 1.35, 1.35, 1.0)
		base_status_tween = create_tween().set_parallel(true)
		base_status_tween.tween_property(base_status_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		base_status_tween.tween_property(base_status_panel, "modulate", Color.WHITE, 0.24)

func notify_wave_started(is_boss: bool = false, wave_number: int = 1) -> void:
	if wave_number == 1 and not is_boss:
		show_notice("FIRST SCOUT — return to the base and move into it to auto-attack!", 4.5)
		show_objective("COMBAT TIP", "DEFEND THE BASE", "Approach an enemy to attack automatically. Move away to retreat.")
		var objective_hud := self
		get_tree().create_timer(6.0).timeout.connect(func():
			if is_instance_valid(objective_hud):
				objective_hud.hide_objective()
		)
	else:
		show_notice("BOSS BREACH — return to the base!" if is_boss else "WAVE BREACH — enemies are moving toward the base!", 3.0)

func notify_base_damaged(current_health: int, maximum_health: int = 100) -> void:
	var previous_state := base_warning_state
	_set_base_warning_health(current_health, maximum_health, true)
	var entered_critical := base_warning_state == "critical" and previous_state != "critical"
	if base_hit_notice_cooldown <= 0.0 or entered_critical:
		show_notice("The base is in critical danger!" if base_warning_state == "critical" else "The base is under attack.", 2.2)
		base_hit_notice_cooldown = BASE_HIT_NOTICE_COOLDOWN

func _update_base_direction_cue() -> void:
	if not base_direction_cue or not base_direction_arrow:
		return
	var world := get_parent()
	var player := world.get_node_or_null("Player") if world else null
	var base := world.get_node_or_null("Base") if world else null
	if not player or not base or base_warning_state == "stable":
		base_direction_cue.visible = false
		return
	var to_base: Vector2 = base.global_position - player.global_position
	if to_base.length() < BASE_DIRECTION_DISTANCE:
		base_direction_cue.visible = false
		return
	var direction := to_base.normalized()
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var half_extent := Vector2(max(viewport_size.x * 0.5 - 70.0, 20.0), max(viewport_size.y * 0.5 - 48.0, 20.0))
	var edge_scale := 1000000.0
	if abs(direction.x) > 0.001:
		edge_scale = min(edge_scale, half_extent.x / abs(direction.x))
	if abs(direction.y) > 0.001:
		edge_scale = min(edge_scale, half_extent.y / abs(direction.y))
	var cue_position := center + direction * edge_scale - base_direction_cue.size * 0.5
	cue_position.x = clamp(cue_position.x, 8.0, max(viewport_size.x - base_direction_cue.size.x - 8.0, 8.0))
	cue_position.y = clamp(cue_position.y, 8.0, max(viewport_size.y - base_direction_cue.size.y - 8.0, 8.0))
	base_direction_cue.position = cue_position
	base_direction_arrow.rotation = direction.angle()
	base_direction_cue.visible = true

func _process(delta):
	base_hit_notice_cooldown = max(base_hit_notice_cooldown - delta, 0.0)
	if minimap and minimap.visible:
		minimap.queue_redraw()
	_refresh_hero_portrait()
	_update_carry_status()
	_update_return_cue()
	_update_breach_direction_cue()
	_update_base_direction_cue()
	_update_nerubian_status_from_world()

func _relayout_unlocked_hud() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var compact := viewport_size.x < 760.0
	var edge := 12.0 if compact else 16.0
	var player_width := 230.0 if compact else 280.0
	var base_width := 190.0 if compact else 220.0
	var center_width := 300.0 if compact else 420.0

	# Player cluster: portrait/resources, optional health, then purchased stats.
	_layout_health_hud_module("PlayerLabel", player_health_bar, 82.0, false, edge, player_width)
	var stats_container := get_node_or_null("StatsContainer") as Control
	if stats_backdrop:
		stats_backdrop.visible = stats_container != null and stats_container.visible
		stats_backdrop.offset_left = edge
		stats_backdrop.offset_top = 114.0
		stats_backdrop.offset_right = edge + (222.0 if compact else 244.0)
		stats_backdrop.offset_bottom = 154.0
	if stats_container and stats_container.visible:
		stats_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
		stats_container.position = Vector2(edge + 8.0, 120.0)
		stats_container.size = Vector2(206.0 if compact else 228.0, 30.0)

	# Large run rewards stay out of the player cluster until compact item icons exist.
	if cave_reward_container:
		cave_reward_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		cave_reward_container.offset_left = edge
		cave_reward_container.offset_top = -96.0
		cave_reward_container.offset_right = edge + 220.0
		cave_reward_container.offset_bottom = -16.0

	# XP remains a strong bottom-center anchor and never occupies the future mana slot.
	if xp_label and xp_bar:
		xp_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		xp_bar.offset_left = -center_width * 0.5
		xp_bar.offset_top = -42.0
		xp_bar.offset_right = center_width * 0.5
		xp_bar.offset_bottom = -20.0
		xp_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		xp_label.offset_left = -center_width * 0.5
		xp_label.offset_top = -43.0
		xp_label.offset_right = center_width * 0.5
		xp_label.offset_bottom = -19.0
		xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_style_hud_progress_bar(xp_bar, Color(0.48, 0.26, 0.86, 1.0))

	# Base cluster: sprite only at the top-right with exact health directly beneath.
	if base_status_panel:
		base_status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		base_status_panel.offset_left = -146.0
		base_status_panel.offset_top = 14.0
		base_status_panel.offset_right = -edge
		base_status_panel.offset_bottom = 104.0
	_layout_health_hud_module("BaseLabel", base_health_bar, 108.0, true, edge, base_width)

	# Purchased wave information sits between screen center and the base cluster.
	if wave_label:
		wave_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		wave_label.offset_left = 20.0
		wave_label.offset_top = 18.0
		wave_label.offset_right = 280.0
		wave_label.offset_bottom = 46.0
		wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if get_node_or_null("WaveBar"):
		var wave_bar := get_node("WaveBar") as TextureProgressBar
		wave_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
		wave_bar.offset_left = 20.0
		wave_bar.offset_top = 48.0
		wave_bar.offset_right = 280.0
		wave_bar.offset_bottom = 62.0
		_style_hud_progress_bar(wave_bar, Color(0.95, 0.58, 0.14, 1.0))
	if minimap and minimap.visible:
		minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		minimap.position = Vector2(viewport_size.x - edge - minimap.size.x, 148.0)

func _layout_health_hud_module(label_name: String, bar: TextureProgressBar, y: float, align_right: bool, edge: float, module_width: float) -> float:
	var value_label := get_node_or_null(label_name) as Label
	var is_visible := (bar != null and bar.visible) or (value_label != null and value_label.visible)
	if not is_visible:
		return y
	var x := get_viewport().get_visible_rect().size.x - edge - module_width if align_right else edge
	if bar:
		bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
		bar.position = Vector2(x, y)
		bar.size = Vector2(module_width, 22.0)
		_style_hud_progress_bar(bar, Color(0.35, 0.86, 0.38, 1.0) if align_right else Color(0.9, 0.16, 0.18, 1.0))
	if value_label:
		value_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		value_label.position = Vector2(x, y)
		value_label.size = Vector2(module_width, 22.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 13)
		value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		value_label.add_theme_constant_override("outline_size", 3)
	return y + 30.0

func _style_hud_progress_bar(bar: TextureProgressBar, progress_color: Color) -> void:
	if not bar:
		return
	bar.tint_under = Color(0.025, 0.03, 0.04, 0.92)
	bar.tint_progress = progress_color
	bar.tint_over = Color(1, 1, 1, 0.78)

func _make_texture_style(texture: Texture2D) -> StyleBoxTexture:
	var stylebox = StyleBoxTexture.new()
	if texture:
		stylebox.texture = texture
	return stylebox

func _apply_menu_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_texture_style(MENU_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("hover", _make_texture_style(MENU_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("pressed", _make_texture_style(MENU_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _setup_totem_wheel_ui() -> void:
	totem_wheel = Control.new()
	totem_wheel.name = "TotemWheel"
	totem_wheel.visible = false
	totem_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	totem_wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(totem_wheel)
	
	var dim = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	totem_wheel.add_child(dim)
	
	var offsets = {
		"dig": Vector2(0, -92),
		"heal": Vector2(92, 0),
		"radar": Vector2(0, 92),
		"gem": Vector2(-92, 0)
	}
	
	for type in TOTEM_TYPES:
		var slot = PanelContainer.new()
		slot.name = "%sSlot" % type.capitalize()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.custom_minimum_size = Vector2(74, 84)
		slot.set_anchors_preset(Control.PRESET_CENTER)
		slot.offset_left = offsets[type].x - 37
		slot.offset_top = offsets[type].y - 42
		slot.offset_right = offsets[type].x + 37
		slot.offset_bottom = offsets[type].y + 42
		
		var box = VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_child(box)
		
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = TOTEM_TEXTURES[type] as Texture2D
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		
		var text = Label.new()
		text.text = TOTEM_LABELS[type]
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", 12)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(text)
		
		totem_wheel.add_child(slot)
		totem_wheel_icons[type] = slot

func _setup_totem_status_ui() -> void:
	totem_status_container = HBoxContainer.new()
	totem_status_container.name = "TotemStatus"
	totem_status_container.visible = false
	totem_status_container.alignment = BoxContainer.ALIGNMENT_END
	totem_status_container.add_theme_constant_override("separation", 6)
	totem_status_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	totem_status_container.offset_left = -282
	totem_status_container.offset_top = -136
	totem_status_container.offset_right = -28
	totem_status_container.offset_bottom = -82
	add_child(totem_status_container)
	
	for type in TOTEM_TYPES:
		var slot = _create_icon_status_slot(TOTEM_TEXTURES[type], Vector2(56, 54))
		slot.visible = false
		totem_status_container.add_child(slot)
		totem_status_slots[type] = slot

func _setup_nerubian_status_ui() -> void:
	nerubian_status_container = HBoxContainer.new()
	nerubian_status_container.name = "NerubianStatus"
	nerubian_status_container.visible = false
	nerubian_status_container.alignment = BoxContainer.ALIGNMENT_END
	nerubian_status_container.add_theme_constant_override("separation", 6)
	nerubian_status_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	nerubian_status_container.offset_left = -392
	nerubian_status_container.offset_top = 18
	nerubian_status_container.offset_right = -24
	nerubian_status_container.offset_bottom = 78
	add_child(nerubian_status_container)
	
	nerubian_spawn_slot = _create_icon_status_slot(NERUBIAN_SPIDER_TEXTURE, Vector2(64, 58), "BROOD")
	nerubian_status_container.add_child(nerubian_spawn_slot)
	
	for i in range(NERUBIAN_MAX_SPIDER_SLOTS):
		var slot = _create_icon_status_slot(NERUBIAN_SPIDER_TEXTURE, Vector2(48, 50))
		slot.visible = false
		nerubian_status_container.add_child(slot)
		nerubian_spider_slots.append(slot)

func _create_icon_status_slot(texture: Texture2D, size: Vector2, title: String = "") -> Control:
	var slot = Control.new()
	slot.custom_minimum_size = size
	
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(bg)
	
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6
	icon.offset_top = 4
	icon.offset_right = -6
	icon.offset_bottom = -12
	slot.add_child(icon)
	
	var fill = ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(0.25, 0.75, 1.0, 0.35)
	fill.anchor_left = 0
	fill.anchor_right = 1
	fill.anchor_top = 1
	fill.anchor_bottom = 1
	fill.offset_left = 0
	fill.offset_right = 0
	fill.offset_top = -4
	fill.offset_bottom = 0
	slot.add_child(fill)
	
	var label = Label.new()
	label.name = "Timer"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", 10)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(label)
	
	if title != "":
		var title_label = Label.new()
		title_label.name = "Title"
		title_label.text = title
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		title_label.add_theme_font_size_override("font_size", 9)
		title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(title_label)
	
	return slot

func add_gems(amount: int) -> void:
	total_gems += amount
	if amount > 0:
		run_gems_collected += amount
	label.text = "%d" % total_gems

func add_gold(amount: int) -> void:
	total_gold += amount
	if amount > 0:
		run_gold_collected += amount
	if gold_label:
		gold_label.text = "%d" % total_gold

func update_health(new_health: int) -> void:
	if base_health_bar:
		base_health_bar.value = new_health
	var base_value_label := get_node_or_null("BaseLabel") as Label
	if base_value_label:
		base_value_label.text = "%d / %d" % [new_health, base_warning_max_health]
	_set_base_warning_health(new_health, base_warning_max_health, false)

func update_stats(str_val: int, agi_val: int, int_val: int) -> void:
	if str_label: str_label.text = str(str_val)
	if agi_label: agi_label.text = str(agi_val)
	if int_label: int_label.text = str(int_val)

func unlock_healthbar() -> void:
	if player_health_bar:
		player_health_bar.visible = true
	var pl = get_node_or_null("PlayerLabel")
	if pl: pl.visible = true
	_relayout_unlocked_hud()

func unlock_base_healthbar() -> void:
	if base_health_bar: base_health_bar.visible = true
	var bl = get_node_or_null("BaseLabel")
	if bl: bl.visible = true
	_relayout_unlocked_hud()

func unlock_stats() -> void:
	var sc = get_node_or_null("StatsContainer")
	if sc:
		sc.visible = true
	if stats_backdrop:
		stats_backdrop.visible = true
	_relayout_unlocked_hud()

func unlock_wave_timer() -> void:
	if wave_label: wave_label.visible = true
	var wb = get_node_or_null("WaveBar")
	if wb: wb.visible = true
	_relayout_unlocked_hud()

func unlock_xp() -> void:
	if xp_bar: xp_bar.visible = true
	if xp_label: xp_label.visible = true
	_relayout_unlocked_hud()

func update_player_health(current: int, max_hp: int) -> void:
	player_health_bar.max_value = max_hp
	player_health_bar.value = current
	var player_value_label := get_node_or_null("PlayerLabel") as Label
	if player_value_label:
		player_value_label.text = "%d / %d" % [current, max_hp]

func update_xp(level: int, current_xp: int, max_xp: int) -> void:
	if xp_label:
		xp_label.text = "Lvl %d: %d / %d XP" % [level, current_xp, max_xp]
	if xp_bar:
		xp_bar.max_value = max_xp
		xp_bar.value = current_xp

func update_stomp_cooldown(stomp_level: int, current_cooldown: float, max_cooldown: float) -> void:
	if stomp_level > 0:
		if stomp_container and not stomp_container.visible:
			stomp_container.visible = true
		if stomp_progress:
			stomp_progress.max_value = max_cooldown
			stomp_progress.value = current_cooldown

func show_notice(text: String, duration: float = 1.8) -> void:
	if not notice_label:
		return
	if notice_tween and notice_tween.is_running():
		notice_tween.kill()
	notice_label.text = text
	notice_label.visible = true
	notice_label.modulate = Color(1, 1, 1, 1)
	notice_tween = create_tween()
	notice_tween.tween_interval(duration)
	notice_tween.tween_property(notice_label, "modulate", Color(1, 1, 1, 0), 0.35)
	notice_tween.tween_callback(func(): notice_label.visible = false)

func show_totem_wheel(selected_type: String) -> void:
	if not totem_wheel:
		return
	totem_wheel.visible = true
	update_totem_wheel_selection(selected_type)

func update_totem_wheel_selection(selected_type: String) -> void:
	for type in totem_wheel_icons.keys():
		var slot = totem_wheel_icons[type]
		if type == selected_type:
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
			slot.scale = Vector2(1.16, 1.16)
		else:
			slot.modulate = Color(0.55, 0.65, 0.75, 0.9)
			slot.scale = Vector2.ONE

func hide_totem_wheel() -> void:
	if totem_wheel:
		totem_wheel.visible = false

func update_totem_status(statuses: Dictionary) -> void:
	var any_visible = false
	for type in TOTEM_TYPES:
		var slot = totem_status_slots.get(type)
		if not slot:
			continue
		var data = statuses.get(type, {})
		var active = float(data.get("active", 0.0))
		var cooldown = float(data.get("cooldown", 0.0))
		var ratio = float(data.get("ratio", 0.0))
		var visible = active > 0.0 or cooldown > 0.0
		slot.visible = visible
		if not visible:
			continue
		any_visible = true
		if active > 0.0:
			_update_status_slot(slot, active, ratio, false, Color(0.2, 0.8, 1.0, 0.45))
		else:
			_update_status_slot(slot, cooldown, 0.0, true, Color(0.1, 0.1, 0.1, 0.55))
	
	totem_status_container.visible = any_visible

func _update_nerubian_status_from_world() -> void:
	if not nerubian_status_container:
		return
	var world = get_parent()
	var player = world.get_node_or_null("Player") if world else null
	if not player or str(player.get("current_hero_name")) != "Nerubian":
		nerubian_status_container.visible = false
		return
	
	nerubian_status_container.visible = true
	var cooldown = max(float(player.get("nerubian_spawn_cooldown_timer")), 0.0)
	var cooldown_ratio = clamp(cooldown / NERUBIAN_SPAWN_MAX_COOLDOWN, 0.0, 1.0)
	if cooldown > 0.0:
		_update_status_slot(nerubian_spawn_slot, cooldown, cooldown_ratio, true, Color(0.1, 0.1, 0.1, 0.55))
	else:
		_update_status_slot(nerubian_spawn_slot, 0.0, 1.0, false, Color(0.2, 0.9, 0.35, 0.42), "READY")
	
	var spider_data = []
	for spider in get_tree().get_nodes_in_group("nerubian_spiders"):
		if is_instance_valid(spider) and spider.get("owner_player") == player:
			var active = float(spider.get("lifetime"))
			var max_life = active
			if spider.has_method("get_max_lifetime"):
				max_life = spider.get_max_lifetime()
			var ratio = active / max(max_life, 0.01)
			spider_data.append({"lifetime": active, "ratio": clamp(ratio, 0.0, 1.0)})
	
	spider_data.sort_custom(func(a, b): return float(a["lifetime"]) < float(b["lifetime"]))
	for i in range(nerubian_spider_slots.size()):
		var slot = nerubian_spider_slots[i]
		if i < spider_data.size():
			slot.visible = true
			_update_status_slot(slot, float(spider_data[i]["lifetime"]), float(spider_data[i]["ratio"]), false, Color(0.75, 0.35, 1.0, 0.38))
		else:
			slot.visible = false

func _update_status_slot(slot: Control, time_value: float, ratio: float, is_cooldown: bool, fill_color: Color, override_text: String = "") -> void:
	if not slot:
		return
	var fill = slot.get_node_or_null("Fill")
	var label = slot.get_node_or_null("Timer")
	var icon = slot.get_node_or_null("Icon")
	slot.modulate = Color(0.58, 0.58, 0.58, 0.95) if is_cooldown else Color(1, 1, 1, 1)
	if label:
		if override_text != "":
			label.text = override_text
		elif time_value > 0.0:
			label.text = "%d" % ceil(time_value)
		else:
			label.text = ""
	if fill:
		fill.color = fill_color
		fill.anchor_top = clamp(1.0 - ratio, 0.0, 1.0)
	if icon:
		icon.modulate = Color.WHITE

func unlock_minimap() -> void:
	minimap.visible = true
	_relayout_unlocked_hud()

func upgrade_minimap_enemies() -> void:
	minimap_shows_enemies = true

func update_respawn_timer(time_left: float) -> void:
	_set_hero_portrait_respawn(time_left)
	if time_left > 0:
		respawn_label.visible = true
		respawn_label.text = "Respawning in %.1f..." % time_left
	else:
		respawn_label.visible = false

func update_wave_info(wave: int, time_left: float, max_time: float, is_boss: bool) -> void:
	last_wave_reached = max(last_wave_reached, wave)
	if is_boss:
		wave_label.add_theme_color_override("font_color", Color(1, 0, 0)) # Red text for Boss
		if time_left < 0:
			wave_label.text = "BOSS WAVE %d - COMBAT!" % wave
		else:
			wave_label.text = "BOSS WAVE %d!" % wave
	else:
		wave_label.add_theme_color_override("font_color", Color(1, 1, 1))
		if time_left < 0:
			wave_label.text = "Wave %d - Combat Phase" % wave
		else:
			wave_label.text = "Wave %d" % wave
	
	var wave_bar = get_node_or_null("WaveBar")
	if wave_bar:
		wave_bar.max_value = max_time
		if time_left < 0:
			wave_bar.value = max_time
		else:
			wave_bar.value = time_left

func _on_minimap_draw() -> void:
	var world = get_parent()
	var tile_map = world.get_node_or_null("BlockLayer")
	if not tile_map: return
	
	minimap.draw_rect(Rect2(0, 0, 200, 200), Color(0.1, 0.1, 0.1, 0.8))
	
	for x in range(-20, 20):
		for y in range(-2, 30):
			var cell = Vector2i(x, y)
			var px = (x + 20) * 5
			var py = (y + 2) * 5
			
			if tile_map.get_cell_source_id(cell) == -1:
				minimap.draw_rect(Rect2(px, py, 5, 5), Color(0.5, 0.4, 0.3))
			else:
				minimap.draw_rect(Rect2(px, py, 5, 5), Color(0.2, 0.15, 0.1))
				
	var base_node = world.get_node_or_null("Base")
	if base_node:
		var base_cell = tile_map.local_to_map(tile_map.to_local(base_node.global_position))
		minimap.draw_rect(Rect2((base_cell.x + 20) * 5 - 2, (base_cell.y + 2) * 5 - 2, 9, 9), Color(0, 0.5, 1))

	var player = world.get_node_or_null("Player")
	if player and player.visible:
		var player_cell = tile_map.local_to_map(tile_map.to_local(player.global_position))
		minimap.draw_rect(Rect2((player_cell.x + 20) * 5, (player_cell.y + 2) * 5, 5, 5), Color(0, 1, 0))

	if minimap_shows_enemies:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy):
				var enemy_cell = tile_map.local_to_map(tile_map.to_local(enemy.global_position))
				minimap.draw_rect(Rect2((enemy_cell.x + 20) * 5, (enemy_cell.y + 2) * 5, 5, 5), Color(1, 0, 0))

func _get_player_node() -> Node:
	var world = get_parent()
	if world:
		return world.get_node_or_null("Player")
	return null

func _format_run_time() -> String:
	var elapsed = max(0, int((Time.get_ticks_msec() - run_started_msec) / 1000))
	var minutes = int(elapsed / 60)
	var seconds = elapsed % 60
	return "%02d:%02d" % [minutes, seconds]

func _get_player_hero_name() -> String:
	var player = _get_player_node()
	if player:
		var hero_name = player.get("current_hero_name")
		if typeof(hero_name) == TYPE_STRING and hero_name != "":
			return hero_name
	return "Hero"

func _get_player_stat(player: Node, stat_name: String, fallback: int = 0) -> int:
	if not player:
		return fallback
	var value = player.get(stat_name)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback

func _get_player_portrait_texture() -> Texture2D:
	var player = _get_player_node()
	if not player:
		return null
	var sprite = player.get_node_or_null("Sprite2D")
	if not sprite or not sprite.texture:
		return null
	var texture = sprite.texture
	var frame_w = texture.get_width() / 8.0
	var frame_h = texture.get_height() / 8.0
	if frame_w > 0.0 and frame_h > 0.0:
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(0, 0, frame_w, frame_h)
		return atlas
	return texture

func _create_game_over_stat_label(stat_name: String, stat_value: String) -> Label:
	var stat_label = Label.new()
	stat_label.text = "%s: %s" % [stat_name, stat_value]
	stat_label.add_theme_font_size_override("font_size", 18)
	stat_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.72, 1.0))
	return stat_label

func _add_game_over_stats(stats_box: VBoxContainer) -> void:
	var player = _get_player_node()
	stats_box.add_child(_create_game_over_stat_label("Time survived", _format_run_time()))
	stats_box.add_child(_create_game_over_stat_label("Wave reached", str(last_wave_reached)))
	stats_box.add_child(_create_game_over_stat_label("Gems collected", str(run_gems_collected)))
	stats_box.add_child(_create_game_over_stat_label("Gold earned", str(run_gold_collected)))
	stats_box.add_child(_create_game_over_stat_label("Gems left", str(total_gems)))
	stats_box.add_child(_create_game_over_stat_label("Gold left", str(total_gold)))
	if player:
		stats_box.add_child(_create_game_over_stat_label("Level", str(_get_player_stat(player, "level", 1))))
		stats_box.add_child(_create_game_over_stat_label("Stats", "%d STR / %d AGI / %d INT" % [
			_get_player_stat(player, "strength", 1),
			_get_player_stat(player, "agility", 1),
			_get_player_stat(player, "intelligence", 1)
		]))

func _create_game_over_overlay() -> void:
	if has_node("GameOverOverlay"):
		return
	if has_node("GameOverMenuButton"):
		get_node("GameOverMenuButton").queue_free()
	if respawn_label:
		respawn_label.visible = false
	
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_width = min(viewport_size.x * 0.78, 720.0)
	var panel_height = min(viewport_size.y * 0.82, 500.0)
	
	var overlay = Control.new()
	overlay.name = "GameOverOverlay"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	
	var dim = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.58)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	
	var panel = Panel.new()
	panel.name = "Panel"
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_theme_stylebox_override("panel", _make_texture_style(MENU_PANEL_TEXTURE))
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_bottom = panel_height * 0.5
	overlay.add_child(panel)
	
	var content = VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 72
	content.offset_top = 48
	content.offset_right = -72
	content.offset_bottom = -42
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	
	var title = Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.16, 0.1, 1.0))
	content.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Base Destroyed"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.9, 0.72, 1.0))
	content.add_child(subtitle)
	
	var body = HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(0, 220)
	body.add_theme_constant_override("separation", 28)
	content.add_child(body)
	
	var hero_box = VBoxContainer.new()
	hero_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_box.custom_minimum_size = Vector2(170, 0)
	hero_box.add_theme_constant_override("separation", 6)
	body.add_child(hero_box)
	
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(140, 150)
	portrait.texture = _get_player_portrait_texture()
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_box.add_child(portrait)
	
	var hero_name = Label.new()
	hero_name.text = _get_player_hero_name()
	hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_name.add_theme_font_size_override("font_size", 22)
	hero_name.add_theme_color_override("font_color", Color(1.0, 0.92, 0.74, 1.0))
	hero_box.add_child(hero_name)
	
	var stats_box = VBoxContainer.new()
	stats_box.custom_minimum_size = Vector2(330, 0)
	stats_box.add_theme_constant_override("separation", 4)
	body.add_child(stats_box)
	_add_game_over_stats(stats_box)
	
	var btn = Button.new()
	btn.name = "RetrySetupButton"
	btn.text = "Change Hero / Base & Retry"
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.custom_minimum_size = Vector2(420, 58)
	btn.add_theme_font_size_override("font_size", 26)
	_apply_menu_button_style(btn)
	btn.pressed.connect(_open_solo_retry_setup)
	content.add_child(btn)
	btn.call_deferred("grab_focus")

func _open_solo_retry_setup() -> void:
	if has_node("SoloRetrySetup"):
		return
	var world := get_parent()
	var player := world.get_node_or_null("Player") if world else null
	var base := world.get_node_or_null("Base") if world else null
	if player and base:
		player.global_position = base.global_position + Vector2(0, 32)
		player.velocity = Vector2.ZERO
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera:
			camera.reset_smoothing()
	var overlay_panel := get_node_or_null("GameOverOverlay/Panel") as Control
	if overlay_panel:
		overlay_panel.visible = false
	var selector = preload("res://hero_selection_menu.tscn").instantiate()
	selector.name = "SoloRetrySetup"
	selector.process_mode = Node.PROCESS_MODE_ALWAYS
	if selector.has_method("setup"):
		selector.setup(0, "solo_retry")
	add_child(selector)
	selector.tree_exited.connect(func():
		if not is_inside_tree():
			return
		if is_instance_valid(overlay_panel) and overlay_panel.is_inside_tree():
			overlay_panel.visible = true
			var retry_button := get_node_or_null("GameOverOverlay/Panel/Content/RetrySetupButton") as Button
			if retry_button and retry_button.is_inside_tree():
				retry_button.grab_focus()
	)

func _return_to_main_menu() -> void:
	get_tree().paused = false
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/menus/main/menu.tscn")

func on_game_over() -> void:
	var match_flow := get_node_or_null("/root/MatchFlow")
	if match_flow and match_flow.has_method("request_defeat"):
		match_flow.request_defeat(get_parent())
		return
	# Fallback for isolated HUD scene tests or projects without MatchFlow.
	_create_game_over_overlay()
	get_tree().paused = true
