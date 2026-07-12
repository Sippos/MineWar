extends Control

@export var player_id: int = 1

const ICON_PATHS := {
	"stomp": "res://ability_icons/placeholder_stomp.svg",
	"totem": "res://ability_icons/placeholder_totem.svg",
	"brood": "res://ability_icons/placeholder_brood.svg",
	"mole": "res://ability_icons/placeholder_avatar.svg",
	"raise_dead": "res://ability_icons/placeholder_brood.svg",
	"hammer": "res://ability_icons/placeholder_hammer.svg",
	"chain": "res://ability_icons/placeholder_chain.svg",
	"web": "res://ability_icons/placeholder_web.svg",
	"avatar": "res://ability_icons/placeholder_avatar.svg",
	"ascendance": "res://ability_icons/placeholder_ascendance.svg",
	"broodmother": "res://ability_icons/placeholder_broodmother.svg"
}

const HERO_BUTTONS := {
	"Dwarf": {
		"primary": ["Ground Stomp", "stomp"],
		"secondary": ["Hammer", "hammer"],
		"ultimate": ["Avatar", "avatar"]
	},
	"Shaman": {
		"primary": ["Totem", "totem"],
		"secondary": ["Chain", "chain"],
		"ultimate": ["Ascend", "ascendance"]
	},
	"Nerubian": {
		"primary": ["Brood", "brood"],
		"secondary": ["Web", "web"],
		"ultimate": ["Broodmother", "broodmother"]
	},
	"Druid": {
		"primary": ["Mole", "mole"],
		"secondary": ["Ability", ""],
		"ultimate": ["Ultimate", ""]
	},
	"Undead King": {
		"primary": ["Raise Dead", "raise_dead"],
		"secondary": ["Ability", ""],
		"ultimate": ["Ultimate", ""]
	}
}

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
var current_hero := ""
var icon_cache := {}
var buttons = [
	{ "action": "p%d_grab", "role": "grab", "pos": Vector2(), "color": Color(0.2, 0.8, 0.2), "active": false, "touch_id": -1, "label": "Grab", "icon": "" },
	{ "action": "p%d_drop", "role": "drop", "pos": Vector2(), "color": Color(0.8, 0.2, 0.2), "active": false, "touch_id": -1, "label": "Drop", "icon": "" },
	{ "action": "p%d_stomp", "role": "primary", "pos": Vector2(), "color": Color(0.55, 0.42, 0.12), "active": false, "touch_id": -1, "label": "Ability", "icon": "stomp" },
	{ "action": "p%d_secondary", "role": "secondary", "pos": Vector2(), "color": Color(0.18, 0.34, 0.58), "active": false, "touch_id": -1, "label": "Ability", "icon": "" },
	{ "action": "p%d_ultimate", "role": "ultimate", "pos": Vector2(), "color": Color(0.42, 0.18, 0.52), "active": false, "touch_id": -1, "label": "Ultimate", "icon": "" },
]

func _ready() -> void:
	set_process(true)
	set_process_input(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_parent() and "player_id" in get_parent():
		player_id = get_parent().player_id
	for btn in buttons:
		btn.action = btn.action % player_id
		if not InputMap.has_action(btn.action):
			InputMap.add_action(btn.action)
	get_tree().root.size_changed.connect(_on_size_changed)
	_refresh_hero_buttons()
	_on_size_changed()

func _process(_delta: float) -> void:
	_refresh_hero_buttons()
	_hide_desktop_ability_bar()

func _refresh_hero_buttons() -> void:
	var hud = get_parent()
	var world = hud.get_parent() if hud else null
	var player = world.get_node_or_null("Player") if world else null
	if player == null or not ("current_hero_name" in player):
		return
	var hero_name := str(player.current_hero_name)
	if hero_name == current_hero:
		return
	current_hero = hero_name
	var definitions: Dictionary = HERO_BUTTONS.get(current_hero, HERO_BUTTONS["Dwarf"])
	for btn in buttons:
		var role := str(btn.role)
		if definitions.has(role):
			var definition: Array = definitions[role]
			btn.label = str(definition[0])
			btn.icon = str(definition[1])
	queue_redraw()

func _hide_desktop_ability_bar() -> void:
	var hud = get_parent()
	if hud == null:
		return
	var ability_bar = hud.get_node_or_null("HeroAbilityBarP%d" % player_id)
	if ability_bar:
		ability_bar.visible = false

func _on_size_changed() -> void:
	var size = get_viewport().get_visible_rect().size
	var min_axis = min(size.x, size.y)
	var compact = min_axis < 520.0
	var margin = 18.0 if compact else 30.0
	button_radius = clamp(min_axis * 0.062, 29.0, 42.0)
	joystick_radius = clamp(min_axis * 0.13, 52.0, 80.0)
	joystick_knob_radius = joystick_radius * 0.5
	menu_button_radius = clamp(min_axis * 0.055, 26.0, 36.0)
	base_tap_radius = clamp(min_axis * 0.18, 72.0, 112.0)
	joystick_center = Vector2(margin + joystick_radius, size.y - margin - joystick_radius)
	joystick_current_pos = joystick_center

	var gap: float = button_radius * 2.18
	var bottom_y: float = size.y - margin - button_radius
	var upper_y: float = bottom_y - gap
	var right_x: float = size.x - margin - button_radius
	buttons[1].pos = Vector2(right_x, bottom_y) # Drop
	buttons[0].pos = Vector2(right_x - gap, bottom_y) # Grab
	buttons[4].pos = Vector2(right_x, upper_y) # Ultimate
	buttons[3].pos = Vector2(right_x - gap, upper_y) # Secondary
	buttons[2].pos = Vector2(right_x - gap * 2.0, upper_y) # Primary hero ability
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
				if event.position.distance_to(btn.pos) < button_radius * 1.05:
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
		_draw_action_button(btn)

func _draw_action_button(btn: Dictionary) -> void:
	var c: Color = btn.color
	c.a = 0.82 if btn.active else 0.48
	draw_circle(btn.pos, button_radius * (0.92 if btn.active else 1.0), c)
	draw_arc(btn.pos, button_radius, 0.0, TAU, 32, Color(0.95, 0.78, 0.38, 0.9), 2.0)
	var texture := _get_icon(str(btn.icon))
	if texture:
		var icon_size: float = button_radius * 1.18
		var icon_rect := Rect2(btn.pos - Vector2(icon_size, icon_size) * 0.5 - Vector2(0, 5), Vector2(icon_size, icon_size))
		draw_texture_rect(texture, icon_rect, false, Color.WHITE)
	var font = ThemeDB.fallback_font
	if font:
		var font_size := 12 if btn.label.length() > 8 else 14
		var str_size = font.get_string_size(btn.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, btn.pos + Vector2(-str_size.x / 2.0, button_radius * 0.62), btn.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

func _get_icon(icon_name: String) -> Texture2D:
	if icon_name == "":
		return null
	if icon_cache.has(icon_name):
		return icon_cache[icon_name]
	var path := str(ICON_PATHS.get(icon_name, ""))
	var texture: Texture2D = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	icon_cache[icon_name] = texture
	return texture

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
