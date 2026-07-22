extends Node

const MENU_PATH := "res://scripts/ui/menus/main/menu.gd"
var failures: Array[String] = []

func _ready() -> void:
	var source := FileAccess.get_file_as_string(MENU_PATH)
	if source.is_empty():
		push_error("Could not read main menu script")
		get_tree().quit(1)
		return

	source = _replace_once(source,
		"@onready var lexicon_button: TextureButton = $LexikonButton\n",
		"@onready var lexicon_button: TextureButton = $LexikonButton\n\nvar stronghold_button: Button\nvar advanced_modes_button: Button\n"
	)
	source = _replace_once(source,
		"\t_configure_release_menu()\n\tsingle_player_button.pressed.connect(_on_single_player_pressed)",
		"\t_configure_release_menu()\n\tstronghold_button.pressed.connect(_on_stronghold_pressed)\n\tadvanced_modes_button.pressed.connect(_on_advanced_modes_pressed)\n\tsingle_player_button.pressed.connect(_on_single_player_pressed)"
	)

	source = _replace_function(source, "func _configure_release_menu() -> void:", "func _configure_focus_navigation() -> void:", '''func _configure_release_menu() -> void:
	$Label.text = "MINEWARS"
	single_player_button.text = "START EXPEDITION"
	single_player_button.tooltip_text = "Begin the complete four-stage MineWars expedition."

	stronghold_button = _ensure_release_button("StrongholdButton", "STRONGHOLD & LOADOUT")
	stronghold_button.tooltip_text = "Change hero or base and inspect permanent progression."

	advanced_modes_button = _ensure_release_button("AdvancedModesButton", "ADVANCED MODES" if Global.first_level_beaten else "ADVANCED MODES — WIN ONCE")
	advanced_modes_button.tooltip_text = "Enter the Stronghold and use the LineWars or Adventure gateways."
	advanced_modes_button.disabled = not Global.first_level_beaten

	local_multiplayer_button.text = "LOCAL MULTIPLAYER"
	local_multiplayer_button.tooltip_text = "Play local co-op Exploration or local Maze Builder VS."
	online_multiplayer_button.text = "ONLINE MULTIPLAYER"
	online_multiplayer_button.tooltip_text = "Play the existing WebRTC Exploration VS mode online."

	var tagline := get_node_or_null("ReleaseTagline") as Label
	if tagline == null:
		tagline = Label.new()
		tagline.name = "ReleaseTagline"
		tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tagline.add_theme_font_size_override("font_size", 14)
		tagline.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0, 0.94))
		tagline.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 0.96))
		tagline.add_theme_constant_override("outline_size", 3)
		add_child(tagline)
	tagline.text = "MINE • BUILD • RETURN • DEFEND"

func _ensure_release_button(node_name: String, label_text: String) -> Button:
	var button := get_node_or_null(node_name) as Button
	if button == null:
		button = Button.new()
		button.name = node_name
		add_child(button)
	button.text = label_text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(250, 52)
	return button

''')

	source = _replace_function(source, "func _configure_focus_navigation() -> void:", "func _configure_lexicon_action() -> void:", '''func _configure_focus_navigation() -> void:
	var buttons: Array[Button] = [single_player_button, stronghold_button]
	if not advanced_modes_button.disabled:
		buttons.append(advanced_modes_button)
	buttons.append(local_multiplayer_button)
	buttons.append(online_multiplayer_button)
	buttons.append(controls_button)
	buttons.append(settings_button)
	for index in buttons.size():
		buttons[index].focus_neighbor_top = buttons[index - 1].get_path() if index > 0 else NodePath()
		buttons[index].focus_neighbor_bottom = buttons[index + 1].get_path() if index < buttons.size() - 1 else lexicon_button.get_path()
	lexicon_button.focus_neighbor_top = settings_button.get_path()

''')

	source = _replace_once(source,
		"\tvar buttons: Array[Button] = [single_player_button, local_multiplayer_button, online_multiplayer_button, controls_button, settings_button]\n",
		"\tvar buttons: Array[Button] = [single_player_button, stronghold_button, advanced_modes_button, local_multiplayer_button, online_multiplayer_button, controls_button, settings_button]\n"
	)

	source = _replace_once(source,
		"\tvar stack_height := button_height * 5.0 + gap * 4.0\n\tif stack_height > available_height:\n\t\tbutton_height = maxf(34.0, (available_height - gap * 4.0) / 5.0)\n\t\tstack_height = button_height * 5.0 + gap * 4.0\n",
		"\tvar button_count := 7.0\n\tvar stack_height := button_height * button_count + gap * (button_count - 1.0)\n\tif stack_height > available_height:\n\t\tbutton_height = maxf(34.0, (available_height - gap * (button_count - 1.0)) / button_count)\n\t\tstack_height = button_height * button_count + gap * (button_count - 1.0)\n"
	)

	source = _replace_function(source, "func _on_local_multiplayer_pressed() -> void:", "func _on_online_multiplayer_pressed() -> void:", '''func _on_stronghold_pressed() -> void:
	GameMode.set_mode(GameMode.Mode.HUB)
	Global.apply_selected_loadout()
	get_tree().change_scene_to_file("res://scenes/world/preparation/preparation_hub.tscn")

func _on_advanced_modes_pressed() -> void:
	if not Global.first_level_beaten:
		return
	GameMode.set_mode(GameMode.Mode.HUB)
	Global.apply_selected_loadout()
	get_tree().change_scene_to_file("res://scenes/world/preparation/preparation_hub.tscn")

func _on_local_multiplayer_pressed() -> void:
	_open_multiplayer_menu(false)

''')

	source = _replace_function(source, "func _on_online_multiplayer_pressed() -> void:", "func _on_controls_pressed() -> void:", '''func _on_online_multiplayer_pressed() -> void:
	_open_multiplayer_menu(true)

''')

	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
		return
	var file := FileAccess.open(MENU_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write main menu script")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("RESTORE_MULTIPLAYER_MENU_PATCH_OK")
	get_tree().quit(0)

func _replace_once(source: String, old_text: String, new_text: String) -> String:
	if source.contains(new_text):
		return source
	if not source.contains(old_text):
		failures.append("Missing patch target: %s" % old_text.left(90))
		return source
	return source.replace(old_text, new_text)

func _replace_function(source: String, start_marker: String, end_marker: String, replacement: String) -> String:
	var start := source.find(start_marker)
	if start < 0:
		failures.append("Missing function start: %s" % start_marker)
		return source
	var end := source.find(end_marker, start + start_marker.length())
	if end < 0:
		failures.append("Missing function end: %s" % end_marker)
		return source
	return source.substr(0, start) + replacement + source.substr(end)
