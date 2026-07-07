extends Area2D

var xp_value = 10

var can_pickup = false

func _ready() -> void:
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
		queue_free()
