extends SceneTree

func _init():
    var bench = load("res://tools/sprite_lab/dome_material_workbench.gd").new()
    var base = Image.create(64, 64, false, Image.FORMAT_RGBA8)
    base.fill(Color.TRANSPARENT)
    # simulate the patch
    for y in range(16, 48):
        for x in range(16, 48):
            base.set_pixel(x, y, Color.WHITE)
    
    for frame in range(4):
        var rendered = bench._rotate_vertex_composite(base, frame)
        var min_x = 64; var max_x = 0; var min_y = 64; var max_y = 0
        for y in range(64):
            for x in range(64):
                if rendered.get_pixel(x, y).a > 0.5:
                    if x < min_x: min_x = x
                    if x > max_x: max_x = x
                    if y < min_y: min_y = y
                    if y > max_y: max_y = y
        print("Frame ", frame, " logical bounds: x=", min_x, "..", max_x, ", y=", min_y, "..", max_y)
    quit()
