import os
from PIL import Image, ImageDraw

def create_mask_atlas(output_file):
    atlas = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
    
    for i in range(16):
        x_offset = (i % 4) * 64
        y_offset = (i // 4) * 64
        
        # Create a grayscale mask where 255 is TUNNEL (transparent), 0 is FOG (black)
        mask = Image.new('L', (64, 64), 0)
        draw = ImageDraw.Draw(mask)
        
        top_open = (i & 1) != 0
        right_open = (i & 2) != 0
        bottom_open = (i & 4) != 0
        left_open = (i & 8) != 0
        
        if top_open or bottom_open or left_open or right_open:
            # Draw central circle to perfectly round all dead ends and intersections
            # Bounding box width = 40 (12 to 51)
            draw.ellipse([12, 12, 51, 51], fill=255)
            
            # Draw straight rectangles for the open tunnels
            if top_open:
                draw.rectangle([12, 0, 51, 31], fill=255)
            if right_open:
                draw.rectangle([32, 12, 63, 51], fill=255)
            if bottom_open:
                draw.rectangle([12, 32, 51, 63], fill=255)
            if left_open:
                draw.rectangle([0, 12, 31, 51], fill=255)
                
        # Now convert the mask to the RGBA tile
        # Where mask is 0 (Fog), we want black (0,0,0,255)
        # Where mask is 255 (Tunnel), we want transparent (0,0,0,0)
        tile = Image.new('RGBA', (64, 64), (0, 0, 0, 255))
        tile.putalpha(Image.eval(mask, lambda a: 255 - a))
        
        atlas.paste(tile, (x_offset, y_offset))
        
    atlas.save(output_file)
    print(f"Generated {output_file} with PERFECT path-based rounding!")

create_mask_atlas("fog_mask_atlas.png")

