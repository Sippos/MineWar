import sys

def add_shadow_sub_resources(content):
    if "Gradient_shadow" in content:
        return content
    # Find the last sub_resource
    lines = content.split('\n')
    last_sub_res_index = -1
    for i, line in enumerate(lines):
        if line.startswith('[sub_resource '):
            last_sub_res_index = i
            
    # Find the end of that sub_resource block
    insert_idx = last_sub_res_index + 1
    while insert_idx < len(lines) and (lines[insert_idx].strip() != '' and not lines[insert_idx].startswith('[')):
        insert_idx += 1
        
    shadow_resources = """
[sub_resource type="Gradient" id="Gradient_shadow"]
colors = PackedColorArray(0, 0, 0, 0.6, 0, 0, 0, 0)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_shadow"]
gradient = SubResource("Gradient_shadow")
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(0.8, 0.8)
width = 48
height = 24
"""
    lines.insert(insert_idx, shadow_resources.strip() + "\n")
    return "\n".join(lines)

def process_level():
    with open('level.tscn', 'r') as f:
        content = f.read()
        
    content = add_shadow_sub_resources(content)
    
    # Add Shadow node to Player
    player_idx = content.find('[node name="Player" type="CharacterBody2D"')
    if player_idx == -1: return
    sprite_idx = content.find('[node name="Sprite2D" type="Sprite2D" parent="Player"]', player_idx)
    
    if "name=\"Shadow\"" not in content[player_idx:sprite_idx]:
        shadow_node = """[node name="Shadow" type="Sprite2D" parent="Player"]
position = Vector2(0, 0)
texture = SubResource("GradientTexture2D_shadow")

"""
        content = content[:sprite_idx] + shadow_node + content[sprite_idx:]
        
    with open('level.tscn', 'w') as f:
        f.write(content)

def process_enemy():
    with open('enemy.tscn', 'r') as f:
        content = f.read()
        
    content = add_shadow_sub_resources(content)
    
    sprite_idx = content.find('[node name="Sprite2D" type="Sprite2D" parent="."]')
    if "name=\"Shadow\"" not in content[:sprite_idx]:
        shadow_node = """[node name="Shadow" type="Sprite2D" parent="."]
position = Vector2(0, 8)
texture = SubResource("GradientTexture2D_shadow")

"""
        content = content[:sprite_idx] + shadow_node + content[sprite_idx:]
        
    with open('enemy.tscn', 'w') as f:
        f.write(content)

process_level()
process_enemy()
