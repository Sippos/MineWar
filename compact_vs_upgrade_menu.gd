extends CanvasLayer

const MENU_TEX = preload("res://MenuPanel.png")

var upgrade_menu: CanvasLayer
var panel: Control
var grid: GridContainer
var title: Label
var prompt_button_bound := false

func setup(target_menu: CanvasLayer) -> void:
	upgrade_menu = target_menu
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _process(_delta: float) -> void:
	if upgrade_menu == null or not is_instance_valid(upgrade_menu):
		queue_free()
		return
	if not prompt_button_bound:
		_bind_prompt_button()
	if panel != null and panel.visible:
		var legacy := upgrade_menu.get_node_or_null("Panel")
		if legacy:
			legacy.visible = false

func _bind_prompt_button() -> void:
	var prompt := upgrade_menu.get_node_or_null("VSPromptPanel")
	if prompt == null:
		return
	for node in prompt.find_children("*", "Button", true, false):
		if node is Button and node.text == "Upgrades":
			var callback := Callable(self, "show_compact")
			if not node.pressed.is_connected(callback):
				node.pressed.connect(callback)
			prompt_button_bound = true
			return

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
	root.offset_left = 54
	root.offset_top = 38
	root.offset_right = -54
	root.offset_bottom = -44
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	title = Label.new()
	title.text = "Base Upgrades"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	var close := _button("Close", "", "_compact_close")
	close.custom_minimum_size = Vector2(0, 42)
	root.add_child(close)
	_rebuild_buttons()

func show_compact() -> void:
	if upgrade_menu == null:
		return
	var legacy := upgrade_menu.get_node_or_null("Panel")
	if legacy:
		legacy.visible = false
	var prompt := upgrade_menu.get_node_or_null("VSPromptPanel")
	if prompt:
		prompt.visible = false
	var send_panel := upgrade_menu.get_node_or_null("VSSendPanel")
	if send_panel:
		send_panel.visible = false
	_rebuild_buttons()
	panel.visible = true
	var first := grid.get_child(0) if grid.get_child_count() > 0 else null
	if first is Button:
		first.call_deferred("grab_focus")

func _rebuild_buttons() -> void:
	if grid == null or upgrade_menu == null:
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
	_add("Base HP", "_on_unlock_base_health_pressed", _base_icon(hero), "10 gold")
	_add("XP Bar", "_on_unlock_xp_pressed", "res://HealthBarPurple.png", "10 gold")
	_add("Minimap", "_on_unlock_minimap_pressed", "res://icon.svg", "20 gold")
	_add("See Enemies", "_on_upgrade_minimap_pressed", "res://character_sprites/rat_walk_pixelart_spritesheet.png", "50 gold")
	if hero == "Dwarf":
		_add("Buy Rail", "_on_buy_rail_pressed", "res://rail_item_placeholder.png", "10 gold")
		_add("Buy Minecart", "_on_buy_minecart_pressed", "res://character_sprites/minecart_spritesheet_25d.png", "50 gold")
	elif hero == "Shaman":
		_add("Buy Peon", "_on_buy_peon_pressed", "res://character_sprites/peon_walk_spritesheet_25d.png", "30 gold")
	grid.queue_sort()

func _base_icon(hero: String) -> String:
	if hero == "Shaman" and ResourceLoader.exists("res://ShamanBase.png"):
		return "res://ShamanBase.png"
	return "res://DwarfBase.png"

func _gem_cost(stat: String) -> String:
	var p = upgrade_menu.get("player")
	if p == null:
		return "1 gem"
	return "%d gems" % max(1, int(p.get(stat)) * 2 - 1)

func _add(label_text: String, method_name: String, icon_path: String, cost: String) -> void:
	grid.add_child(_button(label_text, cost, method_name, icon_path))

func _icon_texture(icon_path: String) -> Texture2D:
	if icon_path == "" or not ResourceLoader.exists(icon_path):
		return null
	var texture := load(icon_path) as Texture2D
	if texture == null:
		return null
	if "spritesheet" in icon_path:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(0, 0, texture.get_width() / 8.0, texture.get_height() / 8.0)
		return atlas
	return texture

func _button(title_text: String, cost_text: String, method_name: String, icon_path: String = "") -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 62)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = ""
	_apply_style(button)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_top = 6
	row.offset_right = -8
	row.offset_bottom = -6
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)
	button.add_child(row)

	if icon_path != "":
		var icon := TextureRect.new()
		icon.texture = _icon_texture(icon_path)
		icon.custom_minimum_size = Vector2(38, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(labels)
	var heading := Label.new()
	heading.text = title_text
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(heading)
	if cost_text != "":
		var cost := Label.new()
		cost.text = cost_text
		cost.add_theme_font_size_override("font_size", 12)
		cost.add_theme_color_override("font_color", Color(1.0, 0.75, 0.28))
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels.add_child(cost)

	button.pressed.connect(func():
		if method_name == "_compact_close":
			panel.visible = false
			if upgrade_menu.has_method("_on_close_pressed"):
				upgrade_menu.call("_on_close_pressed")
			return
		if upgrade_menu.has_method(method_name):
			upgrade_menu.call(method_name)
		_rebuild_buttons()
	)
	return button

func _apply_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.07, 0.035, 0.95)
	normal.border_color = Color(0.62, 0.42, 0.18)
	normal.set_border_width_all(2)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	var hover := normal.duplicate()
	hover.bg_color = Color(0.25, 0.14, 0.05, 1.0)
	hover.border_color = Color(1.0, 0.78, 0.28)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)
