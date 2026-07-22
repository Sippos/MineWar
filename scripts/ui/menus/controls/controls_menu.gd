extends CanvasLayer

const MENU_FONT: FontFile = preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")

const CONTROLS_ICON: Texture2D = preload("res://assets/sprites/ui/common/icon_controls.svg")

const GOLD := Color(1.0, 0.82, 0.31, 1.0)
const PALE_GOLD := Color(1.0, 0.91, 0.72, 1.0)
const DARK_PANEL := Color(0.055, 0.028, 0.014, 0.96)
const KEY_FILL := Color(0.11, 0.065, 0.035, 0.98)
const KEY_BORDER := Color(0.72, 0.43, 0.18, 1.0)

var _closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_menu_typography()
	$Panel/VBoxContainer/Title.text = "CONTROLS"
	$Panel/VBoxContainer/Title.add_theme_color_override("font_color", GOLD)
	$Panel/VBoxContainer/Title.add_theme_color_override("font_outline_color", Color.BLACK)
	$Panel/VBoxContainer/Title.add_theme_constant_override("outline_size", 4)
	_build_control_rows()
	_ensure_header_controller_icon()
	get_tree().root.size_changed.connect(_layout_for_screen)
	call_deferred("_layout_for_screen")
	$Panel/VBoxContainer/BackButton.call_deferred("grab_focus")


func _apply_menu_typography() -> void:
	for node in get_tree().get_nodes_in_group("ui_text"):
		node.add_theme_font_override("font", MENU_FONT)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _build_control_rows() -> void:
	var list: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ControlsList as VBoxContainer
	for child: Node in list.get_children():
		child.queue_free()

	# The old generic "Stomp" action is the first hero ability slot. Present the
	# player-facing meaning instead of leaking the legacy input-map name.
	list.add_child(_make_control_row("MOVE", ["W", "A", "S", "D"], ["L", "+"]))
	list.add_child(_make_control_row("INTERACT / USE", ["E"], ["Y"]))
	list.add_child(_make_control_row("GEM: GRAB / DROP", ["SPACE", "Q"], ["A", "B"]))
	list.add_child(_make_control_row("HERO ABILITY 1", ["R"], ["X"]))
	list.add_child(_make_control_row("PAUSE", ["ESC"], ["≡"]))


func _make_control_row(action_text: String, keyboard_tokens: Array[String], controller_tokens: Array[String]) -> PanelContainer:
	var row_panel := PanelContainer.new()
	row_panel.name = action_text.replace(" ", "").replace("/", "").replace(":", "") + "Row"
	row_panel.custom_minimum_size = Vector2(0.0, 42.0)
	row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_panel.set_meta("control_row", true)

	var row_style := StyleBoxFlat.new()
	# Let the wood panel act as the background; rows only provide spacing.
	row_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	row_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	row_style.set_border_width_all(0)
	row_style.set_corner_radius_all(0)
	row_style.content_margin_left = 10.0
	row_style.content_margin_right = 10.0
	row_style.content_margin_top = 4.0
	row_style.content_margin_bottom = 4.0
	row_panel.add_theme_stylebox_override("panel", row_style)

	var row := HBoxContainer.new()
	row.name = "Columns"
	row.add_theme_constant_override("separation", 8)
	row_panel.add_child(row)

	var action := Label.new()
	action.name = "ActionLabel"
	action.text = action_text
	action.custom_minimum_size = Vector2(160.0, 0.0)
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action.add_theme_color_override("font_color", PALE_GOLD)
	action.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.0, 1.0))
	action.add_theme_constant_override("outline_size", 2)
	action.add_theme_font_size_override("font_size", 15)
	row.add_child(action)

	var keyboard_group := HBoxContainer.new()
	keyboard_group.name = "KeyboardGroup"
	keyboard_group.custom_minimum_size = Vector2(170.0, 0.0)
	keyboard_group.alignment = BoxContainer.ALIGNMENT_CENTER
	keyboard_group.add_theme_constant_override("separation", 4)
	keyboard_group.tooltip_text = "Keyboard"
	for token: String in keyboard_tokens:
		keyboard_group.add_child(_make_keycap(token))
	row.add_child(keyboard_group)

	var divider := VSeparator.new()
	divider.name = "InputDivider"
	divider.custom_minimum_size = Vector2(6.0, 0.0)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(divider)

	var controller_group := HBoxContainer.new()
	controller_group.name = "ControllerGroup"
	controller_group.custom_minimum_size = Vector2(76.0, 0.0)
	controller_group.alignment = BoxContainer.ALIGNMENT_CENTER
	controller_group.add_theme_constant_override("separation", 5)
	controller_group.tooltip_text = "Controller"
	for token: String in controller_tokens:
		controller_group.add_child(_make_controller_glyph(token))
	row.add_child(controller_group)

	return row_panel


func _make_keycap(token: String) -> PanelContainer:
	var key := PanelContainer.new()
	key.name = "Key_%s" % token
	key.set_meta("key_token", token)
	var width: float = 56.0 if token.length() > 2 else 30.0
	key.custom_minimum_size = Vector2(width, 28.0)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = KEY_FILL
	style.border_color = KEY_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	style.shadow_size = 3
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	key.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.name = "Glyph"
	label.text = token
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_font_size_override("font_size", 13 if token.length() <= 2 else 11)
	key.add_child(label)
	return key


func _make_controller_glyph(token: String) -> PanelContainer:
	var glyph := PanelContainer.new()
	glyph.name = "Pad_%s" % token
	glyph.set_meta("controller_token", token)
	glyph.custom_minimum_size = Vector2(28.0, 28.0)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = DARK_PANEL
	style.border_color = _controller_color(token)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14 if token not in ["+", "≡"] else 6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	style.shadow_size = 3
	glyph.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.name = "Glyph"
	label.text = token
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", _controller_color(token))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_font_size_override("font_size", 17 if token in ["+", "≡"] else 13)
	glyph.add_child(label)

	match token:
		"L": glyph.tooltip_text = "Left Stick"
		"+": glyph.tooltip_text = "D-Pad"
		"≡": glyph.tooltip_text = "Start"
		_: glyph.tooltip_text = "%s button" % token
	return glyph


func _controller_color(token: String) -> Color:
	match token:
		"A": return Color(0.39, 0.92, 0.43, 1.0)
		"B": return Color(1.0, 0.37, 0.29, 1.0)
		"X": return Color(0.35, 0.72, 1.0, 1.0)
		"Y": return Color(1.0, 0.84, 0.24, 1.0)
		_: return Color(0.72, 0.9, 1.0, 1.0)


func _ensure_header_controller_icon() -> TextureRect:
	var existing := $Panel.get_node_or_null("HeaderControllerIcon") as TextureRect
	if existing != null:
		return existing
	var icon := TextureRect.new()
	icon.name = "HeaderControllerIcon"
	icon.texture = CONTROLS_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1.0, 0.82, 0.31, 0.88)
	$Panel.add_child(icon)
	return icon


func _layout_for_screen() -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var compact: bool = screen_size.x < 700.0 or screen_size.y < 540.0
	var panel_width: float = minf(650.0, maxf(320.0, screen_size.x - 28.0))
	var panel_height: float = minf(500.0, maxf(300.0, screen_size.y - 28.0))
	var panel: Panel = $Panel as Panel
	panel.offset_left = -panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_bottom = panel_height * 0.5

	# The texture has a thick metal frame. These larger insets keep every row on
	# the wooden center instead of drawing across the decorative border.
	var content: VBoxContainer = $Panel/VBoxContainer as VBoxContainer
	var horizontal_margin: float = 40.0 if compact else 72.0
	var vertical_margin: float = 26.0 if compact else 50.0
	content.offset_left = horizontal_margin
	content.offset_top = vertical_margin
	content.offset_right = -horizontal_margin
	content.offset_bottom = -vertical_margin
	content.add_theme_constant_override("separation", 6 if compact else 8)

	var title: Label = $Panel/VBoxContainer/Title as Label
	title.custom_minimum_size = Vector2(title.custom_minimum_size.x, 32.0 if compact else 40.0)
	title.add_theme_font_size_override("font_size", 21 if compact else 25)

	var list: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ControlsList as VBoxContainer
	list.add_theme_constant_override("separation", 3 if compact else 7)
	var row_height: float = 32.0 if compact else 42.0
	for row_node: Node in list.get_children():
		var row_panel := row_node as PanelContainer
		if row_panel == null:
			continue
		row_panel.custom_minimum_size = Vector2(0.0, row_height)
		var columns := row_panel.get_node_or_null("Columns") as HBoxContainer
		if columns == null:
			continue
		columns.add_theme_constant_override("separation", 6 if compact else 8)
		var action := columns.get_node_or_null("ActionLabel") as Label
		var keyboard := columns.get_node_or_null("KeyboardGroup") as HBoxContainer
		var controller := columns.get_node_or_null("ControllerGroup") as HBoxContainer
		if action != null:
			action.custom_minimum_size = Vector2(108.0 if compact else 160.0, 0.0)
			action.add_theme_font_size_override("font_size", 13 if compact else 15)
		if keyboard != null:
			keyboard.custom_minimum_size = Vector2(138.0 if compact else 170.0, 0.0)
			keyboard.add_theme_constant_override("separation", 3 if compact else 4)
			for key_node: Node in keyboard.get_children():
				var key := key_node as PanelContainer
				if key == null:
					continue
				var token: String = str(key.get_meta("key_token", ""))
				key.custom_minimum_size = Vector2((50.0 if compact else 56.0) if token.length() > 2 else (26.0 if compact else 30.0), 25.0 if compact else 28.0)
		if controller != null:
			controller.custom_minimum_size = Vector2(64.0 if compact else 76.0, 0.0)
			for glyph_node: Node in controller.get_children():
				var glyph := glyph_node as PanelContainer
				if glyph != null:
					glyph.custom_minimum_size = Vector2(25.0 if compact else 28.0, 25.0 if compact else 28.0)

	var header_icon: TextureRect = _ensure_header_controller_icon()
	var icon_size: float = 28.0 if compact else 34.0
	header_icon.offset_left = panel_width - horizontal_margin - icon_size
	header_icon.offset_top = vertical_margin + 1.0
	header_icon.offset_right = header_icon.offset_left + icon_size
	header_icon.offset_bottom = header_icon.offset_top + icon_size

	var back_button: Button = $Panel/VBoxContainer/BackButton as Button
	back_button.custom_minimum_size = Vector2(minf(260.0, panel_width - horizontal_margin * 2.0), 42.0 if compact else 50.0)


func _on_back_pressed() -> void:
	if _closing:
		return
	_closing = true
	# Keep the clicked button alive through mouse release so the event cannot hit the menu below.
	get_tree().create_timer(0.12, true).timeout.connect(queue_free)
