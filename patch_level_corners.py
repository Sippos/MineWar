import re

with open('scenes/world/mine/level.tscn', 'r') as f:
    content = f.read()

layers = """[node name="InsideCornerTL" type="TileMapLayer" parent="." unique_id=2000000000]
z_index = 2
tile_set = SubResource("TileSet_main")

[node name="InsideCornerTR" type="TileMapLayer" parent="." unique_id=2000000001]
z_index = 2
tile_set = SubResource("TileSet_main")

[node name="InsideCornerBL" type="TileMapLayer" parent="." unique_id=2000000002]
z_index = 2
tile_set = SubResource("TileSet_main")

[node name="InsideCornerBR" type="TileMapLayer" parent="." unique_id=2000000003]
z_index = 2
tile_set = SubResource("TileSet_main")"""

content = content.replace(
"""[node name="InsideCornerLayer" type="TileMapLayer" parent="." unique_id=1939264170]
z_index = 2
tile_set = SubResource("TileSet_main")""",
layers
)

with open('scenes/world/mine/level.tscn', 'w') as f:
    f.write(content)
