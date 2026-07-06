from PIL import Image
import os

files_to_resize = [
    "Easy_Brick.png", "Medium_Brick.png", "Hard_Brick.png",
    "Easy_Brick_Border.png", "Medium_Brick_Border.png", "Hard_Brick_Border.png",
    "Black_BG.png", "Black_BG_TransparentBorder.png",
    "First_Hitting.png", "Second_Hitting.png"
]

for file in files_to_resize:
    if os.path.exists(file):
        img = Image.open(file)
        if img.size == (32, 32):
            img_resized = img.resize((64, 64), Image.Resampling.NEAREST)
            img_resized.save(file)
            print(f"Resized {file} to 64x64")
        else:
            print(f"{file} is already {img.size}")
    else:
        print(f"File not found: {file}")
