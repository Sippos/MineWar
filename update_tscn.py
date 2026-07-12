with open("scenes/boot/main.tscn", "r") as f:
    content = f.read()

# Replace tex_fog path
content = content.replace('path="res://Black_BG.png" id="tex_fog"', 'path="res://fog_mask_atlas.png" id="tex_fog"')

# Replace Source_fog
old_fog_source = """[sub_resource type="TileSetAtlasSource" id="Source_fog"]
texture = ExtResource("tex_fog")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0"""

new_fog_source = """[sub_resource type="TileSetAtlasSource" id="Source_fog"]
texture = ExtResource("tex_fog")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0
1:0/0 = 0
2:0/0 = 0
3:0/0 = 0
0:1/0 = 0
1:1/0 = 0
2:1/0 = 0
3:1/0 = 0
0:2/0 = 0
1:2/0 = 0
2:2/0 = 0
3:2/0 = 0
0:3/0 = 0
1:3/0 = 0
2:3/0 = 0
3:3/0 = 0"""

content = content.replace(old_fog_source, new_fog_source)

with open("scenes/boot/main.tscn", "w") as f:
    f.write(content)

print("Updated main.tscn to use fog atlas")
