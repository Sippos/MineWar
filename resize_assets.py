from PIL import Image
import os

files_to_resize = [
    "assets/sprites/world/terrain/bricks/Easy_Brick.png", "assets/sprites/world/terrain/bricks/Medium_Brick.png", "assets/sprites/world/terrain/bricks/Hard_Brick.png",
    "Easy_Brick_Border.png", "Medium_Brick_Border.png", "Hard_Brick_Border.png",
    "Black_BG.png", "assets/sprites/world/terrain/Black_BG_TransparentBorder.png",
    "assets/sprites/world/terrain/damage/First_Hitting.png", "assets/sprites/world/terrain/damage/Second_Hitting.png"
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
