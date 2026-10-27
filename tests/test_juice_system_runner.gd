extends Node

## Test suite verifying POLISH-027:
## 1. Hit-stop time_scale drops and guarantees restoration to 1.0 via real-time timers
## 2. Multi-hit overlapping hit-stop does not prematurely restore
## 3. Camera trauma decays smoothly and restores base offset with zero drift
## 4. Directional gem bounce and squash/stretch recovery

var failures := 0
var juice_manager: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	juice_manager = get_node_or_null("/root/JuiceManager")
	_expect(juice_manager != null, "JuiceManager autoload should exist in /root/JuiceManager")
	if juice_manager == null:
		_finish()
		return

	await _test_single_hit_stop()
	await _test_overlapping_hit_stops()
	await _test_camera_trauma_lifecycle()
	await _test_gem_pop_bounce()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: %s" % message)
	else:
		print("PASS: %s" % message)

func _finish() -> void:
	if failures == 0:
		print("JUICE_SYSTEM_PASS")
		get_tree().quit(0)
	else:
		print("JUICE_SYSTEM_FAIL (%d failures)" % failures)
		get_tree().quit(1)

func _test_single_hit_stop() -> void:
	_expect(Engine.time_scale == 1.0, "Initial time_scale should be 1.0")
	juice_manager.hit_stop(0.05, 0.05)
	await get_tree().process_frame
	_expect(juice_manager.is_hit_stop_active(), "hit_stop should be active immediately")
	_expect(Engine.time_scale <= 0.05, "Engine.time_scale should drop during hit_stop")
	
	# Wait for real-time timer to expire (ignore_time_scale = true)
	await get_tree().create_timer(0.08, true, false, true).timeout
	await get_tree().process_frame
	_expect(not juice_manager.is_hit_stop_active(), "hit_stop should end after duration")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale must restore to 1.0")

func _test_overlapping_hit_stops() -> void:
	# Trigger hit 1 (duration 0.04s)
	juice_manager.hit_stop(0.04, 0.05)
	await get_tree().create_timer(0.02, true, false, true).timeout
	_expect(juice_manager.is_hit_stop_active(), "First hit_stop should be active at t=0.02s")
	
	# Trigger hit 2 (duration 0.06s) at t=0.02s (ends at t=0.08s)
	juice_manager.hit_stop(0.06, 0.05)
	
	# Wait until t=0.05s (first hit would have ended at 0.04s, but second hit must keep it active)
	await get_tree().create_timer(0.03, true, false, true).timeout
	await get_tree().process_frame
	_expect(juice_manager.is_hit_stop_active(), "Hit-stop should still be active at t=0.05s due to second hit")
	_expect(is_equal_approx(Engine.time_scale, 0.05), "Engine.time_scale should still be slowed at t=0.05s")
	
	# Wait until second hit expires (after t=0.08s)
	await get_tree().create_timer(0.05, true, false, true).timeout
	await get_tree().process_frame
	_expect(not juice_manager.is_hit_stop_active(), "Hit-stop should conclude after second hit duration")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale should restore to 1.0 after overlapping hits")

func _test_camera_trauma_lifecycle() -> void:
	var dummy_camera := Camera2D.new()
	dummy_camera.offset = Vector2(5.0, 5.0) # non-zero base offset
	add_child(dummy_camera)
	dummy_camera.make_current()
	await get_tree().process_frame

	juice_manager.add_camera_trauma(0.5)
	_expect(is_equal_approx(juice_manager.get_trauma(), 0.5), "Camera trauma should register 0.5")

	# Let trauma process for a frame
	await get_tree().process_frame
	_expect(dummy_camera.offset != Vector2(5.0, 5.0), "Camera offset should move while trauma is active")

	# Simulate trauma decay to zero
	while juice_manager.get_trauma() > 0.0:
		await get_tree().process_frame
	await get_tree().process_frame

	_expect(dummy_camera.offset == Vector2(5.0, 5.0), "Camera offset must cleanly return to base offset (5.0, 5.0)")
	dummy_camera.queue_free()

func _test_gem_pop_bounce() -> void:
	var gem_scene := load("res://scenes/entities/collectibles/gems/gem.tscn") as PackedScene
	_expect(gem_scene != null, "Gem scene should exist")
	var gem = gem_scene.instantiate() as RigidBody2D
	add_child(gem)
	
	var origin := Vector2(100.0, 100.0)
	var impulse_dir := Vector2.RIGHT
	gem.pop_from_mine(origin, impulse_dir)
	
	_expect(gem.has_method("pop_from_mine"), "Gem should support pop_from_mine")
	_expect(gem.global_position == origin, "Gem should initialize at mine origin")
	
	# Allow arc tween to complete
	await get_tree().create_timer(0.35, true, false, true).timeout
	await get_tree().process_frame
	
	_expect(gem.global_position.x > origin.x + 10.0, "Gem should have bounced in the impulse direction")
	
	var sprite := gem.get_node_or_null("Sprite2D") as Node2D
	if sprite:
		# Allow landing squash & stretch spring back
		await get_tree().create_timer(0.25, true, false, true).timeout
		await get_tree().process_frame
		_expect(sprite.scale.is_equal_approx(Vector2.ONE), "Gem sprite scale should return to Vector2.ONE after squash/stretch")
	
	gem.queue_free()
