extends Node

const LEVEL_SCENE: PackedScene = preload("res://scenes/world/mine/level.tscn")
const HEROES := ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King"]

var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	for hero in HEROES:
		await _test_hero(hero)
	if failures.is_empty():
		print("HERO_BALANCE_SMOKE: PASS (5/5 heroes)")
		get_tree().quit()
	else:
		for failure in failures:
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
	await _wait_physics_frames(5)
	var player := level.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		_fail(hero, "Player node missing")
		level.queue_free()
		await get_tree().process_frame
		return
	var abilities := player.get_node_or_null("HeroAbilities")
	var balance := player.get_node_or_null("HeroBalanceController")
	if abilities == null:
		_fail(hero, "HeroAbilities controller missing")
	if balance == null:
		_fail(hero, "HeroBalanceController missing")
	if str(player.get("current_hero_name")) != hero:
		_fail(hero, "wrong hero loaded: %s" % str(player.get("current_hero_name")))
	var sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		_fail(hero, "hero sprite missing")
	elif sprite.scale.x <= 0.0 or sprite.scale.y <= 0.0:
		_fail(hero, "invalid sprite scale")
	var upgrade_menu := level.get_node_or_null("UpgradeMenu")
	if upgrade_menu and abilities:
		var callback := Callable(abilities, "_on_upgrade_selected")
		if not upgrade_menu.is_connected("upgrade_selected", callback):
			_fail(hero, "level-up ability signal not connected")
	if abilities and balance:
		match hero:
			"Dwarf":
				abilities.set("hammer_level", 1)
				abilities.call("_try_throw_hammer")
			"Shaman":
				abilities.set("totem_level", 1)
				abilities.call("_spawn_all_totems")
				await get_tree().process_frame
				if get_tree().get_nodes_in_group("shaman_totems").is_empty():
					_fail(hero, "totem summon produced no totems")
			"Nerubian":
				abilities.set("brood_level", 1)
				var spawned = abilities.call("_try_spawn_brood", false)
				await get_tree().process_frame
				if spawned != true or get_tree().get_nodes_in_group("nerubian_spiders").is_empty():
					_fail(hero, "brood summon produced no spider")
				if sprite and sprite.scale.x < 0.58:
					_fail(hero, "Nerubian is still visually too small (scale %.2f)" % sprite.scale.x)
			"Druid":
				abilities.set("mole_level", 1)
				abilities.call("_try_cast_mole_form")
				await _wait_physics_frames(2)
				if not bool(player.get("druid_mole_active")):
					_fail(hero, "Mole Form did not activate")
				if sprite and sprite.scale.x < 0.80:
					_fail(hero, "Mole Form is still visually too small (scale %.2f)" % sprite.scale.x)
			"Undead King":
				abilities.set("grave_might_level", 1)
				abilities.call("_try_summon_undead_minion")
				await get_tree().process_frame
				balance.call("_try_grave_might")
				await get_tree().process_frame
				if get_tree().get_nodes_in_group("undead_minions").is_empty():
					_fail(hero, "Raise Dead produced no minion")
				if not bool(balance.get("grave_might_active")):
					_fail(hero, "Grave Might command did not activate")
	print("HERO_SMOKE %s: hp=%d speed=%.1f scale=%.2f" % [hero, int(player.get("max_health")), float(player.get("base_speed")), sprite.scale.x if sprite else 0.0])
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _wait_physics_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().physics_frame

func _fail(hero: String, message: String) -> void:
	failures.append("%s: %s" % [hero, message])
