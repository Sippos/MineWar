extends Node

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan_tree")

func _scan_tree() -> void:
	_find_menus(get_tree().root)

func _find_menus(node: Node) -> void:
	_try_attach(node)
	for child in node.get_children():
		_find_menus(child)

func _on_node_added(node: Node) -> void:
	call_deferred("_try_attach", node)

func _try_attach(node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.name != "Menu":
		return
	if not node.has_node("SinglePlayerButton") or not node.has_node("MazeModeButton"):
		return
	if bool(node.get_meta("game_modes_attached", false)):
		return
	node.set_meta("game_modes_attached", true)

	var exploration := node.get_node("SinglePlayerButton") as Button
	var maze := node.get_node("MazeModeButton") as Button
	var vs_local := node.get_node_or_null("VSModeButton") as Button
	var vs_online := node.get_node_or_null("VSOnlineButton") as Button
	exploration.button_down.connect(func(): GameMode.set_mode(GameMode.Mode.EXPLORATION))
	maze.button_down.connect(func(): GameMode.set_mode(GameMode.Mode.LINE_WARS))
	if vs_local:
		vs_local.button_down.connect(func(): GameMode.set_mode(GameMode.Mode.EXPLORATION_VS))
	if vs_online:
		vs_online.button_down.connect(func(): GameMode.set_mode(GameMode.Mode.EXPLORATION_VS))

	var breach := node.get_node_or_null("BreachExperimentButton") as Button
	if breach == null:
		breach = Button.new()
		breach.name = "BreachExperimentButton"
		breach.text = "Breach Experiment"
		breach.tooltip_text = "Enemies approach through hidden dirt and connect to the mine."
		node.add_child(breach)
		breach.pressed.connect(_start_breach_experiment)

	var callable := Callable(self, "_layout_mode_buttons").bind(node)
	get_tree().root.size_changed.connect(callable)
	call_deferred("_layout_mode_buttons", node)

func _start_breach_experiment() -> void:
	GameMode.set_mode(GameMode.Mode.BREACH_EXPERIMENT)
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
		"BreachExperimentButton",
		"MazeModeButton",
		"VSModeButton",
		"VSOnlineButton",
		"ControlsButton",
	]
	var compact := viewport_size.x < 700.0 or viewport_size.y < 520.0
	var width := clampf(viewport_size.x * 0.42, 190.0, 232.0)
	var height := 46.0 if compact else 50.0
	var gap := 3.0 if compact else 6.0
	var stack_height := height * names.size() + gap * (names.size() - 1)
	var top := clampf(viewport_size.y * 0.49 - stack_height * 0.5, 122.0, maxf(122.0, viewport_size.y - 16.0 - stack_height))
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

	for i in range(names.size()):
		var button := menu.get_node_or_null(names[i]) as Button
		if button == null:
			continue
		if i > 0:
			var previous := menu.get_node_or_null(names[i - 1]) as Button
			if previous:
				button.focus_neighbor_top = previous.get_path()
		if i < names.size() - 1:
			var next := menu.get_node_or_null(names[i + 1]) as Button
			if next:
				button.focus_neighbor_bottom = next.get_path()
