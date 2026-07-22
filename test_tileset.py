import subprocess

code = """
extends SceneTree
func _init():
    var source = TileSetAtlasSource.new()
    source.texture_region_size = Vector2i(128, 128)
    source.create_tile(Vector2i(0, 0))
    # Try setting texture origin
    source.texture_origin = Vector2i(24, 24) # error?
    print("Methods:")
    for method in source.get_method_list():
        if "origin" in method.name:
            print(method.name)
    quit()
"""
with open("test_tileset.gd", "w") as f:
    f.write(code)

subprocess.run(["godot", "--headless", "-s", "test_tileset.gd"])
