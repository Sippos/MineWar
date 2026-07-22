extends Control

const GRAB_ICON: Texture2D = preload("res://assets/sprites/ui/mobile/grab_hand.svg")
const DROP_ICON: Texture2D = preload("res://assets/sprites/ui/mobile/drop_arrow.svg")

@export var player_id: int = 1

var joystick_center = Vector2(150, 450)
var joystick_radius = 80.0
var joystick_knob_radius = 40.0
var joystick_active = false
var joystick_touch_id = -1
var joystick_current_pos = Vector2()

var button_radius = 40.0
var base_tap_radius = 96.0
var menu_button_pos = Vector2(0, 0)
var menu_button_radius = 34.0
var menu_button_active = false
var menu_button_touch_id = -1
var buttons = [
	{ "action": "p%d_grab", "role": "grab", "pos": Vector2(), "color": Color(0.25, 0.86, 0.78), "active": false, "touch_id": -1, "label": "PICK" },
	{ "action": "p%d_drop", "role": "drop", "pos": Vector2(), "color": Color(1.0, 0.52, 0.25), "active": false, "touch_id": -1, "label": "DROP" },
]

const UI_GOLD := Color(0.95, 0.72, 0.28, 0.96)
const UI_PANEL := Color(0.035, 0.045, 0.06, 0.92)
const UI_PANEL_ACTIVE := Color(0.12, 0.14, 0.18, 0.98)
const ABILITY_SLOT_SIZE := 56.0
const ABILITY_BOTTOM_MARGIN := 18.0
const ACTION_ROW_GAP := 12.0

func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_parent() and "player_id" in get_parent():
		player_id = get_parent().player_id
	for btn in buttons:
		btn.action = btn.action % player_id
		if not InputMap.has_action(btn.action):
			InputMap.add_action(btn.action)
	get_tree().root.size_changed.connect(_on_size_changed)
	_on_size_changed()

func _process(_delta: float) -> void:
	pass

func _on_size_changed() -> void:
	# This full-rect Control already lives in stretched canvas coordinates. Base
	# drawing and hit regions on its actual size so iPad landscape cannot apply a
	# second scale and push actions into the ability dock.
	var viewport_size: Vector2 = size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport().get_visible_rect().size
	var min_axis: float = min(viewport_size.x, viewport_size.y)
	var margin: float = clamp(min_axis * 0.025, 14.0, 24.0)
	button_radius = clamp(min_axis * 0.035, 24.0, 28.0)
	joystick_radius = clamp(min_axis * 0.1, 54.0, 72.0)
	joystick_knob_radius = joystick_radius * 0.5
	menu_button_radius = clamp(min_axis * 0.035, 22.0, 26.0)
	base_tap_radius = clamp(min_axis * 0.15, 72.0, 108.0)
	joystick_center = Vector2(margin + joystick_radius, viewport_size.y - margin - joystick_radius)
	joystick_current_pos = joystick_center

	var gap: float = button_radius * 2.0 + 8.0
	# PICK/DROP form a dedicated row above the 56px ability dock.
	var bottom_y: float = viewport_size.y - ABILITY_BOTTOM_MARGIN - ABILITY_SLOT_SIZE - ACTION_ROW_GAP - button_radius
	var right_x: float = viewport_size.x - margin - button_radius
	buttons[1].pos = Vector2(right_x, bottom_y) # Drop
	buttons[0].pos = Vector2(right_x - gap, bottom_y) # Grab
	# The old top-right menu button was drawn over the bastion status icon. Keep
	# it in the empty top-center safe area instead.
	menu_button_pos = Vector2(viewport_size.x * 0.5, margin + menu_button_radius)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_position := _screen_to_canvas(event.position)
		if event.pressed:
			if touch_position.distance_to(menu_button_pos) < menu_button_radius * 1.4:
				menu_button_active = true
				menu_button_touch_id = event.index
				queue_redraw()
				_open_pause_menu()
				get_viewport().set_input_as_handled()
				return
			for btn in buttons:
				if touch_position.distance_to(btn.pos) < button_radius * 1.05:
					btn.active = true
					btn.touch_id = event.index
					Input.action_press(btn.action)
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
			if _try_open_upgrade_menu_from_base_tap(touch_position):
				get_viewport().set_input_as_handled()
				return
			if _can_start_joystick(touch_position):
				joystick_active = true
				joystick_touch_id = event.index
				joystick_current_pos = touch_position
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
			joystick_current_pos = _screen_to_canvas(event.position)
			if joystick_current_pos.distance_to(joystick_center) > joystick_radius:
				joystick_current_pos = joystick_center + (joystick_current_pos - joystick_center).normalized() * joystick_radius
			update_joystick_input()
			queue_redraw()
			get_viewport().set_input_as_handled()

func _screen_to_canvas(screen_position: Vector2) -> Vector2:
	return make_canvas_position_local(screen_position)

func _can_start_joystick(touch_position: Vector2) -> bool:
	# Movement owns only the visible lower-left pad. It must never capture taps
	# on world prompts, menus, PICK/DROP, or the ability dock.
	return touch_position.distance_to(joystick_center) <= joystick_radius * 1.35

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
		draw_circle(joystick_center, joystick_radius, Color(0.04, 0.07, 0.1, 0.72))
		draw_arc(joystick_center, joystick_radius, 0.0, TAU, 40, Color(0.28, 0.78, 0.9, 0.82), 2.0)
		draw_circle(joystick_current_pos, joystick_knob_radius, Color(0.32, 0.62, 0.72, 0.72))
		draw_arc(joystick_current_pos, joystick_knob_radius, 0.0, TAU, 32, Color(0.85, 0.9, 0.92, 0.78), 2.0)
	else:
		draw_circle(joystick_center, joystick_radius, Color(0.04, 0.07, 0.1, 0.24))
		draw_arc(joystick_center, joystick_radius, 0.0, TAU, 40, Color(0.28, 0.6, 0.72, 0.42), 2.0)
		draw_circle(joystick_center, joystick_knob_radius, Color(0.35, 0.44, 0.52, 0.26))
		draw_arc(joystick_center, joystick_knob_radius, 0.0, TAU, 32, Color(0.75, 0.82, 0.88, 0.36), 2.0)
	for btn in buttons:
		_draw_action_button(btn)

func _draw_action_button(btn: Dictionary) -> void:
	var c: Color = btn.color
	var size: float = button_radius * 2.0
	var rect := Rect2(btn.pos - Vector2.ONE * button_radius, Vector2.ONE * size)
	var style := StyleBoxFlat.new()
	style.bg_color = UI_PANEL_ACTIVE if btn.active else UI_PANEL
	style.border_color = c if btn.active else UI_GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 4
	draw_style_box(style, rect)
	var icon_texture: Texture2D = GRAB_ICON if btn.role == "grab" else DROP_ICON
	var icon_size: float = button_radius * 1.08
	var icon_rect := Rect2(
		btn.pos + Vector2(-icon_size * 0.5, -icon_size * 0.56),
		Vector2(icon_size, icon_size)
	)
	draw_texture_rect(icon_texture, icon_rect, false, Color(1.0, 1.0, 1.0, 1.0 if btn.active else 0.9))
	var font = ThemeDB.fallback_font
	if font:
		var font_size := 11
		var str_size = font.get_string_size(btn.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, btn.pos + Vector2(-str_size.x / 2.0, button_radius * 0.78), btn.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.96, 0.96, 0.98, 1.0))

func _draw_menu_button() -> void:
	var diameter: float = menu_button_radius * 2.0
	var rect := Rect2(menu_button_pos - Vector2.ONE * menu_button_radius, Vector2.ONE * diameter)
	var style := StyleBoxFlat.new()
	style.bg_color = UI_PANEL_ACTIVE if menu_button_active else UI_PANEL
	style.border_color = UI_GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	draw_style_box(style, rect)
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
	draw_colored_polygon(roof, Color(0.96, 0.96, 0.98, 0.95))
	draw_rect(Rect2(Vector2(left * 0.96 + menu_button_pos.x * 0.04, wall_top), Vector2((right - left) * 0.92, wall_bottom - wall_top)), Color(0.96, 0.96, 0.98, 0.95))
