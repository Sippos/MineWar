extends Control

enum Mode { SINGLE_PLAYER, VS_LOCAL, VS_ONLINE }
var current_mode = Mode.SINGLE_PLAYER

var p1_index = 0
var p2_index = 0

# Keep unlock progression in Global for later, but expose every implemented hero
# in the selection carousel while the project is in playtest mode.
var available_heroes = ["Dwarf", "Shaman", "Nerubian", "Mech"]
const PLAYTEST_ALL_HEROES := true

@onready var panel = $Panel
@onready var root_vbox = $Panel/VBox
@onready var hero_hbox = $Panel/VBox/HBox
@onready var title_label = $Panel/VBox/Label
@onready var p1_container = $Panel/VBox/HBox/P1Container
@onready var p1_label = $Panel/VBox/HBox/P1Container/HeroName
@onready var p1_sprite_container = $Panel/VBox/HBox/P1Container/SpriteContainer
@onready var p1_sprite = $Panel/VBox/HBox/P1Container/SpriteContainer/Sprite
@onready var p1_prev = $Panel/VBox/HBox/P1Container/HBox/PrevBtn
@onready var p1_next = $Panel/VBox/HBox/P1Container/HBox/NextBtn

@onready var p2_container = $Panel/VBox/HBox/P2Container
@onready var p2_label = $Panel/VBox/HBox/P2Container/HeroName
@onready var p2_sprite_container = $Panel/VBox/HBox/P2Container/SpriteContainer
@onready var p2_sprite = $Panel/VBox/HBox/P2Container/SpriteContainer/Sprite
@onready var p2_prev = $Panel/VBox/HBox/P2Container/HBox/PrevBtn
@onready var p2_next = $Panel/VBox/HBox/P2Container/HBox/NextBtn

@onready var start_btn = $Panel/VBox/StartBtn
@onready var back_btn = $Panel/VBox/BackBtn

func setup(mode: int) -> void:
	current_mode = mode

func _ready() -> void:
	p1_prev.pressed.connect(func(): change_hero(1, -1))
	p1_next.pressed.connect(func(): change_hero(1, 1))
	p2_prev.pressed.connect(func(): change_hero(2, -1))
	p2_next.pressed.connect(func(): change_hero(2, 1))
	
	start_btn.pressed.connect(_on_start_pressed)
	back_btn.pressed.connect(func(): queue_free())
	
	p2_container.visible = (current_mode == Mode.VS_LOCAL)
	get_tree().root.size_changed.connect(_layout_for_screen)
	_layout_for_screen()
	
	update_ui(1)
	if current_mode == Mode.VS_LOCAL:
		update_ui(2)
		
	start_btn.grab_focus()

func _layout_for_screen() -> void:
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var compact = screen_size.x < 700.0 or screen_size.y < 520.0
	var panel_w = clamp(screen_size.x * 0.9, 300.0, 620.0)
	var panel_h = clamp(screen_size.y * 0.86, 300.0, 430.0)
	panel.offset_left = -panel_w * 0.5
	panel.offset_right = panel_w * 0.5
	panel.offset_top = -panel_h * 0.5
	panel.offset_bottom = panel_h * 0.5
	root_vbox.add_theme_constant_override("separation", 8 if compact else 18)
	hero_hbox.add_theme_constant_override("separation", 12 if compact else 40)
	title_label.add_theme_font_size_override("font_size", 24 if compact else 32)
	
	var sprite_size = 84.0 if compact else 128.0
	_configure_sprite_container(p1_sprite_container, p1_sprite, sprite_size)
	_configure_sprite_container(p2_sprite_container, p2_sprite, sprite_size)
	var button_size = Vector2(180, 42) if compact else Vector2(200, 50)
	start_btn.custom_minimum_size = button_size
	back_btn.custom_minimum_size = button_size

func _configure_sprite_container(container: Control, sprite: Sprite2D, sprite_size: float) -> void:
	container.custom_minimum_size = Vector2(sprite_size, sprite_size)
	sprite.position = Vector2(sprite_size * 0.5, sprite_size * 0.5)
	var scale_factor = sprite_size / 128.0
	sprite.scale = Vector2(scale_factor, scale_factor)

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
	var tex = load(Global.hero_data[h_name].walk)
	
	if player_id == 1:
		p1_label.text = h_name if is_unlocked else (h_name + " (Locked)")
		p1_sprite.texture = tex
		p1_sprite.modulate = Color(1,1,1,1) if is_unlocked else Color(0,0,0,1)
	else:
		p2_label.text = h_name if is_unlocked else (h_name + " (Locked)")
		p2_sprite.texture = tex
		p2_sprite.modulate = Color(1,1,1,1) if is_unlocked else Color(0,0,0,1)
		
	check_start_btn()

func check_start_btn() -> void:
	var h1 = available_heroes[p1_index]
	start_btn.disabled = not _is_hero_playable(h1)

func _on_start_pressed() -> void:
	Global.hero_p1 = available_heroes[p1_index]
	Global.current_hero = Global.hero_p1
	if current_mode == Mode.VS_LOCAL:
		Global.hero_p2 = available_heroes[p2_index]
	else:
		Global.hero_p2 = Global.hero_p1
		
	if current_mode == Mode.SINGLE_PLAYER:
		get_tree().change_scene_to_file("res://main.tscn")
	elif current_mode == Mode.VS_LOCAL:
		get_tree().change_scene_to_file("res://vs_mode.tscn")
	elif current_mode == Mode.VS_ONLINE:
		get_tree().change_scene_to_file("res://online_lobby.tscn")