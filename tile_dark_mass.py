import os
from PIL import Image

def tile_3x3(path):
    img = Image.open(path).convert('RGBA')
    w, h = img.size
    
    # Create 3x3 tiled image
    tiled = Image.new('RGBA', (w*3, h*3))
    for y in range(3):
        for x in range(3):
            tiled.paste(img, (x*w, y*h))
            
    tiled.save(path)
    print(f"Tiled {path} to 3x3 ({w*3}x{h*3})")

tile_3x3("assets/sprites/world/terrain/dome/Dome_Dark_Mass.png")
