extends SceneTree

func _init():
	var packed = load("res://upgrade_menu.tscn")
	var menu = packed.instantiate()
	root.add_child(menu)
	
	# Mock player and hud so it doesn't crash on _ready() or show_menu()
	var parent = Node2D.new()
	parent.name = "Level"
	root.add_child(parent)
	
	var player = Node2D.new()
	player.name = "Player"
	player.set("strength", 1)
	player.set("agility", 1)
	player.set("intelligence", 1)
	player.set("can_move", true)
	parent.add_child(player)
	
	var hud = Node2D.new()
	hud.name = "HUD"
	parent.add_child(hud)
	
	parent.set("is_vs_mode", false)
	
	menu.get_parent().remove_child(menu)
	parent.add_child(menu)
	
	print("--- TEST START ---")
	menu.show_menu()
	print("Menu panel visible: ", menu.get_node("Panel").visible)
	print("--- TEST END ---")
	
	quit()
