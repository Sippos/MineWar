extends Node

## Peon maze VS: both fronts of one side exist at the same time. The peon digs
## the tunnel above the base, the hero mines below it, and one button hands
## direct control -- input plus camera -- back and forth between them.
##
## The bindings deliberately match continuous_line_wars_controller.gd, so Tab
## (player one) and slash (player two), or the right shoulder button on either
## pad, mean the same thing on every LineWars screen.

const HERO_HINT := "HERO — digs down  •  %s: peon"
const PEON_HINT := "PEON — digs up  •  %s: hero"

var player_id := 1
var hero: CharacterBody2D
var peon: CharacterBody2D
var peon_front_active := true

var hint_label: Label
var switch_button: TextureButton
var hero_icon: Texture2D
var peon_icon: Texture2D

func setup(hero_node: CharacterBody2D, peon_node: CharacterBody2D) -> void:
	hero = hero_node
	peon = peon_node
	_ensure_switch_bindings()
	_build_hint()
	_apply_control()

func _process(_delta: float) -> void:
	if hero == null or peon == null:
		return
	if _switch_just_pressed():
		toggle_front()

func toggle_front() -> void:
	set_peon_front_active(not peon_front_active)

func set_peon_front_active(value: bool) -> void:
	if peon_front_active == value:
		return
	peon_front_active = value
	_apply_control()

func _apply_control() -> void:
	if hero == null or peon == null:
		return
	# The inactive front stays in the world -- visible, still standing where it
	# was left -- it just stops taking input and loses the camera.
	peon.visible = true
	if peon.has_method("set_controlled"):
		peon.call("set_controlled", peon_front_active)
	var peon_camera := peon.get_node_or_null("Camera2D") as Camera2D
	if peon_camera:
		peon_camera.enabled = peon_front_active
		if peon_front_active:
			peon_camera.make_current()
			peon_camera.reset_smoothing()

	hero.visible = true
	hero.velocity = Vector2.ZERO
	hero.process_mode = Node.PROCESS_MODE_DISABLED if peon_front_active else Node.PROCESS_MODE_INHERIT
	var hero_camera := hero.get_node_or_null("Camera2D") as Camera2D
	if hero_camera:
		hero_camera.enabled = not peon_front_active
		if not peon_front_active:
			hero_camera.make_current()
			hero_camera.reset_smoothing()

	_update_hint()

func _build_hint() -> void:
	hero_icon = _unit_icon(hero)
	peon_icon = _unit_icon(peon)

	var layer := CanvasLayer.new()
	layer.name = "MazeFrontHint"
	layer.layer = 20
	add_child(layer)

	# One column at the bottom of this half of the screen: the portrait of the
	# unit the button will hand control to, and the line explaining the fronts.
	var column := VBoxContainer.new()
	column.name = "SwitchColumn"
	column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_top = -104.0
	column.offset_left = -220.0
	column.offset_right = 220.0
	column.offset_bottom = -8.0
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(column)

	var button_row := HBoxContainer.new()
	button_row.name = "SwitchRow"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(button_row)

	# A framed plate, otherwise the bare sprite reads as scenery rather than UI.
	var plate := PanelContainer.new()
	plate.name = "SwitchPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.06, 0.05, 0.09, 0.82)
	plate_style.border_color = Color(1.0, 0.78, 0.42, 0.95)
	plate_style.set_border_width_all(2)
	plate_style.set_corner_radius_all(8)
	plate_style.set_content_margin_all(4)
	plate.add_theme_stylebox_override("panel", plate_style)
	button_row.add_child(plate)

	switch_button = TextureButton.new()
	switch_button.name = "SwitchFrontButton"
	switch_button.custom_minimum_size = Vector2(58, 58)
	switch_button.ignore_texture_size = true
	switch_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	# Tab is the keyboard switch; the button must never eat it as focus travel.
	switch_button.focus_mode = Control.FOCUS_NONE
	switch_button.tooltip_text = "Switch front"
	switch_button.pressed.connect(toggle_front)
	plate.add_child(switch_button)

	hint_label = Label.new()
	hint_label.name = "Hint"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.87, 0.62, 1.0))
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hint_label.add_theme_constant_override("outline_size", 5)
	column.add_child(hint_label)

	_update_hint()

func _update_hint() -> void:
	if hint_label:
		hint_label.text = (PEON_HINT if peon_front_active else HERO_HINT) % _switch_key_hint()
	if switch_button:
		# The button always shows who you are switching to.
		switch_button.texture_normal = hero_icon if peon_front_active else peon_icon
		switch_button.modulate = Color(1, 1, 1, 0.9)

func _unit_icon(unit: Node) -> Texture2D:
	# First frame of the unit's own walk sheet, so the button shows the actual
	# peon / hero art instead of a separate icon asset that could drift.
	if unit == null:
		return null
	var sprite := unit.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return null
	var columns := maxi(sprite.hframes, 1)
	var rows := maxi(sprite.vframes, 1)
	var frame := AtlasTexture.new()
	frame.atlas = sprite.texture
	frame.region = Rect2(
		Vector2.ZERO,
		Vector2(float(sprite.texture.get_width()) / columns, float(sprite.texture.get_height()) / rows)
	)
	return frame

func _switch_key_hint() -> String:
	return "Tab / RB" if player_id == 1 else "/ (slash) / RB"

func _switch_action() -> String:
	return "p%d_switch_front" % player_id

func _switch_just_pressed() -> bool:
	var action := _switch_action()
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)

func _ensure_switch_bindings() -> void:
	# Split screen must never let one shared key flip both sides at once, so
	# each half only listens to its own action.
	_ensure_switch_binding("p1_switch_front", KEY_TAB, 0)
	_ensure_switch_binding("p2_switch_front", KEY_SLASH, 1)

func _ensure_switch_binding(action_name: String, keycode: Key, device: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var has_key := false
	var has_shoulder := false
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			has_key = true
		elif existing is InputEventJoypadButton and existing.button_index == JOY_BUTTON_RIGHT_SHOULDER and existing.device == device:
			has_shoulder = true
	if not has_key:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = keycode
		InputMap.action_add_event(action_name, key_event)
	if not has_shoulder:
		var pad_event := InputEventJoypadButton.new()
		pad_event.button_index = JOY_BUTTON_RIGHT_SHOULDER
		pad_event.device = device
		InputMap.action_add_event(action_name, pad_event)
