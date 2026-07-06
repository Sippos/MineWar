from PIL import Image

def fix(filename, r0, g0, b0, tol=60):
    img = Image.open(filename).convert("RGBA")
    data = img.getdata()
    new_data = []
    for r,g,b,a in data:
        if abs(r-r0)+abs(g-g0)+abs(b-b0) < tol:
            new_data.append((r,g,b,0))
        else:
            new_data.append((r,g,b,a))
    img.putdata(new_data)
    img.save(filename)

fix("Goldcoin.png", 127, 129, 128)
fix("Gold_Pile.png", 0, 0, 0, 30)
fix("Healthbar.png", 83, 82, 77)
fix("Goldcoin.png", 173, 173, 173, 60) # To catch the anti-aliased edge if present from previous
