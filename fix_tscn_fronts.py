import re

with open("scenes/boot/main.tscn", "r") as f:
    content = f.read()

# Replace the texture paths for front walls
content = content.replace('path="res://Easy_Front.png"', 'path="res://Easy_Brick_Gradient.png"')
content = content.replace('path="res://Medium_Front.png"', 'path="res://Middle_Brick_Gradient.png"')
content = content.replace('path="res://Hard_Front.png"', 'path="res://Hard_Brick_Gradient.png"')

# Now add texture_origin = Vector2i(0, 32) to shift the sprites UP by 32 pixels!
# The syntax in Godot 4 .tscn for TileSetAtlasSource tile properties is:
# 0:0/0 = 0
# 0:0/0/texture_origin = Vector2i(0, 32)

# Source 10, 11, 12 are the front walls
sources_to_modify = [
    'id="Source_front_easy"',
    'id="Source_front_med"',
    'id="Source_front_hard"'
]

for source in sources_to_modify:
    # Find the block for this source
    # Pattern: [sub_resource type="TileSetAtlasSource" id="Source_front_easy"]\n... 0:0/0 = 0
    pattern = rf'(\[sub_resource type="TileSetAtlasSource" {source}\].*?0:0/0 = 0)'
    
    # We use re.sub with DOTALL to match across lines
    # Then append \n0:0/0/texture_origin = Vector2i(0, 32)
    def repl(m):
        return m.group(1) + '\n0:0/0/texture_origin = Vector2i(0, 32)'
        
    content = re.sub(pattern, repl, content, flags=re.DOTALL)

with open("scenes/boot/main.tscn", "w") as f:
    f.write(content)

print("Updated main.tscn with new gradients and texture_origin offset!")
