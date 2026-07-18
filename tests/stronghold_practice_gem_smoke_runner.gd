extends Node

const HUB_SCENE: PackedScene = preload("res://scenes/world/preparation/preparation_hub.tscn")
const TEST_SAVE := "user://stronghold_practice_gem_smoke.save"

var failures := 0
var hub: Node
var level: Node2D
var player: CharacterBody2D
var station: Node2D
var hud: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	_prepare_isolated_progression()
	hub = HUB_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(16)
	level = hub.get_node_or_null("Level") as Node2D
	_expect(level != null, "Practice test should load the real Stronghold level")
	if level == null:
		_finish()
		return
	player = level.get_node_or_null("Player") as CharacterBody2D
	hud = level.get_node_or_null("HUD") as CanvasLayer
	station = level.get_node_or_null("StrongholdPracticeYard") as Node2D
	_expect(player != null and hud != null, "Practice test requires the real player and HUD")
	_expect(station != null, "The Stronghold should create the practice gem yard")
	if player == null or hud == null or station == null:
		_finish()
		return

	var starting_gems: int = int(hud.get("total_gems"))
	var vein_position: Vector2 = station.call("get_practice_vein_position")
	player.global_position = vein_position + Vector2(58.0, 0.0)
	player.velocity = Vector2.ZERO
	await _wait_frames(3)
	Input.action_press("p1_left")
	await get_tree().create_timer(3.1).timeout
	Input.action_release("p1_left")
	await _wait_frames(4)
	_expect(str(station.call("get_practice_state_name")) == "gem_active", "Holding toward the vein should mine the practice gem with the real control pattern")

	var gem_value: Variant = station.get("practice_gem")
	var gem := gem_value as Node2D
	_expect(gem != null and is_instance_valid(gem), "Mining the practice vein should spawn one real gem object")
	if gem == null or not is_instance_valid(gem):
		_finish()
		return
	_expect(bool(gem.get_meta("stronghold_practice_gem", false)), "The spawned gem should be marked as non-progression practice cargo")
	player.global_position = gem.global_position + Vector2(18.0, 0.0)
	await _wait_frames(4)
	Input.action_press("p1_grab")
	await _wait_frames(2)
	Input.action_release("p1_grab")
	await _wait_frames(3)
	var carried_value: Variant = player.get("carried_gems")
	var carried: Array = carried_value as Array
	_expect(carried.has(gem), "The practice gem should use the normal pickup and tether system")
	_expect(int(player.call("get_carry_overload")) == 1, "The dense practice gem should always simulate exactly one overload slot")
	_expect(absf(float(player.call("get_weight_penalty")) - 0.15) < 0.001, "The practice gem should visibly test the real 15 percent movement penalty")

	var deposited: int = int(player.call("deposit_gems"))
	_expect(deposited == 0, "Practice cargo should never deposit as spendable currency")
	carried_value = player.get("carried_gems")
	carried = carried_value as Array
	_expect(carried.has(gem), "Attempting a base-style deposit should leave the practice gem carried")
	_expect(int(hud.get("total_gems")) == starting_gems, "Practice mining should not change the HUD gem total")

	var receiver_position: Vector2 = station.call("get_practice_receiver_position")
	player.global_position = receiver_position
	player.velocity = Vector2.ZERO
	await _wait_frames(4)
	Input.action_press("p1_drop")
	await _wait_frames(2)
	Input.action_release("p1_drop")
	await _wait_frames(4)
	_expect(str(station.call("get_practice_state_name")) == "delivery", "Dropping at the platform should hand the gem to the practice cart and peon")
	_expect(int(hud.get("total_gems")) == starting_gems, "Cart handoff should still award no currency")

	await get_tree().create_timer(4.3).timeout
	await _wait_frames(3)
	_expect(str(station.call("get_practice_state_name")) == "vein_ready", "The peon/cart loop should regenerate the practice vein")
	_expect(station.get("practice_gem") == null, "Only one practice gem may exist at a time")
	_expect(int(hud.get("total_gems")) == starting_gems, "The complete practice loop should remain progression-neutral")

	level.remove_meta("single_player_hub_active")
	await _wait_frames(4)
	_expect(not is_instance_valid(station), "The practice yard should clean itself up when a real run begins")
	_finish()

func _prepare_isolated_progression() -> void:
	if Global.has_method("set_save_path_override"):
		Global.set_save_path_override(TEST_SAVE)
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	Global.unlocked_heroes = ["Dwarf"]
	Global.unlocked_bases = ["default_base"]
	Global.first_level_beaten = false
	Global.minewars_runs_completed = 0
	Global.minewars_victories = 0
	Global.hero_victories = {}
	Global.unlocked_stronghold_ambience = []
	Global.pending_unlock_rewards = []
	Global.last_unlock_rewards = []
	Global.selected_hero_id = "Dwarf"
	Global.selected_base_id = "default_base"
	Global.current_hero = "Dwarf"
	Global.hero_p1 = "Dwarf"
	Global.legacy_ore = 0

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
	Input.action_release("p1_left")
	Input.action_release("p1_grab")
	Input.action_release("p1_drop")
	if hub != null and is_instance_valid(hub):
		hub.queue_free()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	if Global.has_method("set_save_path_override"):
		Global.set_save_path_override("")
	if failures == 0:
		print("STRONGHOLD_PRACTICE_GEM_SMOKE_PASS")
		get_tree().quit()
	else:
		push_error("STRONGHOLD_PRACTICE_GEM_SMOKE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)
