from PIL import Image, ImageDraw

def create_front(color, filename):
    img = Image.new('RGBA', (64, 64), color)
    draw = ImageDraw.Draw(img)
    # Top highlight
    draw.rectangle([0, 0, 63, 5], fill=(255, 255, 255, 50))
    # Bottom shadow
    draw.rectangle([0, 58, 63, 63], fill=(0, 0, 0, 100))
    # Some vertical streaks
    for x in range(10, 60, 15):
        draw.line([x, 5, x, 58], fill=(0, 0, 0, 40), width=3)
    img.save(filename)

create_front((120, 50, 10, 255), "Easy_Front.png")   # Darker Brown
create_front((80, 47, 23, 255), "Medium_Front.png")  # Very Dark Brown
create_front((60, 60, 60, 255), "Hard_Front.png")    # Dark Gray

print("Generated Front Wall placeholders.")
