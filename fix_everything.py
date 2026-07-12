import os
import re
from PIL import Image

def process_image(filename):
    if not os.path.exists(filename): return
    img = Image.open(filename)
    if img.size == (32, 32):
        img_resized = img.resize((64, 64), Image.NEAREST)
        img_resized.save(filename)
        print(f"Resized {filename} to 64x64")
    else:
        print(f"{filename} is already {img.size}")

files = [
    "Easy_Brick_Gradient.png",
    "Middle_Brick_Gradient.png",
    "Hard_Brick_Gradient.png",
    "Easy_Brick_Border_gradient.png",
    "Middle_Brick_Border_Gradient.png",
    "Hard_Brick_Border_Gradient.png"
]

for f in files:
    process_image(f)

# Now fix main.tscn back so top blocks use original flat bricks
with open("scenes/boot/main.tscn", "r") as f:
    content = f.read()

# We need to change the path for tex_easy, tex_med, tex_hard back to original
# In Godot .tscn:
# [ext_resource type="Texture2D" path="res://Easy_Brick_Gradient.png" id="tex_easy"]
# We want to change that back to Easy_Brick.png.
# BUT we also have tex_front_easy which uses Easy_Brick_Gradient.png, we DO NOT want to change that.

content = re.sub(r'path="res://Easy_Brick_Gradient\.png" id="tex_easy"', 'path="res://Easy_Brick.png" id="tex_easy"', content)
content = re.sub(r'path="res://Middle_Brick_Gradient\.png" id="tex_med"', 'path="res://Medium_Brick.png" id="tex_med"', content)
content = re.sub(r'path="res://Hard_Brick_Gradient\.png" id="tex_hard"', 'path="res://Hard_Brick.png" id="tex_hard"', content)

with open("scenes/boot/main.tscn", "w") as f:
    f.write(content)

print("Updated main.tscn top blocks back to flat bricks.")
