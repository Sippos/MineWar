extends Node

const LEVEL_SCENE: PackedScene = preload("res://scenes/world/mine/level.tscn")
const DUMMY_SCRIPT: Script = preload("res://tests/hero_dummy_enemy.gd")
const HEROES: Array[String] = ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King"]

var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	for hero: String in HEROES:
		await _run_hero_combat_test(hero)
	get_tree().paused = false
	if failures.is_empty():
		print("HERO_COMBAT_BALANCE: PASS (5/5 heroes)")
		get_tree().quit()
		return
	for failure: String in failures:
		push_error(failure)
	print("HERO_COMBAT_BALANCE: FAIL (%d issues)" % failures.size())
	get_tree().quit(1)

func _run_hero_combat_test(hero: String) -> void:
	Global.hero_p1 = hero
	Global.current_hero = hero
	Global.selected_hero_id = hero
	var level: Node = LEVEL_SCENE.instantiate()
	level.name = "CombatBalance_%s" % hero.replace(" ", "_")
	add_child(level)
	await _wait_physics_frames(10)
	var player := level.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		_fail(hero, "Player missing")
		await _remove_level(level)
		return
	var abilities: Node = player.get_node_or_null("HeroAbilities")
	var balance: Node = player.get_node_or_null("HeroBalanceController")
	if abilities == null or balance == null:
		_fail(hero, "ability or balance controller missing")
		await _remove_level(level)
		return
	player.set("level", 6)
	player.set("strength", 3)
	player.set("agility", 3)
	player.set("intelligence", 3)
	var dummies: Array[CharacterBody2D] = _spawn_dummies(level, player.global_position)
	match hero:
		"Dwarf":
			await _test_dwarf(hero, player, abilities, dummies)
		"Shaman":
			await _test_shaman(hero, player, abilities, dummies)
		"Nerubian":
			await _test_nerubian(hero, player, abilities, balance, dummies)
		"Druid":
			await _test_druid(hero, level, player, abilities, balance, dummies)
		"Undead King":
			await _test_undead(hero, player, abilities, balance, dummies)
	print("COMBAT_BALANCE %s: total_damage=%d summons=%d" % [hero, _total_dummy_damage(dummies), _friendly_summon_count(player)])
	await _remove_level(level)

func _spawn_dummies(level: Node, origin: Vector2) -> Array[CharacterBody2D]:
	var result: Array[CharacterBody2D] = []
	var offsets: Array[Vector2] = [Vector2(90, 0), Vector2(185, 0), Vector2(280, 0), Vector2(80, 95)]
	for index: int in range(offsets.size()):
		var dummy := CharacterBody2D.new()
		dummy.name = "BalanceDummy%d" % index
		dummy.set_script(DUMMY_SCRIPT)
		level.add_child(dummy)
		dummy.global_position = origin + offsets[index]
		result.append(dummy)
	return result

func _test_dwarf(hero: String, player: CharacterBody2D, abilities: Node, dummies: Array[CharacterBody2D]) -> void:
	player.set("stomp_level", 3)
	abilities.set("hammer_level", 3)
	abilities.set("bash_level", 3)
	abilities.set("avatar_level", 1)
	abilities.set("facing_direction", Vector2.RIGHT)
	abilities.call("_try_activate_avatar")
	if not bool(abilities.get("avatar_active")):
		_fail(hero, "Avatar did not activate")
	abilities.call("_try_throw_hammer")
	await get_tree().process_frame
	var hit_count := _damaged_dummy_count(dummies)
	if hit_count < 3:
		_fail(hero, "Avatar hammer should cleave three targets, hit %d" % hit_count)
	if float(abilities.get("hammer_cooldown")) < 4.0 or float(abilities.get("hammer_cooldown")) > 9.0:
		_fail(hero, "Hammer cooldown outside playable range")
	if _max_dummy_damage(dummies) > 420:
		_fail(hero, "Hammer burst is overtuned")

func _test_shaman(hero: String, player: CharacterBody2D, abilities: Node, dummies: Array[CharacterBody2D]) -> void:
	abilities.set("totem_level", 3)
	abilities.set("chain_level", 3)
	abilities.set("wisdom_level", 3)
	abilities.set("ascendance_level", 1)
	abilities.set("facing_direction", Vector2.RIGHT)
	abilities.call("_try_chain_lightning")
	await get_tree().process_frame
	if _damaged_dummy_count(dummies) < 3:
		_fail(hero, "Chain Lightning did not chain through a useful pack")
	var chain_cd := float(abilities.get("chain_cooldown"))
	if chain_cd < 2.4 or chain_cd > 8.0:
		_fail(hero, "Chain Lightning cooldown outside playable range: %.2f" % chain_cd)
	abilities.call("_try_ascendance")
	await _wait_physics_frames(2)
	if not bool(abilities.get("ascendance_active")):
		_fail(hero, "Ascendance did not activate")
	if _owned_group_count("shaman_totems", player) < 4:
		_fail(hero, "Ascendance did not create the four-totem formation")

func _test_nerubian(hero: String, player: CharacterBody2D, abilities: Node, balance: Node, dummies: Array[CharacterBody2D]) -> void:
	abilities.set("brood_level", 3)
	abilities.set("web_level", 3)
	abilities.set("carapace_level", 3)
	abilities.set("broodmother_level", 1)
	abilities.call("_try_web_burst")
	await get_tree().process_frame
	if _damaged_dummy_count(dummies) < 3:
		_fail(hero, "Web Burst did not control a nearby pack")
	var before_bites := _total_dummy_damage(dummies)
	var spawned: bool = bool(abilities.call("_try_spawn_brood", true))
	await _wait_physics_frames(120)
	if not spawned or _owned_group_count("nerubian_spiders", player) < 1:
		_fail(hero, "Spawn Brood produced no spider")
	if _total_dummy_damage(dummies) <= before_bites:
		_fail(hero, "Brood spiders did not defend or bite nearby enemies")
	abilities.call("_try_broodmother")
	await _wait_physics_frames(2)
	if not bool(abilities.get("broodmother_active")):
		_fail(hero, "Broodmother's Call did not activate")
	if _owned_group_count("nerubian_spiders", player) < 3:
		_fail(hero, "Broodmother's Call did not establish a real brood")
	if not balance.has_method("_process_nerubian_claw_mining"):
		_fail(hero, "Nerubian manual mining fallback missing")

func _test_druid(hero: String, level: Node, player: CharacterBody2D, abilities: Node, balance: Node, dummies: Array[CharacterBody2D]) -> void:
	abilities.set("mole_level", 3)
	abilities.set("tunnel_level", 3)
	abilities.set("deep_roots_level", 3)
	abilities.set("worldroot_level", 1)
	var health_before := int(player.get("max_health")) - 12
	player.set("health", health_before)
	abilities.call("_try_cast_mole_form")
	await _wait_physics_frames(3)
	if not bool(player.get("druid_mole_active")):
		_fail(hero, "Mole Form did not activate")
	if float(player.get("base_speed")) < 245.0:
		_fail(hero, "Mole Form lacks a meaningful movement burst")
	var before_pulse := _total_dummy_damage(dummies)
	balance.call("_druid_burrow_pulse")
	await get_tree().process_frame
	if _total_dummy_damage(dummies) <= before_pulse:
		_fail(hero, "Burrow pulse did not affect nearby enemies")
	await _wait_physics_frames(90)
	if int(player.get("health")) <= health_before:
		_fail(hero, "Deep Roots did not regenerate health")
	var first_position := player.global_position
	abilities.set("facing_direction", Vector2.RIGHT)
	abilities.call("_try_place_or_use_tunnel")
	player.global_position = first_position + Vector2(220, 0)
	abilities.call("_try_place_or_use_tunnel")
	abilities.set("tunnel_cooldown", 0.0)
	player.global_position = first_position
	abilities.call("_try_place_or_use_tunnel")
	if player.global_position.distance_to(first_position) < 120.0:
		_fail(hero, "Burrow Tunnel did not transport the Druid")
	var base := level.get_node_or_null("Base") as Node2D
	abilities.set("worldroot_cooldown", 0.0)
	abilities.call("_try_worldroot_passage")
	if base != null and player.global_position.distance_to(base.global_position) > 120.0:
		_fail(hero, "Worldroot Passage did not return to base")

func _test_undead(hero: String, player: CharacterBody2D, abilities: Node, balance: Node, dummies: Array[CharacterBody2D]) -> void:
	abilities.set("undead_summon_level", 3)
	abilities.set("grave_might_level", 3)
	abilities.set("soul_harvest_level", 3)
	abilities.set("death_march_level", 1)
	abilities.call("_try_summon_undead_minion")
	await _wait_physics_frames(120)
	if _owned_group_count("undead_minions", player) < 1:
		_fail(hero, "Raise Dead produced no minion")
	var before_command := _total_dummy_damage(dummies)
	balance.call("_try_grave_might")
	await _wait_physics_frames(2)
	if not bool(balance.get("grave_might_active")):
		_fail(hero, "Grave Might command did not activate")
	if _total_dummy_damage(dummies) <= before_command:
		_fail(hero, "Grave Might produced no combat impact")
	abilities.call("_try_death_march")
	await _wait_physics_frames(2)
	if float(abilities.get("death_march_cooldown")) <= 0.0:
		_fail(hero, "Death March did not activate")
	if _owned_group_count("undead_minions", player) < 2:
		_fail(hero, "Death March did not reinforce the army")

func _damaged_dummy_count(dummies: Array[CharacterBody2D]) -> int:
	var count := 0
	for dummy: CharacterBody2D in dummies:
		if is_instance_valid(dummy) and int(dummy.get("total_damage_taken")) > 0:
			count += 1
	return count

func _total_dummy_damage(dummies: Array[CharacterBody2D]) -> int:
	var total := 0
	for dummy: CharacterBody2D in dummies:
		if is_instance_valid(dummy):
			total += int(dummy.get("total_damage_taken"))
	return total

func _max_dummy_damage(dummies: Array[CharacterBody2D]) -> int:
	var maximum := 0
	for dummy: CharacterBody2D in dummies:
		if is_instance_valid(dummy):
			maximum = maxi(maximum, int(dummy.get("total_damage_taken")))
	return maximum

func _friendly_summon_count(owner_player: Node) -> int:
	return _owned_group_count("shaman_totems", owner_player) + _owned_group_count("nerubian_spiders", owner_player) + _owned_group_count("undead_minions", owner_player)

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
