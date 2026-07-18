extends Node

func _ready() -> void:
	var output: Array = []
	var commands := [
		["git", ["status", "--short", "--", "scripts/systems/continuous_line_wars_controller.gd"]],
		["git", ["log", "--oneline", "-8", "--", "scripts/systems/continuous_line_wars_controller.gd"]],
		["bash", ["-lc", "git show HEAD:scripts/systems/continuous_line_wars_controller.gd 2>/dev/null | wc -l"]],
		["bash", ["-lc", "find .godot-mcp -type f -path '*continuous_line_wars_controller.gd' -printf '%T@ %p\\n' 2>/dev/null | sort -nr | head -20"]],
		["bash", ["-lc", "find . -type f \\( -name '*continuous_line_wars_controller*' -o -name '*.tmp' -o -name '*~' \\) -not -path './.git/*' -printf '%T@ %s %p\\n' 2>/dev/null | sort -nr | head -40"]]
	]
	for command in commands:
		output.clear()
		var exit_code := OS.execute(command[0], command[1], output, true)
		print("COMMAND: ", command[0], " ", command[1], " EXIT=", exit_code)
		for line in output:
			print(line)
	get_tree().quit(0)
