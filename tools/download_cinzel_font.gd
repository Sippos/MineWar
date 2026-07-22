extends Node

const FONT_URL := "https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/Cinzel%5Bwght%5D.ttf"
const LICENSE_URL := "https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/OFL.txt"

func _ready() -> void:
	var target_dir := ProjectSettings.globalize_path("res://assets/fonts/cinzel")
	var mkdir_error := DirAccess.make_dir_recursive_absolute(target_dir)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		push_error("Could not create font directory: %s" % error_string(mkdir_error))
		get_tree().quit(1)
		return

	var font_path := target_dir.path_join("Cinzel-Variable.ttf")
	var license_path := target_dir.path_join("OFL.txt")
	var output: Array = []
	var font_code := OS.execute("curl", PackedStringArray(["-L", "--fail", "--silent", "--show-error", FONT_URL, "-o", font_path]), output, true, false)
	for line in output:
		print(line)
	output.clear()
	var license_code := OS.execute("curl", PackedStringArray(["-L", "--fail", "--silent", "--show-error", LICENSE_URL, "-o", license_path]), output, true, false)
	for line in output:
		print(line)

	if font_code == 0 and license_code == 0 and FileAccess.file_exists(font_path) and FileAccess.file_exists(license_path):
		print("MINEWARS_CINZEL_DOWNLOAD_OK ", font_path)
		get_tree().quit(0)
	else:
		push_error("Cinzel font download failed: font=%d license=%d" % [font_code, license_code])
		get_tree().quit(1)
