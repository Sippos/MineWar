extends Node

var rtc_peer: WebRTCMultiplayerPeer
var rtc_conn: WebRTCPeerConnection

const DEFAULT_UNLOCKED_HEROES = ["Dwarf"]
const SINGLE_PLAYER_PLAYTEST_HEROES = ["Shaman"]
const FIRST_LEVEL_REWARD_HEROES = ["Nerubian", "Druid", "Undead King"]
const GAME_UI_THEME_PATH = "res://assets/themes/global/global_theme.tres"
const SAFE_UI_SCENES = ["res://boot.tscn", "res://launch_router.tscn"]
const DEFAULT_HERO_ID := "Dwarf"
const DEFAULT_BASE_ID := "default_base"
const PERMANENT_UPGRADE_IDS := ["reinforced_core", "starter_cache", "miners_harness"]
const PERMANENT_UPGRADE_MAX_LEVELS := {
	"reinforced_core": 5,
	"starter_cache": 3,
	"miners_harness": 4
}
const PERMANENT_UPGRADE_BASE_COSTS := {
	"reinforced_core": 1,
	"starter_cache": 2,
	"miners_harness": 1
}

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
var current_hero = DEFAULT_HERO_ID
var hero_p1 = DEFAULT_HERO_ID
var hero_p2 = DEFAULT_HERO_ID
var selected_hero_id := DEFAULT_HERO_ID
var selected_base_id := DEFAULT_BASE_ID
var prototype_onboarding_completed := false
var legacy_ore := 0
var last_run_legacy_ore_earned := 0
var permanent_upgrade_levels := {
	"reinforced_core": 0,
	"starter_cache": 0,
	"miners_harness": 0
}

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
		"walk": preload("res://character_sprites/shaman_walk_pre_restore_recovered_review.png"),
		"attack": preload("res://character_sprites/shaman_attack_spritesheet_25d.png")
	},
	"Nerubian": {
		"walk": preload("res://character_sprites/nerubian_walk_spritesheet_25d_review.png"),
		"attack": preload("res://character_sprites/nerubian_attack_spritesheet_25d.png")
	},
	"Druid": {
		"walk": preload("res://character_sprites/druid_walk_spritesheet_25d.png"),
		"attack": preload("res://character_sprites/druid_humanoid_staff_swing_spritesheet_25d_review.png"),
		"mole": preload("res://character_sprites/druid_mole_crawl_spritesheet_25d.png"),
		"mole_attack": preload("res://character_sprites/druid_mole_attack_spritesheet_25d.png")
	},
	"Undead King": {
		"walk": preload("res://character_sprites/undead_king_float_idle_spritesheet_25d_review.png"),
		"attack": preload("res://character_sprites/undead_king_staff_cast_spritesheet_25d_review.png")
	}
}

var base_data = {
	"default_base": {
		"name": "Dwarf Bastion",
		"texture": preload("res://DwarfBase.png")
	},
	"shaman_base": {
		"name": "Shaman Lodge",
		"texture": preload("res://ShamanBase.png")
	},
	"nerubian_base": {
		"name": "Nerubian Nest",
		"texture": preload("res://NerubianBase.png")
	},
	"druid_base": {
		"name": "Druid Grove",
		"texture": preload("res://DruidBase.png")
	},
	"undead_king_base": {
		"name": "Undead Citadel",
		"texture": preload("res://UndeadKingBase.png")
	}
}

var seen_monsters = []

var monster_data = {
	"Rat": preload("res://assets/sprites/enemies/rat/rat_walk_pixelart_spritesheet.png"),
	"Orc": preload("res://character_sprites/orc_walk_pixelart_spritesheet.png"),
	"Mech": preload("res://character_sprites/mech_walk_pixelart_spritesheet.png"),
	"Spider": preload("res://character_sprites/spider_walk_spritesheet.png"),
	"Bat": preload("res://character_sprites/bat_fly_spritesheet.png"),
	"Trogg": preload("res://character_sprites/trogg_walk_spritesheet.png")
}

func set_run_loadout(hero_id: String = DEFAULT_HERO_ID, base_id: String = DEFAULT_BASE_ID) -> void:
	selected_hero_id = hero_id if hero_data.has(hero_id) else DEFAULT_HERO_ID
	selected_base_id = base_id if base_data.has(base_id) else DEFAULT_BASE_ID
	apply_selected_loadout()
	save_game()

func apply_selected_loadout() -> void:
	if not hero_data.has(selected_hero_id):
		selected_hero_id = DEFAULT_HERO_ID
	if not base_data.has(selected_base_id):
		selected_base_id = DEFAULT_BASE_ID
	current_hero = selected_hero_id
	hero_p1 = selected_hero_id
	hero_p2 = selected_hero_id

func reset_to_default_loadout() -> void:
	set_run_loadout(DEFAULT_HERO_ID, DEFAULT_BASE_ID)

func complete_prototype_onboarding() -> void:
	if prototype_onboarding_completed:
		return
	prototype_onboarding_completed = true
	save_game()

func get_permanent_upgrade_level(upgrade_id: String) -> int:
	return int(permanent_upgrade_levels.get(upgrade_id, 0))

func get_permanent_upgrade_cost(upgrade_id: String) -> int:
	if not PERMANENT_UPGRADE_IDS.has(upgrade_id):
		return 999999
	var level := get_permanent_upgrade_level(upgrade_id)
	return int(PERMANENT_UPGRADE_BASE_COSTS[upgrade_id]) * (level + 1)

func is_permanent_upgrade_maxed(upgrade_id: String) -> bool:
	return get_permanent_upgrade_level(upgrade_id) >= int(PERMANENT_UPGRADE_MAX_LEVELS.get(upgrade_id, 0))

func purchase_permanent_upgrade(upgrade_id: String) -> bool:
	if not PERMANENT_UPGRADE_IDS.has(upgrade_id) or is_permanent_upgrade_maxed(upgrade_id):
		return false
	var cost := get_permanent_upgrade_cost(upgrade_id)
	if legacy_ore < cost:
		return false
	legacy_ore -= cost
	permanent_upgrade_levels[upgrade_id] = get_permanent_upgrade_level(upgrade_id) + 1
	save_game()
	return true

func award_run_legacy_ore(wave_reached: int, victory: bool) -> int:
	var reward := maxi(1, int(ceil(float(maxi(wave_reached, 1)) / 3.0)))
	if victory:
		reward += 3
	legacy_ore += reward
	last_run_legacy_ore_earned = reward
	save_game()
	return reward

func get_permanent_base_health_bonus() -> int:
	return get_permanent_upgrade_level("reinforced_core") * 15

func get_permanent_starting_gems() -> int:
	return get_permanent_upgrade_level("starter_cache")

func get_permanent_carry_bonus() -> int:
	return get_permanent_upgrade_level("miners_harness")

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
			"first_level_beaten": first_level_beaten,
			"selected_hero_id": selected_hero_id,
			"selected_base_id": selected_base_id,
			"prototype_onboarding_completed": prototype_onboarding_completed,
			"legacy_ore": legacy_ore,
			"permanent_upgrade_levels": permanent_upgrade_levels
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
				if loaded.has("selected_hero_id"):
					selected_hero_id = str(loaded["selected_hero_id"])
				if loaded.has("selected_base_id"):
					selected_base_id = str(loaded["selected_base_id"])
				if loaded.has("prototype_onboarding_completed"):
					prototype_onboarding_completed = bool(loaded["prototype_onboarding_completed"])
				if loaded.has("legacy_ore"):
					legacy_ore = maxi(0, int(loaded["legacy_ore"]))
				if loaded.has("permanent_upgrade_levels") and typeof(loaded["permanent_upgrade_levels"]) == TYPE_DICTIONARY:
					var loaded_upgrades: Dictionary = loaded["permanent_upgrade_levels"]
					for upgrade_id in PERMANENT_UPGRADE_IDS:
						var max_level := int(PERMANENT_UPGRADE_MAX_LEVELS[upgrade_id])
						permanent_upgrade_levels[upgrade_id] = clampi(int(loaded_upgrades.get(upgrade_id, 0)), 0, max_level)
			file.close()
	apply_selected_loadout()

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
