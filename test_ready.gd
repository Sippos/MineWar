extends SceneTree

func _init():
    var level = Node.new()
    level.name = "Level"
    
    var menu = Node.new()
    menu.name = "UpgradeMenu"
    var script = GDScript.new()
    script.source_code = """
extends Node
@onready var player = get_parent().get_node("Player")
func _ready():
    print("Menu ready! Player is: ", player)
"""
    script.reload()
    menu.set_script(script)
    
    var player = Node.new()
    player.name = "Player"
    
    level.add_child(menu)
    level.add_child(player)
    
    root.add_child(level)
    
    await create_timer(0.1).timeout
    print("Done test")
    quit()
