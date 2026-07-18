extends Node

# Core gameplay input must exist before the hub, player, abilities, or tests
# begin processing. Scenes may still add extra bindings, but they no longer own
# whether the actions themselves exist.

func _enter_tree() -> void:
	_register_player_one()
	_register_player_two()
	_register_ui_and_pause()

func _register_player_one() -> void:
	_ensure_key("p1_left", KEY_A)
	_ensure_key("p1_right", KEY_D)
	_ensure_key("p1_up", KEY_W)
	_ensure_key("p1_down", KEY_S)
	_ensure_key("p1_interact", KEY_E)
	_ensure_key("p1_grab", KEY_SPACE)
	_ensure_key("p1_drop", KEY_Q)
	_ensure_key("p1_stomp", KEY_R)
	_ensure_joy_axis("p1_left", 0, JOY_AXIS_LEFT_X, -1.0)
	_ensure_joy_axis("p1_right", 0, JOY_AXIS_LEFT_X, 1.0)
	_ensure_joy_axis("p1_up", 0, JOY_AXIS_LEFT_Y, -1.0)
	_ensure_joy_axis("p1_down", 0, JOY_AXIS_LEFT_Y, 1.0)
	_ensure_joy_button("p1_left", 0, JOY_BUTTON_DPAD_LEFT)
	_ensure_joy_button("p1_right", 0, JOY_BUTTON_DPAD_RIGHT)
	_ensure_joy_button("p1_up", 0, JOY_BUTTON_DPAD_UP)
	_ensure_joy_button("p1_down", 0, JOY_BUTTON_DPAD_DOWN)
	_ensure_joy_button("p1_interact", 0, JOY_BUTTON_Y)
	_ensure_joy_button("p1_grab", 0, JOY_BUTTON_A)
	_ensure_joy_button("p1_drop", 0, JOY_BUTTON_B)
	_ensure_joy_button("p1_stomp", 0, JOY_BUTTON_X)

func _register_player_two() -> void:
	_ensure_key("p2_left", KEY_LEFT)
	_ensure_key("p2_right", KEY_RIGHT)
	_ensure_key("p2_up", KEY_UP)
	_ensure_key("p2_down", KEY_DOWN)
	_ensure_key("p2_interact", KEY_ENTER)
	_ensure_key("p2_grab", KEY_CTRL)
	_ensure_key("p2_drop", KEY_SHIFT)
	_ensure_key("p2_stomp", KEY_PERIOD)
	_ensure_joy_axis("p2_left", 1, JOY_AXIS_LEFT_X, -1.0)
	_ensure_joy_axis("p2_right", 1, JOY_AXIS_LEFT_X, 1.0)
	_ensure_joy_axis("p2_up", 1, JOY_AXIS_LEFT_Y, -1.0)
	_ensure_joy_axis("p2_down", 1, JOY_AXIS_LEFT_Y, 1.0)
	_ensure_joy_button("p2_left", 1, JOY_BUTTON_DPAD_LEFT)
	_ensure_joy_button("p2_right", 1, JOY_BUTTON_DPAD_RIGHT)
	_ensure_joy_button("p2_up", 1, JOY_BUTTON_DPAD_UP)
	_ensure_joy_button("p2_down", 1, JOY_BUTTON_DPAD_DOWN)
	_ensure_joy_button("p2_interact", 1, JOY_BUTTON_Y)
	_ensure_joy_button("p2_grab", 1, JOY_BUTTON_A)
	_ensure_joy_button("p2_drop", 1, JOY_BUTTON_B)
	_ensure_joy_button("p2_stomp", 1, JOY_BUTTON_X)

func _register_ui_and_pause() -> void:
	_ensure_key("pause", KEY_ESCAPE)
	_ensure_joy_button("pause", 0, JOY_BUTTON_START)
	_ensure_joy_button("ui_left", -1, JOY_BUTTON_DPAD_LEFT)
	_ensure_joy_button("ui_right", -1, JOY_BUTTON_DPAD_RIGHT)
	_ensure_joy_button("ui_up", -1, JOY_BUTTON_DPAD_UP)
	_ensure_joy_button("ui_down", -1, JOY_BUTTON_DPAD_DOWN)
	_ensure_joy_button("ui_accept", -1, JOY_BUTTON_A)
	_ensure_joy_button("ui_cancel", -1, JOY_BUTTON_B)

func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

func _ensure_key(action: StringName, keycode: Key) -> void:
	_ensure_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _ensure_joy_button(action: StringName, device: int, button: JoyButton) -> void:
	_ensure_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and existing.device == device and existing.button_index == button:
			return
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	InputMap.action_add_event(action, event)

func _ensure_joy_axis(action: StringName, device: int, axis: JoyAxis, axis_value: float) -> void:
	_ensure_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadMotion and existing.device == device and existing.axis == axis and is_equal_approx(existing.axis_value, axis_value):
			return
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = axis_value
	InputMap.action_add_event(action, event)
