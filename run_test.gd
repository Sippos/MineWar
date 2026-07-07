extends SceneTree

func _init():
	print("Starting Godot headless test...")
	var packed = load("res://level.tscn")
	if not packed:
		print("Failed to load level")
		quit()
		return
	
	var level = packed.instantiate()
	root.add_child(level)
	
	# Wait one frame for ready functions
	await get_tree().process_frame
	
	var base = level.get_node_or_null("Base")
	if base:
		print("Emitting upgrade_requested...")
		base.upgrade_requested.emit()
	else:
		print("Base not found!")
	
	# Wait one frame to let signal process
	await get_tree().process_frame
	
	var menu = level.get_node_or_null("UpgradeMenu")
	if menu:
		var panel = menu.get_node("Panel")
		print("Menu Panel visible: ", panel.visible)
	else:
		print("UpgradeMenu not found!")
		
	quit()
