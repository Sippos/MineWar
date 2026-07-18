extends Node

const JOBS_PATH := "res://tools/mcp_patch_jobs.json"

func _ready() -> void:
	var jobs_file := FileAccess.open(JOBS_PATH, FileAccess.READ)
	if jobs_file == null:
		push_error("MCP patch jobs file could not be opened")
		get_tree().quit(1)
		return
	var parsed: Variant = JSON.parse_string(jobs_file.get_as_text())
	if not parsed is Array:
		push_error("MCP patch jobs must be a JSON array")
		get_tree().quit(1)
		return

	for job_value in parsed:
		var job: Dictionary = job_value
		var path := str(job.get("path", ""))
		var from_text := str(job.get("from", ""))
		var to_text := str(job.get("to", ""))
		var expected_count := int(job.get("count", 1))
		if path.is_empty() or from_text.is_empty():
			push_error("Invalid MCP patch job")
			get_tree().quit(1)
			return
		var source_file := FileAccess.open(path, FileAccess.READ)
		if source_file == null:
			push_error("Could not read patch target: %s" % path)
			get_tree().quit(1)
			return
		var source := source_file.get_as_text()
		var actual_count := source.count(from_text)
		if actual_count != expected_count:
			push_error("Patch count mismatch for %s: expected %d, found %d" % [path, expected_count, actual_count])
			get_tree().quit(1)
			return
		source = source.replace(from_text, to_text)
		var output := FileAccess.open(path, FileAccess.WRITE)
		if output == null:
			push_error("Could not write patch target: %s" % path)
			get_tree().quit(1)
			return
		output.store_string(source)
	print("MCP_TEXT_PATCH_PASS")
	get_tree().quit(0)
