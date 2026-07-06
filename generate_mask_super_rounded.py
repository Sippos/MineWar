import os
from PIL import Image, ImageDraw

def create_mask_atlas(output_file):
    atlas = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
    
    for i in range(16):
        x_offset = (i % 4) * 64
        y_offset = (i // 4) * 64
        
        tile = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
        draw = ImageDraw.Draw(tile)
        
        top_open = (i & 1) != 0
        right_open = (i & 2) != 0
        bottom_open = (i & 4) != 0
        left_open = (i & 8) != 0
        
        # 1. Base core - rounded rectangle in the center!
        draw.rounded_rectangle([12, 12, 51, 51], radius=12, fill=(0, 0, 0, 255))
        
        # 2. Extensions to the edges if the neighbor is solid
        if not top_open: draw.rectangle([12, 0, 51, 24], fill=(0, 0, 0, 255))
        if not right_open: draw.rectangle([40, 12, 63, 51], fill=(0, 0, 0, 255))
        if not bottom_open: draw.rectangle([12, 40, 51, 63], fill=(0, 0, 0, 255))
        if not left_open: draw.rectangle([0, 12, 24, 51], fill=(0, 0, 0, 255))
            
        # 3. Fill the corners if both neighbors are solid (inner corners)
        if not top_open and not left_open: draw.rectangle([0, 0, 24, 24], fill=(0, 0, 0, 255))
        if not top_open and not right_open: draw.rectangle([40, 0, 63, 24], fill=(0, 0, 0, 255))
        if not bottom_open and not left_open: draw.rectangle([0, 40, 24, 63], fill=(0, 0, 0, 255))
        if not bottom_open and not right_open: draw.rectangle([40, 40, 63, 63], fill=(0, 0, 0, 255))
        
        # 4. Hide the ugly boundary lines by rounding the fog into the open tunnel!
        # If exactly ONE adjacent side is open, it's a straight wall. 
        # The edge of the wall has a boundary line. Hide it with a pie slice!
        if top_open != left_open:
            draw.pieslice([0, 0, 24, 24], 180, 270, fill=(0,0,0,255))
        if top_open != right_open:
            draw.pieslice([40, 0, 64, 24], 270, 360, fill=(0,0,0,255))
        if bottom_open != left_open:
            draw.pieslice([0, 40, 24, 64], 90, 180, fill=(0,0,0,255))
        if bottom_open != right_open:
            draw.pieslice([40, 40, 64, 64], 0, 90, fill=(0,0,0,255))
            
        atlas.paste(tile, (x_offset, y_offset))
        
    atlas.save(output_file)
    print(f"Generated {output_file} with super rounded corners!")

create_mask_atlas("fog_mask_atlas.png")

