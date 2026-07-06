import re

with open("main.tscn", "r") as f:
    content = f.read()

# Add ext_resources for fronts
front_ext = """[ext_resource type="Texture2D" path="res://Easy_Front.png" id="tex_front_easy"]
[ext_resource type="Texture2D" path="res://Medium_Front.png" id="tex_front_med"]
[ext_resource type="Texture2D" path="res://Hard_Front.png" id="tex_front_hard"]"""

content = re.sub(r'(\[ext_resource type="Texture2D" path="res://Black_BG.png" id="tex_fog"\])', r'\1\n' + front_ext, content)

# Add TileSetAtlasSources for fronts
front_sources = """[sub_resource type="TileSetAtlasSource" id="Source_front_easy"]
texture = ExtResource("tex_front_easy")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0

[sub_resource type="TileSetAtlasSource" id="Source_front_med"]
texture = ExtResource("tex_front_med")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0

[sub_resource type="TileSetAtlasSource" id="Source_front_hard"]
texture = ExtResource("tex_front_hard")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0

[sub_resource type="TileSet" id="TileSet_main"]"""

content = re.sub(r'\[sub_resource type="TileSet" id="TileSet_main"\]', front_sources, content)

# Add them to the TileSet_main
tile_set_add = """sources/10 = SubResource("Source_front_easy")
sources/11 = SubResource("Source_front_med")
sources/12 = SubResource("Source_front_hard")"""

content = re.sub(r'(sources/9 = SubResource\("Source_fog"\))', r'\1\n' + tile_set_add, content)

# Enable Y-Sort on Main
content = re.sub(r'(\[node name="Main" type="Node2D"\]\nscript = ExtResource\("1_world"\))', r'\1\ny_sort_enabled = true', content)

# Enable Y-Sort on MapLayers and add FrontWallLayer
old_map_layers = """[node name="MapLayers" type="Node2D" parent="."]

[node name="BackgroundLayer" type="TileMapLayer" parent="MapLayers"]
tile_set = SubResource("TileSet_main")

[node name="BlockLayer" type="TileMapLayer" parent="MapLayers"]"""

new_map_layers = """[node name="MapLayers" type="Node2D" parent="."]
y_sort_enabled = true

[node name="BackgroundLayer" type="TileMapLayer" parent="MapLayers"]
tile_set = SubResource("TileSet_main")

[node name="BlockLayer" type="TileMapLayer" parent="MapLayers"]
tile_set = SubResource("TileSet_main")

[node name="FrontWallLayer" type="TileMapLayer" parent="MapLayers"]
y_sort_enabled = true
tile_set = SubResource("TileSet_main")"""

content = content.replace(old_map_layers, new_map_layers)

with open("main.tscn", "w") as f:
    f.write(content)

print("Updated main.tscn for 2.5D")
