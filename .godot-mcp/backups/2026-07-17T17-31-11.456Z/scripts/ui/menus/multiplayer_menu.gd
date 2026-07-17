extends Control

const MENU_THEME = preload("res://assets/themes/global/global_theme.tres")
const HERO_SELECTION = preload("res://hero_selection_menu.tscn")

var online_mode := false

@onready var title_label: Label = $Dimmer/Center/Panel/VBox/Title
@onready var description_label: Label = $Dimmer/Center/Panel/VBox/Description
@onready var coop_button: Button = $Dimmer/Center/Panel/VBox/CoopButton
@onready var maze_button: Button = $Dimmer/Center/Panel/VBox/MazeButton
@onready var legacy_online_button: Button = $Dimmer/Center/Panel/VBox/LegacyOnlineButton
@onready var back_button: Button = $Dimmer/Center/Panel/VBox/BackButton

func setup(use_online_mode: bool) -> void:
	online_mode = use_online_mode

func _ready() -> void:
	theme = MENU_THEME
	coop_button.pressed.connect(_on_coop_pressed)
	maze_button.pressed.connect(_on_maze_pressed)
	legacy_online_button.pressed.connect(_on_legacy_online_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_configure_mode()
	_configure_focus()
	coop_button.grab_focus()

func _configure_mode() -> void:
	if online_mode:
		title_label.text = "ONLINE MULTIPLAYER"
		description_label.text = "Choose a network mode. The current WebRTC build supports Exploration VS; co-op and maze networking remain visible as the next integration targets."
		coop_button.text = "Co-op Exploration — Coming Soon"
		coop_button.disabled = true
		maze_button.text = "Maze Builder VS — Coming Soon"
		maze_button.disabled = true
		legacy_online_button.visible = true
		legacy_online_button.text = "Exploration VS — Play Online"
	else:
		title_label.text = "LOCAL MULTIPLAYER"
		description_label.text = "Explore one mine together or compete by constructing longer enemy routes."
		coop_button.text = "Co-op Exploration"
		coop_button.disabled = false
		maze_button.text = "Maze Builder VS"
		maze_button.disabled = false
		legacy_online_button.visible = false

func _configure_focus() -> void:
	if online_mode:
		legacy_online_button.focus_neighbor_bottom = back_button.get_path()
		back_button.focus_neighbor_top = legacy_online_button.get_path()
	else:
		coop_button.focus_neighbor_bottom = maze_button.get_path()
		maze_button.focus_neighbor_top = coop_button.get_path()
		maze_button.focus_neighbor_bottom = back_button.get_path()
		back_button.focus_neighbor_top = maze_button.get_path()

func _open_hero_selection(context: String, selection_mode: int) -> void:
	var selector = HERO_SELECTION.instantiate()
	selector.setup(selection_mode, context)
	add_child(selector)
	selector.tree_exited.connect(func():
		if is_instance_valid(self):
			coop_button.grab_focus()
	)

func _on_coop_pressed() -> void:
	GameMode.set_mode(GameMode.Mode.EXPLORATION)
	_open_hero_selection("local_coop", 1)

func _on_maze_pressed() -> void:
	GameMode.set_mode(GameMode.Mode.LINE_WARS)
	_open_hero_selection("maze_vs", 1)

func _on_legacy_online_pressed() -> void:
	GameMode.set_mode(GameMode.Mode.EXPLORATION_VS)
	_open_hero_selection("online_exploration_vs", 2)

func _on_back_pressed() -> void:
	queue_free()
