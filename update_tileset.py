import re

with open("main.tscn", "r") as f:
    content = f.read()

# Replace the texture paths back to original
content = content.replace('res://fog_mask_atlas_256.png', 'res://fog_mask_atlas.png')
content = content.replace('res://Easy_Edge_Atlas_256.png', 'res://Easy_Edge_Atlas.png')
content = content.replace('res://Medium_Edge_Atlas_256.png', 'res://Medium_Edge_Atlas.png')
content = content.replace('res://Hard_Edge_Atlas_256.png', 'res://Hard_Edge_Atlas.png')

def revert_source(source_id, content):
    pattern = r'(\[sub_resource type="TileSetAtlasSource" id="' + source_id + r'"\]\ntexture = ExtResource\(".*?"\)\ntexture_region_size = Vector2i\(64, 64\)\n)(.*?)(?=\n\n|\Z)'
    
    match = re.search(pattern, content, re.DOTALL)
    if match:
        header = match.group(1)
        
        tiles = []
        for y in range(4):
            for x in range(4):
                tiles.append(f"{x}:{y}/0 = 0")
        
        new_block = header + "\n".join(tiles)
        content = content[:match.start()] + new_block + content[match.end():]
    return content

content = revert_source("Source_edge_easy", content)
content = revert_source("Source_edge_med", content)
content = revert_source("Source_edge_hard", content)
content = revert_source("Source_fog", content)

with open("main.tscn", "w") as f:
    f.write(content)

print("Reverted main.tscn to 16-tile definitions!")
