import re

with open("main.tscn", "r") as f:
    content = f.read()

# Replace external resources section
old_ext = """[ext_resource type="Texture2D" path="res://bg.png" id="tex_bg"]
[ext_resource type="Texture2D" path="res://block_easy.png" id="tex_easy"]
[ext_resource type="Texture2D" path="res://block_med.png" id="tex_med"]
[ext_resource type="Texture2D" path="res://block_hard.png" id="tex_hard"]
[ext_resource type="Texture2D" path="res://edge.png" id="tex_edge"]
[ext_resource type="Texture2D" path="res://damage.png" id="tex_damage"]
[ext_resource type="Texture2D" path="res://fog.png" id="tex_fog"]"""

new_ext = """[ext_resource type="Texture2D" path="res://Black_BG_TransparentBorder.png" id="tex_bg"]
[ext_resource type="Texture2D" path="res://Easy_Brick.png" id="tex_easy"]
[ext_resource type="Texture2D" path="res://Medium_Brick.png" id="tex_med"]
[ext_resource type="Texture2D" path="res://Hard_Brick.png" id="tex_hard"]
[ext_resource type="Texture2D" path="res://Easy_Brick_Border.png" id="tex_edge_easy"]
[ext_resource type="Texture2D" path="res://Medium_Brick_Border.png" id="tex_edge_med"]
[ext_resource type="Texture2D" path="res://Hard_Brick_Border.png" id="tex_edge_hard"]
[ext_resource type="Texture2D" path="res://First_Hitting.png" id="tex_dmg1"]
[ext_resource type="Texture2D" path="res://Second_Hitting.png" id="tex_dmg2"]
[ext_resource type="Texture2D" path="res://Black_BG.png" id="tex_fog"]"""

content = content.replace(old_ext, new_ext)

# Replace SubResources for TileSet
old_subres = """[sub_resource type="TileSetAtlasSource" id="Source_bg"]
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
sources/6 = SubResource("Source_fog")"""

new_subres = """[sub_resource type="TileSetAtlasSource" id="Source_bg"]
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

[sub_resource type="TileSetAtlasSource" id="Source_edge_easy"]
texture = ExtResource("tex_edge_easy")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0

[sub_resource type="TileSetAtlasSource" id="Source_edge_med"]
texture = ExtResource("tex_edge_med")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0

[sub_resource type="TileSetAtlasSource" id="Source_edge_hard"]
texture = ExtResource("tex_edge_hard")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0

[sub_resource type="TileSetAtlasSource" id="Source_dmg1"]
texture = ExtResource("tex_dmg1")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0

[sub_resource type="TileSetAtlasSource" id="Source_dmg2"]
texture = ExtResource("tex_dmg2")
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
sources/4 = SubResource("Source_edge_easy")
sources/5 = SubResource("Source_edge_med")
sources/6 = SubResource("Source_edge_hard")
sources/7 = SubResource("Source_dmg1")
sources/8 = SubResource("Source_dmg2")
sources/9 = SubResource("Source_fog")"""

content = content.replace(old_subres, new_subres)

with open("main.tscn", "w") as f:
    f.write(content)

print("Updated main.tscn with new tile IDs.")
