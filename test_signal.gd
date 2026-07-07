extends SceneTree
func _init():
    var obj = Node.new()
    obj.add_user_signal("send_enemy")
    obj.connect("send_enemy", Callable(self, "_on_send"))
    obj.emit_signal("send_enemy", 0)
    print("Done")
    quit()
func _on_send(arg):
    print("Received: ", arg)
