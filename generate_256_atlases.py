import os
from PIL import Image, ImageDraw

def create_256_edge_atlas(base_img_path, output_name):
    if not os.path.exists(base_img_path):
        print(f"Error: {base_img_path} not found.")
        return
        
    base_img = Image.open(base_img_path).convert("RGBA")
    if base_img.size != (64, 64):
        base_img = base_img.resize((64, 64), Image.NEAREST)
        
    atlas = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    
    q_states = {0: {}, 1: {}, 2: {}, 3: {}}
    
    def composite(img1, img2):
        res = Image.new('RGBA', (32, 32), (0,0,0,0))
        res.alpha_composite(img1)
        res.alpha_composite(img2)
        return res

    q_states[0][0] = Image.new('RGBA', (32, 32), (0,0,0,0))
    q_states[0][1] = base_img.crop((16, 0, 48, 32))
    q_states[0][2] = base_img.crop((0, 16, 32, 48))
    q_states[0][3] = base_img.crop((0, 0, 32, 32))
    q_states[0][4] = composite(q_states[0][1], q_states[0][2])

    q_states[1][0] = Image.new('RGBA', (32, 32), (0,0,0,0))
    q_states[1][1] = base_img.crop((16, 0, 48, 32))
    q_states[1][2] = base_img.crop((32, 16, 64, 48))
    q_states[1][3] = base_img.crop((32, 0, 64, 32))
    q_states[1][4] = composite(q_states[1][1], q_states[1][2])

    q_states[2][0] = Image.new('RGBA', (32, 32), (0,0,0,0))
    q_states[2][1] = base_img.crop((16, 32, 48, 64))
    q_states[2][2] = base_img.crop((0, 16, 32, 48))
    q_states[2][3] = base_img.crop((0, 32, 32, 64))
    q_states[2][4] = composite(q_states[2][1], q_states[2][2])

    q_states[3][0] = Image.new('RGBA', (32, 32), (0,0,0,0))
    q_states[3][1] = base_img.crop((16, 32, 48, 64))
    q_states[3][2] = base_img.crop((32, 16, 64, 48))
    q_states[3][3] = base_img.crop((32, 32, 64, 64))
    q_states[3][4] = composite(q_states[3][1], q_states[3][2])

    for mask in range(256):
        x_offset = (mask % 16) * 64
        y_offset = (mask // 16) * 64
        
        T = (mask & 1) != 0
        TR = (mask & 2) != 0
        R = (mask & 4) != 0
        BR = (mask & 8) != 0
        B = (mask & 16) != 0
        BL = (mask & 32) != 0
        L = (mask & 64) != 0
        TL = (mask & 128) != 0
        
        tile = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
        
        if T and L: s = 3
        elif T and not L: s = 1
        elif not T and L: s = 2
        else: s = 4 if TL else 0
        tile.paste(q_states[0][s], (0, 0))
        
        if T and R: s = 3
        elif T and not R: s = 1
        elif not T and R: s = 2
        else: s = 4 if TR else 0
        tile.paste(q_states[1][s], (32, 0))
        
        if B and L: s = 3
        elif B and not L: s = 1
        elif not B and L: s = 2
        else: s = 4 if BL else 0
        tile.paste(q_states[2][s], (0, 32))
        
        if B and R: s = 3
        elif B and not R: s = 1
        elif not B and R: s = 2
        else: s = 4 if BR else 0
        tile.paste(q_states[3][s], (32, 32))
        
        atlas.paste(tile, (x_offset, y_offset))
        
    atlas.save(output_name)
    print(f"Generated {output_name}")


def create_256_mask_atlas():
    atlas = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    
    for mask in range(256):
        x_offset = (mask % 16) * 64
        y_offset = (mask // 16) * 64
        
        T = (mask & 1) != 0
        TR = (mask & 2) != 0
        R = (mask & 4) != 0
        BR = (mask & 8) != 0
        B = (mask & 16) != 0
        BL = (mask & 32) != 0
        L = (mask & 64) != 0
        TL = (mask & 128) != 0
        
        tile = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
        draw_tile = ImageDraw.Draw(tile)
        
        # 1. Base core - rounded rectangle in the center
        draw_tile.rounded_rectangle([12, 12, 51, 51], radius=12, fill=(0, 0, 0, 255))
        
        # 2. Straight extensions
        if not T: draw_tile.rectangle([12, 0, 51, 11], fill=(0, 0, 0, 255))
        if not R: draw_tile.rectangle([52, 12, 63, 51], fill=(0, 0, 0, 255))
        if not B: draw_tile.rectangle([12, 52, 51, 63], fill=(0, 0, 0, 255))
        if not L: draw_tile.rectangle([0, 12, 11, 51], fill=(0, 0, 0, 255))
            
        # 3. Corners
        # TL
        if not TL and (not T or not L):
            draw_tile.rectangle([0, 0, 24, 24], fill=(0, 0, 0, 255))
        elif not T and not L and TL:
            draw_tile.rectangle([0, 0, 11, 11], fill=(0, 0, 0, 255))
            draw_tile.ellipse([0, 0, 24, 24], fill=(0, 0, 0, 0))
            
        # TR
        if not TR and (not T or not R):
            draw_tile.rectangle([40, 0, 63, 24], fill=(0, 0, 0, 255))
        elif not T and not R and TR:
            draw_tile.rectangle([52, 0, 63, 11], fill=(0, 0, 0, 255))
            draw_tile.ellipse([39, 0, 63, 24], fill=(0, 0, 0, 0))
            
        # BR
        if not BR and (not B or not R):
            draw_tile.rectangle([40, 40, 63, 63], fill=(0, 0, 0, 255))
        elif not B and not R and BR:
            draw_tile.rectangle([52, 52, 63, 63], fill=(0, 0, 0, 255))
            draw_tile.ellipse([39, 39, 63, 63], fill=(0, 0, 0, 0))
            
        # BL
        if not BL and (not B or not L):
            draw_tile.rectangle([0, 40, 24, 63], fill=(0, 0, 0, 255))
        elif not B and not L and BL:
            draw_tile.rectangle([0, 52, 11, 63], fill=(0, 0, 0, 255))
            draw_tile.ellipse([0, 39, 24, 63], fill=(0, 0, 0, 0))
            
        # 4. Dead Ends
        if T and not B: draw_tile.ellipse([12, 0, 51, 24], fill=(0, 0, 0, 0))
        if R and not L: draw_tile.ellipse([39, 12, 63, 51], fill=(0, 0, 0, 0))
        if B and not T: draw_tile.ellipse([12, 39, 51, 63], fill=(0, 0, 0, 0))
        if L and not R: draw_tile.ellipse([0, 12, 24, 51], fill=(0, 0, 0, 0))
            
        atlas.paste(tile, (x_offset, y_offset))
        
    atlas.save("fog_mask_atlas_256.png")
    print("Generated fog_mask_atlas_256.png")

create_256_edge_atlas("Easy_Brick_Border_gradient.png", "Easy_Edge_Atlas_256.png")
create_256_edge_atlas("Medium_Brick_Border.png", "Medium_Edge_Atlas_256.png")
create_256_edge_atlas("Hard_Brick_Border.png", "Hard_Edge_Atlas_256.png")
create_256_mask_atlas()
