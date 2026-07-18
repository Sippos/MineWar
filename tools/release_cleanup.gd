extends Node

const QUARANTINE_ROOT := "res://_quarantine/2026-07-18/release_cleanup"
const IGNORE_LINES: Array[String] = [
	"/.godot/",
	"/.godot-mcp/",
	"/build/",
	"/_quarantine/",
	"/shaman_hand_review_temp/",
	"/addons/godot_ai/"
]
const EXPORT_EXCLUDES := "_quarantine/**,tools/**,tests/**,docs/**,shaman_hand_review_temp/**,addons/godot_ai/**,build/**,*.blend,*.py,*.bak,*.b64,*.md,package.json,signaling_server.js,godot-ai-LICENSE.txt"

func _ready() -> void:
	var report: Dictionary = {
		"commands": [],
		"moved": [],
		"changed": [],
		"errors": []
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QUARANTINE_ROOT))

	_update_gitignore(report)
	_update_export_preset(report)

	# Keep generated/local content on disk, but remove it from the Git index.
	for path in [".godot", ".godot-mcp", "build", "_quarantine", "shaman_hand_review_temp", "addons/godot_ai"]:
		_run_git(report, PackedStringArray(["rm", "-r", "--cached", "--ignore-unmatch", "--", path]))

	# The PNG is corrupt and has no runtime reference; current gem indicators use SVGs.
	_move_if_exists(
		report,
		"res://assets/sprites/world/terrain/gem_overlays/minewars_buried_gem_overlays_256x128.png",
		QUARANTINE_ROOT + "/corrupt_assets/minewars_buried_gem_overlays_256x128.png"
	)
	_move_if_exists(
		report,
		"res://assets/sprites/world/terrain/gem_overlays/minewars_buried_gem_overlays_256x128.png.import",
		QUARANTINE_ROOT + "/corrupt_assets/minewars_buried_gem_overlays_256x128.png.import"
	)

	# Preserve the Blender source locally, outside the runtime/export set.
	_move_if_exists(report, "res://NerubianBase.blend", QUARANTINE_ROOT + "/source_art/NerubianBase.blend")
	_move_if_exists(report, "res://NerubianBase.blend.import", QUARANTINE_ROOT + "/source_art/NerubianBase.blend.import")

	_run_git(report, PackedStringArray(["status", "--short"]))
	_write_report(report)
	print("MINEWARS_RELEASE_CLEANUP " + JSON.stringify({
		"moved": report["moved"].size(),
		"changed": report["changed"].size(),
		"errors": report["errors"].size()
	}))
	get_tree().quit(0 if report["errors"].is_empty() else 1)

func _update_gitignore(report: Dictionary) -> void:
	var path := ProjectSettings.globalize_path("res://.gitignore")
	var current := FileAccess.get_file_as_string(path)
	var additions: Array[String] = []
	for line in IGNORE_LINES:
		if not _contains_ignore_line(current, line):
			additions.append(line)
	if additions.is_empty():
		return
	if not current.is_empty() and not current.ends_with("\n"):
		current += "\n"
	current += "\n# MineWars generated/local release files\n" + "\n".join(additions) + "\n"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		report["errors"].append({"path": ".gitignore", "error": FileAccess.get_open_error()})
		return
	file.store_string(current)
	file.close()
	report["changed"].append("res://.gitignore")

func _contains_ignore_line(content: String, target: String) -> bool:
	for raw_line in content.split("\n"):
		if raw_line.strip_edges() == target:
			return true
	return false

func _update_export_preset(report: Dictionary) -> void:
	var path := ProjectSettings.globalize_path("res://export_presets.cfg")
	var current := FileAccess.get_file_as_string(path)
	if current.is_empty():
		report["errors"].append({"path": "export_presets.cfg", "error": "missing_or_empty"})
		return
	var updated := current
	updated = _replace_setting(updated, "include_filter", "")
	updated = _replace_setting(updated, "exclude_filter", EXPORT_EXCLUDES)
	if updated == current:
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		report["errors"].append({"path": "export_presets.cfg", "error": FileAccess.get_open_error()})
		return
	file.store_string(updated)
	file.close()
	report["changed"].append("res://export_presets.cfg")

func _replace_setting(content: String, key: String, value: String) -> String:
	var prefix := key + "=\""
	var lines := content.split("\n")
	for index in range(lines.size()):
		if lines[index].begins_with(prefix):
			lines[index] = key + "=\"" + value + "\""
			return "\n".join(lines)
	return content

func _run_git(report: Dictionary, args: PackedStringArray) -> void:
	var output: Array = []
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var full_args := PackedStringArray(["-C", root])
	full_args.append_array(args)
	var code := OS.execute("git", full_args, output, true)
	var entry := {
		"command": "git " + " ".join(full_args),
		"code": code,
		"output": "\n".join(output)
	}
	report["commands"].append(entry)
	if code != 0:
		report["errors"].append(entry)

func _move_if_exists(report: Dictionary, source: String, destination: String) -> void:
	var source_abs := ProjectSettings.globalize_path(source)
	if not FileAccess.file_exists(source_abs):
		return
	var destination_abs := ProjectSettings.globalize_path(destination)
	DirAccess.make_dir_recursive_absolute(destination_abs.get_base_dir())
	if FileAccess.file_exists(destination_abs):
		report["errors"].append({"from": source, "to": destination, "error": "destination_exists"})
		return
	var error := DirAccess.rename_absolute(source_abs, destination_abs)
	if error == OK:
		report["moved"].append({"from": source, "to": destination})
	else:
		report["errors"].append({"from": source, "to": destination, "error": error})

func _write_report(report: Dictionary) -> void:
	var path := ProjectSettings.globalize_path(QUARANTINE_ROOT + "/release_cleanup_report.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write release cleanup report: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
