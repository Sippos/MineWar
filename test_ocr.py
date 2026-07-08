try:
    import pytesseract
    from PIL import Image
    text = pytesseract.image_to_string(Image.open('ShamanBase.png'))
    print("OCR ShamanBase:", text.strip())
except Exception as e:
    print("OCR Failed:", e)
