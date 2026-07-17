extends Node

func _ready() -> void:
	var output: Array = []
	var command := "find .godot-mcp/backups -type f \\( -name 'exploration_mode_controller.gd' -o -name 'test_exploration_mode_smoke.gd' \\) -print | sort"
	var code := OS.execute("bash", ["-lc", command], output, true)
	print("BACKUP_FIND_CODE=", code)
	for line in output:
		print(line)
	get_tree().quit()
