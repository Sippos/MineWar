extends Node

const HUD_PATH := "res://hud.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(HUD_PATH)
	if source.is_empty():
		push_error("Could not read %s" % HUD_PATH)
		get_tree().quit(1)
		return

	source = source.replace(
		"\t_setup_stomp_ui()\n",
		"\t# Ability 1 is displayed by the hero ability bar; the obsolete standalone stomp slot is intentionally not created.\n"
	)

	source = _replace_section(
		source,
		"func _setup_stomp_ui() -> void:\n",
		"func _setup_notice_ui() -> void:\n",
		"func _setup_stomp_ui() -> void:\n\t# Kept as a compatibility no-op for older callers. Ground Stomp is the Dwarf's\n\t# first hero ability and already has a proper slot in the hero ability bar.\n\tstomp_container = null\n\tstomp_progress = null\n\n"
	)

	source = _replace_section(
		source,
		"func update_stomp_cooldown(",
		"func show_notice(",
		"func update_stomp_cooldown(_stomp_level: int, _current_cooldown: float, _max_cooldown: float) -> void:\n\t# Compatibility hook: cooldown presentation is owned by the hero ability bar.\n\tpass\n\n"
	)

	var file := FileAccess.open(HUD_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % HUD_PATH)
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("LEGACY_STOMP_UI_CLEANUP_APPLIED")
	get_tree().quit(0)


func _replace_section(source: String, start_marker: String, end_marker: String, replacement: String) -> String:
	var start_index := source.find(start_marker)
	if start_index < 0:
		push_error("Missing start marker: %s" % start_marker)
		return source
	var end_index := source.find(end_marker, start_index)
	if end_index < 0:
		push_error("Missing end marker: %s" % end_marker)
		return source
	return source.substr(0, start_index) + replacement + source.substr(end_index)
