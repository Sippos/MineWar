import re

with open("main.tscn", "r") as f:
    content = f.read()

# Replace the texture paths
content = content.replace('path="res://Easy_Brick_Border_gradient.png" id="tex_edge_easy"', 'path="res://Easy_Edge_Atlas.png" id="tex_edge_easy"')
content = content.replace('path="res://Middle_Brick_Border_Gradient.png" id="tex_edge_med"', 'path="res://Medium_Edge_Atlas.png" id="tex_edge_med"')
content = content.replace('path="res://Hard_Brick_Border_Gradient.png" id="tex_edge_hard"', 'path="res://Hard_Edge_Atlas.png" id="tex_edge_hard"')

# Define the 16 tiles
sixteen_tiles = """0:0/0 = 0
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

sources_to_modify = [
    'id="Source_edge_easy"',
    'id="Source_edge_med"',
    'id="Source_edge_hard"'
]

for source in sources_to_modify:
    pattern = rf'(\[sub_resource type="TileSetAtlasSource" {source}\].*?texture_region_size = Vector2i\(64, 64\)\n)0:0/0 = 0'
    
    def repl(m):
        return m.group(1) + sixteen_tiles
        
    content = re.sub(pattern, repl, content, flags=re.DOTALL)

with open("main.tscn", "w") as f:
    f.write(content)

print("Updated main.tscn with 16-tile edge atlases.")
