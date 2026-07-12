from PIL import Image, ImageDraw

atlas = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
draw = ImageDraw.Draw(atlas)

for i in range(16):
    x_offset = (i % 4) * 64
    y_offset = (i // 4) * 64
    
    # Draw solid black tile
    draw.rectangle([x_offset, y_offset, x_offset + 63, y_offset + 63], fill=(0, 0, 0, 255))
    
    # Define borders to make transparent
    top_open = (i & 1) != 0
    right_open = (i & 2) != 0
    bottom_open = (i & 4) != 0
    left_open = (i & 8) != 0
    
    # Clear edges (12 pixels on 64x64 scale, which is 6px on 32x32)
    if top_open:
        draw.rectangle([x_offset, y_offset, x_offset + 63, y_offset + 11], fill=(0, 0, 0, 0))
    if right_open:
        draw.rectangle([x_offset + 52, y_offset, x_offset + 63, y_offset + 63], fill=(0, 0, 0, 0))
    if bottom_open:
        draw.rectangle([x_offset, y_offset + 52, x_offset + 63, y_offset + 63], fill=(0, 0, 0, 0))
    if left_open:
        draw.rectangle([x_offset, y_offset, x_offset + 11, y_offset + 63], fill=(0, 0, 0, 0))

atlas.save('assets/sprites/world/fog/fog_mask_atlas.png')
print("Updated assets/sprites/world/fog/fog_mask_atlas.png with thicker borders")
