extends Node

const PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		push_error("Could not read preview v2")
		get_tree().quit(1)
		return
	text = text.replace(
		"func set_all_material_images(new_mass_image: Image, new_border_images: Dictionary, new_corner_images: Dictionary, new_convex_images: Dictionary, new_front_images: Dictionary) -> void:",
		"func set_material_library(new_mass_image: Image, new_border_images: Dictionary, new_corner_images: Dictionary, new_convex_images: Dictionary, new_front_images: Dictionary) -> void:\n\tset_all_material_images(new_mass_image, new_border_images, new_corner_images, new_convex_images, new_front_images)\n\nfunc set_all_material_images(new_mass_image: Image, new_border_images: Dictionary, new_corner_images: Dictionary, new_convex_images: Dictionary, new_front_images: Dictionary) -> void:"
	)
	text = text.replace("func _textures_for_cell(cell_type: int) -> Array[ImageTexture]:", "func _textures_for_cell(cell_type: int) -> Array:")
	text = text.replace("\treturn composite_textures.get(tier, []) as Array[ImageTexture]", "\treturn composite_textures.get(tier, []) as Array")
	text = text.replace("func _corner_textures_for_cell(cell_type: int) -> Array[ImageTexture]:", "func _corner_textures_for_cell(cell_type: int) -> Array:")
	text = text.replace("\treturn inside_corner_textures.get(tier, []) as Array[ImageTexture]", "\treturn inside_corner_textures.get(tier, []) as Array")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write preview v2")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Fixed preview v2 API and array typing")
	get_tree().quit()
