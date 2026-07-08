from PIL import Image
img = Image.open('DwarfBase.png')
print(f'DwarfBase: {img.width}x{img.height}')
img2 = Image.open('ShamanBase.png')
print(f'ShamanBase: {img2.width}x{img2.height}')
