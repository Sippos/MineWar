import os
from PIL import Image, ImageDraw

def create_solid(color, filename):
    img = Image.new('RGBA', (64, 64), color)
    img.save(filename)

def create_edge(filename):
    img = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Draw a 4px inner border
    draw.rectangle([0, 0, 63, 63], outline=(200, 200, 150, 200), width=4)
    img.save(filename)

def create_damage(filename):
    img = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Draw some cracks
    draw.line([32, 32, 10, 10], fill=(255, 255, 255, 200), width=2)
    draw.line([32, 32, 50, 15], fill=(255, 255, 255, 200), width=2)
    draw.line([32, 32, 40, 50], fill=(255, 255, 255, 200), width=2)
    img.save(filename)

# Base blocks (making them 64x64 since TileSet_block in main.tscn uses 64x64)
create_solid((139, 69, 19, 255), "block_easy.png")    # Brown
create_solid((101, 67, 33, 255), "block_med.png")     # Dark Brown
create_solid((80, 80, 80, 255), "block_hard.png")      # Gray

# Fog
create_solid((0, 0, 0, 255), "fog.png")

# Background
create_solid((30, 25, 40, 255), "bg.png")

# Overlays
create_edge("edge.png")
create_damage("damage.png")

print("Created placeholder sprites.")
