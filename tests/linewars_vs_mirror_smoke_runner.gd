extends Node

const MIRROR_SCENE := preload("res://scenes/world/preparation/linewars_vs_mirror.tscn")

var failures := 0

func _ready() -> void:
	await _run_test()
	if failures == 0:
		print("LINEWARS_VS_MIRROR_SMOKE_PASS")
		get_tree().quit(0)
	else:
		push_error("LINEWARS_VS_MIRROR_SMOKE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

func _run_test() -> void:
	var mirror := MIRROR_SCENE.instantiate()
	add_child(mirror)
	await _wait_until(func() -> bool: return mirror.get("controller_a") != null and mirror.get("controller_b") != null, 180)

	var controller_a: Node = mirror.get("controller_a")
	var controller_b: Node = mirror.get("controller_b")
	var world_a: Node2D = mirror.get("world_a")
	var world_b: Node2D = mirror.get("world_b")
	var machine_a: Node = mirror.get("machine_a")

	_expect(controller_a != null and controller_b != null, "The mirrored scene should create two real LineWars controllers")
	_expect(world_a != null and world_b != null and world_a != world_b, "Each side should own an independent mine world")
	if controller_a == null or controller_b == null or world_a == null or world_b == null or machine_a == null:
		return

	mirror.call("_complete_both_openings")
	await _wait_until(func() -> bool: return bool(mirror.get("side_a_ready")) and bool(mirror.get("side_b_ready")), 240)
	_expect(bool(mirror.get("side_a_ready")) and bool(mirror.get("side_b_ready")), "Both sides should independently complete the protected five-tile opening")
	_expect(not bool(controller_a.get("vs_match_started")) and not bool(controller_b.get("vs_match_started")), "Waves should remain gated until both ready players start the match")

	mirror.call("_start_match")
	await _wait_frames(4)
	_expect(bool(controller_a.get("vs_match_started")) and bool(controller_b.get("vs_match_started")), "The shared start action should release both LineWars clocks together")

	var hud_a := world_a.get_node("HUD")
	var gems_before := int(hud_a.get("total_gems"))
	var queued := bool(machine_a.call("_queue_send", "RAT RAID", 5, "RAT", 1))
	_expect(queued, "Player A should be able to spend one gem on a Rat Raid")
	_expect(int(hud_a.get("total_gems")) == gems_before - 1, "The sending side should pay the War Machine cost")
	machine_a.call("_dispatch_next")
	await _wait_frames(3)
	var incoming_b: Array = controller_b.get("vs_incoming_queue")
	_expect(incoming_b.size() == 1, "A dispatched payload should enter Player B's incoming queue only")
	var incoming_a: Array = controller_a.get("vs_incoming_queue")
	_expect(incoming_a.is_empty(), "Player A must not receive its own send")

	controller_b.call("_process_vs_incoming", 0.1)
	controller_b.call("_process_vs_incoming", 20.0)
	await _wait_frames(5)
	var enemies_b := _count_world_enemies(world_b)
	var enemies_a := _count_world_enemies(world_a)
	_expect(enemies_b == 5, "The Rat Raid should spawn five real enemies at Player B's farthest tunnel endpoint")
	_expect(enemies_a == 0, "Cross-side enemy spawning should remain isolated from Player A's world")
	if enemies_b > 0:
		var first_enemy := _first_world_enemy(world_b)
		_expect(first_enemy != null and int(first_enemy.get("enemy_type")) == 0, "The mirrored payload should preserve its forced Rat enemy type")
		_expect(first_enemy != null and str(first_enemy.get_meta("linewars_layer", "")) == "tunnel", "Opponent sends should enter through the defender's tunnel layer")

	controller_b.call("_finish_run", false)
	await _wait_frames(4)
	_expect(bool(mirror.get("match_finished")), "Destroying one mirrored base should end the shared match")
	_expect(str(mirror.get("winner_label")) == "PLAYER A", "The surviving opposite side should be declared the winner")
	var result_panel := mirror.get_node("ResultPanel") as PanelContainer
	_expect(result_panel.visible, "The mirrored match should show a final result panel")

	mirror.queue_free()
	await _wait_frames(4)

func _count_world_enemies(world: Node) -> int:
	var count := 0
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(candidate) and world.is_ancestor_of(candidate):
			count += 1
	return count

func _first_world_enemy(world: Node) -> CharacterBody2D:
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(candidate) and world.is_ancestor_of(candidate):
			return candidate as CharacterBody2D
	return null

func _wait_until(predicate: Callable, max_frames: int) -> void:
	for _index in range(max_frames):
		if bool(predicate.call()):
			return
		await get_tree().process_frame

func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
