with open('scenes/world/mine/level.tscn', 'r') as f:
    content = f.read()

# Make sure FrontWallLayer is explicitly above BlockLayer but below EdgeLayer just in case!
content = content.replace(
"""[node name="FrontWallLayer" type="TileMapLayer" parent="." unique_id=601881360]
y_sort_enabled = true
tile_set = SubResource("TileSet_main")""",
"""[node name="FrontWallLayer" type="TileMapLayer" parent="." unique_id=601881360]
z_index = 1
y_sort_enabled = true
tile_set = SubResource("TileSet_main")"""
)

content = content.replace(
"""[node name="EdgeLayer" type="TileMapLayer" parent="." unique_id=1939264169]
z_index = 1
tile_set = SubResource("TileSet_main")""",
"""[node name="EdgeLayer" type="TileMapLayer" parent="." unique_id=1939264169]
z_index = 2
tile_set = SubResource("TileSet_main")"""
)

# Also bump inside corners
for x in ["TL", "TR", "BL", "BR"]:
    content = content.replace(
f"""[node name="InsideCorner{x}" type="TileMapLayer" parent="." unique_id=200000000{['TL', 'TR', 'BL', 'BR'].index(x)}]
z_index = 2
tile_set = SubResource("TileSet_main")""",
f"""[node name="InsideCorner{x}" type="TileMapLayer" parent="." unique_id=200000000{['TL', 'TR', 'BL', 'BR'].index(x)}]
z_index = 3
tile_set = SubResource("TileSet_main")"""
    )

with open('scenes/world/mine/level.tscn', 'w') as f:
    f.write(content)
