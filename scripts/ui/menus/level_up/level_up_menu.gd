extends CanvasLayer

signal upgrade_selected(upgrade_type: String)

const HERO_SCRIPT = preload("res://hero_abilities.gd")
const MENU_TEX = preload("res://assets/sprites/ui/common/MenuPanel.png")
const MENU_FONT = preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")
const DECORATIVE_FONT = preload("res://assets/fonts/grenze_gotisch/GrenzeGotisch-Variable.ttf")

var player: Node
var controller: Node
var grid: GridContainer
var compact := false
var cached_button_font: FontVariation = null

func _get_button_font() -> FontVariation:
	if cached_button_font == null:
		cached_button_font = FontVariation.new()
		cached_button_font.base_font = MENU_FONT
		cached_button_font.variation_opentype = {"wght": 900.0}
		cached_button_font.variation_embolden = 0.85
	return cached_button_font

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(_legacy = false) -> void:
	call_deferred("_build")

func setup_for_player(target: Node) -> void:
	player = target
	call_deferred("_build")

func _build() -> void:
	if player == null:
		player = get_parent().get_node_or_null("Player")
	if player == null:
		_show_error("Player not found")
		return
	controller = player.get_node_or_null("HeroAbilities")
	if controller == null:
		controller = Node.new()
		controller.name = "HeroAbilities"
		controller.set_script(HERO_SCRIPT)
		player.add_child(controller)
		await get_tree().process_frame
	if not controller.has_method("get_level_up_options") or not controller.has_method("_on_upgrade_selected"):
		_show_error("Ability controller unavailable")
		return
	var callback := Callable(controller, "_on_upgrade_selected")
	if not upgrade_selected.is_connected(callback):
		upgrade_selected.connect(callback)
	_make_background()
	_build_visuals()

func _make_background() -> void:
	if get_node_or_null("Dim") != null:
		return
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.58)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	move_child(dim, 0)

func _build_visuals() -> void:
	var panel := $Panel
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	var view_size := get_viewport().get_visible_rect().size
	compact = view_size.x < 900.0
	var max_panel_width := 620.0 if compact else 960.0
	var width: float = min(max_panel_width, max(390.0, view_size.x - 28.0))
	var height: float = min(560.0, max(430.0, view_size.y - 28.0))
	panel.offset_left = -width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_right = width * 0.5
	panel.offset_bottom = height * 0.5

	var art := TextureRect.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.texture = MENU_TEX
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(art)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 52.0 if compact else 72.0
	box.offset_top = 38.0 if compact else 50.0
	box.offset_right = -52.0 if compact else -72.0
	box.offset_bottom = -44.0 if compact else -58.0
	box.add_theme_constant_override("separation", 8 if compact else 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "%s — Choose Ability" % str(player.get("current_hero_name"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", DECORATIVE_FONT)
	title.add_theme_font_size_override("font_size", 30 if compact else 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	grid = GridContainer.new()
	grid.columns = 1 if compact else 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8 if compact else 10)
	center.add_child(grid)

	var options: Array = controller.call("get_level_up_options")
	if options.is_empty():
		_show_grid_message("No ability upgrades available")
		return
	for option in options:
		grid.add_child(_ability_card(option))
	grid.queue_sort()
	for child in grid.get_children():
		if child is Button and not child.disabled:
			child.call_deferred("grab_focus")
			break

func _ability_card(option: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(180, 220) if compact else Vector2(260, 280)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	button.disabled = not bool(option.get("enabled", true))
	button.text = ""
	button.clip_contents = true
	_apply_card_style(button)

	var row := VBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_top = 8
	row.offset_right = -6
	row.offset_bottom = -8
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(row)

	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(80, 80) if compact else Vector2(120, 120)
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_holder)
	var path := str(option.get("icon_path", ""))
	if path != "" and ResourceLoader.exists(path):
		var icon := TextureRect.new()
		icon.texture = load(path)
		icon.custom_minimum_size = Vector2(72, 72) if compact else Vector2(108, 108)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(icon)
	else:
		var fallback := Label.new()
		fallback.text = "?"
		fallback.custom_minimum_size = Vector2(72, 72) if compact else Vector2(108, 108)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 48 if compact else 72)
		fallback.add_theme_color_override("font_color", Color(0.85, 0.68, 0.3))
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(fallback)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_box)

	var level_value := int(option.get("level", 0))
	var max_level := int(option.get("max_level", 1))
	var suffix := "  Lv.%d/%d" % [level_value, max_level] if max_level > 1 else ""
	var heading := Label.new()
	heading.text = "%s%s" % [str(option.get("title", "Ability")), suffix]
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_override("font", _get_button_font())
	heading.add_theme_font_size_override("font_size", 18 if compact else 22)
	heading.add_theme_color_override("font_color", Color(0.62, 0.59, 0.54) if button.disabled else Color(1.0, 0.9, 0.68))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(heading)

	var reason := str(option.get("reason", ""))
	var description := Label.new()
	description.text = reason if reason != "" else str(option.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_font_override("font", _get_button_font())
	description.add_theme_font_size_override("font_size", 13 if compact else 15)
	description.add_theme_color_override("font_color", Color(0.75, 0.55, 0.45) if reason != "" else Color(0.88, 0.82, 0.7))
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(description)

	var id := str(option.get("id", ""))
	button.pressed.connect(func(): _choose(id))
	return button

func _apply_card_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.07, 0.035, 0.94)
	normal.border_color = Color(0.63, 0.42, 0.17)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.24, 0.13, 0.05, 0.98)
	hover.border_color = Color(1.0, 0.78, 0.28)
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.34, 0.18, 0.06, 1.0)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.08, 0.06, 0.05, 0.88)
	disabled.border_color = Color(0.3, 0.26, 0.22)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)

func _show_grid_message(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	grid.add_child(label)

func _show_error(message: String) -> void:
	push_error("LevelUpMenu: " + message)
	_make_background()
	var panel := $Panel
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	panel.offset_left = -220
	panel.offset_top = -90
	panel.offset_right = 220
	panel.offset_bottom = 90
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	panel.add_child(label)

func _choose(id: String) -> void:
	if id == "":
		return
	upgrade_selected.emit(id)
	get_tree().paused = false
	queue_free()
