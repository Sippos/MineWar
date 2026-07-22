extends Node

const TARGET := "res://tools/sprite_lab/dome_material_workbench.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(TARGET)
	text = text.replace('var inner_tier := "easy" if current_tier == "unmineable" else current_tier\n\tpreview.call("set_material_images", mass_image, border_images[inner_tier], border_images["unmineable"], corner_images[inner_tier], corner_images["unmineable"], convex_images[inner_tier], convex_images["unmineable"])', 'var inner_tier := current_tier\n\tpreview.call("set_material_images", mass_image, border_images[inner_tier], border_images["unmineable"], corner_images[inner_tier], corner_images["unmineable"], convex_images[inner_tier], convex_images["unmineable"])')
	FileAccess.open(TARGET, FileAccess.WRITE).store_string(text)
	print("Preview now follows selected tier")
	get_tree().quit()
