extends CanvasLayer

const MENU_TEX = preload("res://MenuPanel.png")

var upgrade_menu: CanvasLayer
var panel: Control
var grid: GridContainer
var title: Label

func setup(target_menu: CanvasLayer) -> void:
	upgrade_menu = target_menu
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _process(_delta: float) -> void:
	if upgrade_menu == null or not is_instance_valid(upgrade_menu):
		queue_free()
		return
	var legacy := upgrade_menu.get_node_or_null("Panel")
	if legacy and legacy.visible:
		legacy.visible = false
		show_compact()

func _build() -> void:
	panel = Control.new()
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -230
	panel.offset_top = -245
	panel.offset_right = 230
	panel.offset_bottom = 245
	add_child(panel)

	var art := TextureRect.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.texture = MENU_TEX
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(art)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 58
	root.offset_top = 42
	root.offset_right = -58
	root.offset_bottom = -48
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	title = Label.new()
	title.text = "Base Upgrades"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	root.add_child(title)

	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(grid)

	var close := _button("Close", "_on_close_pressed")
	close.custom_minimum_size = Vector2(0, 46)
	root.add_child(close)
	_rebuild_buttons()

func show_compact() -> void:
	_rebuild_buttons()
	panel.visible = true
	var first := grid.get_child(0) if grid.get_child_count() > 0 else null
	if first is Button:
		first.call_deferred("grab_focus")

func _rebuild_buttons() -> void:
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()
	var hero := upgrade_menu._get_menu_hero() if upgrade_menu.has_method("_get_menu_hero") else "Hero"
	title.text = "%s Base Upgrades" % hero
	_add("STR +1", "_on_upgrade_strength_pressed", "res://Strenght.png", _gem_cost("strength"))
	_add("AGI +1", "_on_upgrade_agility_pressed", "res://Agility.png", _gem_cost("agility"))
	_add("INT +1", "_on_upgrade_intelligence_pressed", "res://Int.png", _gem_cost("intelligence"))
	_add("+20 Max HP", "_on_upgrade_max_health_pressed", "res://Healthbar.png", "15 gold")
	_add("Heal +20", "_on_heal_player_pressed", "res://Healthbar.png", "10 gold")
	_add("Player HP", "_on_unlock_healthbar_pressed", "res://Healthbar.png", "10 gold")
	_add("Base HP", "_on_unlock_base_health_pressed", "res://Healthbar.png", "10 gold")
	_add("XP Bar", "_on_unlock_xp_pressed", "res://HealthBarPurple.png", "10 gold")
	_add("Minimap", "_on_unlock_minimap_pressed", "res://icon.svg", "20 gold")
	_add("See Enemies", "_on_upgrade_minimap_pressed", "res://icon.svg", "50 gold")
	if hero == "Dwarf":
		_add("Buy Rail", "_on_buy_rail_pressed", "res://rail_item_placeholder.png", "10 gold")
		_add("Buy Minecart", "_on_buy_minecart_pressed", "res://character_sprites/minecart_spritesheet_25d.png", "50 gold")
	elif hero == "Shaman":
		_add("Buy Peon", "_on_buy_peon_pressed", "res://character_sprites/peon_walk_spritesheet_25d.png", "30 gold")

func _gem_cost(stat: String) -> String:
	var p = upgrade_menu.get("player")
	if p == null:
		return "1 gem"
	var level_value := int(p.get(stat))
	return "%d gems" % max(1, level_value * 2 - 1)

func _add(label_text: String, method_name: String, icon_path: String, cost: String) -> void:
	grid.add_child(_button("%s\n%s" % [label_text, cost], method_name, icon_path))

func _button(text_value: String, method_name: String, icon_path: String = "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 62)
	b.text = text_value
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	b.expand_icon = true
	b.icon_max_width = 38
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.07, 0.035, 0.95)
	normal.border_color = Color(0.62, 0.42, 0.18)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.25, 0.14, 0.05, 1.0)
	hover.border_color = Color(1.0, 0.78, 0.28)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(func():
		if upgrade_menu.has_method(method_name):
			upgrade_menu.call(method_name)
		if method_name == "_on_close_pressed":
			panel.visible = false
		else:
			_rebuild_buttons()
	)
	return b
