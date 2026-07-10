extends CanvasLayer

signal upgrade_selected(upgrade_type: String)
const HERO_SCRIPT = preload("res://hero_abilities.gd")
const MENU_TEX = preload("res://assets/sprites/ui/common/MenuPanel.png")

var player: Node
var controller: Node
var grid: GridContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(_legacy = false) -> void:
	call_deferred("_build")

func _build() -> void:
	player = get_parent().get_node_or_null("Player")
	if player == null:
		return
	controller = player.get_node_or_null("HeroAbilities")
	if controller == null:
		controller = Node.new()
		controller.name = "HeroAbilities"
		controller.set_script(HERO_SCRIPT)
		player.add_child(controller)
		await get_tree().process_frame
	if not upgrade_selected.is_connected(controller._on_upgrade_selected):
		upgrade_selected.connect(controller._on_upgrade_selected)
	_make_background()
	_make_menu()

func _make_background() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.52)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	move_child(dim, 0)

func _make_menu() -> void:
	var panel := $Panel
	var size := get_viewport().get_visible_rect().size
	var compact := size.x < 700.0
	var w: float = min(620.0, max(390.0, size.x - 28.0))
	var h: float = min(560.0, max(430.0, size.y - 28.0))
	panel.offset_left = -w * 0.5
	panel.offset_top = -h * 0.5
	panel.offset_right = w * 0.5
	panel.offset_bottom = h * 0.5

	var art := TextureRect.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.texture = MENU_TEX
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(art)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 58.0 if compact else 78.0
	box.offset_top = 40.0 if compact else 52.0
	box.offset_right = -58.0 if compact else -78.0
	box.offset_bottom = -48.0 if compact else -62.0
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "%s — Choose Ability" % str(player.get("current_hero_name"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25 if compact else 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	box.add_child(title)

	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)

	var options: Array = controller.get_level_up_options()
	for option in options:
		grid.add_child(_ability_button(option, compact))
	for child in grid.get_children():
		if child is Button and not child.disabled:
			child.call_deferred("grab_focus")
			break

func _ability_button(option: Dictionary, compact: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 145 if compact else 180)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not bool(option.get("enabled", true))
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 78 if compact else 96)
	b.add_theme_constant_override("icon_spacing", 8)
	b.add_theme_font_size_override("font_size", 15 if compact else 17)
	b.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.48))
	var path := str(option.get("icon_path", ""))
	if path != "" and ResourceLoader.exists(path):
		b.icon = load(path)
	var lvl := int(option.get("level", 0))
	var max_lvl := int(option.get("max_level", 1))
	var suffix := ""
	if max_lvl > 1:
		suffix = "  Lv.%d/%d" % [lvl, max_lvl]
	var reason := str(option.get("reason", ""))
	b.text = "%s%s\n%s" % [str(option.get("title", "Ability")), suffix, reason if reason != "" else str(option.get("description", ""))]
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
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	var id := str(option.get("id", ""))
	b.pressed.connect(func(): _choose(id))
	return b

func _choose(id: String) -> void:
	upgrade_selected.emit(id)
	get_tree().paused = false
	queue_free()
