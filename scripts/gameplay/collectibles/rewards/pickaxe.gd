extends "res://scripts/gameplay/collectibles/rewards/cave_reward.gd"

func _ready() -> void:
	reward_id = "pickaxe"
	item_texture = preload("res://assets/sprites/items/Pickaxe.png")
	sprite_scale = 0.52
	super._ready()
