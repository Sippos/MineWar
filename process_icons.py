from PIL import Image

def process_image(filename):
    print(f"Processing {filename}...")
    try:
        img = Image.open(filename).convert("RGBA")
        
        # Get background color from top-left pixel
        bg_color = img.getpixel((0, 0))
        
        # If it's not fully transparent, make the background transparent
        if bg_color[3] > 0:
            print(f"Background color detected as {bg_color}, making it transparent...")
            # Create a mask for pixels that are close to bg_color
            data = img.getdata()
            new_data = []
            for item in data:
                # Calculate distance
                dist = sum(abs(item[i] - bg_color[i]) for i in range(3))
                if dist < 30: # Tolerance
                    new_data.append((255, 255, 255, 0))
                else:
                    new_data.append(item)
            img.putdata(new_data)
        
        # Crop to bounding box of non-transparent pixels
        bbox = img.getbbox()
        if bbox:
            print(f"Cropping to {bbox}...")
            img = img.crop(bbox)
        
        # Resize to 64x64
        print("Resizing to 64x64...")
        # Maintain aspect ratio? The user said "crop them to 64x 64 px sprite".
        # Let's resize with LANCZOS to fit within 64x64 while maintaining aspect ratio, or just force 64x64.
        # Usually icons are best fit into 64x64
        img.thumbnail((64, 64), Image.Resampling.LANCZOS)
        
        # Save back
        img.save(filename)
        print(f"Saved {filename}")
    except Exception as e:
        print(f"Error processing {filename}: {e}")

process_image("Goldcoin.png")
process_image("Gold_Pile.png")
process_image("Healthbar.png")
