from PIL import Image, ImageDraw

def generate_peon():
    img = Image.new('RGBA', (64, 64), color=(0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([16, 16, 48, 64], fill=(50, 150, 50, 255)) # Green orc body
    d.ellipse([16, 0, 48, 32], fill=(50, 200, 50, 255)) # Green head
    img.save("peon_placeholder.png")

def generate_minecart():
    img = Image.new('RGBA', (64, 64), color=(0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(10, 10), (54, 10), (44, 40), (20, 40)], fill=(120, 120, 120, 255))
    d.ellipse([20, 40, 32, 52], fill=(50, 50, 50, 255)) # Wheel
    d.ellipse([32, 40, 44, 52], fill=(50, 50, 50, 255)) # Wheel
    img.save("minecart_placeholder.png")

def generate_rail_item():
    img = Image.new('RGBA', (32, 32), color=(0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 12, 28, 16], fill=(150, 100, 50, 255)) # Wood plank
    d.rectangle([4, 20, 28, 24], fill=(150, 100, 50, 255)) # Wood plank
    d.rectangle([8, 8, 12, 28], fill=(180, 180, 180, 255)) # Metal rail
    d.rectangle([20, 8, 24, 28], fill=(180, 180, 180, 255)) # Metal rail
    img.save("rail_item_placeholder.png")

def generate_rail_atlas():
    img = Image.new('RGBA', (128, 128), color=(0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([16, 0, 24, 64], fill=(150, 150, 150, 255))
    d.rectangle([40, 0, 48, 64], fill=(150, 150, 150, 255))
    for y in range(8, 64, 16):
        d.rectangle([8, y, 56, y+4], fill=(100, 60, 20, 255))
    d.rectangle([64+0, 16, 64+64, 24], fill=(150, 150, 150, 255))
    d.rectangle([64+0, 40, 64+64, 48], fill=(150, 150, 150, 255))
    for x in range(64+8, 64+64, 16):
        d.rectangle([x, 8, x+4, 56], fill=(100, 60, 20, 255))
    d.rectangle([16, 64+0, 24, 64+64], fill=(150, 150, 150, 255))
    d.rectangle([40, 64+0, 48, 64+64], fill=(150, 150, 150, 255))
    d.rectangle([0, 64+16, 64, 64+24], fill=(150, 150, 150, 255))
    d.rectangle([0, 64+40, 64, 64+48], fill=(150, 150, 150, 255))
    img.save("rail_atlas_placeholder.png")

if __name__ == "__main__":
    generate_peon()
    generate_minecart()
    generate_rail_item()
    generate_rail_atlas()
    print("Assets generated.")
