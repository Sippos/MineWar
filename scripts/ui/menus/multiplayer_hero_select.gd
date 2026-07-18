extends Control

const MENU_THEME = preload("res://assets/themes/global/global_theme.tres")
const HEROES := ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King"]

var target_mode := "local_coop"

@onready var title_label: Label = $Dimmer/Center/Panel/VBox/Title
@onready var p1_option: OptionButton = $Dimmer/Center/Panel/VBox/Selectors/P1Column/P1Option
@onready var p2_option: OptionButton = $Dimmer/Center/Panel/VBox/Selectors/P2Column/P2Option
@onready var start_button: Button = $Dimmer/Center/Panel/VBox/Footer/StartButton
@onready var back_button: Button = $Dimmer/Center/Panel/VBox/Footer/BackButton

func setup(mode_name: String) -> void:
	target_mode = mode_name

func _ready() -> void:
	theme = MENU_THEME
	for hero_name in HEROES:
		p1_option.add_item(hero_name)
		p2_option.add_item(hero_name)
	var p1_index := HEROES.find(Global.hero_p1)
	var p2_index := HEROES.find(Global.hero_p2)
	p1_option.select(maxi(p1_index, 0))
	p2_option.select(maxi(p2_index, 1 if HEROES.size() > 1 else 0))
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(queue_free)
	_configure_mode()
	_configure_focus()
	p1_option.grab_focus()

func _configure_mode() -> void:
	if target_mode == "maze_vs":
		title_label.text = "CHOOSE MAZE DUEL HEROES"
		start_button.text = "Build Mazes"
	else:
		title_label.text = "CHOOSE CO-OP HEROES"
		start_button.text = "Enter Shared Mine"

func _configure_focus() -> void:
	p1_option.focus_neighbor_right = p2_option.get_path()
	p2_option.focus_neighbor_left = p1_option.get_path()
	p1_option.focus_neighbor_bottom = back_button.get_path()
	p2_option.focus_neighbor_bottom = start_button.get_path()
	back_button.focus_neighbor_top = p1_option.get_path()
	start_button.focus_neighbor_top = p2_option.get_path()
	back_button.focus_neighbor_right = start_button.get_path()
	start_button.focus_neighbor_left = back_button.get_path()

func _on_start_pressed() -> void:
	Global.hero_p1 = HEROES[p1_option.selected]
	Global.hero_p2 = HEROES[p2_option.selected]
	Global.current_hero = Global.hero_p1
	get_tree().paused = false
	if target_mode == "maze_vs":
		GameMode.set_mode(GameMode.Mode.LINE_WARS)
		get_tree().change_scene_to_file("res://scenes/world/preparation/linewars_vs_mirror.tscn")
	else:
		GameMode.set_mode(GameMode.Mode.EXPLORATION)
		get_tree().change_scene_to_file("res://local_coop_mode.tscn")
