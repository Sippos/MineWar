extends SceneTree

func _init():
	var level = load("res://scenes/world/mine/level.tscn").instantiate()
	root.add_child(level)
	
	var base = level.get_node("Base")
	var upgrade_menu = level.get_node("UpgradeMenu")
	
	print("--- TEST START ---")
	print("Emitting upgrade_requested...")
	base.upgrade_requested.emit()
	print("Menu panel visible: ", upgrade_menu.get_node("Panel").visible)
	print("--- TEST END ---")
	
	quit()
