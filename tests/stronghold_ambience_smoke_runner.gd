extends Node

const SOURCES := [
	"res://global.gd",
	"res://scripts/systems/single_player_world_controller.gd",
	"res://scripts/systems/stronghold_ambience_controller.gd"
]

func _ready() -> void:
	var ok := true
	for path in SOURCES:
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string(path)
		var result := script.reload()
		if result != OK:
			ok = false
			push_error("Could not compile %s: %s" % [path, error_string(result)])
	if ok:
		print("STRONGHOLD_AMBIENCE_SMOKE_OK")
	get_tree().quit(0 if ok else 1)
