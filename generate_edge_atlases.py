import os
from PIL import Image, ImageDraw

def create_edge_atlas(source_file, output_file):
    if not os.path.exists(source_file):
        print(f"Missing {source_file}")
        return
        
    src_img = Image.open(source_file).convert("RGBA")
    # Ensure it is 64x64
    if src_img.size != (64, 64):
        src_img = src_img.resize((64, 64), Image.NEAREST)
        
    atlas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    
    for i in range(16):
        x_offset = (i % 4) * 64
        y_offset = (i // 4) * 64
        
        # Paste the base border
        atlas.paste(src_img, (x_offset, y_offset))
        
        # Create a drawing context for this tile to erase parts
        draw = ImageDraw.Draw(atlas)
        
        top_open = (i & 1) != 0
        right_open = (i & 2) != 0
        bottom_open = (i & 4) != 0
        left_open = (i & 8) != 0
        
        # Helper to clear a rect
        def clear_rect(x1, y1, x2, y2):
            draw.rectangle([x_offset + x1, y_offset + y1, x_offset + x2, y_offset + y2], fill=(0,0,0,0))
            
        # Edges
        if not top_open: clear_rect(12, 0, 51, 11)
        if not bottom_open: clear_rect(12, 52, 51, 63)
        if not left_open: clear_rect(0, 12, 11, 51)
        if not right_open: clear_rect(52, 12, 63, 51)
        
        # Corners
        if not top_open and not left_open: clear_rect(0, 0, 11, 11)
        if not top_open and not right_open: clear_rect(52, 0, 63, 11)
        if not bottom_open and not left_open: clear_rect(0, 52, 11, 63)
        if not bottom_open and not right_open: clear_rect(52, 52, 63, 63)
        
    atlas.save(output_file)
    print(f"Generated {output_file}")

create_edge_atlas("Easy_Brick_Border_gradient.png", "assets/sprites/world/terrain/edges/Easy_Edge_Atlas.png")
create_edge_atlas("Middle_Brick_Border_Gradient.png", "assets/sprites/world/terrain/edges/Medium_Edge_Atlas.png")
create_edge_atlas("Hard_Brick_Border_Gradient.png", "assets/sprites/world/terrain/edges/Hard_Edge_Atlas.png")

