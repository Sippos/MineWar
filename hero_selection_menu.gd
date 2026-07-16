extends Control

enum Mode { SINGLE_PLAYER, VS_LOCAL, VS_ONLINE }
var current_mode: Mode = Mode.SINGLE_PLAYER
var current_context := "menu"

var p1_index = 0
var p2_index = 0

# Keep unlock progression in Global for later, but expose every implemented hero
# in the selection carousel while the project is in playtest mode.
var available_heroes = ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King"]
const PLAYTEST_ALL_HEROES := true
const HERO_IDLE_PREVIEWS = {
	"Dwarf": preload("res://character_sprites/hero_idle/dwarf_idle_front.png"),
	"Mech": preload("res://character_sprites/hero_idle/mech_idle_front.png"),
	"Shaman": preload("res://character_sprites/hero_idle/shaman_idle_front.png"),
	"Nerubian": preload("res://character_sprites/hero_idle/nerubian_idle_front.png"),
	"Druid": preload("res://character_sprites/hero_idle/druid_idle_front.png"),
	"Undead King": preload("res://character_sprites/hero_idle/undead_king_idle_front.png")
}
const HERO_PREVIEW_VISUALS = {
	"Dwarf": {"scale": 2.20, "center": Vector2(65.5, 76.5)},
	"Shaman": {"scale": 1.75, "center": Vector2(62.5, 56.0)},
	"Nerubian": {"scale": 1.02, "center": Vector2(70.0, 87.0)},
	"Druid": {"scale": 1.45, "center": Vector2(72.5, 53.0)},
	"Undead King": {"scale": 1.20, "center": Vector2(53.5, 95.5)}
}
const HERO_ABILITY_PREVIEWS = {
	"Dwarf": [
		{"icon": preload("res://ability_icons/placeholder_stomp.svg"), "title": "Ground Stomp", "description": "Area damage and stun"},
		{"icon": preload("res://ability_icons/placeholder_hammer.svg"), "title": "Throwing Hammer", "description": "Ranged stun; breaks blocks"},
		{"icon": preload("res://ability_icons/placeholder_bash.svg"), "title": "Dwarven Bash", "description": "Every third hit is empowered"},
		{"icon": preload("res://ability_icons/placeholder_avatar.svg"), "title": "Avatar", "description": "Level 6 combat form"}
	],
	"Shaman": [
		{"icon": preload("res://ability_icons/placeholder_totem.svg"), "title": "Totem Wheel", "description": "Dig, heal, radar or gem"},
		{"icon": preload("res://ability_icons/placeholder_chain.svg"), "title": "Chain Lightning", "description": "Jumps between enemies"},
		{"icon": preload("res://ability_icons/placeholder_wisdom.svg"), "title": "Ancestral Wisdom", "description": "Stronger totems and Int"},
		{"icon": preload("res://ability_icons/placeholder_ascendance.svg"), "title": "Ascendance", "description": "Level 6 all-totem form"}
	],
	"Nerubian": [
		{"icon": preload("res://ability_icons/placeholder_brood.svg"), "title": "Spawn Brood", "description": "Summon mining spiders"},
		{"icon": preload("res://ability_icons/placeholder_web.svg"), "title": "Web Burst", "description": "Damage, root and slow"},
		{"icon": preload("res://ability_icons/placeholder_carapace.svg"), "title": "Chitinous Carapace", "description": "Health and regeneration"},
		{"icon": preload("res://ability_icons/placeholder_broodmother.svg"), "title": "Broodmother", "description": "Level 6 full brood"}
	],
	"Druid": [
		{"sheet": preload("res://character_sprites/druid_mole_crawl_spritesheet_25d.png"), "title": "Mole Form", "description": "Alternate digging form"},
		{"icon": preload("res://ability_icons/placeholder_wisdom.svg"), "title": "Ability kit", "description": "More abilities coming soon"}
	],
	"Undead King": [
		{"sheet": preload("res://character_sprites/undead_king_staff_cast_spritesheet_25d.png"), "title": "Staff Cast", "description": "Dark spell attack art"},
		{"icon": preload("res://ability_icons/placeholder_ascendance.svg"), "title": "Ability kit", "description": "More abilities coming soon"}
	]
}

@onready var panel = $Panel
@onready var root_vbox = $Panel/VBox
@onready var hero_hbox = $Panel/VBox/HBox
@onready var title_label = $Panel/VBox/Label
@onready var footer = $Panel/VBox/Footer
@onready var p1_container = $Panel/VBox/HBox/P1Container
@onready var p1_player_caption = $Panel/VBox/HBox/P1Container/Label
@onready var p1_label = $Panel/VBox/HBox/P1Container/HeroPreviewRow/PortraitColumn/HeroName
@onready var p1_portrait_panel = $Panel/VBox/HBox/P1Container/HeroPreviewRow/PortraitColumn/PortraitPanel
@onready var p1_sprite_container = $Panel/VBox/HBox/P1Container/HeroPreviewRow/PortraitColumn/PortraitPanel/SpriteContainer
@onready var p1_sprite = $Panel/VBox/HBox/P1Container/HeroPreviewRow/PortraitColumn/PortraitPanel/SpriteContainer/Sprite
@onready var p1_ability_spacer = $Panel/VBox/HBox/P1Container/HeroPreviewRow/AbilitySpacer
@onready var p1_ability_panel = $Panel/VBox/HBox/P1Container/HeroPreviewRow/AbilityPanel
@onready var p1_ability_list = $Panel/VBox/HBox/P1Container/HeroPreviewRow/AbilityPanel/AbilityList
@onready var p1_nav = $Panel/VBox/HBox/P1Container/HBox
@onready var p1_prev = $Panel/VBox/HBox/P1Container/HBox/PrevBtn
@onready var p1_next = $Panel/VBox/HBox/P1Container/HBox/NextBtn

@onready var p2_container = $Panel/VBox/HBox/P2Container
@onready var p2_player_caption = $Panel/VBox/HBox/P2Container/Label
@onready var p2_label = $Panel/VBox/HBox/P2Container/HeroPreviewRow/PortraitColumn/HeroName
@onready var p2_portrait_panel = $Panel/VBox/HBox/P2Container/HeroPreviewRow/PortraitColumn/PortraitPanel
@onready var p2_sprite_container = $Panel/VBox/HBox/P2Container/HeroPreviewRow/PortraitColumn/PortraitPanel/SpriteContainer
@onready var p2_sprite = $Panel/VBox/HBox/P2Container/HeroPreviewRow/PortraitColumn/PortraitPanel/SpriteContainer/Sprite
@onready var p2_ability_spacer = $Panel/VBox/HBox/P2Container/HeroPreviewRow/AbilitySpacer
@onready var p2_ability_panel = $Panel/VBox/HBox/P2Container/HeroPreviewRow/AbilityPanel
@onready var p2_ability_list = $Panel/VBox/HBox/P2Container/HeroPreviewRow/AbilityPanel/AbilityList
@onready var p2_nav = $Panel/VBox/HBox/P2Container/HBox
@onready var p2_prev = $Panel/VBox/HBox/P2Container/HBox/PrevBtn
@onready var p2_next = $Panel/VBox/HBox/P2Container/HBox/NextBtn

@onready var back_btn = $Panel/VBox/Footer/BackBtn
@onready var start_btn = $Panel/VBox/Footer/StartBtn

var compact_layout = false
var minimal_layout = false
var ability_icon_cache = {}

func setup(mode: int, context: String = "menu") -> void:
	current_mode = mode as Mode
	current_context = context
	var selected_index := available_heroes.find(Global.hero_p1)
	if selected_index >= 0:
		p1_index = selected_index

func _ready() -> void:
	p1_prev.pressed.connect(func(): change_hero(1, -1))
	p1_next.pressed.connect(func(): change_hero(1, 1))
	p2_prev.pressed.connect(func(): change_hero(2, -1))
	p2_next.pressed.connect(func(): change_hero(2, 1))
	
	start_btn.pressed.connect(_on_start_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	
	p2_container.visible = (current_mode == Mode.VS_LOCAL)
	_configure_ability_panels()
	get_tree().root.size_changed.connect(_layout_for_screen)
	_layout_for_screen()
	
	update_ui(1)
	if current_mode == Mode.VS_LOCAL:
		update_ui(2)
	_apply_context_labels()
	_configure_focus_navigation()
	start_btn.grab_focus()

func _apply_context_labels() -> void:
	if current_mode == Mode.SINGLE_PLAYER:
		title_label.text = "Choose Hero & Matching Base" if current_context == "solo_retry" else "Select Hero & Matching Base"
		p1_player_caption.text = "HERO"
	else:
		title_label.text = "Select Heroes"
		p1_player_caption.text = "PLAYER 1"
	p2_player_caption.text = "PLAYER 2"
	start_btn.text = "Retry from Surface" if current_context == "solo_retry" else "Start"
	back_btn.text = "Back"
	p1_prev.text = "◀  Previous"
	p1_next.text = "Next  ▶"
	p2_prev.text = "◀  Previous"
	p2_next.text = "Next  ▶"

func _on_back_pressed() -> void:
	queue_free()

func _configure_ability_panels() -> void:
	for ability_panel_value in [p1_ability_panel, p2_ability_panel]:
		var ability_panel := ability_panel_value as PanelContainer
		var source_style: StyleBox = ability_panel.get_theme_stylebox("panel")
		if source_style == null:
			continue
		var panel_style: StyleBox = source_style.duplicate() as StyleBox
		panel_style.content_margin_left = 18.0
		panel_style.content_margin_right = 18.0
		panel_style.content_margin_top = 10.0
		panel_style.content_margin_bottom = 10.0
		ability_panel.add_theme_stylebox_override("panel", panel_style)

func _configure_focus_navigation() -> void:
	p1_prev.focus_neighbor_right = p1_next.get_path()
	p1_next.focus_neighbor_left = p1_prev.get_path()
	p1_prev.focus_neighbor_bottom = back_btn.get_path()
	p1_next.focus_neighbor_bottom = start_btn.get_path()
	p2_prev.focus_neighbor_right = p2_next.get_path()
	p2_next.focus_neighbor_left = p2_prev.get_path()
	p2_prev.focus_neighbor_bottom = back_btn.get_path()
	p2_next.focus_neighbor_bottom = start_btn.get_path()
	back_btn.focus_neighbor_right = start_btn.get_path()
	start_btn.focus_neighbor_left = back_btn.get_path()
	back_btn.focus_neighbor_top = p1_prev.get_path()
	start_btn.focus_neighbor_top = p1_next.get_path()

func _layout_for_screen(forced_size: Vector2 = Vector2.ZERO) -> void:
	var screen_size = forced_size if forced_size != Vector2.ZERO else get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	minimal_layout = screen_size.x < 540.0
	compact_layout = minimal_layout or screen_size.x < (980.0 if current_mode == Mode.VS_LOCAL else 680.0) or screen_size.y < 560.0
	var max_panel_width = 1120.0 if current_mode == Mode.VS_LOCAL else 820.0
	var panel_w = max(300.0, min(screen_size.x * 0.94, max_panel_width))
	var panel_h = max(350.0, min(screen_size.y * 0.90, 520.0))
	panel.offset_left = -panel_w * 0.5
	panel.offset_right = panel_w * 0.5
	panel.offset_top = -panel_h * 0.5
	panel.offset_bottom = panel_h * 0.5

	var horizontal_inset = 40.0 if compact_layout else 86.0
	var top_inset = 14.0 if minimal_layout else (18.0 if compact_layout else 24.0)
	var bottom_inset = 32.0 if minimal_layout else (22.0 if compact_layout else 32.0)
	root_vbox.offset_left = horizontal_inset
	root_vbox.offset_top = top_inset
	root_vbox.offset_right = -horizontal_inset
	root_vbox.offset_bottom = -bottom_inset
	root_vbox.add_theme_constant_override("separation", 5 if minimal_layout else (8 if compact_layout else 12))
	hero_hbox.add_theme_constant_override("separation", 6 if minimal_layout else (12 if compact_layout else 24))
	title_label.add_theme_font_size_override("font_size", 20 if minimal_layout else (24 if compact_layout else 28))
	title_label.custom_minimum_size.y = 28.0 if minimal_layout else (34.0 if compact_layout else 40.0)
	p1_player_caption.add_theme_font_size_override("font_size", 10 if minimal_layout else (12 if compact_layout else 14))
	p2_player_caption.add_theme_font_size_override("font_size", 10 if minimal_layout else (12 if compact_layout else 14))
	p1_label.add_theme_font_size_override("font_size", 14 if minimal_layout else (16 if compact_layout else 18))
	p2_label.add_theme_font_size_override("font_size", 14 if minimal_layout else (16 if compact_layout else 18))

	var sprite_size = 92.0 if minimal_layout else (112.0 if compact_layout else 150.0)
	var ability_panel_width = 150.0 if minimal_layout else (230.0 if compact_layout else 320.0)
	var ability_panel_height = 108.0 if minimal_layout else (142.0 if compact_layout else 178.0)
	var ability_gap = 12.0 if minimal_layout else (16.0 if compact_layout else 24.0)
	_configure_sprite_container(p1_portrait_panel, p1_sprite_container, p1_sprite, sprite_size)
	_configure_sprite_container(p2_portrait_panel, p2_sprite_container, p2_sprite, sprite_size)
	p1_ability_spacer.custom_minimum_size = Vector2(ability_gap, 1.0)
	p2_ability_spacer.custom_minimum_size = Vector2(ability_gap, 1.0)
	p1_ability_panel.custom_minimum_size = Vector2(ability_panel_width, ability_panel_height)
	p2_ability_panel.custom_minimum_size = Vector2(ability_panel_width, ability_panel_height)
	p1_ability_list.custom_minimum_size = Vector2(max(90.0, ability_panel_width - 36.0), max(84.0, ability_panel_height - 20.0))
	p2_ability_list.custom_minimum_size = Vector2(max(90.0, ability_panel_width - 36.0), max(84.0, ability_panel_height - 20.0))
	_rebuild_ability_preview(p1_ability_list, available_heroes[p1_index])
	_rebuild_ability_preview(p2_ability_list, available_heroes[p2_index])

	var nav_button_size = Vector2(126, 44) if minimal_layout else (Vector2(150, 46) if compact_layout else Vector2(170, 48))
	for button in [p1_prev, p1_next, p2_prev, p2_next]:
		button.custom_minimum_size = nav_button_size
	p1_nav.add_theme_constant_override("separation", 8 if minimal_layout else 12)
	p2_nav.add_theme_constant_override("separation", 8 if minimal_layout else 12)
	var action_button_size = Vector2(132, 44) if minimal_layout else (Vector2(160, 46) if compact_layout else Vector2(190, 50))
	start_btn.custom_minimum_size = action_button_size
	back_btn.custom_minimum_size = action_button_size
	footer.add_theme_constant_override("separation", 12 if minimal_layout else (16 if compact_layout else 20))

func _configure_sprite_container(portrait_panel: Control, container: Control, sprite: Sprite2D, sprite_size: float) -> void:
	portrait_panel.custom_minimum_size = Vector2(sprite_size + 8.0, sprite_size + 8.0)
	container.custom_minimum_size = Vector2(sprite_size, sprite_size)
	var hero_name = available_heroes[p1_index] if sprite == p1_sprite else available_heroes[p2_index]
	_apply_preview_visuals(sprite, hero_name, sprite_size)

func _apply_preview_visuals(sprite: Sprite2D, _hero_name: String, sprite_size: float) -> void:
	var scale_factor = sprite_size / 128.0
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.position = Vector2(sprite_size * 0.5, sprite_size * 0.5)

func _rebuild_ability_preview(container: VBoxContainer, hero_name: String) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	container.add_theme_constant_override("separation", 4 if minimal_layout else (7 if compact_layout else 10))
	var definitions: Array = HERO_ABILITY_PREVIEWS.get(hero_name, [])
	var icon_size = 18.0 if minimal_layout else (24.0 if compact_layout else 30.0)
	var title_size = 8 if minimal_layout else (10 if compact_layout else 12)
	var description_size = 8 if compact_layout else 9
	for definition in definitions:
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0.0, icon_size)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 4 if compact_layout else 6)
		container.add_child(row)
		
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.texture = _get_ability_preview_icon(definition)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		
		var text_box = VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_theme_constant_override("separation", 0)
		row.add_child(text_box)
		
		var title = Label.new()
		title.text = str(definition.get("title", "Ability"))
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.add_theme_font_size_override("font_size", title_size)
		title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58))
		text_box.add_child(title)
		
		if not minimal_layout:
			var description = Label.new()
			description.text = str(definition.get("description", ""))
			description.clip_text = true
			description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			description.add_theme_font_size_override("font_size", description_size)
			description.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
			text_box.add_child(description)

func _get_ability_preview_icon(definition: Dictionary) -> Texture2D:
	var source = definition.get("sheet", definition.get("icon", null))
	var cache_key = str(source)
	if ability_icon_cache.has(cache_key):
		return ability_icon_cache[cache_key]
	var texture: Texture2D = null
	if definition.has("sheet"):
		var sheet = definition["sheet"] as Texture2D
		if sheet:
			var atlas = AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(0.0, 0.0, 128.0, 128.0)
			texture = atlas
	elif definition.has("icon"):
		texture = definition["icon"] as Texture2D
	ability_icon_cache[cache_key] = texture
	return texture

func change_hero(player_id: int, dir: int) -> void:
	if player_id == 1:
		p1_index = (p1_index + dir + available_heroes.size()) % available_heroes.size()
		update_ui(1)
	else:
		p2_index = (p2_index + dir + available_heroes.size()) % available_heroes.size()
		update_ui(2)

func _is_hero_playable(hero_name: String) -> bool:
	if PLAYTEST_ALL_HEROES:
		return Global.hero_data.has(hero_name)
	if current_mode == Mode.SINGLE_PLAYER:
		return Global.is_hero_playable_in_single_player(hero_name)
	return true

func update_ui(player_id: int) -> void:
	var h_name = available_heroes[p1_index] if player_id == 1 else available_heroes[p2_index]
	var is_unlocked = _is_hero_playable(h_name)
	var tex = HERO_IDLE_PREVIEWS.get(h_name, Global.hero_data[h_name]["walk"]) as Texture2D
	
	if player_id == 1:
		p1_label.text = h_name if is_unlocked else (h_name + " (Locked)")
		p1_sprite.texture = tex
		p1_sprite.hframes = 1
		p1_sprite.vframes = 1
		p1_sprite.frame = 0
		p1_sprite.flip_h = false
		_apply_preview_visuals(p1_sprite, h_name, p1_sprite_container.custom_minimum_size.x)
		_rebuild_ability_preview(p1_ability_list, h_name)
		p1_sprite.modulate = Color(1,1,1,1) if is_unlocked else Color(0,0,0,1)
	else:
		p2_label.text = h_name if is_unlocked else (h_name + " (Locked)")
		p2_sprite.texture = tex
		p2_sprite.hframes = 1
		p2_sprite.vframes = 1
		p2_sprite.frame = 0
		p2_sprite.flip_h = false
		_apply_preview_visuals(p2_sprite, h_name, p2_sprite_container.custom_minimum_size.x)
		_rebuild_ability_preview(p2_ability_list, h_name)
		p2_sprite.modulate = Color(1,1,1,1) if is_unlocked else Color(0,0,0,1)
		
	check_start_btn()

func check_start_btn() -> void:
	var h1 = available_heroes[p1_index]
	start_btn.disabled = not _is_hero_playable(h1)

func _on_start_pressed() -> void:
	get_tree().paused = false
	Global.hero_p1 = available_heroes[p1_index]
	Global.current_hero = Global.hero_p1
	if current_mode == Mode.VS_LOCAL:
		Global.hero_p2 = available_heroes[p2_index]
	else:
		Global.hero_p2 = Global.hero_p1
		
	if current_mode == Mode.SINGLE_PLAYER:
		Global.set_run_loadout(available_heroes[p1_index], Global.selected_base_id)
		get_tree().change_scene_to_file("res://scenes/boot/main.tscn")
	elif current_mode == Mode.VS_LOCAL:
		get_tree().change_scene_to_file("res://vs_mode.tscn")
	elif current_mode == Mode.VS_ONLINE:
		get_tree().change_scene_to_file("res://online_lobby.tscn")
