extends Node

var failed := false

func _ready() -> void:
	_patch_file("res://enemy.gd")
	_patch_file("res://player.gd")
	if failed:
		push_error("COMBAT_VFX_PRELOAD_FIX_FAILED")
		get_tree().quit(1)
		return
	print("COMBAT_VFX_PRELOAD_FIX_APPLIED")
	get_tree().quit()

func _patch_file(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Could not read " + path)
		failed = true
		return
	if not text.contains("const COMBAT_FEEDBACK := preload(\"res://combat_feedback.gd\")"):
		var anchor := "extends CharacterBody2D\n"
		if not text.contains(anchor):
			push_error("Missing extends anchor in " + path)
			failed = true
			return
		text = text.replace(anchor, anchor + "\nconst COMBAT_FEEDBACK := preload(\"res://combat_feedback.gd\")\n")
	text = text.replace("CombatFeedback.ensure(", "COMBAT_FEEDBACK.ensure(")
	text = text.replace("var feedback := COMBAT_FEEDBACK.ensure(", "var feedback: Node = COMBAT_FEEDBACK.ensure(")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + path)
		failed = true
		return
	file.store_string(text)
	file.close()
