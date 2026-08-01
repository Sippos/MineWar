extends SceneTree

func _init():
	call_deferred("_run_test")

func _run_test():
	var world_scene = preload("res://scenes/world/mine/level.tscn")
	var w = world_scene.instantiate()
	root.add_child(w)
	
	# Global singletons are already loaded in a normal run, but with -s they might not be if we override the main scene?
	# Wait, -s runs a script AFTER autoloads. So GameMode is available!
	var GameMode = root.get_node("/root/GameMode")
	GameMode.set_mode(2) # 2 is LINE_WARS (actually let's check enum)
	
	w.is_vs_mode = true
	w.player_id = 1
	w.call("begin_run_from_preparation")
	
	# Wait for generation
	await create_timer(1.0).timeout
	
	GameMode.set_mode(5) # LINE_WARS is 5
	
	# Dig the maze
	print("Digging maze...")
	w.on_cell_dug(Vector2i(0, -5))
	w.on_cell_dug(Vector2i(0, -6))
	w.on_cell_dug(Vector2i(0, -7))
	w.on_cell_dug(Vector2i(0, -8))
	w.on_cell_dug(Vector2i(0, -9))
	w.on_cell_dug(Vector2i(0, -10))
	
	var cell = w.get_farthest_open_cell()
	print("Test complete. Cell: ", cell)
	quit()
