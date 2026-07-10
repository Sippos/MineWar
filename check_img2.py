from PIL import Image
try:
    img = Image.open('assets/sprites/ui/common/MenuPanel.png')
    print(f'MenuPanel.png: {img.width}x{img.height}')
except:
    pass
