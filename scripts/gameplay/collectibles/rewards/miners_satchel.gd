extends Area2D

const REWARD_ID := "miners_satchel"

var collected := false
var can_collect := false
var hover_origin_y := 0.0

func _ready() -> void:
	add_to_group("cave_rewards")
	hover_origin_y = position.y
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	queue_redraw()
	scale = Vector2.ZERO
	var reveal_tween := create_tween()
	reveal_tween.tween_property(self, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var hover_tween := create_tween().set_loops()
	hover_tween.tween_property(self, "position:y", hover_origin_y - 4.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hover_tween.tween_property(self, "position:y", hover_origin_y + 4.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.8).timeout
	can_collect = true
	for body in get_overlapping_bodies():
		_on_body_entered(body)

func _draw() -> void:
	# A contained procedural icon keeps the prototype independent from new art.
	draw_circle(Vector2(0, 13), 18.0, Color(0.95, 0.72, 0.18, 0.13))
	var bag_points := PackedVector2Array([
		Vector2(-15, -5),
		Vector2(-11, -14),
		Vector2(11, -14),
		Vector2(15, -5),
		Vector2(13, 15),
		Vector2(8, 20),
		Vector2(-8, 20),
		Vector2(-13, 15)
	])
	draw_colored_polygon(bag_points, Color(0.46, 0.25, 0.11))
	draw_line(Vector2(-11, -4), Vector2(11, -4), Color(0.78, 0.51, 0.2), 4.0, true)
	draw_arc(Vector2(0, -12), 8.0, PI, TAU, 18, Color(0.9, 0.68, 0.28), 3.0, true)
	draw_rect(Rect2(-4, -1, 8, 7), Color(0.95, 0.75, 0.28), true)
	draw_rect(Rect2(-2, 1, 4, 3), Color(0.24, 0.13, 0.07), true)
	draw_line(Vector2(-8, 8), Vector2(8, 8), Color(0.66, 0.38, 0.14), 2.0, true)

func _on_body_entered(body: Node2D) -> void:
	if collected or not can_collect or not body.has_method("apply_cave_reward"):
		return
	if not bool(body.apply_cave_reward(REWARD_ID)):
		return
	collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var world := get_parent()
	if world and world.has_method("spawn_cave_reward_pickup_feedback"):
		world.spawn_cave_reward_pickup_feedback(global_position)
	var pickup_tween := create_tween().set_parallel(true)
	pickup_tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pickup_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.22)
	pickup_tween.chain().tween_callback(queue_free)
