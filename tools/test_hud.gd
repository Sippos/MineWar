extends Node

func _ready():
    # Wait a bit for HUD to initialize
    await get_tree().create_timer(1.0).timeout
    var hud = get_node_or_null("/root/Main/Level/HUD")
    if not hud:
        print("No HUD found!")
        return
    
    for child in hud.get_children():
        if child is TextureProgressBar:
            print("--- ", child.name, " ---")
            print("Size: ", child.size)
            print("Scale: ", child.scale)
            print("Global Position: ", child.global_position)
            print("NinePatchStretch: ", child.nine_patch_stretch)
            print("TextureProgressOffset: ", child.texture_progress_offset)
            print("FillMode: ", child.fill_mode)
            print("Value: ", child.value)
            
