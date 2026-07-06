import re

with open("main.tscn", "r") as f:
    content = f.read()

# 1. Add ext_resource for the new textures at the top
ext_resources = """[ext_resource type="Texture2D" path="res://First-Hit-Front.png" id="tex_front_dmg1"]
[ext_resource type="Texture2D" path="res://Next-Hit-Front.png" id="tex_front_dmg2"]
"""
# Insert after the first ext_resource
content = re.sub(r'(\[ext_resource.*?\]\n)', r'\1' + ext_resources, content, count=1)

# 2. Add sub_resource for the atlas sources
sub_resources = """
[sub_resource type="TileSetAtlasSource" id="Source_front_dmg1"]
texture = ExtResource("tex_front_dmg1")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0
0:0/0/texture_origin = Vector2i(0, 32)

[sub_resource type="TileSetAtlasSource" id="Source_front_dmg2"]
texture = ExtResource("tex_front_dmg2")
texture_region_size = Vector2i(64, 64)
0:0/0 = 0
0:0/0/texture_origin = Vector2i(0, 32)
"""
# Insert before [resource] which defines the TileSet
content = content.replace("[resource]\n", sub_resources + "[resource]\n")

# 3. Register the sources in the TileSet
source_registrations = """sources/13 = SubResource("Source_front_dmg1")
sources/14 = SubResource("Source_front_dmg2")
"""
# Insert after sources/9 (or whatever the last source is, let's just insert before TileSet_main end)
content = re.sub(r'(sources/9 = SubResource\("Source_fog"\)\n)', r'\1' + source_registrations, content)

# 4. Add the FrontDamageLayer node
layer_node = """[node name="FrontDamageLayer" type="TileMapLayer" parent="MapLayers"]
tile_set = SubResource("TileSet_main")

"""
content = re.sub(r'(\[node name="DamageLayer" type="TileMapLayer" parent="MapLayers"\]\ntile_set = SubResource\("TileSet_main"\)\n)', r'\1\n' + layer_node, content)

with open("main.tscn", "w") as f:
    f.write(content)

print("Added FrontDamageLayer and new sources to main.tscn")
