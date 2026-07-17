extends Node

const LANE_SCENE := preload("res://maze_vs_lane.tscn")

var failures := 0

func _ready() -> void:
	await _run_lane_smoke()
	if failures == 0:
		print("MAZE_VS_SMOKE_PASS")
		get_tree().quit(0)
	else:
		push_error("MAZE_VS_SMOKE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

func _run_lane_smoke() -> void:
	var lane := LANE_SCENE.instantiate() as Control
	add_child(lane)
	await get_tree().process_frame
	lane.setup("TEST SHAMAN", 1, "Shaman")
	lane.enter_build_phase(1)
	_expect(int(lane.get_path_length()) == 15, "Direct route should start at 15 tiles")

	for x in range(2, 7):
		lane.call("_toggle_cell", Vector2i(x, 2))
	lane.call("_toggle_cell", Vector2i(4, 1))
	_expect(int(lane.get_path_length()) > 15, "Closing the shortcut should activate the longer connected detour")

	lane.call("_on_runner_pressed")
	lane.call("_on_brute_pressed")
	_expect(int(lane.get_queued_send_points()) == 3, "Runner plus Brute should spend all three pressure points")
	var manifest: Array[String] = lane.consume_queued_attack()
	_expect(manifest.size() == 2, "Two typed attackers should be exported")
	_expect(manifest.has("runner") and manifest.has("brute"), "Manifest should contain Runner and Brute")

	lane.enter_build_phase(1)
	lane.begin_wave(1, 4, 16.0, 2.65, manifest)
	lane.set_process(false)
	_expect(bool(lane.is_wave_active()), "Wave should become active")
	_expect((lane.get("spawn_queue") as Array).size() == 6, "Wave queue should include four Raiders and two sent attackers")

	lane.activate_hero_ability()
	_expect(float(lane.get("ability_cooldown")) > 0.0, "Hero ability should enter cooldown")

	for _step in 800:
		lane.call("_process", 0.05)
		if not bool(lane.is_wave_active()):
			break
	_expect(not bool(lane.is_wave_active()), "Wave should eventually resolve")
	_expect(int(lane.get_core_hp()) >= 0, "Core HP should remain valid after leaks")
	lane.queue_free()
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
