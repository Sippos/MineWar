import re
with open("tools/sprite_lab/dome_corner_builder.gd", "r") as f:
    text = f.read()

print("Found _map_corner_point:")
match = re.search(r'static func _map_corner_point.*?(?=static func)', text, re.DOTALL)
if match:
    print(match.group(0))
