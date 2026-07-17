extends Node

func _ready() -> void:
	var output: Array = []
	var code := OS.execute("git", ["status", "--short"], output, true)
	print("GIT_PROBE_CODE=", code)
	for line in output:
		print(line)
	get_tree().quit()
