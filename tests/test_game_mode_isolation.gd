extends Node

const LEVEL_SCENE := preload("res://scenes/world/mine/level.tscn")

func _ready() -> void:
	GameMode.set_mode(GameMode.Mode.BREACH_EXPERIMENT)
	var breach_level := LEVEL_SCENE.instantiate()
	add_child(breach_level)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert(breach_level.has_node("EnemyApproachPrototype"), "Breach mode should attach its approach prototype")
	assert(not breach_level.has_node("ExplorationModeController"), "Exploration controller must stay out of Breach mode")
	breach_level.queue_free()
	await get_tree().process_frame

	GameMode.set_mode(GameMode.Mode.EXPLORATION)
	var exploration_level := LEVEL_SCENE.instantiate()
	add_child(exploration_level)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert(exploration_level.has_node("ExplorationModeController"), "Exploration mode should attach its controller")
	assert(not exploration_level.has_node("EnemyApproachPrototype"), "Breach prototype must stay out of Exploration mode")

	print("GAME_MODE_ISOLATION_OK breach=true exploration=true")
	get_tree().quit()
