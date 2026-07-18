extends Node

const HUB_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")

func _ready() -> void:
	Global.first_level_beaten = true
	var hub := HUB_SCENE.instantiate()
	add_child(hub)
	for _index in 6:
		await get_tree().process_frame
	var world := hub.get_node("Level") as Node2D
	var selector := hub.get_node("SinglePlayerWorldController")
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var hero := world.get_node("Player") as CharacterBody2D
	hero.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(0, -7)))
	selector.call("_activate_line_wars")
