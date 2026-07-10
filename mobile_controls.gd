extends Control

@export var player_id: int = 1

var joystick_center = Vector2(150, 450)
var joystick_radius = 80.0
var joystick_knob_radius = 40.0
var joystick_active = false
var joystick_touch_id = -1
var joystick_current_pos = Vector2()

var button_radius = 40.0
var base_tap_radius = 96.0
var menu_button_pos = Vector2(64, 64)
var menu_button_radius = 34.0
var menu_button_active = false
var menu_button_touch_id = -1
var buttons = [
	{ "action": "p%d_grab", "pos": Vector2(), "color": Color(0.2, 0.8, 0.2), "active": false, "touch_id": -1, "label": "Grab" },
	{ "action": "p%d_drop", "pos": Vector2(), "color": Color(0.8, 0.2, 0.2), "active": false, "touch_id": -1, "label": "Drop" },
	{ "action": "p%d_stomp", "pos": Vector2(), "color": Color(0.8, 0.8, 0.2), "active": false, "touch_id": -1, "label": "Stomp" },
]

func _ready() -> void:
	set_process_input(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if get_parent() and "player_id" in get_parent():
		player_id = get_parent().player_id
	
	for btn in buttons:
		btn.action = btn.action % player_id
		
	get_tree().root.size_changed.connect(_on_size_changed)
	_on_size_changed()

func _on_size_changed() -> void:
	var size = get_viewport().get_visible_rect().size
	var min_axis = min(size.x, size.y)
	var compact = min_axis < 520.0
	var margin = 18.0 if compact else 30.0
	button_radius = clamp(min_axis * 0.07, 30.0, 44.0)
	joystick_radius = clamp(min_axis * 0.13, 52.0, 80.0)
	joystick_knob_radius = joystick_radius * 0.5
	menu_button_radius = clamp(min_axis * 0.055, 26.0, 36.0)
	base_tap_radius = clamp(min_axis * 0.18, 72.0, 112.0)
	
	joystick_center = Vector2(margin + joystick_radius, size.y - margin - joystick_radius)
	joystick_current_pos = joystick_center
	
	buttons[0].pos = Vector2(size.x - margin - button_radius * 3.2, size.y - margin - button_radius) # Grab
	buttons[1].pos = Vector2(size.x - margin - button_radius, size.y - margin - button_radius) # Drop
	buttons[2].pos = Vector2(size.x - margin - button_radius * 2.1, size.y - margin - button_radius * 3.0) # Stomp
	menu_button_pos = Vector2(size.x - margin - menu_button_radius, margin + menu_button_radius)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.distance_to(menu_button_pos) < menu_button_radius * 1.4:
				menu_button_active = true
				menu_button_touch_id = event.index
				queue_redraw()
				_open_pause_menu()
				get_viewport().set_input_as_handled()
				return
			
			for btn in buttons:
				if event.position.distance_to(btn.pos) < button_radius * 1.5:
					btn.active = true
					btn.touch_id = event.index
					Input.action_press(btn.action)
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
			
			if _try_open_upgrade_menu_from_base_tap(event.position):
				get_viewport().set_input_as_handled()
				return
			
			if event.position.x < get_viewport().get_visible_rect().size.x / 2.0:
				joystick_active = true
				joystick_touch_id = event.index
				joystick_center = event.position
				joystick_current_pos = event.position
				queue_redraw()
				get_viewport().set_input_as_handled()
		else:
			if menu_button_touch_id == event.index:
				menu_button_active = false
				menu_button_touch_id = -1
				queue_redraw()
				get_viewport().set_input_as_handled()
			
			for btn in buttons:
				if btn.touch_id == event.index:
					btn.active = false
					btn.touch_id = -1
					Input.action_release(btn.action)
					queue_redraw()
					get_viewport().set_input_as_handled()
			
			if joystick_touch_id == event.index:
				joystick_active = false
				joystick_touch_id = -1
				joystick_current_pos = joystick_center
				update_joystick_input()
				queue_redraw()
				get_viewport().set_input_as_handled()
				
	elif event is InputEventScreenDrag:
		if joystick_touch_id == event.index:
			joystick_current_pos = event.position
			if joystick_current_pos.distance_to(joystick_center) > joystick_radius:
				joystick_current_pos = joystick_center + (joystick_current_pos - joystick_center).normalized() * joystick_radius
			update_joystick_input()
			queue_redraw()
			get_viewport().set_input_as_handled()

func update_joystick_input() -> void:
	if not joystick_active:
		Input.action_release("p%d_up" % player_id)
		Input.action_release("p%d_down" % player_id)
		Input.action_release("p%d_left" % player_id)
		Input.action_release("p%d_right" % player_id)
		return
		
	var dir = (joystick_current_pos - joystick_center) / joystick_radius
	
	if dir.y < -0.3: Input.action_press("p%d_up" % player_id)
	else: Input.action_release("p%d_up" % player_id)
	
	if dir.y > 0.3: Input.action_press("p%d_down" % player_id)
	else: Input.action_release("p%d_down" % player_id)
	
	if dir.x < -0.3: Input.action_press("p%d_left" % player_id)
	else: Input.action_release("p%d_left" % player_id)
	
	if dir.x > 0.3: Input.action_press("p%d_right" % player_id)
	else: Input.action_release("p%d_right" % player_id)

func _open_pause_menu() -> void:
	var root = get_tree().root
	if root.get_node_or_null("PauseMenu"):
		return
	get_tree().paused = true
	var pause_menu = preload("res://scenes/ui/overlays/pause/pause_menu.tscn").instantiate()
	pause_menu.name = "PauseMenu"
	root.add_child(pause_menu)

func _try_open_upgrade_menu_from_base_tap(screen_pos: Vector2) -> bool:
	var base = _find_node_named(get_tree().current_scene, "Base")
	if base == null or not (base is Node2D):
		return false
	var world_pos = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	if world_pos.distance_to(base.global_position) > base_tap_radius:
		return false
	if base.has_signal("upgrade_requested"):
		base.emit_signal("upgrade_requested")
		queue_redraw()
		return true
	return false

func _find_node_named(node: Node, node_name: String) -> Node:
	if node == null:
		return null
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found = _find_node_named(child, node_name)
		if found:
			return found
	return null

func _draw() -> void:
	_draw_menu_button()
	
	if joystick_active:
		draw_circle(joystick_center, joystick_radius, Color(0.5, 0.5, 0.5, 0.3))
		draw_circle(joystick_current_pos, joystick_knob_radius, Color(0.8, 0.8, 0.8, 0.6))
	else:
		draw_circle(joystick_center, joystick_radius, Color(0.5, 0.5, 0.5, 0.1))
		draw_circle(joystick_center, joystick_knob_radius, Color(0.8, 0.8, 0.8, 0.2))
		
	for btn in buttons:
		var c = btn.color
		if btn.active:
			c.a = 0.8
			draw_circle(btn.pos, button_radius * 0.9, c)
		else:
			c.a = 0.4
			draw_circle(btn.pos, button_radius, c)
			
		var font = ThemeDB.fallback_font
		if font:
			var str_size = font.get_string_size(btn.label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
			draw_string(font, btn.pos + Vector2(-str_size.x/2, str_size.y/3), btn.label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 1, 1, 1))

func _draw_menu_button() -> void:
	var bg = Color(0.08, 0.08, 0.08, 0.55)
	if menu_button_active:
		bg.a = 0.85
	draw_circle(menu_button_pos, menu_button_radius, bg)
	var roof_y = menu_button_pos.y - menu_button_radius * 0.25
	var wall_top = menu_button_pos.y - menu_button_radius * 0.05
	var wall_bottom = menu_button_pos.y + menu_button_radius * 0.42
	var left = menu_button_pos.x - menu_button_radius * 0.45
	var right = menu_button_pos.x + menu_button_radius * 0.45
	var roof = PackedVector2Array([
		Vector2(menu_button_pos.x, menu_button_pos.y - menu_button_radius * 0.58),
		Vector2(right, roof_y),
		Vector2(left, roof_y)
	])
	draw_colored_polygon(roof, Color(1, 1, 1, 0.95))
	draw_rect(Rect2(Vector2(left * 0.96 + menu_button_pos.x * 0.04, wall_top), Vector2((right - left) * 0.92, wall_bottom - wall_top)), Color(1, 1, 1, 0.95))
