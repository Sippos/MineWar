extends Node

const MOBILE_CONTROLS_SCENE := preload("res://mobile_controls.tscn")
const HUD_SCENE := preload("res://hud.tscn")

var failures := 0

func _ready() -> void:
	get_tree().root.set_meta("web_low_memory_mode", true)
	await _test_mobile_controls()
	await _test_mobile_hud_progression()
	get_tree().root.remove_meta("web_low_memory_mode")
	if failures == 0:
		print("MOBILE_HUD_INPUT_SMOKE_PASS")
		get_tree().quit(0)
	else:
		push_error("MOBILE_HUD_INPUT_SMOKE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

func _test_mobile_controls() -> void:
	var controls := MOBILE_CONTROLS_SCENE.instantiate()
	add_child(controls)
	await get_tree().process_frame
	controls.size = Vector2(1024, 768)
	controls.call("_on_size_changed")

	var joystick_center: Vector2 = controls.get("joystick_center")
	var joystick_radius: float = float(controls.get("joystick_radius"))
	_expect(bool(controls.call("_can_start_joystick", joystick_center)), "Joystick accepts its visible pad")
	_expect(not bool(controls.call("_can_start_joystick", Vector2(512, 384))), "Joystick rejects unrelated playfield taps")

	var buttons: Array = controls.get("buttons")
	var ability_dock := Rect2(Vector2(1024 - 198, 768 - 74), Vector2(180, 56))
	for button in buttons:
		var radius: float = float(controls.get("button_radius"))
		var rect := Rect2(button["pos"] - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		_expect(not rect.intersects(ability_dock), "%s does not overlap the ability dock" % str(button["label"]))

	var grab_action := str(buttons[0]["action"])
	var grab_press := _touch_for_local(controls, buttons[0]["pos"], true, 3)
	controls.call("_unhandled_input", grab_press)
	_expect(Input.is_action_pressed(grab_action), "PICK press reaches its gameplay action")
	controls.call("_unhandled_input", _touch_for_local(controls, buttons[0]["pos"], false, 3))
	_expect(not Input.is_action_pressed(grab_action), "PICK release clears its gameplay action")

	controls.call("_unhandled_input", _touch_for_local(controls, joystick_center, true, 4))
	_expect(bool(controls.get("joystick_active")), "Joystick can start from its own pad")
	controls.call("_unhandled_input", _touch_for_local(controls, joystick_center, false, 4))
	_expect(not bool(controls.get("joystick_active")), "Joystick releases without sticking")
	_expect(joystick_radius >= 54.0 and joystick_radius <= 72.0, "Joystick stays inside the intended mobile size range")

	controls.queue_free()
	await get_tree().process_frame

func _test_mobile_hud_progression() -> void:
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	await get_tree().process_frame
	_expect(bool(hud.call("_is_mobile_hud")), "Landscape web touch uses the mobile HUD")
	_expect(not hud.get_node("StatsContainer").visible, "Stats remain hidden until purchased")
	_expect(not hud.get_node("WaveLabel").visible, "Wave module remains hidden until purchased")
	_expect(not hud.get_node("XPBar").visible, "XP remains hidden until purchased")

	hud.call("unlock_xp")
	var xp_bar := hud.get_node("XPBar") as TextureProgressBar
	var xp_label := hud.get_node("XPLabel") as Label
	_expect(xp_bar.visible and xp_label.visible, "XP upgrade reveals one complete module")
	_expect(xp_bar.scale == Vector2.ONE, "XP bar does not inherit the detached legacy half-scale")
	_expect(is_equal_approx(xp_bar.offset_left, xp_label.offset_left) and is_equal_approx(xp_bar.offset_top, xp_label.offset_top), "XP text is aligned inside its bar")

	hud.call("_set_base_warning_health", 98, 100, false)
	var base_percent := hud.get("base_status_label") as Label
	_expect(base_percent != null and not base_percent.visible, "Mobile base icon does not duplicate the health percentage")
	hud.call("show_objective", "III", "SPACE / A", "")
	var objective_panel := hud.get("objective_panel") as PanelContainer
	var notice_label := hud.get("notice_label") as Label
	_expect(objective_panel != null and not objective_panel.visible, "Large tutorial card stays off the touch playfield")
	_expect(notice_label != null and notice_label.text == "TAP PICK", "Mobile tutorial uses the touch action name")

	hud.queue_free()
	await get_tree().process_frame

func _touch_for_local(control: Control, local_position: Vector2, pressed: bool, index: int) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = control.get_global_transform_with_canvas() * local_position
	return event

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
