extends Node

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan_tree")

func _scan_tree() -> void:
	if not is_inside_tree():
		return
	_find_menus(get_tree().root)

func _find_menus(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_try_attach(node)
	for child in node.get_children():
		_find_menus(child)

func _on_node_added(_node: Node) -> void:
	call_deferred("_scan_tree")

func _try_attach(node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.name != "Menu":
		return
	if not node.has_node("SinglePlayerButton") or not node.has_node("LocalMultiplayerButton"):
		return
	if bool(node.get_meta("game_modes_attached", false)):
		return
	node.set_meta("game_modes_attached", true)

	var play_minewars := node.get_node("SinglePlayerButton") as Button
	play_minewars.text = "Play MineWars"
	play_minewars.tooltip_text = "Mine under pressure, build an RPG hero, and defend the base directly."
	# The menu's original handler starts the preparation flow. This later signal
	# connection ensures the selected single-player mode is Siege before the
	# deferred scene change completes.
	play_minewars.pressed.connect(func(): GameMode.set_mode(GameMode.Mode.SIEGE))

	var exploration := _ensure_mode_button(node, "ExplorationModeButton", "Adventure Exploration")
	exploration.tooltip_text = "No scheduled surface waves. Discover nests, artifacts, and the deep boss underground."
	exploration.pressed.connect(_start_mode.bind(GameMode.Mode.EXPLORATION))

	var breach := _ensure_mode_button(node, "BreachExperimentButton", "Breach Experiment")
	breach.tooltip_text = "Experimental enemies tunnel through hidden dirt toward the mine."
	breach.pressed.connect(_start_mode.bind(GameMode.Mode.BREACH_EXPERIMENT))

	var callable := Callable(self, "_layout_mode_buttons").bind(node)
	get_tree().root.size_changed.connect(callable)
	call_deferred("_layout_mode_buttons", node)

func _ensure_mode_button(menu: Node, button_name: String, label: String) -> Button:
	var button := menu.get_node_or_null(button_name) as Button
	if button != null:
		return button
	button = Button.new()
	button.name = button_name
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	menu.add_child(button)
	return button

func _start_mode(mode: GameMode.Mode) -> void:
	GameMode.set_mode(mode)
	Global.apply_selected_loadout()
	get_tree().change_scene_to_file("res://scenes/world/preparation/preparation_hub.tscn")

func _layout_mode_buttons(menu: Node) -> void:
	if menu == null or not is_instance_valid(menu):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var names := [
		"SinglePlayerButton",
		"ExplorationModeButton",
		"BreachExperimentButton",
		"LocalMultiplayerButton",
		"OnlineMultiplayerButton",
		"ControlsButton",
		"SettingsButton",
	]
	var compact := viewport_size.x < 700.0 or viewport_size.y < 620.0
	var width := clampf(viewport_size.x * 0.42, 190.0, 250.0)
	var height := 39.0 if compact else 45.0
	var gap := 3.0 if compact else 5.0
	var stack_height := height * names.size() + gap * (names.size() - 1)
	var top := clampf(viewport_size.y * 0.53 - stack_height * 0.5, 118.0, maxf(118.0, viewport_size.y - 16.0 - stack_height))
	var center_x := viewport_size.x * 0.5
	for i in range(names.size()):
		var button := menu.get_node_or_null(names[i]) as Button
		if button == null:
			continue
		var y := top + float(i) * (height + gap)
		button.offset_left = center_x - width * 0.5
		button.offset_top = y
		button.offset_right = center_x + width * 0.5
		button.offset_bottom = y + height
		button.custom_minimum_size = Vector2(width, height)
		if i > 0:
			var previous := menu.get_node_or_null(names[i - 1]) as Control
			if previous != null:
				button.focus_neighbor_top = previous.get_path()
		if i < names.size() - 1:
			var next := menu.get_node_or_null(names[i + 1]) as Control
			if next != null:
				button.focus_neighbor_bottom = next.get_path()
