extends Node

const SOURCE_DIRS: Array[String] = [
	"/mnt/data/hero_ability_icons_64",
	"/mnt/data/godot_icons_64",
	"/mnt/data/godot_icons_64_quant"
]

const ICONS: Array[String] = [
	"dwarf_avatar_64.png",
	"dwarf_bash_64.png",
	"dwarf_hammer_64.png",
	"dwarf_stomp_64.png",
	"nerubian_brood_64.png",
	"nerubian_broodmother_64.png",
	"nerubian_carapace_64.png",
	"nerubian_web_64.png"
]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ability_icons/generated"))
	var copied: Array[String] = []
	var missing: Array[String] = []
	for icon: String in ICONS:
		var found := false
		for source_dir: String in SOURCE_DIRS:
			var source: String = source_dir.path_join(icon)
			if FileAccess.file_exists(source):
				var target: String = ProjectSettings.globalize_path("res://ability_icons/generated/%s" % icon)
				var bytes: PackedByteArray = FileAccess.get_file_as_bytes(source)
				var out: FileAccess = FileAccess.open(target, FileAccess.WRITE)
				if out:
					out.store_buffer(bytes)
					out.close()
					copied.append(icon)
					found = true
					break
		if not found:
			missing.append(icon)
	print("ABILITY_ICON_COPY copied=", copied, " missing=", missing)
	get_tree().quit()
