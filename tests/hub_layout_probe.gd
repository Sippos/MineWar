extends Node

const SINGLE_PLAYER_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")

func _ready() -> void:
	Global.set_save_path_override("user://hub_layout_probe_save.json")
	for hero_count in [1, 3, 6]:
		await _probe(hero_count)
	get_tree().quit(0)

func _probe(hero_count: int) -> void:
	var roster := ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King", "Mech"]
	Global.unlocked_heroes = roster.slice(0, hero_count)
	Global.minewars_runs_completed = 4
	Global.pending_unlock_rewards.clear()
	var hub := SINGLE_PLAYER_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(6)
	var world := hub.get_node("Level") as Node2D
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var tier: int = world.get_hub_tier()
	var layout: Dictionary = world.TIER_LAYOUTS[tier]
	var half_w: int = layout["half_w"]
	var half_h: int = layout["half_h"]
	var top_left := block_layer.to_global(block_layer.map_to_local(Vector2i(-half_w, -half_h)))
	var bottom_right := block_layer.to_global(block_layer.map_to_local(Vector2i(half_w, half_h)))
	print("=== heroes=%d tier=%d half=(%d,%d) ===" % [hero_count, tier, half_w, half_h])
	print("  interior world rect: ", top_left, " .. ", bottom_right)
	print("  base at ", (world.get_node("Base") as Node2D).global_position)
	print("  player at ", (world.get_node("Player") as Node2D).global_position)
	print("  bottom door ", block_layer.to_global(block_layer.map_to_local(world.get_minewars_entrance())))
	print("  top door ", block_layer.to_global(block_layer.map_to_local(world.get_top_tunnel_entrance())))
	for child in world.get_children():
		if child is Node2D and not (child is TileMapLayer):
			print("  child %s at %s" % [child.name, str((child as Node2D).global_position)])
	var shrines := world.get_node_or_null("PhysicalHeroShrines")
	if shrines != null:
		for shrine in shrines.get_children():
			print("  shrine %s at %s" % [shrine.name, str((shrine as Node2D).global_position)])
	else:
		print("  no PhysicalHeroShrines node")
	hub.queue_free()
	await _wait_frames(2)

func _wait_frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame
