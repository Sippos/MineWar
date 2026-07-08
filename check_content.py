from PIL import Image
import pytesseract
import sys

img = Image.open(sys.argv[1])
text = pytesseract.image_to_string(img)
print(f"File: {sys.argv[1]}")
print(f"Size: {img.size}")
print("Text found in image:")
print(text.strip())
