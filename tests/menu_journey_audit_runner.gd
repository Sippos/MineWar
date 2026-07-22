extends Node

const MAIN_MENU := preload("res://scenes/menus/main/menu.tscn")
const SETTINGS_MENU := preload("res://scenes/menus/settings_menu.tscn")
const MULTIPLAYER_MENU := preload("res://scenes/menus/multiplayer_menu.tscn")
const LOCAL_HERO_SELECT := preload("res://scenes/menus/multiplayer_hero_select.tscn")
const HERO_SELECT := preload("res://hero_selection_menu.tscn")
const CONTROLS_MENU := preload("res://scenes/menus/controls/controls_menu.tscn")
const PAUSE_MENU := preload("res://scenes/ui/overlays/pause/pause_menu.tscn")
const BESTIARY := preload("res://scenes/menus/lexicon/lexikon.tscn")
const ONLINE_LOBBY := preload("res://online_lobby.tscn")
const LOADOUT_MENU := preload("res://scenes/menus/loadout_selection_menu.tscn")

var failures: Array[String] = []
var old_heroes: Array
var old_bases: Array
var old_selected_hero := ""
var old_selected_base := ""
var old_first_level := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	_store_progression()
	Global.unlocked_heroes = ["Dwarf"]
	Global.unlocked_bases = ["default_base"]
	Global.selected_hero_id = "Dwarf"
	Global.selected_base_id = "default_base"
	Global.first_level_beaten = false

	await _check_main_menu()
	await _check_settings()
	await _check_multiplayer(false)
	await _check_multiplayer(true)
	await _check_local_hero_select()
	await _check_online_hero_select()
	await _check_controls()
	await _check_pause()
	await _check_bestiary()
	await _check_online_lobby()
	await _check_loadout()

	_restore_progression()
	if failures.is_empty():
		print("MENU_JOURNEY_AUDIT_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		push_error("MENU_JOURNEY_AUDIT_FAIL: %d findings" % failures.size())
		get_tree().quit(1)

func _check_main_menu() -> void:
	var menu := MAIN_MENU.instantiate()
	add_child(menu)
	await _frames(3)
	_expect(menu.get_node("SinglePlayerButton").text == "START EXPEDITION", "Main menu should expose the complete expedition clearly")
	_expect(menu.get_node("StrongholdButton").text == "STRONGHOLD & LOADOUT", "Stronghold should be a separate destination")
	_expect(menu.get_node("AdvancedModesButton").disabled, "Advanced modes should be visibly progression-gated on a fresh save")
	_expect(menu.get_node("LocalMultiplayerButton").text == "LOCAL MULTIPLAYER", "Local multiplayer should remain reachable")
	_expect(menu.get_node("OnlineMultiplayerButton").text == "ONLINE MULTIPLAYER", "Online multiplayer should remain reachable")
	var settings := menu.get_node("SettingsButton") as Button
	_expect(settings.get_global_rect().end.y < get_viewport().get_visible_rect().size.y - 80.0, "All main-menu buttons should stay inside the wooden frame and above the bottom edge")
	menu.queue_free()
	await _frames(2)

func _check_settings() -> void:
	var menu := SETTINGS_MENU.instantiate()
	add_child(menu)
	await _frames(3)
	var panel := menu.get_node("Dimmer/Center/Panel") as PanelContainer
	_expect(panel.get_theme_stylebox("panel") is StyleBoxTexture, "Settings should use the wooden MineWars panel, not a grey placeholder")
	_expect(menu.get_node("Dimmer/Center/Panel/VBox/VolumeRow/VolumeSlider") is HSlider, "Settings volume control should be present")
	menu.queue_free()
	await _frames(2)

func _check_multiplayer(online: bool) -> void:
	var menu := MULTIPLAYER_MENU.instantiate()
	menu.setup(online)
	add_child(menu)
	await _frames(3)
	var panel := menu.get_node("Dimmer/Center/Panel") as PanelContainer
	_expect(panel.get_theme_stylebox("panel") is StyleBoxTexture, "Multiplayer selector should use the wooden MineWars panel")
	var playable := menu.get_node("Dimmer/Center/Panel/VBox/LegacyOnlineButton") as Button
	if online:
		_expect(playable.visible and not playable.disabled, "Online Exploration VS should remain playable")
		_expect((menu.get_node("Dimmer/Center/Panel/VBox/CoopButton") as Button).disabled, "Unimplemented online co-op should be explicitly disabled")
	else:
		_expect(not playable.visible, "Online-only action should not clutter local multiplayer")
	menu.queue_free()
	await _frames(2)

func _check_local_hero_select() -> void:
	var menu := LOCAL_HERO_SELECT.instantiate()
	menu.setup("local_coop")
	add_child(menu)
	await _frames(3)
	var p1 := menu.get_node("Dimmer/Center/Panel/VBox/Selectors/P1Column/P1Option") as OptionButton
	var p2 := menu.get_node("Dimmer/Center/Panel/VBox/Selectors/P2Column/P2Option") as OptionButton
	_expect(p1.item_count == 1 and p2.item_count == 1, "Local hero selection must not bypass progression with locked heroes")
	_expect(p1.get_item_text(0) == "Dwarf" and p2.get_item_text(0) == "Dwarf", "Fresh-save local multiplayer should offer the unlocked Dwarf only")
	menu.queue_free()
	await _frames(2)

func _check_online_hero_select() -> void:
	var menu := HERO_SELECT.instantiate()
	menu.setup(2, "online_exploration_vs")
	add_child(menu)
	await _frames(3)
	var title: Label = menu.get("title_label")
	var start_button: Button = menu.get("start_btn")
	_expect(title != null and title.text == "CHOOSE ONLINE HERO", "Online hero selection should use singular, context-specific wording")
	_expect(start_button != null and start_button.text == "Continue to Room Code", "Online hero flow should explain its next step")
	menu.queue_free()
	await _frames(2)

func _check_controls() -> void:
	var menu := CONTROLS_MENU.instantiate()
	add_child(menu)
	await _frames(3)
	_expect(menu.layer >= 200, "Controls overlay should render above pause and first-run banners")
	_expect((menu.get_node("Panel/VBoxContainer/Title") as Label).text == "CONTROLS", "Controls title should not be mislabeled as Settings")
	menu.queue_free()
	await _frames(2)

func _check_pause() -> void:
	var menu := PAUSE_MENU.instantiate()
	add_child(menu)
	await _frames(3)
	_expect(menu.layer >= 200, "Pause menu should sit above world HUD and onboarding banners")
	_expect(menu.has_node("Panel/VBoxContainer/ButtonSettings"), "Pause menu should expose Settings")
	_expect(menu.has_node("Panel/VBoxContainer/ButtonControls"), "Pause menu should expose Controls")
	menu.queue_free()
	await _frames(2)

func _check_bestiary() -> void:
	var menu := BESTIARY.instantiate()
	add_child(menu)
	await _frames(4)
	_expect((menu.get_node("VBoxContainer/TopBar/Label") as Label).text == "MINEWARS BESTIARY", "Bestiary title should match the game branding")
	var hero_grid := menu.get_node("VBoxContainer/ScrollContainer/VBoxContainer/HeroesGrid") as GridContainer
	var base_grid := menu.get_node("VBoxContainer/ScrollContainer/VBoxContainer/BasesGrid") as GridContainer
	var monster_grid := menu.get_node("VBoxContainer/ScrollContainer/VBoxContainer/MonstersGrid") as GridContainer
	_expect(hero_grid.columns == base_grid.columns and base_grid.columns == monster_grid.columns, "Bestiary sections should share one responsive grid system")
	menu.queue_free()
	await _frames(2)

func _check_online_lobby() -> void:
	var menu := ONLINE_LOBBY.instantiate()
	add_child(menu)
	await _frames(3)
	_expect(menu.get_node("Dimmer/Background") is TextureRect, "Online lobby should reuse the MineWars menu backdrop instead of a flat black/grey screen")
	_expect(menu.get_node("Dimmer/Center/Panel/VBoxContainer/RoomInput") is LineEdit, "Online room-code input should be functional")
	_expect(menu.get_script() != null, "Online lobby must have its networking script attached")
	menu.queue_free()
	await _frames(2)

func _check_loadout() -> void:
	Global.unlocked_bases = ["default_base", "shaman_base", "nerubian_base", "mech_base", "druid_base", "undead_king_base"]
	var menu := LOADOUT_MENU.instantiate()
	add_child(menu)
	await _frames(4)
	var shell: PanelContainer = menu.get("shell")
	_expect(shell != null and shell.get_theme_stylebox("panel") is StyleBoxTexture, "Fortress selection should use the wooden MineWars shell")
	var buttons: Dictionary = menu.get("base_buttons")
	_expect(buttons.size() == 6, "Fortress selection should expose all six authored bases")
	for base_id in Global.unlocked_bases:
		var button := buttons.get(base_id) as Button
		_expect(button != null and button.visible and not button.disabled, "%s should be visible and selectable when unlocked" % base_id)
	menu.queue_free()
	await _frames(2)

func _store_progression() -> void:
	old_heroes = Global.unlocked_heroes.duplicate()
	old_bases = Global.unlocked_bases.duplicate()
	old_selected_hero = Global.selected_hero_id
	old_selected_base = Global.selected_base_id
	old_first_level = Global.first_level_beaten

func _restore_progression() -> void:
	Global.unlocked_heroes = old_heroes
	Global.unlocked_bases = old_bases
	Global.selected_hero_id = old_selected_hero
	Global.selected_base_id = old_selected_base
	Global.first_level_beaten = old_first_level

func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
