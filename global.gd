extends Node

var rtc_peer: WebRTCMultiplayerPeer
var rtc_conn: WebRTCPeerConnection

const DEFAULT_UNLOCKED_HEROES = ["Dwarf", "Nerubian"]

func _ready() -> void:
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
	_ensure_default_heroes_unlocked()

var unlocked_heroes = DEFAULT_UNLOCKED_HEROES.duplicate()
var current_hero = "Dwarf"
var hero_p1 = "Dwarf"
var hero_p2 = "Dwarf"

var hero_data = {
	"Dwarf": {
		"walk": "res://character_sprites/dwarf_walk_highres_spritesheet.png",
		"attack": "res://character_sprites/dwarf_attack_pixelart_spritesheet.png"
	},
	"Mech": {
		"walk": "res://character_sprites/mech_walk_pixelart_spritesheet.png",
		"attack": "res://character_sprites/mech_walk_pixelart_spritesheet.png"
	},
	"Shaman": {
		"walk": "res://character_sprites/shaman_walk_spritesheet_25d.png",
		"attack": "res://character_sprites/shaman_walk_spritesheet_25d.png"
	},
	"Nerubian": {
		"walk": "res://character_sprites/spider_walk_spritesheet.png",
		"attack": "res://character_sprites/spider_walk_spritesheet.png"
	}
}

var seen_monsters = []

var monster_data = {
	"Rat": "res://character_sprites/rat_walk_pixelart_spritesheet.png",
	"Orc": "res://character_sprites/orc_walk_pixelart_spritesheet.png",
	"Mech": "res://character_sprites/mech_walk_pixelart_spritesheet.png",
	"Spider": "res://character_sprites/spider_walk_spritesheet.png",
	"Bat": "res://character_sprites/bat_fly_spritesheet.png",
	"Trogg": "res://character_sprites/trogg_walk_spritesheet.png"
}

func unlock_hero(hero_name: String) -> void:
	if not unlocked_heroes.has(hero_name):
		unlocked_heroes.append(hero_name)
		print("Unlocked Hero: ", hero_name)
		save_game()

func get_next_hero() -> String:
	var index = unlocked_heroes.find(current_hero)
	var next_index = (index + 1) % unlocked_heroes.size()
	return unlocked_heroes[next_index]

func save_game() -> void:
	var file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	if file:
		file.store_var(unlocked_heroes)
		file.close()

func load_game() -> void:
	if FileAccess.file_exists("user://savegame.save"):
		var file = FileAccess.open("user://savegame.save", FileAccess.READ)
		if file:
			var loaded = file.get_var()
			if typeof(loaded) == TYPE_ARRAY:
				unlocked_heroes = loaded
			file.close()

func _ensure_default_heroes_unlocked() -> void:
	var changed = false
	for hero_name in DEFAULT_UNLOCKED_HEROES:
		if not unlocked_heroes.has(hero_name):
			unlocked_heroes.append(hero_name)
			changed = true
	if changed:
		save_game()

func mark_monster_seen(monster_name: String) -> void:
	if not seen_monsters.has(monster_name):
		seen_monsters.append(monster_name)
		print("Seen Monster: ", monster_name)
