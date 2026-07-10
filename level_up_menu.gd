extends CanvasLayer

signal upgrade_selected(upgrade_type: String)

const HERO_SCRIPT = preload("res://hero_abilities.gd")
const MENU_TEX = preload("res://MenuPanel.png")

var player: Node
var controller: Node
var grid: GridContainer
var compact := false

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
	if not controller.has_method("get_level_up_options"):
		_show_error("Ability controller unavailable")
		return
	var callback := Callable(controller, "_on_upgrade_selected")
	if not upgrade_selected.is_connected(callback):
		upgrade_selected.connect(callback)
	_build_visuals()

func _build_visuals() -> void:
	var panel := $Panel
	for child in panel.get_children():
		child.queue_free()
	var view_size := get_viewport().get_visible_rect().size
	compact = view_size.x < 700.0
	var width := min(620.0, max(390.0, view_size.x - 28.0))
	var height := min(560.0, max(430.0, view_size.y - 28.0))
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
	title.add_theme_font_size_override("font_size", 24 if compact else 29)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	box.add_child(title)

	grid = GridContainer.new()
	grid.columns = 1 if compact else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8 if compact else 10)
	box.add_child(grid)

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
	button.custom_minimum_size = Vector2(0, 78 if compact else 155)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.disabled = not bool(option.get("enabled", true))
	button.text = ""
	_apply_card_style(button)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_top = 8
	row.offset_right = -10
	row.offset_bottom = -8
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	button.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(54, 54) if compact else Vector2(82, 82)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := str(option.get("icon_path", ""))
	if path != "" and ResourceLoader.exists(path):
		icon.texture = load(path)
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_box)

	var level_value := int(option.get("level", 0))
	var max_level := int(option.get("max_level", 1))
	var suffix := "  Lv.%d/%d" % [level_value, max_level] if max_level > 1 else ""
	var heading := Label.new()
	heading.text = "%s%s" % [str(option.get("title", "Ability")), suffix]
	heading.add_theme_font_size_override("font_size", 16 if compact else 18)
	heading.add_theme_color_override("font_color", Color(1.0, 0.9, 0.68))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(heading)

	var reason := str(option.get("reason", ""))
	var description := Label.new()
	description.text = reason if reason != "" else str(option.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 13 if compact else 15)
	description.add_theme_color_override("font_color", Color(0.88, 0.82, 0.7) if reason == "" else Color(0.75, 0.55, 0.45))
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
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	var hover := normal.duplicate()
	hover.bg_color = Color(0.24, 0.13, 0.05, 0.98)
	hover.border_color = Color(1.0, 0.78, 0.28)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.08, 0.06, 0.05, 0.88)
	disabled.border_color = Color(0.3, 0.26, 0.22)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)

func _show_grid_message(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	grid.add_child(label)

func _show_error(message: String) -> void:
	push_error("LevelUpMenu: " + message)
	var panel := $Panel
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(label)

func _choose(id: String) -> void:
	upgrade_selected.emit(id)
	get_tree().paused = false
	queue_free()
