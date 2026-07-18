extends Node

const IMAGE_PATHS: Array[String] = [
	"res://background.png",
	"res://DruidBase.png",
	"res://NerubianBase.png",
	"res://UndeadKingBase.png",
	"res://DwarfBase.png",
	"res://ShamanBase.png"
]

func _ready() -> void:
	for path in IMAGE_PATHS:
		if not FileAccess.file_exists(ProjectSettings.globalize_path(path)):
			print("IMAGE_AUDIT missing ", path)
			continue
		var image := Image.load_from_file(path)
		if image == null or image.is_empty():
			print("IMAGE_AUDIT unreadable ", path)
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		var bytes := file.get_length() if file else 0
		print("IMAGE_AUDIT ", path, " ", image.get_width(), "x", image.get_height(), " bytes=", bytes)
	get_tree().quit()
