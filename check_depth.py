from PIL import Image
img = Image.open('assets/sprites/world/terrain/dome/Unmineable_Border_Atlas.png').convert('RGBA')
w, h = img.size
# find depth of straight border (mask 1, top border)
# mask 1 is at tile (1, 0), so x=64..127, y=0..63
deepest = -1
for y in range(64):
    for x in range(64, 128):
        r, g, b, a = img.getpixel((x, y))
        if a > 12:
            deepest = max(deepest, y)
print(f"Unmineable depth: {deepest + 1}")
