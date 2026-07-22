extends Node

var failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	await _test_main_menu_layout()
	await _test_settings()
	await _test_multiplayer(false)
	await _test_multiplayer(true)
	await _test_local_hero_select()
	await _test_controls()
	await _test_online_lobby()
	await _test_bestiary()
	await _test_loadout()
	await _test_pause_menu()
	if failures.is_empty():
		print("MENU_JOURNEY_SMOKE_OK")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _spawn(path: String) -> Node:
	var scene := load(path) as PackedScene
	_expect(scene != null, "%s should load" % path)
	if scene == null:
		return null
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	await get_tree().process_frame
	return instance

func _remove(instance: Node) -> void:
	if instance != null and is_instance_valid(instance):
		remove_child(instance)
		instance.queue_free()
	await get_tree().process_frame

func _test_main_menu_layout() -> void:
	var menu := await _spawn("res://scenes/menus/main/menu.tscn") as Control
	if menu == null:
		return
	var buttons: Array[Button] = [
		menu.get_node("SinglePlayerButton"), menu.get_node("StrongholdButton"), menu.get_node("AdvancedModesButton"),
		menu.get_node("LocalMultiplayerButton"), menu.get_node("OnlineMultiplayerButton"), menu.get_node("ControlsButton"), menu.get_node("SettingsButton")
	]
	for size in [Vector2(1152, 648), Vector2(480, 360)]:
		menu.call("_layout_for_screen", size)
		var title := menu.get_node("Label") as Label
		_expect(buttons[0].offset_top >= title.offset_bottom + 7.0, "Main-menu buttons should clear the title at %s" % size)
		_expect(buttons[-1].offset_bottom <= size.y - 17.0, "All seven main-menu buttons should remain on-screen at %s" % size)
		for index in range(1, buttons.size()):
			_expect(buttons[index].offset_top > buttons[index - 1].offset_top, "Main-menu button order should remain stable")
	await _remove(menu)

func _test_settings() -> void:
	var menu := await _spawn("res://scenes/menus/settings_menu.tscn")
	if menu:
		var panel := menu.get_node("Dimmer/Center/Panel") as PanelContainer
		_expect(panel.get_theme_stylebox("panel") is StyleBoxTexture, "Settings should use the wooden panel rather than a grey default box")
		_expect(menu.has_node("Dimmer/Center/Panel/VBox/VolumeRow/VolumeSlider"), "Settings should expose volume controls")
	await _remove(menu)

func _test_multiplayer(online: bool) -> void:
	var scene := load("res://scenes/menus/multiplayer_menu.tscn") as PackedScene
	var menu = scene.instantiate()
	menu.setup(online)
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel := menu.get_node("Dimmer/Center/Panel") as PanelContainer
	_expect(panel.get_theme_stylebox("panel") is StyleBoxTexture, "Multiplayer chooser should use the wooden panel")
	var legacy := menu.get_node("Dimmer/Center/Panel/VBox/LegacyOnlineButton") as Button
	if online:
		_expect(legacy.visible and not legacy.disabled, "Online Exploration VS should remain reachable")
		_expect((menu.get_node("Dimmer/Center/Panel/VBox/CoopButton") as Button).disabled, "Unimplemented online co-op should be clearly disabled")
	else:
		_expect(not legacy.visible, "Local multiplayer should not show the legacy online action")
	await _remove(menu)

func _test_local_hero_select() -> void:
	var scene := load("res://scenes/menus/multiplayer_hero_select.tscn") as PackedScene
	var menu = scene.instantiate()
	menu.setup("local_coop")
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(menu.get_node("Dimmer/Center/Panel").get_theme_stylebox("panel") is StyleBoxTexture, "Local hero selection should use the wooden panel")
	_expect((menu.get_node("Dimmer/Center/Panel/VBox/Selectors/P1Column/P1Option") as OptionButton).item_count >= 1, "Player 1 should have an available hero")
	await _remove(menu)

func _test_controls() -> void:
	var menu := await _spawn("res://scenes/menus/controls/controls_menu.tscn")
	if menu:
		_expect((menu.get_node("Panel/VBoxContainer/Title") as Label).text == "CONTROLS", "Controls should not be mislabeled as Settings")
	await _remove(menu)

func _test_online_lobby() -> void:
	var lobby := await _spawn("res://online_lobby.tscn")
	if lobby:
		_expect(lobby.get_script() != null, "Online lobby must retain its script attachment")
		_expect(lobby.has_node("Dimmer/Center/Panel/VBoxContainer/RoomInput"), "Online lobby should expose the room-code field")
		_expect(lobby.get_node("Dimmer/Center/Panel").get_theme_stylebox("panel") is StyleBoxTexture, "Online lobby should use the wooden panel")
	await _remove(lobby)

func _test_bestiary() -> void:
	var menu := await _spawn("res://scenes/menus/lexicon/lexikon.tscn")
	if menu:
		var content := menu.get_node("VBoxContainer") as VBoxContainer
		_expect(content.offset_left >= 47.0 and content.offset_right <= -47.0, "Bestiary content should remain inside the transparent frame edges")
		_expect(menu.has_node("VBoxContainer/TopBar/BackButton"), "Bestiary should retain a back action")
	await _remove(menu)

func _test_loadout() -> void:
	var menu := await _spawn("res://scenes/menus/loadout_selection_menu.tscn")
	if menu:
		var buttons: Dictionary = menu.get("base_buttons")
		_expect(buttons.size() == 6, "Fortress selector should keep all six progression choices")
		var dwarf := buttons.get("default_base") as Button
		_expect(dwarf != null and dwarf.visible and dwarf.custom_minimum_size.x >= 200.0, "A fresh save should show one wide readable Dwarf Bastion choice")
	await _remove(menu)

func _test_pause_menu() -> void:
	var menu := await _spawn("res://scenes/ui/overlays/pause/pause_menu.tscn")
	if menu:
		_expect(menu.has_node("Panel/VBoxContainer/ButtonControls"), "Pause menu should expose Controls")
		_expect(menu.has_node("Panel/VBoxContainer/ButtonSettings"), "Pause menu should expose Settings separately")
	await _remove(menu)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
