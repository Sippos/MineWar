from PIL import Image
try:
    img = Image.open('MenuPanel.png')
    print(f'MenuPanel.png: {img.width}x{img.height}')
except:
    pass
