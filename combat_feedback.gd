extends Node

const HIT_EFFECT_SCENE := preload("res://combat_hit_effect.tscn")
const SERVICE_NAME := "CombatFeedback"
const SCRIPT_PATH := "res://combat_feedback.gd"

# Crowd limits keep Vampire-Survivors-style progression feedback readable and
# prevent rapid multi-hit builds from allocating an unbounded number of draw nodes.
const MAX_ACTIVE_EFFECTS := 20
const MAX_ACTIVE_NORMAL_EFFECTS := 14
const CROWD_EFFECT_THRESHOLD := 8
const NORMAL_CROWD_INTERVAL_MSEC := 28
const MAX_CAMERA_SHAKE_STRENGTH := 7.0
const MAX_CAMERA_SHAKE_DURATION_MSEC := 220
const NORMAL_HIT_STOP_COOLDOWN_MSEC := 130
const LETHAL_HIT_STOP_COOLDOWN_MSEC := 180

var _active_effects: Array[Node2D] = []
var _last_normal_effect_msec := 0
var _effect_cleanup_timer := 0.0

var _shake_camera: Camera2D
var _shake_base_offset := Vector2.ZERO
var _shake_strength := 0.0
var _shake_started_msec := 0
var _shake_end_msec := 0

var _hit_stop_active := false
var _hit_stop_end_msec := 0
var _hit_stop_cooldown_msec := 0
var _saved_time_scale := 1.0

static func ensure(parent: Node):
	var existing := parent.get_node_or_null(SERVICE_NAME)
	if existing:
		return existing
	var service := Node.new()
	service.name = SERVICE_NAME
	service.set_script(load(SCRIPT_PATH))
	parent.add_child(service)
	return service

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func play_enemy_hit(world_position: Vector2, hit_direction: Vector2, damage: int, lethal: bool = false) -> void:
	var power := clampf(0.82 + sqrt(float(maxi(damage, 1))) * 0.12, 0.85, 2.15)
	var effect_was_spawned := _spawn_effect(world_position, hit_direction, power, lethal, Color(1.0, 0.55, 0.16, 1.0))
	if not _is_near_active_camera(world_position):
		return

	var crowded := _active_effects.size() >= CROWD_EFFECT_THRESHOLD
	if lethal:
		_request_camera_shake(5.5 * power, 0.19)
		_request_hit_stop(0.055, 0.10, true)
	elif effect_was_spawned and not crowded and damage >= 18:
		_request_camera_shake(1.35 * power, 0.085)
		_request_hit_stop(0.032, 0.18, false)
	elif effect_was_spawned and _active_effects.size() < 5 and damage >= 8:
		_request_camera_shake(0.95 * power, 0.07)
		_request_hit_stop(0.026, 0.22, false)

func play_player_hit(world_position: Vector2, damage: int, lethal: bool = false) -> void:
	var power := clampf(0.9 + sqrt(float(maxi(damage, 1))) * 0.10, 0.9, 1.8)
	_spawn_effect(world_position, Vector2.UP, power, lethal, Color(1.0, 0.18, 0.12, 1.0))
	if _is_near_active_camera(world_position):
		_request_camera_shake(6.0 if lethal else 3.1 * power, 0.20 if lethal else 0.13)

func _spawn_effect(world_position: Vector2, hit_direction: Vector2, power: float, lethal: bool, tint: Color) -> bool:
	_prune_effects()
	var now := Time.get_ticks_msec()
	var active_count := _active_effects.size()

	if not lethal:
		if active_count >= MAX_ACTIVE_NORMAL_EFFECTS:
			return false
		if active_count >= CROWD_EFFECT_THRESHOLD and now - _last_normal_effect_msec < NORMAL_CROWD_INTERVAL_MSEC:
			return false
		_last_normal_effect_msec = now
	elif active_count >= MAX_ACTIVE_EFFECTS:
		var oldest: Node2D = _active_effects.pop_front() as Node2D
		if is_instance_valid(oldest):
			oldest.queue_free()

	var visual_power := power
	if not lethal and active_count >= CROWD_EFFECT_THRESHOLD:
		visual_power *= 0.82

	var effect := HIT_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return false
	if effect.has_method("configure"):
		effect.call("configure", hit_direction, visual_power, lethal, tint)
	var world := get_parent()
	world.add_child(effect)
	effect.global_position = world_position
	_active_effects.append(effect)
	return true

func _prune_effects() -> void:
	for index in range(_active_effects.size() - 1, -1, -1):
		if not is_instance_valid(_active_effects[index]) or _active_effects[index].is_queued_for_deletion():
			_active_effects.remove_at(index)

func _is_near_active_camera(world_position: Vector2) -> bool:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return false
	var visible_size := get_viewport().get_visible_rect().size / camera.zoom
	var delta := world_position - camera.get_screen_center_position()
	return absf(delta.x) <= visible_size.x * 0.68 and absf(delta.y) <= visible_size.y * 0.68

func _request_camera_shake(strength: float, duration: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	if _shake_camera != camera:
		_restore_camera_offset()
		_shake_camera = camera
		_shake_base_offset = camera.offset
	var now := Time.get_ticks_msec()
	_shake_strength = clampf(maxf(_shake_strength, strength), 0.0, MAX_CAMERA_SHAKE_STRENGTH)
	_shake_started_msec = now
	var requested_end := now + mini(int(duration * 1000.0), MAX_CAMERA_SHAKE_DURATION_MSEC)
	_shake_end_msec = maxi(_shake_end_msec, requested_end)

func _request_hit_stop(duration: float, slowed_time_scale: float, priority: bool) -> void:
	var now := Time.get_ticks_msec()
	if not priority:
		if _hit_stop_active or now < _hit_stop_cooldown_msec:
			return
	elif now < _hit_stop_cooldown_msec and not _hit_stop_active:
		return

	if not _hit_stop_active:
		_saved_time_scale = Engine.time_scale
		_hit_stop_active = true
	Engine.time_scale = minf(_saved_time_scale, slowed_time_scale)
	_hit_stop_end_msec = maxi(_hit_stop_end_msec, now + int(duration * 1000.0))
	_hit_stop_cooldown_msec = now + (LETHAL_HIT_STOP_COOLDOWN_MSEC if priority else NORMAL_HIT_STOP_COOLDOWN_MSEC)

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	_update_hit_stop(now)
	_update_camera_shake(now)
	_effect_cleanup_timer += delta
	if _effect_cleanup_timer >= 0.20:
		_effect_cleanup_timer = 0.0
		_prune_effects()

func _update_hit_stop(now: int) -> void:
	if not _hit_stop_active:
		return
	if now < _hit_stop_end_msec:
		return
	Engine.time_scale = _saved_time_scale
	_hit_stop_active = false
	_hit_stop_end_msec = 0

func _update_camera_shake(now: int) -> void:
	if _shake_camera == null:
		return
	if not is_instance_valid(_shake_camera):
		_shake_camera = null
		return
	if now >= _shake_end_msec:
		_restore_camera_offset()
		return
	var full_duration := maxi(_shake_end_msec - _shake_started_msec, 1)
	var remaining := float(_shake_end_msec - now) / float(full_duration)
	var current_strength := _shake_strength * remaining * remaining
	_shake_camera.offset = _shake_base_offset + Vector2(
		randf_range(-current_strength, current_strength),
		randf_range(-current_strength, current_strength)
	).round()

func _restore_camera_offset() -> void:
	if is_instance_valid(_shake_camera):
		_shake_camera.offset = _shake_base_offset
	_shake_camera = null
	_shake_strength = 0.0
	_shake_started_msec = 0
	_shake_end_msec = 0

func _exit_tree() -> void:
	_restore_camera_offset()
	if _hit_stop_active:
		Engine.time_scale = _saved_time_scale
		_hit_stop_active = false
