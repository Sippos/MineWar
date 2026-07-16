extends Area2D

var xp_value = 10

var can_pickup = false

func _ready() -> void:
	$Sprite2D.position.y = -24
	var tween = create_tween()
	scale = Vector2.ZERO
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	var hop_tween = create_tween()
	var start_y = $Sprite2D.position.y
	hop_tween.tween_property($Sprite2D, "position:y", start_y - 30, 0.2).set_ease(Tween.EASE_OUT)
	hop_tween.tween_property($Sprite2D, "position:y", start_y, 0.2).set_ease(Tween.EASE_IN)
	
	await get_tree().create_timer(0.4).timeout
	can_pickup = true
	body_entered.connect(_on_body_entered)
	for body in get_overlapping_bodies():
		_on_body_entered(body)

func _on_body_entered(body: Node2D) -> void:
	if not can_pickup: return
	if body.name == "Player":
		if body.has_method("add_xp"):
			body.add_xp(xp_value)
			
		var burst = CPUParticles2D.new()
		burst.emitting = false
		burst.one_shot = true
		burst.amount = 15
		burst.lifetime = 0.5
		burst.explosiveness = 0.9
		burst.spread = 180.0
		burst.gravity = Vector2(0, 0)
		burst.initial_velocity_min = 50.0
		burst.initial_velocity_max = 120.0
		burst.scale_amount_min = 2.0
		burst.scale_amount_max = 5.0
		burst.color = Color(0.2, 1.0, 0.2, 1.0)
		burst.global_position = global_position
		burst.z_index = 10
		get_parent().call_deferred("add_child", burst)
		burst.call_deferred("set_emitting", true)
		
		var t = get_tree().create_timer(1.0)
		t.timeout.connect(burst.queue_free)
		var world := get_parent()
		if world and world.has_method("spawn_xp_pickup_feedback"):
			world.spawn_xp_pickup_feedback(global_position, xp_value)
		queue_free()
