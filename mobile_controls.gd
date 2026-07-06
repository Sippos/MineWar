extends CanvasLayer

@export var player_id: int = 1

var joystick_center = Vector2(150, 450)
var joystick_radius = 80.0
var joystick_knob_radius = 40.0
var joystick_active = false
var joystick_touch_id = -1
var joystick_current_pos = Vector2()

var button_radius = 40.0
var buttons = [
	{ "action": "p%d_grab", "pos": Vector2(), "color": Color(0.2, 0.8, 0.2), "active": false, "touch_id": -1, "label": "Grab" },
	{ "action": "p%d_drop", "pos": Vector2(), "color": Color(0.8, 0.2, 0.2), "active": false, "touch_id": -1, "label": "Drop" },
	{ "action": "p%d_stomp", "pos": Vector2(), "color": Color(0.8, 0.8, 0.2), "active": false, "touch_id": -1, "label": "Stomp" },
]

func _ready() -> void:
	set_process_input(true)
	
	if get_parent() and "player_id" in get_parent():
		player_id = get_parent().player_id
	
	for btn in buttons:
		btn.action = btn.action % player_id
		
	get_tree().root.size_changed.connect(_on_size_changed)
	_on_size_changed()

func _on_size_changed() -> void:
	var size = get_viewport().get_visible_rect().size
	joystick_center = Vector2(150, size.y - 150)
	joystick_current_pos = joystick_center
	
	buttons[0].pos = Vector2(size.x - 200, size.y - 100) # Grab
	buttons[1].pos = Vector2(size.x - 80, size.y - 100) # Drop
	buttons[2].pos = Vector2(size.x - 140, size.y - 200) # Stomp
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			for btn in buttons:
				if event.position.distance_to(btn.pos) < button_radius * 1.5:
					btn.active = true
					btn.touch_id = event.index
					Input.action_press(btn.action)
					queue_redraw()
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

func _draw() -> void:
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
