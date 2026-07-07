extends Control

enum Mode { SINGLE_PLAYER, VS_LOCAL, VS_ONLINE }
var current_mode = Mode.SINGLE_PLAYER

var p1_index = 0
var p2_index = 0

var available_heroes = ["Dwarf", "Shaman"]

@onready var p1_label = $Panel/VBox/HBox/P1Container/HeroName
@onready var p1_sprite = $Panel/VBox/HBox/P1Container/SpriteContainer/Sprite
@onready var p1_prev = $Panel/VBox/HBox/P1Container/HBox/PrevBtn
@onready var p1_next = $Panel/VBox/HBox/P1Container/HBox/NextBtn

@onready var p2_container = $Panel/VBox/HBox/P2Container
@onready var p2_label = $Panel/VBox/HBox/P2Container/HeroName
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
	
	update_ui(1)
	if current_mode == Mode.VS_LOCAL:
		update_ui(2)
		
	start_btn.grab_focus()

func change_hero(player_id: int, dir: int) -> void:
	if player_id == 1:
		p1_index = (p1_index + dir + available_heroes.size()) % available_heroes.size()
		update_ui(1)
	else:
		p2_index = (p2_index + dir + available_heroes.size()) % available_heroes.size()
		update_ui(2)

func update_ui(player_id: int) -> void:
	var h_name = available_heroes[p1_index] if player_id == 1 else available_heroes[p2_index]
	var is_unlocked = true
	
	if current_mode == Mode.SINGLE_PLAYER and not Global.unlocked_heroes.has(h_name):
		is_unlocked = false
		
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
	var h1_ok = true
	if current_mode == Mode.SINGLE_PLAYER and not Global.unlocked_heroes.has(h1):
		h1_ok = false
		
	start_btn.disabled = not h1_ok

func _on_start_pressed() -> void:
	Global.hero_p1 = available_heroes[p1_index]
	Global.current_hero = Global.hero_p1
	if current_mode == Mode.VS_LOCAL:
		Global.hero_p2 = available_heroes[p2_index]
	else:
		Global.hero_p2 = Global.hero_p1 # default sync
		
	if current_mode == Mode.SINGLE_PLAYER:
		get_tree().change_scene_to_file("res://main.tscn")
	elif current_mode == Mode.VS_LOCAL:
		get_tree().change_scene_to_file("res://vs_mode.tscn")
	elif current_mode == Mode.VS_ONLINE:
		get_tree().change_scene_to_file("res://online_lobby.tscn")
