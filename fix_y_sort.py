import re

path = "scripts/systems/world_generation/world_terrain_runtime.gd"
with open(path, "r") as f:
    content = f.read()

# We need to add `if source_id in [10, 11, 12, 13, 14, 15]: tile_data.y_sort_origin = -32`
# after creating the tile in OTHER_TEXTURE_PATHS
pattern = r"source\.create_tile\(atlas_coords\)\n\s+var tile_data = source\.get_tile_data\(atlas_coords, 0\)"
replacement = r"source.create_tile(atlas_coords)\n\t\t\t\tvar tile_data = source.get_tile_data(atlas_coords, 0)\n\t\t\t\tif source_id in [10, 11, 12, 13, 14, 15]: tile_data.y_sort_origin = -32"

if "y_sort_origin" not in content:
    content = re.sub(pattern, replacement, content)
    with open(path, "w") as f:
        f.write(content)
    print("Fixed y_sort_origin!")
else:
    print("Already fixed?")
