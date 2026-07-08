extends SceneTree

func _init():
    var parent = Node.new()
    var child1 = Node.new()
    child1.name = "Child1"
    var child2 = Node.new()
    child2.name = "Child2"
    
    parent.add_child(child1)
    parent.add_child(child2)
    
    print("Done")
    quit()
