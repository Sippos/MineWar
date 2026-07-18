extends Node

const MENU_SCENE := preload("res://scenes/menus/loadout_selection_menu.tscn")

var failures: Array[String] = []

func _ready() -> void:
	await _run()
	if failures.is_empty():
		print("BASE_LOADOUT_UI_SMOKE_OK")
		get_tree().quit(0)
	else:
		for message in failures:
			push_error(message)
		get_tree().quit(1)

func _run() -> void:
	var previous_bases: Array = Global.unlocked_bases.duplicate()
	var previous_base := Global.selected_base_id
	var all_bases := ["default_base", "shaman_base", "nerubian_base", "mech_base", "druid_base", "undead_king_base"]
	Global.unlocked_bases = all_bases.duplicate()
	Global.selected_base_id = "default_base"

	var menu := MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var buttons_value: Variant = menu.get("base_buttons")
	_expect(buttons_value is Dictionary, "Loadout menu should expose its base button registry")
	if buttons_value is Dictionary:
		var buttons: Dictionary = buttons_value
		_expect(buttons.size() == 6, "Loadout menu should contain six base choices")
		for base_id in all_bases:
			_expect(buttons.has(base_id), "%s should appear in the loadout menu" % base_id)
			menu.call("_select_base", base_id)
			await get_tree().process_frame
			var description_label := menu.get("base_description_label") as Label
			_expect(description_label != null and not description_label.text.is_empty(), "%s should show its passive and defence description" % base_id)
	var mech_button := (buttons_value as Dictionary).get("mech_base") as Button if buttons_value is Dictionary else null
	_expect(mech_button != null and mech_button.visible and not mech_button.disabled, "Unlocked Goblin Workshop should be selectable")

	menu.queue_free()
	Global.unlocked_bases = previous_bases
	Global.selected_base_id = previous_base

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
