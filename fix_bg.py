from PIL import Image

def make_transparent(filename):
    img = Image.open(filename).convert("RGBA")
    data = img.getdata()
    
    # Let's assume top-left is the background
    bg_color = data[0]
    print(f"Top-left color of {filename} is {bg_color}")
    
    new_data = []
    for item in data:
        # Check distance to bg_color
        dist = sum(abs(item[i] - bg_color[i]) for i in range(3))
        if dist < 60: # Use higher tolerance
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    img.save(filename)

make_transparent("Goldcoin.png")
make_transparent("Gold_Pile.png")
make_transparent("Healthbar.png")
print("Done fixing transparency!")
