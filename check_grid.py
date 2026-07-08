from PIL import Image

def analyze_img(filename):
    img = Image.open(filename).convert("RGBA")
    w, h = img.size
    
    # Check bounding box of alpha > 0
    bbox = img.getbbox()
    print(f"{filename} bbox: {bbox}")
    
    # Let's count transparent pixels in rows/cols to find gaps
    col_alpha = [sum(img.getpixel((x,y))[3] for y in range(h)) for x in range(w)]
    row_alpha = [sum(img.getpixel((x,y))[3] for x in range(w)) for y in range(h)]
    
    # Are there large empty gaps in the middle?
    empty_cols = [x for x, a in enumerate(col_alpha) if a == 0]
    empty_rows = [y for y, a in enumerate(row_alpha) if a == 0]
    
    print(f"{filename} empty cols count: {len(empty_cols)}, empty rows count: {len(empty_rows)}")

analyze_img('DwarfBase.png')
analyze_img('ShamanBase.png')
