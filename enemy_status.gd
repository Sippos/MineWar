extends Node

var enemy: CharacterBody2D
var stun_timer := 0.0
var knockback_velocity := Vector2.ZERO
var slow_timer := 0.0
var slow_factor := 1.0
var base_speed := 0.0
var has_speed_property := false
var saved_modulate := Color.WHITE

func _ready() -> void:
	enemy = get_parent() as CharacterBody2D
	process_priority = 200
	if enemy == null:
		queue_free()
		return
	var speed_value = enemy.get("speed")
	if typeof(speed_value) == TYPE_FLOAT or typeof(speed_value) == TYPE_INT:
		has_speed_property = true
		base_speed = float(speed_value)
	var sprite := enemy.get_node_or_null("Sprite2D")
	if sprite:
		saved_modulate = sprite.modulate

func _physics_process(delta: float) -> void:
	if not is_instance_valid(enemy):
		queue_free()
		return
	if stun_timer > 0.0:
		stun_timer = max(0.0, stun_timer - delta)
		enemy.velocity = knockback_velocity
		enemy.move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 750.0 * delta)
		if stun_timer <= 0.0:
			_end_stun()
	if slow_timer > 0.0:
		slow_timer = max(0.0, slow_timer - delta)
		if slow_timer <= 0.0:
			_end_slow()

func apply_stun(duration: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if enemy == null or duration <= 0.0:
		return
	if bool(enemy.get("is_boss_enemy")):
		duration *= 0.55
	if stun_timer <= 0.0:
		enemy.set_physics_process(false)
	stun_timer = max(stun_timer, duration)
	if knockback.length() > knockback_velocity.length():
		knockback_velocity = knockback
	_set_tint(Color(0.75, 0.88, 1.25, 1.0))

func apply_slow(duration: float, factor: float) -> void:
	if enemy == null or duration <= 0.0 or not has_speed_property:
		return
	factor = clamp(factor, 0.2, 1.0)
	if bool(enemy.get("is_boss_enemy")):
		factor = lerp(1.0, factor, 0.55)
	slow_timer = max(slow_timer, duration)
	slow_factor = min(slow_factor, factor)
	enemy.set("speed", base_speed * slow_factor)
	if stun_timer <= 0.0:
		_set_tint(Color(0.72, 0.82, 1.1, 1.0))

func _end_stun() -> void:
	if is_instance_valid(enemy):
		enemy.velocity = Vector2.ZERO
		enemy.set_physics_process(true)
	knockback_velocity = Vector2.ZERO
	if slow_timer <= 0.0:
		_restore_tint()

func _end_slow() -> void:
	if is_instance_valid(enemy) and has_speed_property:
		enemy.set("speed", base_speed)
	slow_factor = 1.0
	if stun_timer <= 0.0:
		_restore_tint()

func _set_tint(color: Color) -> void:
	if not is_instance_valid(enemy):
		return
	var sprite := enemy.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = color

func _restore_tint() -> void:
	if not is_instance_valid(enemy):
		return
	var sprite := enemy.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = saved_modulate

func _exit_tree() -> void:
	if not is_instance_valid(enemy):
		return
	if has_speed_property:
		enemy.set("speed", base_speed)
	if stun_timer > 0.0:
		enemy.set_physics_process(true)
