extends Node

const LEVEL_SCENE: PackedScene = preload("res://scenes/world/mine/level.tscn")
const HEROES: Array[String] = ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King"]
const EXPECTED_START: Dictionary = {
	"Dwarf": {"strength": 4, "agility": 2, "intelligence": 1, "primary": "strength", "level6": [8, 3, 2]},
	"Shaman": {"strength": 1, "agility": 2, "intelligence": 4, "primary": "intelligence", "level6": [2, 3, 8]},
	"Nerubian": {"strength": 2, "agility": 4, "intelligence": 1, "primary": "agility", "level6": [4, 8, 2]},
	"Druid": {"strength": 2, "agility": 2, "intelligence": 4, "primary": "intelligence", "level6": [4, 4, 7]},
	"Undead King": {"strength": 2, "agility": 1, "intelligence": 4, "primary": "intelligence", "level6": [4, 2, 8]}
}

var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	for hero: String in HEROES:
		await _test_hero(hero)
	if failures.is_empty():
		print("HERO_RPG_SYSTEM: PASS (5/5 heroes)")
		get_tree().quit()
		return
	for failure: String in failures:
		push_error(failure)
	print("HERO_RPG_SYSTEM: FAIL (%d issues)" % failures.size())
	get_tree().quit(1)

func _test_hero(hero: String) -> void:
	Global.hero_p1 = hero
	Global.current_hero = hero
	Global.selected_hero_id = hero
	var level: Node = LEVEL_SCENE.instantiate()
	level.name = "RPGLevel_%s" % hero.replace(" ", "_")
	add_child(level)
	await _wait_physics_frames(8)
	var player: CharacterBody2D = level.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		_fail(hero, "Player missing")
		await _remove_level(level)
		return
	var rpg: Node = player.get_node_or_null("HeroRPGController")
	if rpg == null:
		_fail(hero, "HeroRPGController missing")
		await _remove_level(level)
		return
	var expected: Dictionary = EXPECTED_START[hero]
	_assert_int(hero, "starting Strength", int(player.get("strength")), int(expected["strength"]))
	_assert_int(hero, "starting Agility", int(player.get("agility")), int(expected["agility"]))
	_assert_int(hero, "starting Intelligence", int(player.get("intelligence")), int(expected["intelligence"]))
	var primary: String = str(rpg.call("get_primary_attribute"))
	if primary != str(expected["primary"]):
		_fail(hero, "primary attribute is %s, expected %s" % [primary, str(expected["primary"])])
	var starting_damage: int = int(rpg.call("get_basic_attack_damage"))
	var starting_interval: float = float(rpg.call("get_attack_interval"))
	var starting_armor: float = float(rpg.call("get_armor"))
	var starting_spell: float = float(rpg.call("get_spell_power_multiplier"))
	var starting_summon: float = float(rpg.call("get_summon_power_multiplier"))
	var starting_cooldown: float = float(rpg.call("get_cooldown_multiplier"))
	if starting_damage <= 0 or starting_interval <= 0.0 or starting_armor < 0.0:
		_fail(hero, "invalid starting derived combat values")
	var original_max_health: int = int(player.get("max_health"))
	player.call("upgrade_strength")
	if int(player.get("strength")) != int(expected["strength"]) + 1:
		_fail(hero, "Strength investment did not persist")
	if int(player.get("max_health")) != original_max_health + 6:
		_fail(hero, "Strength should grant exactly +6 maximum health")
	var damage_after_strength: int = int(rpg.call("get_basic_attack_damage"))
	if damage_after_strength <= starting_damage:
		_fail(hero, "Strength did not improve basic attack damage")
	var interval_before_agility: float = float(rpg.call("get_attack_interval"))
	var armor_before_agility: float = float(rpg.call("get_armor"))
	var speed_before_agility: float = float(rpg.call("get_move_speed"))
	player.call("upgrade_agility")
	if float(rpg.call("get_attack_interval")) >= interval_before_agility:
		_fail(hero, "Agility did not increase attack speed")
	if float(rpg.call("get_armor")) <= armor_before_agility:
		_fail(hero, "Agility did not increase armor")
	if float(rpg.call("get_move_speed")) <= speed_before_agility:
		_fail(hero, "Agility did not increase movement speed")
	player.call("upgrade_intelligence")
	if float(rpg.call("get_spell_power_multiplier")) <= starting_spell:
		_fail(hero, "Intelligence did not increase spell power")
	if float(rpg.call("get_summon_power_multiplier")) <= starting_summon:
		_fail(hero, "Intelligence did not increase summon power")
	if float(rpg.call("get_cooldown_multiplier")) >= starting_cooldown:
		_fail(hero, "Intelligence did not improve cooldown recovery")
	var reduced_damage: int = int(rpg.call("modify_incoming_damage", 100))
	if reduced_damage >= 100 or reduced_damage <= 0:
		_fail(hero, "armor reduction produced invalid damage: %d" % reduced_damage)
	# Use a fresh hero instance for deterministic level-growth checks, without the
	# three investment points exercised above.
	await _remove_level(level)
	Global.hero_p1 = hero
	Global.current_hero = hero
	Global.selected_hero_id = hero
	var growth_level: Node = LEVEL_SCENE.instantiate()
	growth_level.name = "GrowthLevel_%s" % hero.replace(" ", "_")
	add_child(growth_level)
	await _wait_physics_frames(8)
	var growth_player: CharacterBody2D = growth_level.get_node_or_null("Player") as CharacterBody2D
	var growth_rpg: Node = growth_player.get_node_or_null("HeroRPGController") if growth_player != null else null
	if growth_player == null or growth_rpg == null:
		_fail(hero, "growth-test controller missing")
		await _remove_level(growth_level)
		return
	growth_player.set("level", 6)
	await _wait_physics_frames(3)
	var expected_level6: Array = expected["level6"]
	_assert_int(hero, "level-6 Strength", int(growth_player.get("strength")), int(expected_level6[0]))
	_assert_int(hero, "level-6 Agility", int(growth_player.get("agility")), int(expected_level6[1]))
	_assert_int(hero, "level-6 Intelligence", int(growth_player.get("intelligence")), int(expected_level6[2]))
	var summary: String = "%s primary=%s start=%d/%d/%d level6=%d/%d/%d damage=%d aps=%.2f armor=%.2f" % [
		hero,
		primary,
		int(expected["strength"]),
		int(expected["agility"]),
		int(expected["intelligence"]),
		int(growth_player.get("strength")),
		int(growth_player.get("agility")),
		int(growth_player.get("intelligence")),
		int(growth_rpg.call("get_basic_attack_damage")),
		float(growth_rpg.call("get_attacks_per_second")),
		float(growth_rpg.call("get_armor"))
	]
	print("RPG_PROFILE " + summary)
	await _remove_level(growth_level)

func _assert_int(hero: String, label: String, actual: int, expected: int) -> void:
	if actual != expected:
		_fail(hero, "%s is %d, expected %d" % [label, actual, expected])

func _wait_physics_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame

func _remove_level(level: Node) -> void:
	get_tree().paused = false
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

func _fail(hero: String, message: String) -> void:
	failures.append("%s: %s" % [hero, message])
