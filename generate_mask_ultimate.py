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
        
        # 1. Full-length edge extensions (12px thick)
        # This completely fixes the "missing corner sprite" and "sharp holes" by ensuring 
        # the entire edge is solid black if the neighbor is solid!
        if not top_open:
            draw_tile.rectangle([0, 0, 63, 11], fill=(0, 0, 0, 255))
        if not right_open:
            draw_tile.rectangle([52, 0, 63, 63], fill=(0, 0, 0, 255))
        if not bottom_open:
            draw_tile.rectangle([0, 52, 63, 63], fill=(0, 0, 0, 255))
        if not left_open:
            draw_tile.rectangle([0, 0, 11, 63], fill=(0, 0, 0, 255))
            
        # 2. Base core - rounded rectangle in the center
        draw_tile.rounded_rectangle([12, 12, 51, 51], radius=12, fill=(0, 0, 0, 255))
        
        # 3. Erase U-shapes for open tunnels!
        # This perfectly mimics the manual erasing done in Piskel, rounding dead ends 
        # and creating the organic curves for intersections.
        if top_open:
            draw_tile.ellipse([12, 0, 51, 24], fill=(0, 0, 0, 0))
        if right_open:
            draw_tile.ellipse([39, 12, 63, 51], fill=(0, 0, 0, 0))
        if bottom_open:
            draw_tile.ellipse([12, 39, 51, 63], fill=(0, 0, 0, 0))
        if left_open:
            draw_tile.ellipse([0, 12, 24, 51], fill=(0, 0, 0, 0))
            
        atlas.paste(tile, (x_offset, y_offset))
        
    atlas.save(output_file)
    print(f"Generated {output_file} with the ULTIMATE Piskel-matching logic!")

create_mask_atlas("fog_mask_atlas.png")

