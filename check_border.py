from PIL import Image
img = Image.open('assets/sprites/world/terrain/dome/Easy_Border_Atlas.png').convert('RGBA')
w, h = img.size
trans_pixels = 0
for y in range(h):
    for x in range(w):
        r, g, b, a = img.getpixel((x, y))
        if a < 255:
            trans_pixels += 1
print(f"Total transparent pixels: {trans_pixels} out of {w*h}")
