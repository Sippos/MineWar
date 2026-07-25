extends Node

func _ready() -> void:
	var candidates := [
		"/mnt/data/godot_icons_64/dwarf_stomp_64.png",
		"/mnt/data/glühendes_runensymbol_im_goldenen_rahmen.png",
		"/mnt/data/fantasy_skill_icons_im_ui_stil.png"
	]
	var found := []
	for path in candidates:
		if FileAccess.file_exists(path):
			found.append(path)
	print("ICON_WORKSPACE_FOUND=", found)
	get_tree().quit()
