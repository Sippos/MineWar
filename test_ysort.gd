extends SceneTree

func _init():
	var root = Node2D.new()
	root.y_sort_enabled = true
	
	var child1 = Node2D.new()
	child1.name = "Child1"
	child1.position = Vector2(0, 100)
	root.add_child(child1)
	
	var group = Node2D.new()
	group.name = "Group"
	group.y_sort_enabled = true
	group.position = Vector2(0, 0)
	root.add_child(group)
	
	var child2 = Node2D.new()
	child2.name = "Child2"
	child2.position = Vector2(0, 50)
	group.add_child(child2)
	
	var child3 = Node2D.new()
	child3.name = "Child3"
	child3.position = Vector2(0, 150)
	group.add_child(child3)
	
	print("Test ready")
	quit(0)
