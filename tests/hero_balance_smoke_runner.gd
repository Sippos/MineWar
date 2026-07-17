extends Node

const LEVEL_SCENE: PackedScene = preload("res://scenes/world/mine/level.tscn")
const LEVEL_UP_SCENE: PackedScene = preload("res://scenes/ui/overlays/level_up/level_up_menu.tscn")
const HEROES := ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King"]
const EXPECTED_PROFILES := {
	"Dwarf": {"health": 40, "speed": 190.0, "dig_time": 0.36},
	"Shaman": {"health": 32, "speed": 205.0, "dig_time": 0.42},
	"Nerubian": {"health": 36, "speed": 215.0, "dig_time": 0.46},
	"Druid": {"health": 34, "speed": 210.0, "dig_time": 0.39},
	"Undead King": {"health": 38, "speed": 195.0, "dig_time": 0.43}
}

var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	for hero: String in HEROES:
		await _test_hero(hero)
	get_tree().paused = false
	if failures.is_empty():
		print("HERO_BALANCE_SMOKE: PASS (5/5 heroes)")
		get_tree().quit()
		return
	for failure: String in failures:
		push_error(failure)
	print("HERO_BALANCE_SMOKE: FAIL (%d issues)" % failures.size())
	get_tree().quit(1)

func _test_hero(hero: String) -> void:
	Global.hero_p1 = hero
	Global.current_hero = hero
	Global.selected_hero_id = hero
	var level := LEVEL_SCENE.instantiate()
	level.name = "SmokeLevel_%s" % hero.replace(" ", "_")
	add_child(level)
	await _wait_physics_frames(8)
	var player := level.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		_fail(hero, "Player node missing")
		await _remove_level(level)
		return
	var abilities := player.get_node_or_null("HeroAbilities")
	var balance := player.get_node_or_null("HeroBalanceController")
	if abilities == null:
		_fail(hero, "HeroAbilities controller missing")
	if balance == null:
		_fail(hero, "HeroBalanceController missing")
	if str(player.get("current_hero_name")) != hero:
		_fail(hero, "wrong hero loaded: %s" % str(player.get("current_hero_name")))
	_validate_profile(hero, player)
	var sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		_fail(hero, "hero sprite missing")
	elif sprite.scale.x <= 0.0 or sprite.scale.y <= 0.0:
		_fail(hero, "invalid sprite scale")
	if abilities != null:
		await _validate_level_up_menu(hero, level, player, abilities)
		await _exercise_hero(hero, player, abilities, balance, sprite)
	var scale_value := sprite.scale.x if sprite != null else 0.0
	print("HERO_SMOKE %s: hp=%d speed=%.1f dig=%.2f scale=%.2f" % [
		hero,
		int(player.get("max_health")),
		float(player.get("base_speed")),
		float(player.get("base_dig_time")),
		scale_value
	])
	await _remove_level(level)

func _validate_profile(hero: String, player: CharacterBody2D) -> void:
	var expected: Dictionary = EXPECTED_PROFILES[hero]
	if int(player.get("max_health")) != int(expected["health"]):
		_fail(hero, "health profile mismatch: %d" % int(player.get("max_health")))
	if absf(float(player.get("base_speed")) - float(expected["speed"])) > 0.1:
		_fail(hero, "speed profile mismatch: %.1f" % float(player.get("base_speed")))
	if absf(float(player.get("base_dig_time")) - float(expected["dig_time"])) > 0.01:
		_fail(hero, "dig-time profile mismatch: %.2f" % float(player.get("base_dig_time")))

func _validate_level_up_menu(hero: String, level: Node, player: CharacterBody2D, abilities: Node) -> void:
	var options: Array = abilities.call("get_level_up_options")
	if options.size() != 4:
		_fail(hero, "expected four ability choices, got %d" % options.size())
	var menu := LEVEL_UP_SCENE.instantiate()
	level.add_child(menu)
	menu.call("setup_for_player", player)
	await get_tree().process_frame
	await get_tree().process_frame
	var callback := Callable(abilities, "_on_upgrade_selected")
	if not menu.is_connected("upgrade_selected", callback):
		_fail(hero, "level-up menu did not connect to HeroAbilities")
	menu.queue_free()
	await get_tree().process_frame
	get_tree().paused = false

func _exercise_hero(hero: String, player: CharacterBody2D, abilities: Node, balance: Node, sprite: Sprite2D) -> void:
	match hero:
		"Dwarf":
			if int(player.get("stomp_level")) < 1:
				_fail(hero, "Ground Stomp is not available at level 1")
			abilities.set("hammer_level", 1)
			abilities.call("_try_throw_hammer")
			if float(abilities.get("hammer_cooldown")) <= 0.0:
				_fail(hero, "Throwing Hammer did not activate")
		"Shaman":
			if int(abilities.get("totem_level")) < 1:
				_fail(hero, "Totem Wheel is not available at level 1")
			abilities.call("_spawn_all_totems")
			await get_tree().process_frame
			if _owned_group_count("shaman_totems", player) < 4:
				_fail(hero, "Ascendance totem set did not spawn four totems")
		"Nerubian":
			if int(abilities.get("brood_level")) < 1:
				_fail(hero, "Spawn Brood is not available at level 1")
			var spawned: bool = bool(abilities.call("_try_spawn_brood", true))
			await get_tree().process_frame
			if not spawned or _owned_group_count("nerubian_spiders", player) < 1:
				_fail(hero, "brood summon produced no spider")
			if sprite != null and sprite.scale.x < 0.75:
				_fail(hero, "Nerubian is still visually too small (scale %.2f)" % sprite.scale.x)
			if balance == null or not balance.has_method("_process_nerubian_claw_mining"):
				_fail(hero, "manual claw-mining fallback is unavailable")
		"Druid":
			if int(abilities.get("mole_level")) < 1:
				_fail(hero, "Mole Form is not available at level 1")
			abilities.call("_try_cast_mole_form")
			await _wait_physics_frames(3)
			if not bool(player.get("druid_mole_active")):
				_fail(hero, "Mole Form did not activate")
			if sprite != null and sprite.scale.x < 0.80:
				_fail(hero, "Mole Form is still visually too small (scale %.2f)" % sprite.scale.x)
			if float(player.get("base_speed")) < 240.0:
				_fail(hero, "Mole Form speed burst did not apply")
		"Undead King":
			if int(abilities.get("undead_summon_level")) < 1:
				_fail(hero, "Raise Dead is not available at level 1")
			abilities.set("grave_might_level", 1)
			abilities.call("_try_summon_undead_minion")
			await get_tree().process_frame
			if _owned_group_count("undead_minions", player) < 1:
				_fail(hero, "Raise Dead produced no minion")
			elif balance != null:
				balance.call("_try_grave_might")
				await get_tree().process_frame
				if not bool(balance.get("grave_might_active")):
					_fail(hero, "Grave Might command did not activate")

func _owned_group_count(group_name: String, owner_player: Node) -> int:
	var count := 0
	for node: Node in get_tree().get_nodes_in_group(group_name):
		if not is_instance_valid(node):
			continue
		if group_name == "shaman_totems":
			if int(node.get_meta("hero_owner_id", -1)) == owner_player.get_instance_id():
				count += 1
		elif node.get("owner_player") == owner_player:
			count += 1
	return count

func _remove_level(level: Node) -> void:
	get_tree().paused = false
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

func _wait_physics_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame

func _fail(hero: String, message: String) -> void:
	failures.append("%s: %s" % [hero, message])
