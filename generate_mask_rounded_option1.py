import os
from PIL import Image, ImageDraw

def create_mask_atlas(output_file):
    atlas = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
    
    for i in range(16):
        x_offset = (i % 4) * 64
        y_offset = (i // 4) * 64
        
        tile = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
        draw_tile = ImageDraw.Draw(tile)
        
        top_open = (i & 1) != 0
        right_open = (i & 2) != 0
        bottom_open = (i & 4) != 0
        left_open = (i & 8) != 0
        
        # 1. Base core - rounded rectangle in the center!
        draw_tile.rounded_rectangle([12, 12, 51, 51], radius=12, fill=(0, 0, 0, 255))
        
        # 2. Extensions to the edges if the neighbor is solid
        # OPTION 1: We use rounded_rectangle for the extensions so the dead ends are rounded.
        # This will create small notches on the straight walls, as agreed.
        radius = 8 # 8 pixels for a nice visible curve
        
        if not top_open:
            draw_tile.rounded_rectangle([12, 0, 51, 24], radius=radius, fill=(0, 0, 0, 255))
        if not right_open:
            draw_tile.rounded_rectangle([40, 12, 63, 51], radius=radius, fill=(0, 0, 0, 255))
        if not bottom_open:
            draw_tile.rounded_rectangle([12, 40, 51, 63], radius=radius, fill=(0, 0, 0, 255))
        if not left_open:
            draw_tile.rounded_rectangle([0, 12, 24, 51], radius=radius, fill=(0, 0, 0, 255))
            
        # 3. Fill the corners if both neighbors are solid (inner corners)
        # These remain sharp rectangles so that deep fog has no holes.
        if not top_open and not left_open:
            draw_tile.rectangle([0, 0, 24, 24], fill=(0, 0, 0, 255))
        if not top_open and not right_open:
            draw_tile.rectangle([40, 0, 63, 24], fill=(0, 0, 0, 255))
        if not bottom_open and not left_open:
            draw_tile.rectangle([0, 40, 24, 63], fill=(0, 0, 0, 255))
        if not bottom_open and not right_open:
            draw_tile.rectangle([40, 40, 63, 63], fill=(0, 0, 0, 255))
            
        atlas.paste(tile, (x_offset, y_offset))
        
    atlas.save(output_file)
    print(f"Generated {output_file} with Option 1: Rounded Extensions!")

create_mask_atlas("fog_mask_atlas.png")
