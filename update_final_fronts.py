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

front_files = [
    "Easy-Brick-Front.png",
    "Medium-Brick-Front.png",
    "Hard-Brick-Front.png"
]

for f in front_files:
    process_image(f)

with open("scenes/boot/main.tscn", "r") as f:
    content = f.read()

# Replace the texture paths for front walls to point to the new files!
content = re.sub(r'path="res://Easy_Brick_Gradient\.png" id="tex_front_easy"', 'path="res://Easy-Brick-Front.png" id="tex_front_easy"', content)
content = re.sub(r'path="res://Middle_Brick_Gradient\.png" id="tex_front_med"', 'path="res://Medium-Brick-Front.png" id="tex_front_med"', content)
content = re.sub(r'path="res://Hard_Brick_Gradient\.png" id="tex_front_hard"', 'path="res://Hard-Brick-Front.png" id="tex_front_hard"', content)

with open("scenes/boot/main.tscn", "w") as f:
    f.write(content)

print("Updated main.tscn to use new dedicated Front files.")
