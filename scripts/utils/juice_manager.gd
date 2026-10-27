extends Node

## JuiceManager: Centralized game feel coordinator for MineWars.
## Implements trauma-based screen shake, safe real-time hit-stop freeze frames,
## and kinetic impact distribution across mining and combat.

signal hit_stop_completed

const MAX_SHAKE_OFFSET := Vector2(10.0, 8.0)
const TRAUMA_DECAY_RATE := 1.6

var _trauma: float = 0.0
var _shake_time: float = 0.0
var _tracked_camera: Camera2D = null
var _camera_base_offset := Vector2.ZERO

var _hit_stop_id: int = 0
var _saved_time_scale: float = 1.0
var _hit_stop_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _exit_tree() -> void:
	restore_camera_offset()
	if _hit_stop_active:
		Engine.time_scale = _saved_time_scale
		_hit_stop_active = false

func _is_mobile_or_touch_web() -> bool:
	if not is_inside_tree():
		return false
	if bool(get_tree().root.get_meta("web_low_memory_mode", false)):
		return true
	return OS.has_feature("web") or OS.has_feature("mobile") or OS.has_feature("web_ios")

## Triggers a brief time-scale freeze to give weight to decisive impacts.
## Synchronous call using real-time (unscaled) timer with hit ID tracking.
## Disabled on mobile / web touch browsers to preserve input responsiveness.
func hit_stop(duration: float = 0.05, slow: float = 0.05) -> void:
	if not is_inside_tree() or _is_mobile_or_touch_web():
		hit_stop_completed.emit()
		return
	_hit_stop_id += 1
	var my_id := _hit_stop_id
	if not _hit_stop_active:
		_saved_time_scale = Engine.time_scale
		_hit_stop_active = true
	Engine.time_scale = minf(_saved_time_scale, slow)
	_run_hit_stop_timer(my_id, duration)

func _run_hit_stop_timer(my_id: int, duration: float) -> void:
	# ignore_time_scale = true (4th argument) ensures the timer elapses while the game is frozen
	await get_tree().create_timer(duration, true, false, true).timeout
	if my_id == _hit_stop_id:
		Engine.time_scale = _saved_time_scale
		_hit_stop_active = false
		hit_stop_completed.emit()

func is_hit_stop_active() -> bool:
	return _hit_stop_active

func get_trauma() -> float:
	return _trauma

## Adds decaying trauma (0.0 to 1.0) to drive smooth screen shake.
func add_camera_trauma(amount: float) -> void:
	var scaled_amount: float = amount * 0.45 if _is_mobile_or_touch_web() else amount
	_trauma = clampf(_trauma + scaled_amount, 0.0, 1.0)
	var cam := _find_active_camera()
	if cam != null and _tracked_camera != cam:
		restore_camera_offset()
		_tracked_camera = cam
		_camera_base_offset = cam.offset

func _process(delta: float) -> void:
	# Process camera trauma decay and shake
	if _trauma <= 0.0:
		if _tracked_camera != null and is_instance_valid(_tracked_camera):
			restore_camera_offset()
		return
	
	_trauma = maxf(_trauma - TRAUMA_DECAY_RATE * delta, 0.0)
	var shake := _trauma * _trauma # Quadratic curve: subtle at low trauma, punchy at high
	_shake_time += delta * 32.0
	
	var cam := _find_active_camera()
	if cam == null:
		return
	if _tracked_camera != cam:
		restore_camera_offset()
		_tracked_camera = cam
		_camera_base_offset = cam.offset
	
	cam.offset = _camera_base_offset + Vector2(
		MAX_SHAKE_OFFSET.x * shake * sin(_shake_time * 1.73),
		MAX_SHAKE_OFFSET.y * shake * sin(_shake_time * 2.37)
	)
	
	if _trauma <= 0.0:
		restore_camera_offset()

func restore_camera_offset() -> void:
	if _tracked_camera != null and is_instance_valid(_tracked_camera):
		_tracked_camera.offset = _camera_base_offset
	_tracked_camera = null

func _find_active_camera() -> Camera2D:
	if not is_inside_tree():
		return null
	var vp := get_viewport()
	if vp != null:
		var cam := vp.get_camera_2d()
		if cam != null and is_instance_valid(cam):
			return cam
	return null

## Convenience methods for game events
func trigger_block_hit(is_break: bool, has_gem: bool) -> void:
	if is_break:
		hit_stop(0.045, 0.08)
		add_camera_trauma(0.16 if has_gem else 0.08)
	else:
		add_camera_trauma(0.03)

func trigger_motherlode_shatter() -> void:
	hit_stop(0.075, 0.04)
	add_camera_trauma(0.55)

func trigger_war_horn_blast() -> void:
	hit_stop(0.06, 0.05)
	add_camera_trauma(0.42)

func trigger_melee_impact(damage: int, lethal: bool) -> void:
	var strength := clampf(float(damage) / 25.0, 0.1, 1.0)
	hit_stop(0.06 if lethal else 0.035, 0.05)
	add_camera_trauma((0.38 if lethal else 0.18) * strength)
