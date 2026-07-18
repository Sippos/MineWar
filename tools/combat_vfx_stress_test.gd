extends Node2D

const FEEDBACK_SCRIPT := preload("res://combat_feedback.gd")
const REQUESTS_PER_SECOND := 240.0
const TEST_DURATION_MSEC := 6500

var feedback: Node
var start_msec := 0
var next_log_msec := 0
var request_count := 0
var maximum_active_effects := 0
var minimum_fps := 10000

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var camera := Camera2D.new()
	camera.enabled = true
	add_child(camera)
	feedback = FEEDBACK_SCRIPT.ensure(self)
	start_msec = Time.get_ticks_msec()
	next_log_msec = start_msec + 1000

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var elapsed_seconds := float(now - start_msec) / 1000.0
	var target_requests := int(elapsed_seconds * REQUESTS_PER_SECOND)
	while request_count < target_requests:
		var angle := float(request_count % 120) / 120.0 * TAU
		var ring := 90.0 + float((request_count / 120) % 3) * 55.0
		var position := Vector2.RIGHT.rotated(angle) * ring
		var lethal := request_count % 120 == 0
		feedback.call("play_enemy_hit", position, position.normalized(), 12, lethal)
		request_count += 1

	var active_effects: Array = feedback.get("_active_effects") as Array
	maximum_active_effects = maxi(maximum_active_effects, active_effects.size())
	var fps := Engine.get_frames_per_second()
	if fps > 0:
		minimum_fps = mini(minimum_fps, fps)

	if now >= next_log_msec:
		print("COMBAT_VFX_STRESS sample requests=%d active=%d fps=%d nodes=%d draw_calls=%d" % [
			request_count,
			active_effects.size(),
			fps,
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		])
		next_log_msec += 1000

	if now - start_msec >= TEST_DURATION_MSEC:
		print("COMBAT_VFX_STRESS_RESULT requests=%d max_active=%d min_fps=%d final_nodes=%d" % [
			request_count,
			maximum_active_effects,
			minimum_fps,
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		])
		get_tree().quit()
