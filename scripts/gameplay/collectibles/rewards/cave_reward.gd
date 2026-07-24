extends Area2D

## Shared cave-item pickup used by Bag, Pickaxe and Boots.
## Subclasses only need to set REWARD_ID + sprite texture path.

@export var reward_id: String = ""
@export var item_texture: Texture2D
@export var sprite_scale: float = 0.55

var collected := false
var can_collect := false
var hover_origin_y := 0.0
var sprite: Sprite2D

func _ready() -> void:
	add_to_group("cave_rewards")
	hover_origin_y = position.y
	_setup_sprite()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
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

func _setup_sprite() -> void:
	sprite = Sprite2D.new()
	sprite.name = "ItemSprite"
	sprite.texture = item_texture
	sprite.centered = true
	sprite.position = Vector2(0, 2)
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

func _on_body_entered(body: Node2D) -> void:
	if collected or not can_collect or reward_id.is_empty():
		return
	if not body.has_method("apply_cave_reward"):
		return
	if not bool(body.apply_cave_reward(reward_id)):
		return
	collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var world := get_parent()
	if world and world.has_method("spawn_cave_reward_pickup_feedback"):
		world.spawn_cave_reward_pickup_feedback(global_position, reward_id)
	var pickup_tween := create_tween().set_parallel(true)
	pickup_tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pickup_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.22)
	pickup_tween.chain().tween_callback(queue_free)
