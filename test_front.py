from PIL import Image

def ascii_art(path):
    try:
        img = Image.open(path).convert("RGBA")
        width, height = img.size
        print(f"--- {path} ---")
        for y in range(0, height, 2):
            line = ""
            for x in range(0, width, 2):
                r, g, b, a = img.getpixel((x, y))
                if a == 0:
                    line += " "
                elif r > 100 or g > 100 or b > 100:
                    line += "#"
                else:
                    line += "."
            print(line)
    except Exception as e:
        print(f"Error on {path}: {e}")

ascii_art("assets/sprites/world/terrain/front_walls/Easy_Brick-Front.png")
