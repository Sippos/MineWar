extends Node

const LANE_SCENE := preload("res://maze_vs_lane.tscn")

var failures := 0

func _ready() -> void:
	await _run_continuous_duel_smoke()
	if failures == 0:
		print("MAZE_VS_SMOKE_PASS")
		get_tree().quit(0)
	else:
		push_error("MAZE_VS_SMOKE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

func _run_continuous_duel_smoke() -> void:
	var sender := LANE_SCENE.instantiate() as Control
	var defender := LANE_SCENE.instantiate() as Control
	add_child(sender)
	add_child(defender)
	await get_tree().process_frame
	sender.setup("SENDER", 1, "Shaman")
	defender.setup("DEFENDER", 2, "Dwarf")
	sender.enter_preparation()
	defender.enter_preparation()
	_expect(sender.get_path_length() == 15, "Direct route should start at 15 tiles")
	_expect(not sender.is_combat_active(), "Preparation should begin with sending disabled")

	sender.enemy_purchased.connect(func(enemy_type: String) -> void:
		defender.receive_enemy(enemy_type, int(sender.get("current_round")))
	)
	sender.start_combat()
	defender.start_combat()
	sender.start_round(1)
	defender.start_round(1)

	var starting_gold: int = sender.get_gold()
	sender.call("_purchase_rat")
	_expect(defender.get_enemy_count() == 1, "Buying a Rat should spawn it in the opponent lane immediately")
	_expect(sender.get_gold() == starting_gold - 2, "Rat purchase should spend gold immediately")
	_expect(sender.get_income() == 3, "Rat purchase should increase future income")

	for x in range(2, 7):
		defender.call("_toggle_cell", Vector2i(x, 2))
	defender.call("_toggle_cell", Vector2i(4, 1))
	_expect(defender.get_path_length() > 15, "Live digging should activate a longer connected detour")
	_expect(defender.get_enemy_count() == 1, "Live rerouting should preserve active enemies")

	defender.set_process(false)
	for _step in 8:
		defender.call("_process", 0.1)
	var active_enemies: Array = defender.get("enemies") as Array
	if not active_enemies.is_empty():
		var occupied_cell := Vector2i((active_enemies[0] as Dictionary).get("cell", Vector2i.ZERO))
		defender.call("_toggle_cell", occupied_cell)
		_expect(bool(defender.call("_is_open", occupied_cell)), "An occupied tunnel tile must not be closed")

	defender.call("_use_hero_ability")
	_expect(float(defender.get("ability_cooldown")) > 0.0, "Hero ability should activate during continuous combat")

	sender.grant_income()
	sender.start_round(2)
	_expect(int(sender.get("current_round")) == 2, "Timed escalation should advance the round")
	var gold_before_orc: int = sender.get_gold()
	sender.call("_purchase_orc")
	_expect(sender.get_gold() == gold_before_orc - 7, "Round 2 Orc purchase should spend seven gold")
	_expect(defender.get_enemy_count() >= 2, "Buying an Orc should also spawn immediately")
	var saw_orc := false
	for enemy_value in defender.get("enemies") as Array:
		var enemy: Dictionary = enemy_value
		if str(enemy.get("type", "")) == "Orc":
			saw_orc = true
			break
	_expect(saw_orc, "The real Orc enemy type should be present in the defender lane")

	for _step in 1200:
		defender.call("_process", 0.05)
		if defender.get_enemy_count() == 0:
			break
	_expect(defender.get_enemy_count() == 0, "Continuous enemies should eventually die or reach the core")
	_expect(defender.get_core_hp() >= 0 and defender.get_core_hp() <= 10, "Core HP should remain within valid bounds")

	sender.queue_free()
	defender.queue_free()
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
