import os
from PIL import Image, ImageDraw

def create_edge_atlas(source_file, output_file):
    if not os.path.exists(source_file):
        return
        
    src_img = Image.open(source_file).convert("RGBA")
    if src_img.size != (64, 64):
        src_img = src_img.resize((64, 64), Image.NEAREST)
        
    atlas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    
    for i in range(16):
        x_offset = (i % 4) * 64
        y_offset = (i // 4) * 64
        
        tile = src_img.copy()
        draw = ImageDraw.Draw(tile)
        
        top_open = (i & 1) != 0
        right_open = (i & 2) != 0
        bottom_open = (i & 4) != 0
        left_open = (i & 8) != 0
        
        def clear_rect(x1, y1, x2, y2):
            draw.rectangle([x1, y1, x2, y2], fill=(0,0,0,0))
            
        def clear_pie(x1, y1, x2, y2, start, end):
            draw.pieslice([x1, y1, x2, y2], start, end, fill=(0,0,0,0))
            
        # 1. Erase borders on closed sides (NO COPYING to avoid doubling)
        if not top_open: clear_rect(12, 0, 51, 11)
        if not bottom_open: clear_rect(12, 52, 51, 63)
        if not left_open: clear_rect(0, 12, 11, 51)
        if not right_open: clear_rect(52, 12, 63, 51)
        
        # 2. Erase outer corners if both adjacent sides are closed
        if not top_open and not left_open: clear_rect(0, 0, 11, 11)
        if not top_open and not right_open: clear_rect(52, 0, 63, 11)
        if not bottom_open and not left_open: clear_rect(0, 52, 11, 63)
        if not bottom_open and not right_open: clear_rect(52, 52, 63, 63)
        
        # 3. ROUND THE INNER CORNERS! (if both adjacent sides are OPEN)
        # This removes the "black dot" sharp corner of the border!
        radius = 12
        if top_open and left_open:
            # The inner corner is at (12, 12). Clear a pie slice to round it!
            # Bounding box for a circle centered at (12,12) with radius 12 is (0,0,24,24)
            clear_pie(-12, -12, 12, 12, 0, 90) # Top-Left inner corner
            # Wait, easier to just clear a small rectangle to nip the tip off
            clear_rect(12, 12, 16, 16) 
            
        if top_open and right_open:
            clear_rect(47, 12, 51, 16)
            
        if bottom_open and left_open:
            clear_rect(12, 47, 16, 51)
            
        if bottom_open and right_open:
            clear_rect(47, 47, 51, 51)
            
        atlas.paste(tile, (x_offset, y_offset))
        
    atlas.save(output_file)
    print(f"Generated {output_file} with reverted logic and rounded inner corners!")

create_edge_atlas("Easy_Brick_Border_gradient.png", "Easy_Edge_Atlas.png")
create_edge_atlas("Middle_Brick_Border_Gradient.png", "Medium_Edge_Atlas.png")
create_edge_atlas("Hard_Brick_Border_Gradient.png", "Hard_Edge_Atlas.png")

