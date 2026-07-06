import os
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
    "Easy_Brick-Front.png",
    "First-Hit-Front.png",
    "Next-Hit-Front.png"
]

for f in files:
    process_image(f)
