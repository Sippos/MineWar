extends Node

var rtc_peer: WebRTCMultiplayerPeer
var rtc_conn: WebRTCPeerConnection

const DEFAULT_UNLOCKED_HEROES = ["Dwarf"]
const SINGLE_PLAYER_PLAYTEST_HEROES = ["Shaman"]
const FIRST_LEVEL_REWARD_HEROES = ["Nerubian", "Druid", "Undead King"]
const GAME_UI_THEME_PATH = "res://global_theme.tres"
const SAFE_UI_SCENES = ["res://boot.tscn", "res://launch_router.tscn"]

var _game_ui_theme: Theme
var _game_ui_theme_enabled = false

func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_refresh_scene_theme")
	
	# Global UI controls for menus
	var ui_joy_buttons = {
		"ui_left": JOY_BUTTON_DPAD_LEFT,
		"ui_right": JOY_BUTTON_DPAD_RIGHT,
		"ui_up": JOY_BUTTON_DPAD_UP,
		"ui_down": JOY_BUTTON_DPAD_DOWN,
		"ui_accept": JOY_BUTTON_A,
		"ui_cancel": JOY_BUTTON_B
	}
	for action in ui_joy_buttons:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var joy_event = InputEventJoypadButton.new()
		joy_event.button_index = ui_joy_buttons[action]
		InputMap.action_add_event(action, joy_event)
		
	# Pause action (ESC + Start)
	if not InputMap.has_action("pause"): InputMap.add_action("pause")
	var esc_event = InputEventKey.new(); esc_event.physical_keycode = KEY_ESCAPE; InputMap.action_add_event("pause", esc_event)
	var start_event = InputEventJoypadButton.new(); start_event.button_index = JOY_BUTTON_START; InputMap.action_add_event("pause", start_event)
	
	load_game()
	_sanitize_unlock_progress()

func _on_scene_changed() -> void:
	_refresh_scene_theme()

func _refresh_scene_theme() -> void:
	var scene = get_tree().current_scene
	if scene == null:
		_game_ui_theme_enabled = false
		return
	
	_game_ui_theme_enabled = not SAFE_UI_SCENES.has(scene.scene_file_path)
	if _game_ui_theme_enabled:
		_apply_game_theme_to_branch(scene, false)

func _on_node_added(node: Node) -> void:
	if not _game_ui_theme_enabled or not (node is Control):
		return
	call_deferred("_apply_game_theme_to_added_control", node)

func _apply_game_theme_to_added_control(control: Control) -> void:
	if not _game_ui_theme_enabled or not is_instance_valid(control):
		return
	
	var parent = control.get_parent()
	while parent != null:
		if parent is Control:
			return
		parent = parent.get_parent()
	
	var ui_theme = _get_game_ui_theme()
	if ui_theme != null and control.theme == null:
		control.theme = ui_theme

func _apply_game_theme_to_branch(node: Node, has_control_ancestor: bool) -> void:
	var node_is_control = node is Control
	if node_is_control and not has_control_ancestor:
		var control = node as Control
		var ui_theme = _get_game_ui_theme()
		if ui_theme != null and control.theme == null:
			control.theme = ui_theme
	
	var child_has_control_ancestor = has_control_ancestor or node_is_control
	for child in node.get_children():
		_apply_game_theme_to_branch(child, child_has_control_ancestor)

func _get_game_ui_theme() -> Theme:
	if _game_ui_theme == null:
		_game_ui_theme = load(GAME_UI_THEME_PATH) as Theme
	return _game_ui_theme

var unlocked_heroes = DEFAULT_UNLOCKED_HEROES.duplicate()
var first_level_beaten = false
var current_hero = "Dwarf"
var hero_p1 = "Dwarf"
var hero_p2 = "Dwarf"

var hero_data = {
	"Dwarf": {
		"walk": preload("res://assets/sprites/characters/dwarf/dwarf_walk_highres_spritesheet.png"),
		"attack": preload("res://assets/sprites/characters/dwarf/dwarf_attack_pixelart_spritesheet.png")
	},
	"Mech": {
		"walk": preload("res://character_sprites/mech_walk_pixelart_spritesheet.png"),
		"attack": preload("res://character_sprites/mech_walk_pixelart_spritesheet.png")
	},
	"Shaman": {
		"walk": preload("res://character_sprites/shaman_walk_spritesheet_25d.png"),
		"attack": preload("res://character_sprites/shaman_attack_spritesheet_25d.png")
	},
	"Nerubian": {
		"walk": preload("res://character_sprites/nerubian_walk_spritesheet_25d.png"),
		"attack": preload("res://character_sprites/nerubian_attack_spritesheet_25d.png")
	},
	"Druid": {
		"walk": preload("res://character_sprites/druid_walk_spritesheet_25d.png"),
		"attack": preload("res://character_sprites/druid_humanoid_staff_swing_spritesheet_25d.png"),
		"mole": preload("res://character_sprites/druid_mole_crawl_spritesheet_25d.png")
	},
	"Undead King": {
		"walk": preload("res://character_sprites/undead_king_float_idle_spritesheet_25d.png"),
		"attack": preload("res://character_sprites/undead_king_staff_cast_spritesheet_25d.png")
	}
}

var seen_monsters = []

var monster_data = {
	"Rat": "res://assets/sprites/enemies/rat/rat_walk_pixelart_spritesheet.png",
	"Orc": "res://character_sprites/orc_walk_pixelart_spritesheet.png",
	"Mech": "res://character_sprites/mech_walk_pixelart_spritesheet.png",
	"Spider": "res://character_sprites/spider_walk_spritesheet.png",
	"Bat": "res://character_sprites/bat_fly_spritesheet.png",
	"Trogg": "res://character_sprites/trogg_walk_spritesheet.png"
}

func is_hero_unlocked(hero_name: String) -> bool:
	return unlocked_heroes.has(hero_name)

func is_hero_playable_in_single_player(hero_name: String) -> bool:
	return is_hero_unlocked(hero_name) or SINGLE_PLAYER_PLAYTEST_HEROES.has(hero_name)

func unlock_hero(hero_name: String) -> void:
	if not hero_data.has(hero_name):
		return
	if not unlocked_heroes.has(hero_name):
		unlocked_heroes.append(hero_name)
		print("Unlocked Hero: ", hero_name)
		save_game()

func mark_first_level_beaten() -> void:
	first_level_beaten = true
	var changed = false
	for hero_name in FIRST_LEVEL_REWARD_HEROES:
		if hero_data.has(hero_name) and not unlocked_heroes.has(hero_name):
			unlocked_heroes.append(hero_name)
			changed = true
	if changed:
		print("First level beaten: unlocked extra heroes")
	save_game()

func get_next_hero() -> String:
	var index = unlocked_heroes.find(current_hero)
	if index == -1:
		return DEFAULT_UNLOCKED_HEROES[0]
	var next_index = (index + 1) % unlocked_heroes.size()
	return unlocked_heroes[next_index]

func save_game() -> void:
	var file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	if file:
		file.store_var({
			"unlocked_heroes": unlocked_heroes,
			"first_level_beaten": first_level_beaten
		})
		file.close()

func load_game() -> void:
	if FileAccess.file_exists("user://savegame.save"):
		var file = FileAccess.open("user://savegame.save", FileAccess.READ)
		if file:
			var loaded = file.get_var()
			if typeof(loaded) == TYPE_ARRAY:
				unlocked_heroes = loaded
			elif typeof(loaded) == TYPE_DICTIONARY:
				if loaded.has("unlocked_heroes") and typeof(loaded["unlocked_heroes"]) == TYPE_ARRAY:
					unlocked_heroes = loaded["unlocked_heroes"]
				if loaded.has("first_level_beaten"):
					first_level_beaten = bool(loaded["first_level_beaten"])
			file.close()

func _sanitize_unlock_progress() -> void:
	var valid_unlocked = []
	var changed = false
	
	for hero_name in DEFAULT_UNLOCKED_HEROES:
		if hero_data.has(hero_name) and not valid_unlocked.has(hero_name):
			valid_unlocked.append(hero_name)
	
	if first_level_beaten:
		for hero_name in FIRST_LEVEL_REWARD_HEROES:
			if hero_data.has(hero_name) and not valid_unlocked.has(hero_name):
				valid_unlocked.append(hero_name)
	
	for hero_name in unlocked_heroes:
		if not valid_unlocked.has(hero_name):
			changed = true
	
	for hero_name in valid_unlocked:
		if not unlocked_heroes.has(hero_name):
			changed = true
	
	if changed or unlocked_heroes.size() != valid_unlocked.size():
		unlocked_heroes = valid_unlocked
		save_game()

func mark_monster_seen(monster_name: String) -> void:
	if not seen_monsters.has(monster_name):
		seen_monsters.append(monster_name)
		print("Seen Monster: ", monster_name)