extends Node

const LEVEL_SCENE := preload("res://scenes/world/mine/level.tscn")

func _ready() -> void:
	Global.hero_p1 = "Mech"
	Global.current_hero = "Mech"
	var level := LEVEL_SCENE.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var player := level.get_node("Player") as CharacterBody2D
	assert(player != null)
	if player.has_method("update_hero_sprites"):
		player.update_hero_sprites()
	await get_tree().process_frame
	assert(str(player.get("current_hero_name")) == "Mech")
	player.die()
	await get_tree().process_frame
	await get_tree().process_frame
	var pilot := level.get_node_or_null("MechPilotPlayer") as CharacterBody2D
	assert(pilot != null)
	assert(not bool(player.get("is_dead")))
	pilot.global_position = level.get_node("Base").global_position
	await get_tree().create_timer(2.5).timeout
	assert(level.get_node_or_null("MechPilotPlayer") == null)
	assert(not bool(player.get("is_dead")))
	assert(int(player.get("health")) > 0)
	print("MECH_PILOT_RUNTIME_SMOKE_OK")
	get_tree().quit()
