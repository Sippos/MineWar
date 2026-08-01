extends Node

## Covers the two decisions the expedition gained: the war horn, which lets the
## player end a dig window early for a bounty, and the sealed caches, which turn
## the stage reward into a route choice made inside the mine.

const LEVEL_SCENE := preload("res://scenes/world/mine/level.tscn")
const SIEGE_SCRIPT := preload("res://scripts/systems/world_generation/siege_mode_controller.gd")
const TEST_SAVE_PATH := "user://expedition_horn_cache_test.save"
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
	_configure_isolated_save()
	await _create_level()
	if controller == null:
		_finish()
		return
	if bool(controller.get("first_run_training_active")):
		level.set("onboarding_active", false)
		Global.complete_prototype_onboarding()
		await _wait_frames(4)

	await _test_sealed_cache_choice()
	await _test_war_horn()
	_finish()

## The reward is no longer handed over on the last crystal: three caches open,
## the authored reward is always among them, and taking one buries the rest.
func _test_sealed_cache_choice() -> void:
	var gems_before := int(hud.get("total_gems"))
	await _dig_objective_seam(1)
	_expect(bool(controller.get("objective_completed")), "Clearing the seam should complete the stage objective")
	_expect(not bool(controller.get("objective_reward_claimed")), "The stage reward should wait in a cache rather than pay itself")
	_expect(int(hud.get("total_gems")) == gems_before, "No gems should arrive before a cache is opened")

	var caches: Array = (controller.get("reward_caches") as Array).duplicate()
	_expect(caches.size() >= 2, "Objective completion should open a sealed-cache choice")
	if caches.size() < 2:
		return
	var authored_id := str(controller.call("_objective_data").get("reward_id", ""))
	_expect(str(caches[0].get("reward_id")) == authored_id, "The authored stage reward should always be one of the caches")
	var offered: Array = []
	for cache in caches:
		var id := str(cache.get("reward_id"))
		_expect(not offered.has(id), "Each cache should offer a different reward")
		offered.append(id)
		_expect(str(cache.get("reward_title")) != "", "Every cache should advertise what it holds before it is opened")

	var placements: Array = []
	for cache in caches:
		placements.append((cache as Node2D).global_position)
	for index in range(placements.size()):
		for other in range(index + 1, placements.size()):
			_expect(placements[index].distance_to(placements[other]) > 100.0, "Caches should be far enough apart that a second one costs real time")

	await get_tree().create_timer(0.6).timeout
	var claimed: Node = caches[0]
	var rejected: Array = caches.slice(1)
	claimed.call("_on_body_entered", player)
	await _wait_frames(3)
	_expect(bool(controller.get("objective_reward_claimed")), "Opening a cache should pay the stage reward")
	_expect(int(hud.get("total_gems")) == gems_before + 2, "Rich Vein's authored cache should still pay two secured gems")
	for other in rejected:
		_expect(not is_instance_valid(other) or bool(other.get("collapsing")), "Opening one cache should collapse the others")
	_expect((controller.get("reward_caches") as Array).is_empty(), "A resolved choice should leave no caches behind")

## The horn only answers at the bastion, during the dig window, once per stage.
func _test_war_horn() -> void:
	controller.set("mining_timer", 62.0)
	_expect(bool(controller.call("_horn_available")), "The horn should answer during a dig window")
	_expect(int(controller.call("_horn_gem_bounty")) == 3, "A 62 second window should be worth three bounty gems")
	_expect(int(controller.call("_horn_ore_bounty")) == 2, "A 62 second window should be worth two Legacy Ore")

	# Out of range the horn is scenery: the prompt must not offer what a distant
	# hero cannot take.
	(player as Node2D).global_position = (base as Node2D).global_position + Vector2(900.0, 0.0)
	controller.call("_update_horn_prompt")
	var marker: Node2D = controller.get("horn_marker") as Node2D
	_expect(marker != null and not marker.visible, "The horn prompt should stay hidden away from the bastion")
	(player as Node2D).global_position = (base as Node2D).global_position + Vector2(40.0, 0.0)
	controller.call("_update_horn_prompt")
	_expect(marker.visible, "Standing at the bastion should offer the horn")
	_expect("SOUND THE HORN" in str((controller.get("horn_label") as Label).text), "The prompt should name the action")
	_expect("+3" in str((controller.get("horn_label") as Label).text), "The prompt should price the bounty before it is taken")

	var gems_before := int(hud.get("total_gems"))
	var ore_before := int(Global.pending_run_ore_bonus)
	controller.call("_sound_the_horn")
	await _wait_frames(3)
	_expect(int(hud.get("total_gems")) == gems_before + 3, "The horn should pay its advertised gem bounty")
	_expect(int(Global.pending_run_ore_bonus) == ore_before + 2, "The horn should stage its Legacy Ore on top of the run modifier's own bonus")
	_expect(str(level.get_meta("minewars_phase", "")) == "attack", "The horn should start the assault immediately")
	_expect(not marker.visible, "The horn should stop offering itself once it has been sounded")
	_expect(not bool(controller.call("_horn_available")), "The horn should only answer once per stage")

	# The assault this horn called would clear this flag on its way out; the test
	# never spawns it, so stand in for that before checking the next window.
	controller.set("wave_spawning", false)
	controller.call("_begin_next_expedition")
	await _wait_frames(2)
	_expect(bool(controller.call("_horn_available")), "A new expedition should re-arm the horn")

func _dig_objective_seam(stage: int) -> void:
	var target: int = int(controller.call("_objective_target"))
	var center: Vector2i = level.get("minewars_motherlodes")[stage]
	for index in range(target):
		level.call("notify_minewars_gem_dug", center + PATTERN[index])
	await _wait_frames(3)

func _configure_isolated_save() -> void:
	Global.set_save_path_override(TEST_SAVE_PATH)
	_remove_user_file(TEST_SAVE_PATH)
	Global.unlocked_heroes = Global.DEFAULT_UNLOCKED_HEROES.duplicate()
	Global.minewars_runs_completed = 0
	Global.minewars_victories = 0
	Global.prototype_onboarding_completed = false
	Global.pending_run_ore_bonus = 0
	Global.apply_selected_loadout()

func _create_level() -> void:
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
	_expect(controller != null and player != null and base != null and hud != null, "The horn/cache test requires the real level")

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
	Global.set_save_path_override("")
	Global.load_game()
	if failures == 0:
		print("EXPEDITION_HORN_CACHE_PASS")
		get_tree().quit()
	else:
		push_error("EXPEDITION_HORN_CACHE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)
