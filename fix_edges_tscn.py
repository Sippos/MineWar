import re

with open("scenes/boot/main.tscn", "r") as f:
    content = f.read()

# Replace edge crust textures
content = content.replace('path="res://Easy_Brick_Border.png"', 'path="res://Easy_Brick_Border_gradient.png"')
content = content.replace('path="res://Medium_Brick_Border.png"', 'path="res://Middle_Brick_Border_Gradient.png"')
content = content.replace('path="res://Hard_Brick_Border.png"', 'path="res://Hard_Brick_Border_Gradient.png"')

with open("scenes/boot/main.tscn", "w") as f:
    f.write(content)

print("Updated main.tscn with new edge crusts")
