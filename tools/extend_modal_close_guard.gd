extends Node

const FILES := [
	"res://hero_selection_menu.gd",
	"res://scripts/ui/menus/controls/controls_menu.gd",
	"res://scripts/ui/menus/multiplayer_hero_select.gd",
	"res://scripts/ui/menus/multiplayer_menu.gd",
	"res://scripts/ui/menus/settings_menu.gd",
]

func _ready() -> void:
	for path in FILES:
		var source := FileAccess.get_file_as_string(path)
		if source.is_empty():
			push_error("Could not read %s" % path)
			get_tree().quit(1)
			return
		source = source.replace("create_timer(0.06, true)", "create_timer(0.25, true)")
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Could not write %s" % path)
			get_tree().quit(1)
			return
		file.store_string(source)
		file.close()
	print("EXTEND_MODAL_CLOSE_GUARD_OK")
	get_tree().quit(0)
