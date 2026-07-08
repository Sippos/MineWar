import re

with open("base.gd", "r") as f:
    content = f.read()

content = content.replace(
"""		var img = Image.new()
		var err = img.load("res://ShamanBase.png")
		if err == OK:
			$Sprite2D.texture = ImageTexture.create_from_image(img)
			$Sprite2D.modulate = Color(1, 1, 1, 1)
			$Sprite2D.scale = Vector2(128.0 / $Sprite2D.texture.get_width(), 128.0 / $Sprite2D.texture.get_height())""",
"""		var img = Image.new()
		var err = img.load("res://ShamanBase.png")
		if err == OK:
			$Sprite2D.texture = ImageTexture.create_from_image(img)
			$Sprite2D.modulate = Color(1, 1, 1, 1)
			$Sprite2D.scale = Vector2(128.0 / $Sprite2D.texture.get_width(), 128.0 / $Sprite2D.texture.get_height())
		else:
			var tex = load("res://ShamanBase.png")
			if tex:
				$Sprite2D.texture = tex
				$Sprite2D.modulate = Color(1, 1, 1, 1)
				$Sprite2D.scale = Vector2(128.0 / $Sprite2D.texture.get_width(), 128.0 / $Sprite2D.texture.get_height())"""
)

content = content.replace(
"""		var img = Image.new()
		var err = img.load("res://DwarfBase.png")
		if err == OK:
			$Sprite2D.texture = ImageTexture.create_from_image(img)
			$Sprite2D.modulate = Color(1, 1, 1, 1)
			$Sprite2D.scale = Vector2(128.0 / $Sprite2D.texture.get_width(), 128.0 / $Sprite2D.texture.get_height())""",
"""		var img = Image.new()
		var err = img.load("res://DwarfBase.png")
		if err == OK:
			$Sprite2D.texture = ImageTexture.create_from_image(img)
			$Sprite2D.modulate = Color(1, 1, 1, 1)
			$Sprite2D.scale = Vector2(128.0 / $Sprite2D.texture.get_width(), 128.0 / $Sprite2D.texture.get_height())
		else:
			var tex = load("res://DwarfBase.png")
			if tex:
				$Sprite2D.texture = tex
				$Sprite2D.modulate = Color(1, 1, 1, 1)
				$Sprite2D.scale = Vector2(128.0 / $Sprite2D.texture.get_width(), 128.0 / $Sprite2D.texture.get_height())"""
)

with open("base.gd", "w") as f:
    f.write(content)
