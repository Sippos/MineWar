import re

level_tscn_path = "level.tscn"
with open(level_tscn_path, "r") as f:
    level_tscn = f.read()

# 1. Add ext_resource for tex_rail
if "tex_rail" not in level_tscn:
    ext_res_idx = level_tscn.rfind("[ext_resource")
    end_ext_idx = level_tscn.find("\n", ext_res_idx)
    level_tscn = level_tscn[:end_ext_idx+1] + '[ext_resource type="Texture2D" path="res://rail_atlas_placeholder.png" id="tex_rail"]\n' + level_tscn[end_ext_idx+1:]

# 2. Add Source_rail
if "Source_rail" not in level_tscn:
    source_rail = """
[sub_resource type="TileSetAtlasSource" id="Source_rail"]
texture = ExtResource("tex_rail")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0
1:0/0 = 0
0:1/0 = 0
1:1/0 = 0
"""
    tileset_idx = level_tscn.find("[sub_resource type=\"TileSet\" id=\"TileSet_main\"]")
    level_tscn = level_tscn[:tileset_idx] + source_rail + level_tscn[tileset_idx:]

# 3. Add to TileSet_main
if "sources/15 = SubResource(\"Source_rail\")" not in level_tscn:
    ts_main_end = level_tscn.find("sources/12 =", level_tscn.find("[sub_resource type=\"TileSet\" id=\"TileSet_main\"]"))
    ts_main_end = level_tscn.find("\n", ts_main_end)
    level_tscn = level_tscn[:ts_main_end+1] + 'sources/15 = SubResource("Source_rail")\n' + level_tscn[ts_main_end+1:]

# 4. Add RailLayer
if 'name="RailLayer"' not in level_tscn:
    block_layer_idx = level_tscn.find('[node name="BlockLayer"')
    block_layer_end = level_tscn.find("\n\n", block_layer_idx)
    rail_layer = '\n[node name="RailLayer" type="TileMapLayer" parent="."]\nz_index = -1\ntile_set = SubResource("TileSet_main")\n'
    level_tscn = level_tscn[:block_layer_end+1] + rail_layer + level_tscn[block_layer_end+1:]

with open(level_tscn_path, "w") as f:
    f.write(level_tscn)

# 5. Patch world.gd
world_gd_path = "world.gd"
with open(world_gd_path, "r") as f:
    world_gd = f.read()

rail_methods = """
func update_rail_autotile(cell: Vector2i) -> void:
	if not has_node("RailLayer"): return
	var rail_layer = get_node("RailLayer")
	
	if rail_layer.get_cell_source_id(cell) == -1: return
	
	var up = rail_layer.get_cell_source_id(Vector2i(cell.x, cell.y - 1)) != -1
	var down = rail_layer.get_cell_source_id(Vector2i(cell.x, cell.y + 1)) != -1
	var left = rail_layer.get_cell_source_id(Vector2i(cell.x - 1, cell.y)) != -1
	var right = rail_layer.get_cell_source_id(Vector2i(cell.x + 1, cell.y)) != -1
	
	var atlas_coords = Vector2i(0, 0)
	if up and down and left and right:
		atlas_coords = Vector2i(0, 1) # Intersection
	elif (left or right) and not (up or down):
		atlas_coords = Vector2i(1, 0) # Horizontal
	elif (up or down) and not (left or right):
		atlas_coords = Vector2i(0, 0) # Vertical
	else:
		atlas_coords = Vector2i(0, 1) # Intersection as fallback
		
	rail_layer.set_cell(cell, 15, atlas_coords)
"""

if "update_rail_autotile" not in world_gd:
    world_gd += rail_methods
    with open(world_gd_path, "w") as f:
        f.write(world_gd)

# In rail_item.gd we also need to change the source id to 15 instead of 0
rail_item_gd_path = "rail_item.gd"
with open(rail_item_gd_path, "r") as f:
    rail_item_gd = f.read()

rail_item_gd = rail_item_gd.replace('rail_layer.set_cell(cell, 0, Vector2i(0, 0))', 'rail_layer.set_cell(cell, 15, Vector2i(0, 0))')

with open(rail_item_gd_path, "w") as f:
    f.write(rail_item_gd)

print("Patched level.tscn, world.gd, rail_item.gd")
