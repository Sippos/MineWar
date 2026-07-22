extends Node

const LEVEL_SCENE := preload("res://scenes/world/mine/level.tscn")
const HUB_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")
const SIEGE_SCRIPT := preload("res://scripts/systems/world_generation/siege_mode_controller.gd")
const TEST_SAVE_PATH := "user://minewars_complete_run_test.save"
const TEST_MECH_SAVE_PATH := "user://minewars_complete_run_mech_test.save"
const PATTERN: Array[Vector2i] = [
	Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1),
]

var failures := 0
var level: Node
var controller: Node
var player: Node
var base: Node
var hud: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	_configure_isolated_fresh_save()
	await _create_real_minewars_level()
	if controller == null or level == null:
		_finish()
		return

	_test_initial_journey_state()
	_test_build_identities()
	if bool(controller.get("first_run_training_active")):
		level.set("onboarding_active", false)
		Global.complete_prototype_onboarding()
		await _wait_frames(4)
		_expect(not bool(controller.get("first_run_training_active")), "Completing the tutorial should start the first expedition clock")

	var initial_gems := int(hud.get("total_gems"))
	await _complete_stage_objective(1)
	_expect(int(hud.get("total_gems")) == initial_gems + 2, "Stage 1 Rich Vein should award two secured gems")
	await _clear_standard_assault(1, 3, [0, 0, 0], 16.0)
	_expect(int(hud.get("total_gems")) == initial_gems + 3, "Stage 1 assault should add one salvage gem")

	controller.call("_begin_next_expedition")
	var carry_before := int(player.call("get_free_carry_allowance"))
	await _complete_stage_objective(2)
	_expect(int(player.call("get_free_carry_allowance")) == carry_before + 1, "Stage 2 Miner's Satchel should add one free carry slot")
	await _clear_standard_assault(2, 5, [0, 0, 1, 1, 2], 13.0)

	controller.call("_begin_next_expedition")
	var pick_before := int(player.get("mining_power_level"))
	await _complete_stage_objective(3)
	_expect(int(player.get("mining_power_level")) == mini(pick_before + 1, 3), "Stage 3 Ancient Forge should grant one Pick Power")
	await _clear_standard_assault(3, 7, [1, 1, 2, 2, 3, 3, 4], 10.0)

	controller.call("_begin_next_expedition")
	var gems_before_final := int(hud.get("total_gems"))
	await _complete_stage_objective(4)
	_expect(int(hud.get("total_gems")) == gems_before_final + 3, "Stage 4 Heart Cache should grant three boss-preparation gems")
	await _run_boss_finale()
	await _verify_victory_progression_and_reload()
	await _verify_stronghold_return()
	_finish()

func _configure_isolated_fresh_save() -> void:
	Global.set_save_path_override(TEST_SAVE_PATH)
	MechUnlockPersistence.set_save_path_override(TEST_MECH_SAVE_PATH)
	_remove_user_file(TEST_SAVE_PATH)
	_remove_user_file(TEST_MECH_SAVE_PATH)
	MechUnlockPersistence.mech_defeated = false
	Global.unlocked_heroes = Global.DEFAULT_UNLOCKED_HEROES.duplicate()
	Global.unlocked_bases = Global.DEFAULT_UNLOCKED_BASES.duplicate()
	Global.first_level_beaten = false
	Global.minewars_runs_completed = 0
	Global.minewars_victories = 0
	Global.hero_victories = {}
	Global.unlocked_stronghold_ambience = []
	Global.current_hero = Global.DEFAULT_HERO_ID
	Global.hero_p1 = Global.DEFAULT_HERO_ID
	Global.hero_p2 = Global.DEFAULT_HERO_ID
	Global.selected_hero_id = Global.DEFAULT_HERO_ID
	Global.selected_base_id = Global.DEFAULT_BASE_ID
	Global.prototype_onboarding_completed = false
	Global.legacy_ore = 0
	Global.last_run_legacy_ore_earned = 0
	Global.pending_unlock_rewards = []
	Global.last_unlock_rewards = []
	Global.permanent_upgrade_levels = {"reinforced_core": 0, "starter_cache": 0, "miners_harness": 0}
	Global.apply_selected_loadout()
	Global.save_game()

func _create_real_minewars_level() -> void:
	GameMode.set_mode(GameMode.Mode.SIEGE)
	level = LEVEL_SCENE.instantiate()
	level.set("is_vs_mode", false)
	level.set("preparation_mode", false)
	controller = Node2D.new()
	controller.name = "SiegeModeController"
	controller.set_script(SIEGE_SCRIPT)
	level.add_child(controller)
	add_child(level)
	await _wait_frames(24)
	player = level.get_node_or_null("Player")
	base = level.get_node_or_null("Base")
	hud = level.get_node_or_null("HUD")
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	if base:
		base.process_mode = Node.PROCESS_MODE_DISABLED
	if controller:
		controller.set("upgrade_menu", null)
	_expect(controller != null and is_instance_valid(controller), "The real MineWars controller should activate")
	_expect(player != null and base != null and hud != null, "The complete-run test requires the real Player, Base, and HUD")

func _test_initial_journey_state() -> void:
	_expect(Global.unlocked_heroes.has("Dwarf"), "A fresh save should begin with the Dwarf")
	_expect(not Global.unlocked_heroes.has("Shaman"), "A fresh save should not advertise Shaman before victory")
	_expect(Global.unlocked_bases == ["default_base"], "A fresh save should begin with only the Dwarf Bastion")
	_expect(int(controller.get("stage_number")) == 1, "MineWars should begin at Expedition 1")
	_expect(str(level.get_meta("minewars_phase", "")) == "mining", "The first phase should be mining")
	_expect(absf(float(controller.get("mining_timer")) - 90.0) < 2.0, "The first expedition should provide a generous exploration window")
	_expect(str(level.get_meta("minewars_objective_title", "")) == "RICH VEIN", "The first descent should have a readable objective")

func _test_build_identities() -> void:
	var rpg := player.get_node_or_null("HeroRPGController")
	_expect(rpg != null and rpg.has_method("get_build_identity"), "The hero should expose a readable roguelike build identity")
	if rpg == null:
		return
	var original: Dictionary = rpg.get("permanent_stat_bonuses").duplicate(true)
	_set_build_bonuses(rpg, {"strength": 5, "agility": 0, "intelligence": 0})
	_expect(str((rpg.call("get_build_identity") as Dictionary).get("title", "")) == "EARTHBREAKER", "Five Strength upgrades should form an Earthbreaker build")
	_expect(float(rpg.call("get_mining_force_multiplier", 3)) < 0.65, "Strength should visibly reduce ancient-rock resistance")
	_set_build_bonuses(rpg, {"strength": 0, "agility": 5, "intelligence": 0})
	_expect(str((rpg.call("get_build_identity") as Dictionary).get("title", "")) == "VEIN RUNNER", "Five Agility upgrades should form a Vein Runner build")
	_expect(float(rpg.call("get_dig_time_multiplier")) < 0.82, "Agility should visibly improve mining cadence")
	_set_build_bonuses(rpg, {"strength": 0, "agility": 0, "intelligence": 5})
	_expect(str((rpg.call("get_build_identity") as Dictionary).get("title", "")) == "RUNECASTER", "Five Intelligence upgrades should form a Runecaster build")
	_expect(float(rpg.call("get_cooldown_multiplier")) < 0.90, "Intelligence should visibly shorten ability cooldowns")
	_set_build_bonuses(rpg, original)

func _set_build_bonuses(rpg: Node, bonuses: Dictionary) -> void:
	rpg.set("permanent_stat_bonuses", bonuses.duplicate(true))
	rpg.call("_write_stats_and_health", false, true)

func _complete_stage_objective(stage: int) -> void:
	_expect(int(controller.get("stage_number")) == stage, "Objective should belong to Expedition %d" % stage)
	var targets := [2, 3, 4, 5]
	var target: int = targets[stage - 1]
	var center: Vector2i = level.get("minewars_motherlodes")[stage]
	var first_cell := center + PATTERN[0]
	level.call("notify_minewars_gem_dug", first_cell)
	level.call("notify_minewars_gem_dug", first_cell)
	await _wait_frames(2)
	_expect(int(controller.get("objective_progress")) == 1, "Duplicate mining events should not double-count an objective crystal")
	var ui_layer_node: Node = controller.get("ui_layer") as Node
	var ui_children_before: int = ui_layer_node.get_child_count()
	for index in range(1, target):
		level.call("notify_minewars_gem_dug", center + PATTERN[index])
	await _wait_frames(3)
	_expect(bool(controller.get("objective_completed")), "Expedition %d objective should complete at its authored target" % stage)
	_expect(bool(level.get_meta("minewars_objective_complete", false)), "Objective completion should be exposed to the run state")
	_expect(controller.get("ui_layer").get_child_count() > ui_children_before, "Objective completion should create a visible reward burst")

func _clear_standard_assault(stage: int, expected_count: int, expected_types: Array, expected_muster: float) -> void:
	controller.set("mining_timer", 0.01)
	await get_tree().create_timer(0.10).timeout
	_expect(str(level.get_meta("minewars_phase", "")) == "attack", "Expedition %d should enter its assault" % stage)
	_expect(absf(float(controller.get("assault_muster_timer")) - expected_muster) < 0.5, "Expedition %d should provide its authored return grace" % stage)
	controller.set("assault_muster_timer", 0.01)
	await get_tree().create_timer(1.0 + float(expected_count) * 0.48).timeout
	var enemies := _world_enemies()
	_expect(enemies.size() == expected_count, "Assault %d should spawn %d enemies" % [stage, expected_count])
	_expect(_enemy_types(enemies) == expected_types, "Assault %d should use its distinct enemy roster" % stage)
	_clear_enemies()
	await _wait_frames(12)
	_expect(str(level.get_meta("minewars_phase", "")) == "recovery", "Clearing Assault %d should enter a safe recovery phase" % stage)
	_expect(int(controller.get("stage_number")) == stage + 1, "Clearing Assault %d should advance the expedition" % stage)

func _run_boss_finale() -> void:
	controller.set("mining_timer", 0.01)
	await get_tree().create_timer(0.10).timeout
	_expect(absf(float(controller.get("assault_muster_timer")) - 8.0) < 0.5, "The final assault should still provide a fair return countdown")
	controller.set("assault_muster_timer", 0.01)
	await get_tree().create_timer(1.8).timeout
	var boss := _find_boss_mech()
	_expect(boss != null, "The final assault should spawn the Mech boss")
	if boss == null:
		return
	_expect(int(boss.get("health")) == 540, "The Mech should use the current four-expedition health budget")
	_expect(int(boss.get("damage")) == 9, "The Mech should begin with survivable but dangerous damage")
	_expect(absf(float(boss.get("speed")) - 46.0) < 0.2, "The Mech should begin as a readable advancing threat")
	boss.set("health", 340)
	await get_tree().create_timer(2.0).timeout
	_expect(int(controller.get("boss_phase")) >= 1, "The Mech should enter phase two below 68% health")
	_expect(_count_enemy_type(1) >= 2, "The first boss phase should release a spider guard")
	_clear_non_boss_enemies()
	boss.set("health", 180)
	await get_tree().create_timer(0.12).timeout
	_expect(int(controller.get("pending_reinforcement_batches")) > 0, "The final phase should register its pending reinforcement breach")
	boss.call("take_damage", 99999)
	await _wait_frames(4)
	_expect(int(level.get("current_wave_number")) == 4, "Destroying the Mech must not complete the run while the pilot or reinforcements remain")
	var pilot := level.get_node_or_null("GoblinPilot")
	_expect(pilot != null, "Destroying the Mech should eject a distinct goblin pilot")
	await get_tree().create_timer(2.2).timeout
	_expect(int(controller.get("boss_phase")) == 2, "The Mech should reach its final phase")
	_expect(controller.get("secondary_entrance_marker") != null, "The final phase should tear open a second visible breach")
	_expect(_count_enemy_type(2) >= 2 and _count_enemy_type(3) >= 1, "The second breach should add bats and a trogg")
	_clear_non_boss_enemies()
	pilot = level.get_node_or_null("GoblinPilot")
	if pilot:
		pilot.call("take_damage", 99999)
	await get_tree().create_timer(0.5).timeout
	_expect(Global.unlocked_heroes.has("Mech"), "Defeating the escaping pilot should unlock the Mech hero")
	_expect(Global.unlocked_bases.has("mech_base"), "Defeating the escaping pilot should unlock the Goblin Mech Workshop")
	await get_tree().create_timer(0.5).timeout
	_expect(int(level.get("current_wave_number")) == 5, "Defeating the pilot should complete the four-stage expedition")

func _verify_victory_progression_and_reload() -> void:
	await get_tree().create_timer(0.4).timeout
	var result_overlay := hud.get_node_or_null("MatchResultOverlay")
	_expect(result_overlay != null, "A completed expedition should show the victory result screen")
	_expect(Global.minewars_runs_completed == 1, "The first complete run should be recorded once")
	_expect(Global.minewars_victories == 1, "The first boss clear should be recorded as one victory")
	_expect(Global.first_level_beaten, "A victory should awaken the wider Stronghold")
	_expect(not Global.unlocked_heroes.has("Shaman"), "Shaman should remain a second-victory surprise")
	_expect(not Global.unlocked_bases.has("shaman_base"), "The Shaman Lodge should remain hidden until the second victory")
	_expect(Global.unlocked_heroes.has("Mech"), "The pilot victory should remain part of the same progression save")
	_expect(Global.legacy_ore > 0, "The completed run should award permanent Legacy Ore")
	_expect(_pending_reward_has("workshop"), "The first run should queue the Legacy Forge ceremony")
	_expect(not _pending_reward_has_hero("Shaman"), "The first victory should not reveal the second-victory Shaman ceremony")
	_expect(_pending_reward_has_hero("Mech"), "The boss finale should queue the Mech ceremony")
	var expected_ore := Global.legacy_ore
	Global.minewars_runs_completed = 0
	Global.minewars_victories = 0
	Global.legacy_ore = 0
	Global.unlocked_heroes = ["Dwarf"]
	Global.unlocked_bases = ["default_base"]
	Global.pending_unlock_rewards = []
	Global.load_game()
	_expect(Global.minewars_runs_completed == 1 and Global.minewars_victories == 1, "Save reload should restore completed-run progression")
	_expect(Global.legacy_ore == expected_ore, "Save reload should restore Legacy Ore")
	_expect(Global.unlocked_heroes.has("Mech") and not Global.unlocked_heroes.has("Shaman"), "Save reload should restore the first-victory Mech without leaking later heroes")
	_expect(Global.unlocked_bases.has("default_base") and Global.unlocked_bases.has("mech_base") and Global.unlocked_bases.size() == 2, "Save reload should restore only the Bastion and captured Mech Workshop after one victory")

func _verify_stronghold_return() -> void:
	get_tree().paused = false
	if level and is_instance_valid(level):
		remove_child(level)
		level.queue_free()
	await _wait_frames(5)
	var hub := HUB_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(24)
	var hub_level := hub.get_node_or_null("Level")
	_expect(hub_level != null, "The victory journey should return to the Stronghold")
	if hub_level == null:
		return
	var shrines := hub_level.get_node_or_null("PhysicalHeroShrines")
	_expect(shrines != null and shrines.has_node("DwarfShrine"), "The Stronghold should retain the starting Dwarf shrine")
	_expect(shrines != null and shrines.has_node("MechShrine"), "The Stronghold should physically reveal the captured Mech shrine")
	_expect(shrines == null or not shrines.has_node("ShamanShrine"), "Second-victory heroes should remain hidden after only one victory")
	var pending_meta: Array = hub_level.get_meta("stronghold_pending_rewards", [])
	_expect(not pending_meta.is_empty(), "The Stronghold should receive the pending unlock ceremonies")
	_expect(Global.pending_unlock_rewards.is_empty(), "Entering the Stronghold should consume and persist pending ceremonies")
	var controller_node := hub.get_node_or_null("SinglePlayerWorldController")
	var ceremony_found := false
	if controller_node:
		var hub_hud: Node = controller_node.get("hub_hud") as Node
		if hub_hud:
			ceremony_found = hub_hud.get_node_or_null("StrongholdUnlockBanner") != null
	_expect(ceremony_found, "Returning home should visibly play an unlock ceremony")
	hub.queue_free()
	await _wait_frames(2)

func _world_enemies() -> Array:
	var result: Array = []
	if level == null:
		return result
	for value in get_tree().get_nodes_in_group("enemies"):
		if value is Node and is_instance_valid(value) and level.is_ancestor_of(value):
			result.append(value)
	return result

func _enemy_types(enemies: Array) -> Array:
	var result: Array = []
	for enemy in enemies:
		if enemy.get("enemy_type") != null:
			result.append(int(enemy.get("enemy_type")))
	result.sort()
	return result

func _count_enemy_type(enemy_type: int) -> int:
	var count := 0
	for enemy in _world_enemies():
		if enemy.get("enemy_type") != null and int(enemy.get("enemy_type")) == enemy_type and not bool(enemy.get("is_boss_enemy")):
			count += 1
	return count

func _find_boss_mech() -> Node:
	for enemy in _world_enemies():
		if bool(enemy.get_meta("minewars_boss", false)):
			return enemy
	return null

func _clear_enemies() -> void:
	for enemy in _world_enemies():
		enemy.queue_free()

func _clear_non_boss_enemies() -> void:
	for enemy in _world_enemies():
		if not bool(enemy.get("is_boss_enemy")):
			enemy.queue_free()

func _pending_reward_has(type_name: String) -> bool:
	for value in Global.pending_unlock_rewards:
		if value is Dictionary and str((value as Dictionary).get("type", "")) == type_name:
			return true
	return false

func _pending_reward_has_hero(hero_name: String) -> bool:
	for value in Global.pending_unlock_rewards:
		if value is Dictionary and str((value as Dictionary).get("hero", "")) == hero_name:
			return true
	return false

func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: %s" % message)

func _finish() -> void:
	get_tree().paused = false
	_remove_user_file(TEST_SAVE_PATH)
	_remove_user_file(TEST_MECH_SAVE_PATH)
	Global.set_save_path_override("")
	Global.load_game()
	MechUnlockPersistence.set_save_path_override("")
	MechUnlockPersistence.call_deferred("_restore_unlock")
	if failures == 0:
		print("MINEWARS_COMPLETE_RUN_PASS")
		get_tree().quit()
	else:
		push_error("MINEWARS_COMPLETE_RUN_FAIL: %d checks failed" % failures)
		get_tree().quit(1)
