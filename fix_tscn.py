import re

with open("scenes/boot/main.tscn", "r") as f:
    content = f.read()

# Add ext_resources
ext_resources = """[ext_resource type="Texture2D" path="res://bg.png" id="tex_bg"]
[ext_resource type="Texture2D" path="res://block_easy.png" id="tex_easy"]
[ext_resource type="Texture2D" path="res://block_med.png" id="tex_med"]
[ext_resource type="Texture2D" path="res://block_hard.png" id="tex_hard"]
[ext_resource type="Texture2D" path="res://edge.png" id="tex_edge"]
[ext_resource type="Texture2D" path="res://damage.png" id="tex_damage"]
[ext_resource type="Texture2D" path="res://fog.png" id="tex_fog"]
"""

# Insert before the first sub_resource
content = re.sub(r'(\[sub_resource)', ext_resources + r'\n\1', content, count=1)

# Define subresources
subresources = """[sub_resource type="TileSetAtlasSource" id="Source_bg"]
texture = ExtResource("tex_bg")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0

[sub_resource type="TileSetAtlasSource" id="Source_easy"]
texture = ExtResource("tex_easy")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0
0:0/0/physics_layer_0/polygon_0/points = PackedVector2Array(-32, -32, 32, -32, 32, 32, -32, 32)

[sub_resource type="TileSetAtlasSource" id="Source_med"]
texture = ExtResource("tex_med")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0
0:0/0/physics_layer_0/polygon_0/points = PackedVector2Array(-32, -32, 32, -32, 32, 32, -32, 32)

[sub_resource type="TileSetAtlasSource" id="Source_hard"]
texture = ExtResource("tex_hard")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0
0:0/0/physics_layer_0/polygon_0/points = PackedVector2Array(-32, -32, 32, -32, 32, 32, -32, 32)

[sub_resource type="TileSetAtlasSource" id="Source_edge"]
texture = ExtResource("tex_edge")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0

[sub_resource type="TileSetAtlasSource" id="Source_damage"]
texture = ExtResource("tex_damage")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0

[sub_resource type="TileSetAtlasSource" id="Source_fog"]
texture = ExtResource("tex_fog")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0

[sub_resource type="TileSet" id="TileSet_main"]
tile_size = Vector2i(64, 64)
physics_layer_0/collision_layer = 1
sources/0 = SubResource("Source_bg")
sources/1 = SubResource("Source_easy")
sources/2 = SubResource("Source_med")
sources/3 = SubResource("Source_hard")
sources/4 = SubResource("Source_edge")
sources/5 = SubResource("Source_damage")
sources/6 = SubResource("Source_fog")

"""

# Replace the old SubResource("TileSet_block") with our new ones
# We'll just append it right before [sub_resource type="Gradient"
content = re.sub(r'(\[sub_resource type="Gradient")', subresources + r'\1', content)

# Now replace the TileMapLayer node with our MapLayers Node2D
layers_node = """[node name="MapLayers" type="Node2D" parent="."]

[node name="BackgroundLayer" type="TileMapLayer" parent="MapLayers"]
tile_set = SubResource("TileSet_main")

[node name="BlockLayer" type="TileMapLayer" parent="MapLayers"]
tile_set = SubResource("TileSet_main")

[node name="EdgeLayer" type="TileMapLayer" parent="MapLayers"]
tile_set = SubResource("TileSet_main")

[node name="DamageLayer" type="TileMapLayer" parent="MapLayers"]
tile_set = SubResource("TileSet_main")

[node name="FogLayer" type="TileMapLayer" parent="MapLayers"]
tile_set = SubResource("TileSet_main")"""

content = re.sub(r'\[node name="TileMapLayer" type="TileMapLayer" parent="\."\]\ntile_set = SubResource\("TileSet_block"\)', layers_node, content)

with open("scenes/boot/main.tscn", "w") as f:
    f.write(content)

print("Updated main.tscn")
