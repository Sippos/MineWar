extends Control

const MENU_THEME = preload("res://assets/themes/global/global_theme.tres")
const HERO_ORDER := ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King", "Mech"]

var target_mode := "local_coop"
var available_heroes: Array[String] = []
var closing := false

@onready var panel: PanelContainer = $Dimmer/Center/Panel
@onready var vbox: VBoxContainer = $Dimmer/Center/Panel/VBox
@onready var title_label: Label = $Dimmer/Center/Panel/VBox/Title
@onready var selectors: HBoxContainer = $Dimmer/Center/Panel/VBox/Selectors
@onready var p1_column: VBoxContainer = $Dimmer/Center/Panel/VBox/Selectors/P1Column
@onready var p2_column: VBoxContainer = $Dimmer/Center/Panel/VBox/Selectors/P2Column
@onready var p1_label: Label = $Dimmer/Center/Panel/VBox/Selectors/P1Column/P1Label
@onready var p2_label: Label = $Dimmer/Center/Panel/VBox/Selectors/P2Column/P2Label
@onready var p1_option: OptionButton = $Dimmer/Center/Panel/VBox/Selectors/P1Column/P1Option
@onready var p2_option: OptionButton = $Dimmer/Center/Panel/VBox/Selectors/P2Column/P2Option
@onready var start_button: Button = $Dimmer/Center/Panel/VBox/Footer/StartButton
@onready var back_button: Button = $Dimmer/Center/Panel/VBox/Footer/BackButton

func setup(mode_name: String) -> void:
	target_mode = mode_name

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	theme = MENU_THEME
	available_heroes = _get_available_heroes()
	for hero_name in available_heroes:
		p1_option.add_item(hero_name)
		p2_option.add_item(hero_name)
	var p1_index := available_heroes.find(Global.hero_p1)
	var p2_index := available_heroes.find(Global.hero_p2)
	p1_option.select(maxi(p1_index, 0))
	p2_option.select(maxi(p2_index, 0))
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_configure_mode()
	_configure_focus()
	get_tree().root.size_changed.connect(_layout_for_screen)
	_layout_for_screen()
	p1_option.call_deferred("grab_focus")

func _get_available_heroes() -> Array[String]:
	var result: Array[String] = []
	for hero_name in HERO_ORDER:
		if Global.is_hero_unlocked(hero_name):
			result.append(hero_name)
	if result.is_empty():
		result.append("Dwarf")
	return result

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

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

func _layout_for_screen() -> void:
	if panel == null:
		return
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var compact := size.x < 760.0 or size.y < 520.0
	panel.custom_minimum_size = Vector2(
		minf(720.0, maxf(360.0, size.x - 24.0)),
		minf(410.0, maxf(300.0, size.y - 24.0))
	)
	vbox.add_theme_constant_override("separation", 7 if compact else 14)
	title_label.custom_minimum_size.y = 36.0 if compact else 52.0
	title_label.add_theme_font_size_override("font_size", 22 if compact else 28)
	selectors.add_theme_constant_override("separation", 10 if compact else 28)
	selectors.custom_minimum_size.y = 104.0 if compact else 130.0
	var available_width := minf(600.0, maxf(300.0, size.x - 110.0))
	var column_width := maxf(140.0, (available_width - float(selectors.get_theme_constant("separation"))) * 0.5)
	p1_column.custom_minimum_size.x = column_width
	p2_column.custom_minimum_size.x = column_width
	p1_option.custom_minimum_size = Vector2(column_width, 44.0 if compact else 58.0)
	p2_option.custom_minimum_size = Vector2(column_width, 44.0 if compact else 58.0)
	p1_label.add_theme_font_size_override("font_size", 14 if compact else 18)
	p2_label.add_theme_font_size_override("font_size", 14 if compact else 18)
	back_button.custom_minimum_size = Vector2(180.0 if compact else 220.0, 44.0 if compact else 54.0)
	start_button.custom_minimum_size = back_button.custom_minimum_size

func _on_start_pressed() -> void:
	if available_heroes.is_empty():
		return
	Global.hero_p1 = available_heroes[p1_option.selected]
	Global.hero_p2 = available_heroes[p2_option.selected]
	Global.current_hero = Global.hero_p1
	get_tree().paused = false
	if target_mode == "maze_vs":
		GameMode.set_mode(GameMode.Mode.LINE_WARS)
		get_tree().change_scene_to_file("res://scenes/world/preparation/linewars_vs_mirror.tscn")
	else:
		GameMode.set_mode(GameMode.Mode.EXPLORATION)
		get_tree().change_scene_to_file("res://local_coop_mode.tscn")

func _on_back_pressed() -> void:
	if closing:
		return
	closing = true
	# Keep the clicked controls alive through mouse release so it cannot activate the parent menu.
	get_tree().create_timer(0.12, true).timeout.connect(queue_free)
