extends Node

const LEVEL_SCENE := preload("res://scenes/world/mine/level.tscn")
const SIEGE_SCRIPT := preload("res://scripts/systems/world_generation/siege_mode_controller.gd")

var failures := 0
var level: Node
var controller: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	GameMode.set_mode(GameMode.Mode.SIEGE)
	level = LEVEL_SCENE.instantiate()
	level.set("is_vs_mode", false)
	level.set("preparation_mode", false)

	# The balance harness exercises the real world, controller, enemy, base, and
	# HUD data, but does not need player input or menu prompt processing.
	var player := level.get_node_or_null("Player")
	var base := level.get_node_or_null("Base")
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	if base:
		base.process_mode = Node.PROCESS_MODE_DISABLED

	controller = Node2D.new()
	controller.name = "SiegeModeController"
	controller.set_script(SIEGE_SCRIPT)
	level.add_child(controller)
	add_child(level)
	await _wait_frames(18)

	_expect(controller != null and is_instance_valid(controller), "MineWars controller should attach to the real level")
	var hud := level.get_node_or_null("HUD")
	_expect(base != null and hud != null, "MineWars balance test requires Base and HUD")
	if base == null or hud == null:
		_finish()
		return

	var starting_gems := int(hud.get("total_gems"))

	# Stage 1: verify that the player receives a real return window and that the
	# introductory rats use the authored tutorial-scale combat profile.
	controller.set("mining_timer", 0.02)
	await get_tree().create_timer(0.12).timeout
	_expect(str(level.get_meta("minewars_phase", "")) == "attack", "Stage 1 should enter assault muster")
	var stage_one_muster := float(controller.get("assault_muster_timer"))
	_expect(stage_one_muster > 9.0 and stage_one_muster <= 10.0, "Stage 1 should provide about ten seconds of return grace")
	_expect(_world_enemies().is_empty(), "No enemies should damage the base during the muster countdown")
	controller.set("assault_muster_timer", 0.02)
	await get_tree().create_timer(2.8).timeout
	var stage_one_enemies := _world_enemies()
	_expect(stage_one_enemies.size() == 3, "Stage 1 should spawn three introductory rats")
	for enemy in stage_one_enemies:
		_expect(int(enemy.get("damage")) == 1, "Stage 1 rat damage should remain tutorial-safe")
		_expect(int(enemy.get("health")) == 18, "Stage 1 rat health should remain readable")
	await get_tree().create_timer(12.5).timeout
	_expect(int(base.get("health")) >= 80, "A full bastion should survive long enough for a reasonable Stage 1 return")
	_clear_enemies()
	await _wait_frames(8)
	_expect(str(level.get_meta("minewars_phase", "")) == "recovery", "Clearing Stage 1 should enter recovery")
	_expect(int(hud.get("total_gems")) == starting_gems + 1, "Stage 1 should guarantee one salvage gem")

	# Stage 2: verify roster identity and capped damage.
	controller.call("_begin_next_expedition")
	controller.set("mining_timer", 0.02)
	await get_tree().create_timer(0.12).timeout
	_expect(float(controller.get("assault_muster_timer")) > 7.0, "Stage 2 should retain a meaningful return countdown")
	controller.set("assault_muster_timer", 0.02)
	await get_tree().create_timer(3.7).timeout
	var stage_two_enemies := _world_enemies()
	_expect(stage_two_enemies.size() == 5, "Stage 2 should spawn its five-enemy mixed roster")
	_expect(_enemy_types(stage_two_enemies) == [0, 0, 1, 1, 2], "Stage 2 should introduce spiders and a bat")
	_expect(_maximum_enemy_damage(stage_two_enemies) <= 4, "Stage 2 contact damage should stay inside the early-run cap")
	_clear_enemies()
	await _wait_frames(8)
	_expect(int(hud.get("total_gems")) == starting_gems + 2, "Stage 2 should add another guaranteed salvage gem")

	# Stage 3: verify the late mixed assault without waiting through a full run.
	controller.call("_begin_next_expedition")
	controller.set("mining_timer", 0.02)
	await get_tree().create_timer(0.12).timeout
	_expect(float(controller.get("assault_muster_timer")) > 5.0, "Stage 3 should still allow a short deliberate return")
	controller.set("assault_muster_timer", 0.02)
	await get_tree().create_timer(4.6).timeout
	var stage_three_enemies := _world_enemies()
	_expect(stage_three_enemies.size() == 7, "Stage 3 should deliver the full ancient-strata roster")
	_expect(_enemy_types(stage_three_enemies) == [1, 1, 2, 2, 3, 3, 4], "Stage 3 should include spiders, bats, troggs, and an orc")
	_expect(_maximum_enemy_damage(stage_three_enemies) <= 6, "Stage 3 damage should be dangerous without becoming instant base deletion")
	_clear_enemies()
	await _wait_frames(8)
	_expect(int(hud.get("total_gems")) == starting_gems + 4, "Stage 3 should award two salvage gems")

	# Stage 4: verify the bespoke MineWars boss rather than endless-wave scaling.
	controller.call("_begin_next_expedition")
	controller.set("mining_timer", 0.02)
	await get_tree().create_timer(0.12).timeout
	_expect(float(controller.get("assault_muster_timer")) > 4.0, "The final descent should still provide boss muster time")
	controller.set("assault_muster_timer", 0.02)
	await get_tree().create_timer(2.0).timeout
	var boss_enemies := _world_enemies()
	_expect(boss_enemies.size() == 1, "The final assault should spawn one readable boss")
	if boss_enemies.size() == 1:
		var boss_enemy: Node = boss_enemies[0]
		_expect(int(boss_enemy.get("health")) == 600, "MineWars boss health should match the four-stage economy")
		_expect(int(boss_enemy.get("damage")) == 12, "MineWars boss damage should permit active defence")
		_expect(absf(float(boss_enemy.get("speed")) - 50.0) < 0.1, "MineWars boss should approach slowly enough to create a climax")
	_clear_enemies()
	await _wait_frames(8)
	_expect(int(level.get("current_wave_number")) == 5, "Defeating the boss should complete the four-stage expedition")

	_finish()

func _world_enemies() -> Array[Node]:
	var result: Array[Node] = []
	if level == null:
		return result
	for value in get_tree().get_nodes_in_group("enemies"):
		var enemy := value as Node
		if enemy != null and is_instance_valid(enemy) and level.is_ancestor_of(enemy):
			result.append(enemy)
	return result

func _enemy_types(enemies: Array[Node]) -> Array[int]:
	var result: Array[int] = []
	for enemy in enemies:
		result.append(int(enemy.get("enemy_type")))
	result.sort()
	return result

func _maximum_enemy_damage(enemies: Array[Node]) -> int:
	var maximum := 0
	for enemy in enemies:
		maximum = maxi(maximum, int(enemy.get("damage")))
	return maximum

func _clear_enemies() -> void:
	for enemy in _world_enemies():
		enemy.queue_free()

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
	if failures == 0:
		print("MINEWARS_FOUR_STAGE_BALANCE_PASS")
		get_tree().quit()
	else:
		push_error("MINEWARS_FOUR_STAGE_BALANCE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)
