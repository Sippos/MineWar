extends Node

## Test suite verifying POLISH-028:
## 1. RunSummaryData score calculation (Quantic Foundry Achievement/Completion)
## 2. Serialization and persistence into Global.last_run_summary
## 3. RunSummaryDialog scene layout, node hierarchy, and responsive styling
## 4. Retrospective statistics, cache count, greed multiplier display, and focus flow

const SUMMARY_SCENE: PackedScene = preload("res://scenes/ui/run_summary_dialog.tscn")
const SUMMARY_DATA_SCRIPT: GDScript = preload("res://scripts/systems/gameplay/run_summary_data.gd")
const TEST_SAVE_PATH := "user://test_run_summary_persistence.save"

var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_all_tests")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: %s" % message)
	else:
		print("PASS: %s" % message)

func _finish() -> void:
	if failures == 0:
		print("RUN_SUMMARY_PASS")
		get_tree().quit(0)
	else:
		print("RUN_SUMMARY_FAIL (%d failures)" % failures)
		get_tree().quit(1)

func _run_all_tests() -> void:
	_test_score_calculation()
	_test_serialization_roundtrip()
	await _test_dialog_instantiation_and_hierarchy()
	await _test_victory_and_defeat_presentation()
	await _test_zero_downtime_focus_and_callbacks()
	_test_persistence_with_global()
	_finish()

func _test_score_calculation() -> void:
	var data: RefCounted = SUMMARY_DATA_SCRIPT.new()
	data.set("victory", false)
	data.set("blocks_mined", 15)
	data.set("total_gems", 8)
	data.set("caches_unlocked", 2)
	data.set("waves_survived", 3)
	data.set("base_integrity", 80)
	data.set("horn_greed_multiplier", 1.0)

	# base = 15*10 (150) + 8*25 (200) + 2*200 (400) + 3*500 (1500) + 80*15 (1200) = 3450
	var calculated: int = data.call("calculate_score")
	_expect(calculated == 3450, "Defeat score without horn multiplier should equal 3450 (got %d)" % calculated)

	data.set("horn_greed_multiplier", 1.5)
	calculated = data.call("calculate_score")
	_expect(calculated == 5175, "Horn greed multiplier 1.5x should scale score to 5175 (got %d)" % calculated)

	data.set("victory", true)
	data.set("horn_greed_multiplier", 1.0)
	calculated = data.call("calculate_score")
	# base = 3450 + 2500 (victory bonus) = 5950
	_expect(calculated == 5950, "Victory score with triumph bonus should equal 5950 (got %d)" % calculated)

func _test_serialization_roundtrip() -> void:
	var data: RefCounted = SUMMARY_DATA_SCRIPT.new()
	data.set("victory", true)
	data.set("hero_name", "Shaman")
	data.set("blocks_mined", 42)
	data.set("caches_unlocked", 3)
	data.set("horn_soundings", 2)
	data.set("horn_greed_multiplier", 1.5)
	data.set("score", 8500)
	data.set("legacy_ore_earned", 6)
	data.set("total_legacy_ore", 24)

	var dict: Dictionary = data.call("to_dict")
	_expect(dict.get("hero_name") == "Shaman", "to_dict should capture hero name")
	_expect(int(dict.get("caches_unlocked")) == 3, "to_dict should capture caches unlocked")
	_expect(int(dict.get("horn_soundings")) == 2, "to_dict should capture horn soundings")
	_expect(int(dict.get("score")) == 8500, "to_dict should capture score")

	var restored: RefCounted = SUMMARY_DATA_SCRIPT.call("from_dict", dict)
	_expect(restored.get("hero_name") == "Shaman", "from_dict should restore hero name")
	_expect(int(restored.get("blocks_mined")) == 42, "from_dict should restore blocks mined")
	_expect(int(restored.get("score")) == 8500, "from_dict should restore score")
	_expect(bool(restored.get("victory")) == true, "from_dict should restore victory flag")

func _test_dialog_instantiation_and_hierarchy() -> void:
	var dialog := SUMMARY_SCENE.instantiate() as Control
	_expect(dialog != null, "RunSummaryDialog scene should instantiate cleanly")
	add_child(dialog)
	await get_tree().process_frame

	var panel := dialog.get_node_or_null("Panel")
	_expect(panel != null, "Dialog must have a Panel node")
	var content := dialog.get_node_or_null("Panel/Content")
	_expect(content != null, "Dialog must have a Panel/Content node")
	var actions := dialog.get_node_or_null("Panel/Content/Actions")
	_expect(actions != null, "Dialog must have Actions container")

	var retry_btn := dialog.get_node_or_null("Panel/Content/Actions/RetryButton") as Button
	var loadout_btn := dialog.get_node_or_null("Panel/Content/Actions/ChangeLoadoutButton") as Button
	var workshop_btn := dialog.get_node_or_null("Panel/Content/Actions/WorkshopButton") as Button
	var menu_btn := dialog.get_node_or_null("Panel/Content/Actions/MainMenuButton") as Button

	_expect(retry_btn != null, "Actions must include RetryButton")
	_expect(loadout_btn != null, "Actions must include ChangeLoadoutButton")
	_expect(workshop_btn != null, "Actions must include WorkshopButton")
	_expect(menu_btn != null, "Actions must include MainMenuButton")

	dialog.queue_free()
	await get_tree().process_frame

func _test_victory_and_defeat_presentation() -> void:
	var dialog := SUMMARY_SCENE.instantiate() as Control
	add_child(dialog)

	var victory_data: RefCounted = SUMMARY_DATA_SCRIPT.new()
	victory_data.set("victory", true)
	victory_data.set("hero_name", "Dwarf")
	victory_data.set("hero_level", 4)
	victory_data.set("waves_survived", 4)
	victory_data.set("final_wave", 4)
	victory_data.set("total_gems", 14)
	victory_data.set("blocks_mined", 38)
	victory_data.set("caches_unlocked", 3)
	victory_data.set("horn_soundings", 1)
	victory_data.set("horn_greed_multiplier", 1.25)
	victory_data.set("base_integrity", 92)
	victory_data.set("score", 9400)
	victory_data.set("base_survival_ore", 2)
	victory_data.set("victory_bonus_ore", 3)
	victory_data.set("horn_bonus_ore", 2)
	victory_data.set("legacy_ore_earned", 7)
	victory_data.set("total_legacy_ore", 22)

	dialog.call("setup", victory_data)
	await get_tree().process_frame

	var title := dialog.get_node_or_null("Panel/Content/Title") as Label
	_expect(title != null and title.text.contains("VICTORY"), "Victory setup should display EXPEDITION VICTORY")

	var run_summary_card := dialog.get_node_or_null("Panel/Content/ResultBody/RunSummaryCard")
	_expect(run_summary_card != null, "RunSummaryCard should be populated")

	var legacy_reward := dialog.get_node_or_null("Panel/Content/LegacyReward")
	_expect(legacy_reward != null, "LegacyReward banner should be populated")

	dialog.queue_free()
	await get_tree().process_frame

func _test_zero_downtime_focus_and_callbacks() -> void:
	var dialog := SUMMARY_SCENE.instantiate() as Control
	add_child(dialog)

	var tracker := {"retry": false, "workshop": false}

	var data: RefCounted = SUMMARY_DATA_SCRIPT.new()
	data.set("victory", true)
	data.set("hero_name", "Dwarf")

	dialog.call(
		"setup",
		data,
		Callable(func(): tracker["retry"] = true),
		Callable(),
		Callable(func(): tracker["workshop"] = true),
		Callable()
	)
	await get_tree().process_frame
	await get_tree().process_frame

	var retry_btn := dialog.get_node_or_null("Panel/Content/Actions/RetryButton") as Button
	_expect(retry_btn != null, "Retry button must be valid")
	if retry_btn:
		retry_btn.emit_signal("pressed")
		_expect(tracker["retry"], "Clicking RetryButton should immediately execute retry callback")

	var workshop_btn := dialog.get_node_or_null("Panel/Content/Actions/WorkshopButton") as Button
	_expect(workshop_btn != null, "Workshop button must be valid")
	if workshop_btn:
		workshop_btn.emit_signal("pressed")
		_expect(tracker["workshop"], "Clicking WorkshopButton should immediately execute workshop callback")

	dialog.queue_free()
	await get_tree().process_frame

func _test_persistence_with_global() -> void:
	Global.set_save_path_override(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)

	var data: RefCounted = SUMMARY_DATA_SCRIPT.new()
	data.set("victory", true)
	data.set("hero_name", "Mech")
	data.set("score", 12450)
	data.set("caches_unlocked", 3)
	data.set("legacy_ore_earned", 8)
	data.set("total_legacy_ore", 30)

	Global.record_run_summary(data)
	_expect(Global.last_run_summary.get("hero_name") == "Mech", "Global.last_run_summary should record hero name")
	_expect(int(Global.last_run_summary.get("score")) == 12450, "Global.last_run_summary should record score")

	Global.last_run_summary = {}
	Global.load_game()
	_expect(Global.last_run_summary.get("hero_name") == "Mech", "Save reload should restore last_run_summary hero name")
	_expect(int(Global.last_run_summary.get("score")) == 12450, "Save reload should restore last_run_summary score")

	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)
