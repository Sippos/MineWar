extends Control

const BASE_ENTRIES := [
	{
		"name": "Dwarf Bastion",
		"hero": "Dwarf",
		"texture": preload("res://DwarfBase.png")
	},
	{
		"name": "Shaman Shrine",
		"hero": "Shaman",
		"texture": preload("res://ShamanBase.png")
	},
	{
		"name": "Nerubian Nest",
		"hero": "Nerubian",
		"texture": preload("res://NerubianBase.png")
	},
	{
		"name": "Druid Grove",
		"hero": "Druid",
		"texture": preload("res://DruidBase.png")
	},
	{
		"name": "Undead Crypt",
		"hero": "Undead King",
		"texture": preload("res://UndeadKingBase.png")
	},
	{
		"name": "Goblin Mech Workshop",
		"hero": "Mech",
		"texture": preload("res://DwarfBase.png")
	}
]

var returning_to_menu := false

func _ready() -> void:
	var back_btn := $VBoxContainer/TopBar/BackButton as Button
	if not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)

	populate_heroes()
	populate_bases()
	populate_monsters()
	$VBoxContainer/TopBar/Label.text = "MINEWARS BESTIARY"
	_update_grid_columns()
	get_tree().root.size_changed.connect(_update_grid_columns)
	back_btn.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _on_back_pressed() -> void:
	if returning_to_menu:
		return
	returning_to_menu = true
	await get_tree().create_timer(0.12, true).timeout
	get_tree().change_scene_to_file("res://scenes/menus/main/menu.tscn")

func _update_grid_columns() -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	var columns := 6 if viewport_width >= 1000.0 else (5 if viewport_width >= 820.0 else (4 if viewport_width >= 620.0 else (3 if viewport_width >= 460.0 else 2)))
	var grids: Array[GridContainer] = [
		$VBoxContainer/ScrollContainer/VBoxContainer/HeroesGrid,
		$VBoxContainer/ScrollContainer/VBoxContainer/BasesGrid,
		$VBoxContainer/ScrollContainer/VBoxContainer/MonstersGrid,
	]
	for grid in grids:
		grid.columns = columns

func populate_heroes() -> void:
	var grid := $VBoxContainer/ScrollContainer/VBoxContainer/HeroesGrid as GridContainer
	_clear_container(grid)
	for hero_name in Global.hero_data.keys():
		var is_unlocked: bool = Global.is_hero_playable_in_single_player(str(hero_name))
		var texture := Global.hero_data[hero_name]["walk"] as Texture2D
		var icon := create_icon_from_texture(texture, is_unlocked)
		icon.tooltip_text = str(hero_name) if is_unlocked else "Unknown hero"
		grid.add_child(icon)

func populate_bases() -> void:
	var grid := $VBoxContainer/ScrollContainer/VBoxContainer/BasesGrid as GridContainer
	_clear_container(grid)
	for entry in BASE_ENTRIES:
		var hero_id := str(entry["hero"])
		var is_revealed: bool = Global.is_hero_playable_in_single_player(hero_id)
		grid.add_child(create_base_entry(str(entry["name"]), entry["texture"] as Texture2D, is_revealed))

func populate_monsters() -> void:
	var grid := $VBoxContainer/ScrollContainer/VBoxContainer/MonstersGrid as GridContainer
	_clear_container(grid)
	for monster_name in Global.monster_data.keys():
		var is_seen: bool = Global.seen_monsters.has(monster_name)
		var texture := Global.monster_data[monster_name] as Texture2D
		var icon := create_icon_from_texture(texture, is_seen)
		icon.tooltip_text = str(monster_name) if is_seen else "Unknown monster"
		grid.add_child(icon)

func create_icon(texture_path: String, is_revealed: bool) -> Control:
	return create_icon_from_texture(load(texture_path) as Texture2D, is_revealed)

func create_icon_from_texture(tex: Texture2D, is_revealed: bool) -> Control:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(80, 80)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if tex == null:
		return rect

	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	var frame_width: float = tex.get_width() / 8.0
	var frame_height: float = tex.get_height() / 8.0
	atlas.region = Rect2(0, 0, frame_width, frame_height)
	rect.texture = atlas

	if not is_revealed:
		rect.modulate = Color(0.025, 0.025, 0.035, 1.0)

	return rect

func create_base_entry(base_name: String, tex: Texture2D, is_revealed: bool) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(92, 112)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.tooltip_text = base_name if is_revealed else "Unknown base — unlock its hero to reveal it"

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(88, 88)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.075, 0.038, 0.018, 0.96)
	frame_style.border_color = Color(0.62, 0.43, 0.18, 0.9) if is_revealed else Color(0.18, 0.2, 0.25, 0.9)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(6)
	frame.add_theme_stylebox_override("panel", frame_style)
	card.add_child(frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	frame.add_child(margin)

	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(76, 76)
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_revealed:
		rect.modulate = Color(0.02, 0.02, 0.025, 1.0)
	margin.add_child(rect)

	var label := Label.new()
	label.custom_minimum_size = Vector2(92, 20)
	label.text = base_name if is_revealed else "Unknown Base"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.5, 1.0) if is_revealed else Color(0.48, 0.5, 0.55, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(label)
	return card

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
