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
        if not top_open:
            draw_tile.rectangle([12, 0, 51, 24], fill=(0, 0, 0, 255))
        if not right_open:
            draw_tile.rectangle([40, 12, 63, 51], fill=(0, 0, 0, 255))
        if not bottom_open:
            draw_tile.rectangle([12, 40, 51, 63], fill=(0, 0, 0, 255))
        if not left_open:
            draw_tile.rectangle([0, 12, 24, 51], fill=(0, 0, 0, 255))
            
        # 3. Fill the corners if both neighbors are solid (deep inside fog)
        if not top_open and not left_open:
            draw_tile.rectangle([0, 0, 24, 24], fill=(0, 0, 0, 255))
        if not top_open and not right_open:
            draw_tile.rectangle([40, 0, 63, 24], fill=(0, 0, 0, 255))
        if not bottom_open and not left_open:
            draw_tile.rectangle([0, 40, 24, 63], fill=(0, 0, 0, 255))
        if not bottom_open and not right_open:
            draw_tile.rectangle([40, 40, 63, 63], fill=(0, 0, 0, 255))
            
        # 4. Apply Inverted Corners to round the inner tunnel corners and dead ends!
        mask = Image.new('L', (64, 64), 0)
        draw_m = ImageDraw.Draw(mask)
        
        # Top-Left Corner
        if not (top_open and bottom_open and not left_open) and not (left_open and right_open and not top_open):
            draw_m.rectangle([0, 0, 11, 11], fill=255)
            draw_m.ellipse([0, 0, 24, 24], fill=0)
            
        # Top-Right Corner
        if not (top_open and bottom_open and not right_open) and not (left_open and right_open and not top_open):
            draw_m.rectangle([52, 0, 63, 11], fill=255)
            draw_m.ellipse([39, 0, 63, 24], fill=0)
            
        # Bottom-Left Corner
        if not (top_open and bottom_open and not left_open) and not (left_open and right_open and not bottom_open):
            draw_m.rectangle([0, 52, 11, 63], fill=255)
            draw_m.ellipse([0, 39, 24, 63], fill=0)
            
        # Bottom-Right Corner
        if not (top_open and bottom_open and not right_open) and not (left_open and right_open and not bottom_open):
            draw_m.rectangle([52, 52, 63, 63], fill=255)
            draw_m.ellipse([39, 39, 63, 63], fill=0)
            
        black_tile = Image.new('RGBA', (64, 64), (0, 0, 0, 255))
        tile.paste(black_tile, (0, 0), mask)
            
        atlas.paste(tile, (x_offset, y_offset))
        
    atlas.save(output_file)
    print(f"Generated {output_file} with perfectly rounded inner corners and dead ends!")

create_mask_atlas("assets/sprites/world/fog/fog_mask_atlas.png")

