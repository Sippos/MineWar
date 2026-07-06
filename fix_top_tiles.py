import re

with open("main.tscn", "r") as f:
    content = f.read()

# Update the top blocks to use the new gradient files
content = content.replace('path="res://Easy_Brick.png"', 'path="res://Easy_Brick_Gradient.png"')
content = content.replace('path="res://Medium_Brick.png"', 'path="res://Middle_Brick_Gradient.png"')
content = content.replace('path="res://Hard_Brick.png"', 'path="res://Hard_Brick_Gradient.png"')

with open("main.tscn", "w") as f:
    f.write(content)

print("Updated main.tscn to use new gradient sprites for top blocks!")
