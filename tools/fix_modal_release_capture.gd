extends Node

var failures: Array[String] = []

func _ready() -> void:
	_patch("res://scripts/ui/menus/settings_menu.gd", "\tback_button.disabled = true\n\tget_tree().create_timer(0.06, true).timeout.connect(queue_free)", "\t# Keep the clicked button alive through mouse release so the event cannot hit the menu below.\n\tget_tree().create_timer(0.12, true).timeout.connect(queue_free)")
	_patch("res://scripts/ui/menus/controls/controls_menu.gd", "\t$Panel/VBoxContainer/BackButton.disabled = true\n\tget_tree().create_timer(0.06, true).timeout.connect(queue_free)", "\t# Keep the clicked button alive through mouse release so the event cannot hit the menu below.\n\tget_tree().create_timer(0.12, true).timeout.connect(queue_free)")
	_patch("res://scripts/ui/menus/multiplayer_menu.gd", "\tback_button.disabled = true\n\tget_tree().create_timer(0.06, true).timeout.connect(queue_free)", "\t# Keep the clicked button alive through mouse release so the event cannot hit the menu below.\n\tget_tree().create_timer(0.12, true).timeout.connect(queue_free)")
	_patch("res://scripts/ui/menus/multiplayer_hero_select.gd", "\tback_button.disabled = true\n\tstart_button.disabled = true\n\tget_tree().create_timer(0.06, true).timeout.connect(queue_free)", "\t# Keep the clicked controls alive through mouse release so it cannot activate the parent menu.\n\tget_tree().create_timer(0.12, true).timeout.connect(queue_free)")
	_patch("res://hero_selection_menu.gd", "\tback_btn.disabled = true\n\tstart_btn.disabled = true\n\tget_tree().create_timer(0.06, true).timeout.connect(queue_free)", "\t# Keep the clicked controls alive through mouse release so it cannot activate the parent menu.\n\tget_tree().create_timer(0.12, true).timeout.connect(queue_free)")
	if failures.is_empty():
		print("FIX_MODAL_RELEASE_CAPTURE_OK")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _patch(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.contains(new_text):
		return
	if not source.contains(old_text):
		failures.append("Missing patch target in %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write %s" % path)
		return
	file.store_string(source.replace(old_text, new_text))
	file.close()
