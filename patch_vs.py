import os
import re

# 1. Update world.gd
with open("scripts/systems/world_generation/world.gd", "r") as f:
    world_code = f.read()

world_code = world_code.replace("extends Node2D", """extends Node2D

@export var player_id: int = 1
@export var is_vs_mode: bool = false
var income: int = 0
var income_timer: float = 10.0
""")

# replace input setup
input_code = """func _add_wasd_input() -> void:
	var keys_p1 = {
		"p1_left": KEY_A,
		"p1_right": KEY_D,
		"p1_up": KEY_W,
		"p1_down": KEY_S,
		"p1_interact": KEY_E,
		"p1_grab": KEY_SPACE,
		"p1_drop": KEY_Q
	}
	var keys_p2 = {
		"p2_left": KEY_LEFT,
		"p2_right": KEY_RIGHT,
		"p2_up": KEY_UP,
		"p2_down": KEY_DOWN,
		"p2_interact": KEY_ENTER,
		"p2_grab": KEY_CTRL,
		"p2_drop": KEY_SHIFT
	}
	var joy_buttons = {
		"left": JOY_BUTTON_DPAD_LEFT,
		"right": JOY_BUTTON_DPAD_RIGHT,
		"up": JOY_BUTTON_DPAD_UP,
		"down": JOY_BUTTON_DPAD_DOWN,
		"interact": JOY_BUTTON_Y,
		"grab": JOY_BUTTON_X,
		"drop": JOY_BUTTON_B
	}
	
	for action in keys_p1:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event = InputEventKey.new(); event.physical_keycode = keys_p1[action]; InputMap.action_add_event(action, event)
	
	for action in keys_p2:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event = InputEventKey.new(); event.physical_keycode = keys_p2[action]; InputMap.action_add_event(action, event)
		
	var axes = {
		"left": {"axis": JOY_AXIS_LEFT_X, "val": -1.0},
		"right": {"axis": JOY_AXIS_LEFT_X, "val": 1.0},
		"up": {"axis": JOY_AXIS_LEFT_Y, "val": -1.0},
		"down": {"axis": JOY_AXIS_LEFT_Y, "val": 1.0}
	}
	
	for p_id in [1, 2]:
		var prefix = "p%d_" % p_id
		var joy_id = p_id - 1
		for key in joy_buttons:
			var action = prefix + key
			var joy_event = InputEventJoypadButton.new()
			joy_event.button_index = joy_buttons[key]
			joy_event.device = joy_id
			InputMap.action_add_event(action, joy_event)
		for key in axes:
			var action = prefix + key
			var motion_event = InputEventJoypadMotion.new()
			motion_event.axis = axes[key].axis
			motion_event.axis_value = axes[key].val
			motion_event.device = joy_id
			InputMap.action_add_event(action, motion_event)
"""

world_code = re.sub(r'func _add_wasd_input\(\) -> void:.*?func generate_initial_world', input_code + '\nfunc generate_initial_world', world_code, flags=re.DOTALL)

# in world.gd, disable auto-spawn in vs mode
process_code = """func _process(delta: float) -> void:
	if is_vs_mode:
		income_timer -= delta
		if income_timer <= 0:
			income_timer = 10.0
			var hud = get_node_or_null("HUD")
			if hud and hud.has_method("add_gems") and income > 0:
				hud.add_gems(income)
		return
"""

world_code = re.sub(r'func _process\(delta: float\) -> void:.*?(?=var hud = get_node_or_null\("HUD"\))', process_code, world_code, flags=re.DOTALL)

with open("scripts/systems/world_generation/world.gd", "w") as f:
    f.write(world_code)

# 2. Update player.gd
with open("player.gd", "r") as f:
    player_code = f.read()

player_code = player_code.replace('event.is_action_pressed("grab")', 'event.is_action_pressed("p%d_grab" % get_parent().player_id)')
player_code = player_code.replace('event.is_action_pressed("drop")', 'event.is_action_pressed("p%d_drop" % get_parent().player_id)')
player_code = player_code.replace('Input.is_action_just_pressed("ui_accept")', 'Input.is_action_just_pressed("p%d_interact" % get_parent().player_id)')

player_code = player_code.replace('direction.x = Input.get_axis("ui_left", "ui_right")', 'direction.x = Input.get_axis("p%d_left" % get_parent().player_id, "p%d_right" % get_parent().player_id)')
player_code = player_code.replace('direction.y = Input.get_axis("ui_up", "ui_down")', 'direction.y = Input.get_axis("p%d_up" % get_parent().player_id, "p%d_down" % get_parent().player_id)')

player_code = player_code.replace('Input.is_action_pressed("ui_right")', 'Input.is_action_pressed("p%d_right" % get_parent().player_id)')
player_code = player_code.replace('Input.is_action_pressed("ui_left")', 'Input.is_action_pressed("p%d_left" % get_parent().player_id)')
player_code = player_code.replace('Input.is_action_pressed("ui_down")', 'Input.is_action_pressed("p%d_down" % get_parent().player_id)')
player_code = player_code.replace('Input.is_action_pressed("ui_up")', 'Input.is_action_pressed("p%d_up" % get_parent().player_id)')

with open("player.gd", "w") as f:
    f.write(player_code)

# 3. Update base.gd
with open("base.gd", "r") as f:
    base_code = f.read()

base_code = base_code.replace('event.is_action_pressed("interact")', 'event.is_action_pressed("p%d_interact" % get_parent().player_id)')

with open("base.gd", "w") as f:
    f.write(base_code)
