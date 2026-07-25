extends "res://scripts/gameplay/collectibles/rewards/cave_reward.gd"

func _ready() -> void:
	reward_id = "miners_satchel"
	item_texture = preload("res://assets/sprites/items/Bag.png")
	sprite_scale = 0.30
	super._ready()
