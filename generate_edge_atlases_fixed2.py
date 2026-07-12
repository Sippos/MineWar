import os
from PIL import Image, ImageDraw

def create_edge_atlas(source_file, output_file):
    if not os.path.exists(source_file):
        print(f"Missing {source_file}")
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
        
        # ImageDraw.rectangle bounds are inclusive!
        def clear_rect(x1, y1, x2, y2):
            draw.rectangle([x1, y1, x2, y2], fill=(0,0,0,0))
            
        def copy_rect(src_box, dst_x, dst_y):
            region = src_img.crop(src_box) # crop bounds are (left, top, right, bottom) where right/bottom are exclusive
            tile.paste(region, (dst_x, dst_y))
            
        # Edges
        if not top_open: clear_rect(12, 0, 51, 11)
        if not bottom_open: clear_rect(12, 52, 51, 63)
        if not left_open: clear_rect(0, 12, 11, 51)
        if not right_open: clear_rect(52, 12, 63, 51)
        
        # Corners
        if not top_open and not left_open: 
            clear_rect(0, 0, 11, 11)
        elif top_open and not left_open:
            copy_rect((24, 0, 36, 12), 0, 0)
        elif left_open and not top_open:
            copy_rect((0, 24, 12, 36), 0, 0)
            
        if not top_open and not right_open: 
            clear_rect(52, 0, 63, 11)
        elif top_open and not right_open:
            copy_rect((24, 0, 36, 12), 52, 0)
        elif right_open and not top_open:
            copy_rect((52, 24, 64, 36), 52, 0)
            
        if not bottom_open and not left_open: 
            clear_rect(0, 52, 11, 63)
        elif bottom_open and not left_open:
            copy_rect((24, 52, 36, 64), 0, 52)
        elif left_open and not bottom_open:
            copy_rect((0, 24, 12, 36), 0, 52)
            
        if not bottom_open and not right_open: 
            clear_rect(52, 52, 63, 63)
        elif bottom_open and not right_open:
            copy_rect((24, 52, 36, 64), 52, 52)
        elif right_open and not bottom_open:
            copy_rect((52, 24, 64, 36), 52, 52)
            
        atlas.paste(tile, (x_offset, y_offset))
        
    atlas.save(output_file)
    print(f"Generated {output_file} with PERFECT corners!")

create_edge_atlas("Easy_Brick_Border_gradient.png", "assets/sprites/world/terrain/edges/Easy_Edge_Atlas.png")
create_edge_atlas("Middle_Brick_Border_Gradient.png", "assets/sprites/world/terrain/edges/Medium_Edge_Atlas.png")
create_edge_atlas("Hard_Brick_Border_Gradient.png", "assets/sprites/world/terrain/edges/Hard_Edge_Atlas.png")

