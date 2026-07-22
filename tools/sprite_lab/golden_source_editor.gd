extends Control

## MineWars Tile Forge
## Production pixel editor for the Easy dirt front face. The authored source is
## 32x32 and exports nearest-neighbour to the exact 64x64 asset used by the game.

const PIXEL_CANVAS_SCRIPT := preload("res://tools/sprite_lab/front_face_pixel_canvas.gd")
const LIVE_PREVIEW_SCRIPT := preload("res://tools/sprite_lab/front_face_live_preview.gd")
const TERRAIN_CANVAS_SCRIPT := preload("res://tools/sprite_lab/terrain_interaction_canvas.gd")

const LOGICAL_SIZE := 32
const EXPORT_SIZE := 64
const SOURCE_PATH := "res://tools/sprite_lab/source/easy_front_face_a.json"
const PRODUCTION_PATH := "res://assets/sprites/world/terrain/front_walls/Easy_Brick-Front.png"
const BACKUP_DIR := "res://tools/sprite_lab/source/backups"
const MAX_UNDO := 40

const PALETTE_ORDER: Array[String] = [
	"transparent", "outline", "deep_shadow", "easy_dark", "easy_mid", "easy_light", "easy_highlight"
]
const KEY_TO_CHAR := {
	"transparent": ".",
	"outline": "O",
	"deep_shadow": "S",
	"easy_dark": "D",
	"easy_mid": "M",
	"easy_light": "L",
	"easy_highlight": "H"
}
const CHAR_TO_KEY := {
	".": "transparent",
	"O": "outline",
	"S": "deep_shadow",
	"D": "easy_dark",
	"M": "easy_mid",
	"L": "easy_light",
	"H": "easy_highlight"
}

var palette := {
	"transparent": Color(0, 0, 0, 0),
	"outline": Color.html("242035ff"),
	"deep_shadow": Color.html("312b49ff"),
	"easy_dark": Color.html("49415fff"),
	"easy_mid": Color.html("5b5279ff"),
	"easy_light": Color.html("746b99ff"),
	"easy_highlight": Color.html("958ab8ff")
}

var edit_image: Image
var pixel_canvas: Control
var live_preview: Control
var terrain_canvas: Control
var native_preview: TextureRect
var status_label: Label
var notice_label: Label
var hover_label: Label
var selected_color_label: Label
var tool_selector: OptionButton
var brush_selector: OptionButton
var undo_button: Button
var redo_button: Button
var palette_buttons: Dictionary = {}

var current_tool := 0
var brush_size := 1
var selected_color_key := "easy_mid"
var undo_stack: Array[Image] = []
var redo_stack: Array[Image] = []
var stroke_active := false
var stroke_changed := false
var last_stroke_cell := Vector2i(-1, -1)
var dirty := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edit_image = _load_initial_image()
	_build_interface()
	_refresh_all()
	_set_notice("Ready. Paint the 32x32 source; the cave preview updates immediately.", true)

func _build_interface() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color.html("0d1119ff")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	margin.add_child(outer)

	var title := Label.new()
	title.text = "MINEWARS TILE FORGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color.html("8eeeffff"))
	outer.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Easy Front Face A  •  32x32 source  →  64x64 production PNG  •  live Dome-style excavation preview"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color.html("a9bac6ff"))
	outer.add_child(subtitle)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(tabs)

	var painter_tab := Control.new()
	painter_tab.name = "PIXEL EDITOR"
	painter_tab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tabs.add_child(painter_tab)
	_build_painter_tab(painter_tab)

	var terrain_tab := Control.new()
	terrain_tab.name = "TERRAIN STRESS TEST"
	terrain_tab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tabs.add_child(terrain_tab)
	_build_terrain_tab(terrain_tab)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color.html("c4d4deff"))
	outer.add_child(status_label)

	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 11)
	notice_label.add_theme_color_override("font_color", Color.html("7f96a5ff"))
	outer.add_child(notice_label)

func _build_painter_tab(parent: Control) -> void:
	var body_margin := MarginContainer.new()
	body_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body_margin.add_theme_constant_override("margin_top", 7)
	parent.add_child(body_margin)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body_margin.add_child(body)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(238, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left_panel)

	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left_scroll)

	var left_margin := MarginContainer.new()
	left_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_margin.add_theme_constant_override("margin_left", 10)
	left_margin.add_theme_constant_override("margin_right", 10)
	left_margin.add_theme_constant_override("margin_top", 9)
	left_margin.add_theme_constant_override("margin_bottom", 9)
	left_scroll.add_child(left_margin)

	var tools := VBoxContainer.new()
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_theme_constant_override("separation", 6)
	left_margin.add_child(tools)

	_add_section_label(tools, "PAINT TOOL")
	tool_selector = OptionButton.new()
	for tool_name in ["Pencil", "Eraser", "Flood fill", "Eyedropper"]:
		tool_selector.add_item(tool_name)
	tool_selector.item_selected.connect(func(index: int) -> void:
		current_tool = index
		_update_status()
	)
	tools.add_child(tool_selector)

	var brush_row := HBoxContainer.new()
	brush_row.add_child(_small_label("Brush"))
	brush_selector = OptionButton.new()
	for size_name in ["1 px", "2 px", "3 px"]:
		brush_selector.add_item(size_name)
	brush_selector.item_selected.connect(func(index: int) -> void:
		brush_size = index + 1
		_update_status()
	)
	brush_row.add_child(brush_selector)
	tools.add_child(brush_row)

	var tool_help := Label.new()
	tool_help.text = "Left-drag paints. Right-drag always erases. The source stays pixel-perfect; no smoothing is used."
	tool_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tool_help.add_theme_font_size_override("font_size", 10)
	tool_help.add_theme_color_override("font_color", Color.html("8599a8ff"))
	tools.add_child(tool_help)

	_add_section_label(tools, "MINE PALETTE")
	var palette_grid := GridContainer.new()
	palette_grid.columns = 2
	palette_grid.add_theme_constant_override("h_separation", 5)
	palette_grid.add_theme_constant_override("v_separation", 5)
	tools.add_child(palette_grid)
	for key in PALETTE_ORDER:
		_add_palette_button(palette_grid, key)

	selected_color_label = Label.new()
	selected_color_label.add_theme_font_size_override("font_size", 11)
	selected_color_label.add_theme_color_override("font_color", Color.html("d8e2e9ff"))
	tools.add_child(selected_color_label)

	_add_section_label(tools, "VIEW")
	var grid_check := CheckBox.new()
	grid_check.text = "Pixel grid"
	grid_check.button_pressed = true
	grid_check.toggled.connect(func(value: bool) -> void:
		pixel_canvas.call("set_grid_visible", value)
	)
	tools.add_child(grid_check)

	var guide_check := CheckBox.new()
	guide_check.text = "17 px front-depth guide"
	guide_check.button_pressed = true
	guide_check.toggled.connect(func(value: bool) -> void:
		pixel_canvas.call("set_depth_guide_visible", value)
	)
	tools.add_child(guide_check)

	_add_section_label(tools, "EDIT HISTORY")
	var history_row := HBoxContainer.new()
	undo_button = Button.new()
	undo_button.text = "Undo"
	undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_button.pressed.connect(_undo)
	history_row.add_child(undo_button)
	redo_button = Button.new()
	redo_button.text = "Redo"
	redo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	redo_button.pressed.connect(_redo)
	history_row.add_child(redo_button)
	tools.add_child(history_row)

	_add_section_label(tools, "START / RESET")
	var load_button := Button.new()
	load_button.text = "Reload production PNG"
	load_button.pressed.connect(_reload_production)
	tools.add_child(load_button)

	var starter_button := Button.new()
	starter_button.text = "Apply Dome-style starter"
	starter_button.pressed.connect(_apply_starter_with_history)
	tools.add_child(starter_button)

	var clear_button := Button.new()
	clear_button.text = "Clear transparent"
	clear_button.pressed.connect(_clear_with_history)
	tools.add_child(clear_button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools.add_child(spacer)

	_add_section_label(tools, "PRODUCTION")
	var save_source_button := Button.new()
	save_source_button.text = "Save editable source"
	save_source_button.pressed.connect(_save_source_pressed)
	tools.add_child(save_source_button)

	var export_button := Button.new()
	export_button.text = "EXPORT TO LIVE GAME"
	export_button.custom_minimum_size = Vector2(0, 42)
	export_button.pressed.connect(_export_to_game)
	tools.add_child(export_button)

	var path_note := Label.new()
	path_note.text = "Writes directly to:\nassets/sprites/world/terrain/front_walls/Easy_Brick-Front.png\nA timestamped backup is created first."
	path_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	path_note.add_theme_font_size_override("font_size", 9)
	path_note.add_theme_color_override("font_color", Color.html("8da0adff"))
	tools.add_child(path_note)

	var canvas_panel := PanelContainer.new()
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(canvas_panel)

	var canvas_center := CenterContainer.new()
	canvas_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.add_child(canvas_center)

	pixel_canvas = PIXEL_CANVAS_SCRIPT.new() as Control
	pixel_canvas.stroke_started.connect(_on_stroke_started)
	pixel_canvas.stroke_moved.connect(_on_stroke_moved)
	pixel_canvas.stroke_finished.connect(_on_stroke_finished)
	pixel_canvas.hover_changed.connect(_on_hover_changed)
	canvas_center.add_child(pixel_canvas)

	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(390, 0)
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 10)
	right_margin.add_theme_constant_override("margin_right", 10)
	right_margin.add_theme_constant_override("margin_top", 9)
	right_margin.add_theme_constant_override("margin_bottom", 9)
	right_panel.add_child(right_margin)

	var previews := VBoxContainer.new()
	previews.add_theme_constant_override("separation", 7)
	right_margin.add_child(previews)

	_add_section_label(previews, "LIVE EXCAVATION PREVIEW")
	var mode_selector := OptionButton.new()
	for mode_name in ["Wide room", "Narrow shaft", "Overhang / pillars"]:
		mode_selector.add_item(mode_name)
	mode_selector.item_selected.connect(func(index: int) -> void:
		live_preview.call("set_preview_mode", index)
	)
	previews.add_child(mode_selector)

	var live_center := CenterContainer.new()
	live_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	live_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	previews.add_child(live_center)
	live_preview = LIVE_PREVIEW_SCRIPT.new() as Control
	live_center.add_child(live_preview)

	var preview_row := HBoxContainer.new()
	preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_row.add_theme_constant_override("separation", 14)
	previews.add_child(preview_row)

	var native_column := VBoxContainer.new()
	native_column.add_child(_small_label("64x64 export"))
	native_preview = TextureRect.new()
	native_preview.custom_minimum_size = Vector2(128, 128)
	native_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	native_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	native_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	native_column.add_child(native_preview)
	preview_row.add_child(native_column)

	var rules := VBoxContainer.new()
	rules.custom_minimum_size = Vector2(190, 0)
	rules.add_child(_small_label("Dome-style readability rules"))
	for rule in [
		"• Lower half stays transparent",
		"• Chunky clusters, not pixel noise",
		"• Light from upper-left",
		"• Dark bottom seam anchors depth",
		"• Seamless left/right tile edges"
	]:
		var rule_label := Label.new()
		rule_label.text = rule
		rule_label.add_theme_font_size_override("font_size", 10)
		rule_label.add_theme_color_override("font_color", Color.html("a9bac6ff"))
		rules.add_child(rule_label)
	preview_row.add_child(rules)

	hover_label = Label.new()
	hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hover_label.add_theme_font_size_override("font_size", 10)
	hover_label.add_theme_color_override("font_color", Color.html("9db0bcff"))
	previews.add_child(hover_label)

func _build_terrain_tab(parent: Control) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 7)
	parent.add_child(margin)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)

	var sidebar_panel := PanelContainer.new()
	sidebar_panel.custom_minimum_size = Vector2(275, 0)
	body.add_child(sidebar_panel)
	var sidebar_margin := MarginContainer.new()
	sidebar_margin.add_theme_constant_override("margin_left", 10)
	sidebar_margin.add_theme_constant_override("margin_right", 10)
	sidebar_margin.add_theme_constant_override("margin_top", 9)
	sidebar_margin.add_theme_constant_override("margin_bottom", 9)
	sidebar_panel.add_child(sidebar_margin)
	var sidebar := VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 6)
	sidebar_margin.add_child(sidebar)

	_add_section_label(sidebar, "TEST CAVE SHAPE")
	var template_selector := OptionButton.new()
	for template_name in ["Starter Tunnel", "Solid Mass", "Vertical Shaft", "Horizontal Tunnel", "Large Room", "Staircase", "Pillars / Overhang", "Gem Vein", "Motherlode"]:
		template_selector.add_item(template_name)
	sidebar.add_child(template_selector)
	var apply_template_button := Button.new()
	apply_template_button.text = "Apply template"
	apply_template_button.pressed.connect(func() -> void:
		terrain_canvas.call("apply_template", template_selector.get_item_text(template_selector.selected))
	)
	sidebar.add_child(apply_template_button)

	_add_section_label(sidebar, "INTERACTION TOOL")
	var terrain_tool := OptionButton.new()
	for tool_name in ["Dig tunnel", "Restore block", "Gem: hint", "Gem: revealed", "Gem: rich", "Cycle damage", "Clear gem/damage", "Move player light"]:
		terrain_tool.add_item(tool_name)
	terrain_tool.item_selected.connect(func(index: int) -> void:
		terrain_canvas.call("set_tool", index)
	)
	sidebar.add_child(terrain_tool)

	_add_section_label(sidebar, "LIGHTING")
	var lighting := OptionButton.new()
	for lighting_name in ["Neutral", "Mine ambient", "Player radial", "Dark mine"]:
		lighting.add_item(lighting_name)
	lighting.select(1)
	lighting.item_selected.connect(func(index: int) -> void:
		terrain_canvas.call("set_lighting_mode", index)
	)
	sidebar.add_child(lighting)

	_add_section_label(sidebar, "LAYERS")
	var layer_grid := GridContainer.new()
	layer_grid.columns = 2
	sidebar.add_child(layer_grid)
	_add_terrain_switch(layer_grid, "Dome shell", "shell", true)
	_add_terrain_switch(layer_grid, "Real assets", "assets", true)
	_add_terrain_switch(layer_grid, "Front walls", "fronts", true)
	_add_terrain_switch(layer_grid, "Gem faces", "gems", true)
	_add_terrain_switch(layer_grid, "Damage", "damage", true)
	_add_terrain_switch(layer_grid, "Grid", "grid", true)

	var explanation := Label.new()
	explanation.text = "Use this tab after export to inspect all exposure masks, projected walls, gems and damage together. The Pixel Editor preview always uses the unsaved image immediately."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 10)
	explanation.add_theme_color_override("font_color", Color.html("8da0adff"))
	sidebar.add_child(explanation)

	var terrain_panel := PanelContainer.new()
	terrain_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terrain_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(terrain_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	terrain_panel.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	terrain_canvas = TERRAIN_CANVAS_SCRIPT.new() as Control
	terrain_canvas.state_changed.connect(func(summary: String) -> void:
		if status_label != null:
			status_label.text = summary
	)
	center.add_child(terrain_canvas)

func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.html("8eeeffff"))
	parent.add_child(label)

func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.html("a9bac6ff"))
	return label

func _add_palette_button(parent: GridContainer, key: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(98, 34)
	button.text = key.replace("_", " ").capitalize()
	button.tooltip_text = key
	button.add_theme_font_size_override("font_size", 9)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = palette[key]
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color.html("181522ff")
	normal_style.corner_radius_top_left = 3
	normal_style.corner_radius_top_right = 3
	normal_style.corner_radius_bottom_left = 3
	normal_style.corner_radius_bottom_right = 3
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_color_override("font_color", Color.WHITE if key in ["transparent", "outline", "deep_shadow", "easy_dark"] else Color.html("181522ff"))
	button.pressed.connect(func() -> void:
		_select_palette_key(key)
	)
	parent.add_child(button)
	palette_buttons[key] = button

func _add_terrain_switch(parent: GridContainer, text: String, option: String, initial: bool) -> void:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = initial
	check.toggled.connect(func(value: bool) -> void:
		terrain_canvas.call("set_option", option, value)
	)
	parent.add_child(check)

func _load_initial_image() -> Image:
	var source := _load_source_json()
	if source != null:
		return source
	# Start new authored work from the face-only contract. The old production
	# asset can still be imported explicitly for comparison or repair.
	return _make_dome_starter()

func _load_source_json() -> Image:
	if not FileAccess.file_exists(SOURCE_PATH):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_PATH))
	if not parsed is Dictionary:
		return null
	var document: Dictionary = parsed
	var rows_value: Variant = document.get("rows", [])
	if not rows_value is Array:
		return null
	var rows: Array = rows_value
	if rows.size() != LOGICAL_SIZE:
		return null
	var image := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(LOGICAL_SIZE):
		var row := String(rows[y])
		for x in range(mini(row.length(), LOGICAL_SIZE)):
			var char := row.substr(x, 1)
			var key := String(CHAR_TO_KEY.get(char, "transparent"))
			image.set_pixel(x, y, palette[key])
	return image

func _load_production_image() -> Image:
	if not FileAccess.file_exists(PRODUCTION_PATH):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(PRODUCTION_PATH))
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != LOGICAL_SIZE or image.get_height() != LOGICAL_SIZE:
		image.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return image

func _make_dome_starter() -> Image:
	var image := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# The visible wall is intentionally only 17 logical pixels deep. At export
	# this becomes 34 px, leaving the lower 30 px transparent.
	for y in range(17):
		for x in range(LOGICAL_SIZE):
			var color: Color = palette["easy_mid"]
			if y <= 1:
				color = palette["easy_light"]
			elif y >= 13:
				color = palette["easy_dark"]
			image.set_pixel(x, y, color)
	for x in range(LOGICAL_SIZE):
		image.set_pixel(x, 16, palette["outline"])
	# Chunky, deterministic rock clusters. Edge pixels remain seamless.
	_stamp_cluster(image, Vector2i(4, 4), [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,1)], "easy_highlight", "easy_light")
	_stamp_cluster(image, Vector2i(12, 7), [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(1,1), Vector2i(0,1)], "easy_light", "easy_dark")
	_stamp_cluster(image, Vector2i(23, 4), [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,1), Vector2i(1,1)], "easy_highlight", "easy_light")
	_stamp_cluster(image, Vector2i(28, 9), [Vector2i(0,0), Vector2i(-1,0), Vector2i(-2,0), Vector2i(-1,1)], "easy_light", "deep_shadow")
	_stamp_cluster(image, Vector2i(7, 12), [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)], "easy_light", "deep_shadow")
	_stamp_cluster(image, Vector2i(18, 12), [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(1,1)], "easy_light", "deep_shadow")
	# Break the bottom seam slightly without creating holes at the tile edges.
	for x in [3, 4, 10, 15, 16, 25, 26]:
		image.set_pixel(x, 15, palette["deep_shadow"])
	return image

func _stamp_cluster(image: Image, origin: Vector2i, offsets: Array[Vector2i], light_key: String, shadow_key: String) -> void:
	for index in range(offsets.size()):
		var p := origin + offsets[index]
		if p.x < 1 or p.x >= LOGICAL_SIZE - 1 or p.y < 2 or p.y >= 15:
			continue
		image.set_pixelv(p, palette[light_key] if index == 0 else palette[shadow_key])

func _save_source() -> Error:
	var rows: Array[String] = []
	for y in range(LOGICAL_SIZE):
		var row := ""
		for x in range(LOGICAL_SIZE):
			row += String(KEY_TO_CHAR[_nearest_palette_key(edit_image.get_pixel(x, y))])
		rows.append(row)
	var document := {
		"version": 1,
		"target": PRODUCTION_PATH,
		"logical_size": LOGICAL_SIZE,
		"export_size": EXPORT_SIZE,
		"front_depth": 17,
		"rows": rows
	}
	var file := FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(document, "  "))
	file.close()
	dirty = false
	return OK

func _save_source_pressed() -> void:
	var result := _save_source()
	_set_notice("Saved editable source to tools/sprite_lab/source/easy_front_face_a.json" if result == OK else "Could not save source: %s" % error_string(result), result == OK)
	_update_status()

func _export_to_game() -> void:
	var backup_result := _backup_production_asset()
	if backup_result != OK and backup_result != ERR_FILE_NOT_FOUND:
		_set_notice("Backup failed; export cancelled: %s" % error_string(backup_result), false)
		return
	var export_image := edit_image.duplicate()
	export_image.resize(EXPORT_SIZE, EXPORT_SIZE, Image.INTERPOLATE_NEAREST)
	var result: Error = export_image.save_png(PRODUCTION_PATH)
	if result != OK:
		_set_notice("Production export failed: %s" % error_string(result), false)
		return
	var source_result := _save_source()
	if source_result != OK:
		_set_notice("PNG exported, but editable source failed to save: %s" % error_string(source_result), false)
		return
	_set_notice("Exported Easy_Brick-Front.png. Godot will reimport it; the live preview already shows the exact result.", true)
	_update_status()

func _backup_production_asset() -> Error:
	if not FileAccess.file_exists(PRODUCTION_PATH):
		return ERR_FILE_NOT_FOUND
	var backup_abs := ProjectSettings.globalize_path(BACKUP_DIR)
	var make_result := DirAccess.make_dir_recursive_absolute(backup_abs)
	if make_result != OK and make_result != ERR_ALREADY_EXISTS:
		return make_result
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var target := "%s/Easy_Brick-Front_%s.png" % [backup_abs, stamp]
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(PRODUCTION_PATH), target)

func _reload_production() -> void:
	var image := _load_production_image()
	if image == null:
		_set_notice("Could not reload the production PNG.", false)
		return
	_push_undo()
	edit_image = image
	dirty = false
	_refresh_all()
	_set_notice("Reloaded the current Easy_Brick-Front.png into the editor.", true)

func _apply_starter_with_history() -> void:
	_push_undo()
	edit_image = _make_dome_starter()
	dirty = true
	_refresh_all()
	_set_notice("Applied a clean Dome-style front-wall starting point.", true)

func _clear_with_history() -> void:
	_push_undo()
	edit_image = Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	edit_image.fill(Color.TRANSPARENT)
	dirty = true
	_refresh_all()
	_set_notice("Canvas cleared. Undo remains available.", true)

func _on_stroke_started(cell: Vector2i, mouse_button: int) -> void:
	last_stroke_cell = cell
	stroke_changed = false
	if current_tool == 3 and mouse_button == MOUSE_BUTTON_LEFT:
		_pick_color(cell)
		return
	_push_undo()
	stroke_active = true
	if current_tool == 2 and mouse_button == MOUSE_BUTTON_LEFT:
		_flood_fill(cell, palette[selected_color_key])
		stroke_changed = true
		_refresh_all()
		return
	_apply_brush(cell, mouse_button)
	_refresh_all()

func _on_stroke_moved(cell: Vector2i, mouse_button: int) -> void:
	if not stroke_active or current_tool == 2 or current_tool == 3:
		return
	_paint_line(last_stroke_cell, cell, mouse_button)
	last_stroke_cell = cell
	_refresh_all()

func _on_stroke_finished() -> void:
	if stroke_active and stroke_changed:
		dirty = true
	stroke_active = false
	last_stroke_cell = Vector2i(-1, -1)
	_update_status()

func _on_hover_changed(cell: Vector2i) -> void:
	if hover_label == null:
		return
	if cell.x < 0:
		hover_label.text = "Right-drag erases  •  Ctrl+Z / Ctrl+Y also work"
		return
	var key := _nearest_palette_key(edit_image.get_pixelv(cell))
	hover_label.text = "pixel %s  •  %s" % [str(cell), key.replace("_", " ")]

func _apply_brush(cell: Vector2i, mouse_button: int) -> void:
	var erase := mouse_button == MOUSE_BUTTON_RIGHT or current_tool == 1
	var color: Color = palette["transparent"] if erase else palette[selected_color_key]
	var start_offset := -int(floor(float(brush_size - 1) * 0.5))
	for oy in range(brush_size):
		for ox in range(brush_size):
			var p := cell + Vector2i(start_offset + ox, start_offset + oy)
			if not _pixel_in_bounds(p):
				continue
			if not edit_image.get_pixelv(p).is_equal_approx(color):
				edit_image.set_pixelv(p, color)
				stroke_changed = true

func _paint_line(from: Vector2i, to: Vector2i, mouse_button: int) -> void:
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	if steps <= 0:
		_apply_brush(to, mouse_button)
		return
	for index in range(steps + 1):
		var weight := float(index) / float(steps)
		var p := Vector2i(roundi(lerpf(float(from.x), float(to.x), weight)), roundi(lerpf(float(from.y), float(to.y), weight)))
		_apply_brush(p, mouse_button)

func _flood_fill(start: Vector2i, replacement: Color) -> void:
	if not _pixel_in_bounds(start):
		return
	var target := edit_image.get_pixelv(start)
	if target.is_equal_approx(replacement):
		return
	var open: Array[Vector2i] = [start]
	var visited: Dictionary = {}
	while not open.is_empty():
		var p: Vector2i = open.pop_back()
		if visited.has(p) or not _pixel_in_bounds(p):
			continue
		visited[p] = true
		if not edit_image.get_pixelv(p).is_equal_approx(target):
			continue
		edit_image.set_pixelv(p, replacement)
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			open.append(p + direction)

func _pick_color(cell: Vector2i) -> void:
	if not _pixel_in_bounds(cell):
		return
	_select_palette_key(_nearest_palette_key(edit_image.get_pixelv(cell)))
	_set_notice("Picked %s." % selected_color_key.replace("_", " "), true)

func _select_palette_key(key: String) -> void:
	selected_color_key = key
	if key == "transparent":
		current_tool = 1
		tool_selector.select(1)
	elif current_tool == 1:
		current_tool = 0
		tool_selector.select(0)
	_refresh_palette_state()
	_update_status()

func _push_undo() -> void:
	undo_stack.append(edit_image.duplicate())
	if undo_stack.size() > MAX_UNDO:
		undo_stack.pop_front()
	redo_stack.clear()
	_update_history_buttons()

func _undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(edit_image.duplicate())
	edit_image = undo_stack.pop_back()
	dirty = true
	_refresh_all()
	_set_notice("Undo", true)

func _redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(edit_image.duplicate())
	edit_image = redo_stack.pop_back()
	dirty = true
	_refresh_all()
	_set_notice("Redo", true)

func _refresh_all() -> void:
	if pixel_canvas != null:
		pixel_canvas.call("set_preview_image", edit_image)
	if live_preview != null:
		live_preview.call("set_front_image", edit_image)
	if native_preview != null:
		var export_image := edit_image.duplicate()
		export_image.resize(EXPORT_SIZE, EXPORT_SIZE, Image.INTERPOLATE_NEAREST)
		native_preview.texture = ImageTexture.create_from_image(export_image)
	_refresh_palette_state()
	_update_history_buttons()
	_update_status()

func _refresh_palette_state() -> void:
	if selected_color_label != null:
		selected_color_label.text = "Selected: %s" % selected_color_key.replace("_", " ")
	for key_value in palette_buttons.keys():
		var key := String(key_value)
		var button: Button = palette_buttons[key]
		button.modulate = Color.WHITE if key == selected_color_key else Color(0.72, 0.72, 0.78, 1.0)

func _update_history_buttons() -> void:
	if undo_button != null:
		undo_button.disabled = undo_stack.is_empty()
	if redo_button != null:
		redo_button.disabled = redo_stack.is_empty()

func _update_status() -> void:
	if status_label == null or edit_image == null:
		return
	var opaque := 0
	var lower_opaque := 0
	for y in range(LOGICAL_SIZE):
		for x in range(LOGICAL_SIZE):
			if edit_image.get_pixel(x, y).a > 0.01:
				opaque += 1
				if y >= 17:
					lower_opaque += 1
	var dirty_text := "UNSAVED" if dirty else "saved"
	var warning := "  •  WARNING: %d opaque pixels below guide" % lower_opaque if lower_opaque > 0 else "  •  lower half transparent ✓"
	status_label.text = "%s  •  tool %s  •  brush %d  •  %d painted pixels%s" % [dirty_text, tool_selector.get_item_text(current_tool) if tool_selector != null else "", brush_size, opaque, warning]

func _set_notice(text: String, success: bool) -> void:
	if notice_label == null:
		return
	notice_label.text = text
	notice_label.add_theme_color_override("font_color", Color.html("78d98bff") if success else Color.html("ef7373ff"))

func _nearest_palette_key(color: Color) -> String:
	if color.a < 0.05:
		return "transparent"
	var best_key := "easy_mid"
	var best_distance := INF
	for key in PALETTE_ORDER:
		if key == "transparent":
			continue
		var candidate: Color = palette[key]
		var distance := pow(color.r - candidate.r, 2) + pow(color.g - candidate.g, 2) + pow(color.b - candidate.b, 2) + pow(color.a - candidate.a, 2)
		if distance < best_distance:
			best_distance = distance
			best_key = key
	return best_key

func _pixel_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < LOGICAL_SIZE and cell.y < LOGICAL_SIZE

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.ctrl_pressed and key_event.keycode == KEY_Z:
		_undo()
		get_viewport().set_input_as_handled()
	elif key_event.ctrl_pressed and (key_event.keycode == KEY_Y or (key_event.shift_pressed and key_event.keycode == KEY_Z)):
		_redo()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_B:
		current_tool = 0
		tool_selector.select(0)
	elif key_event.keycode == KEY_E:
		current_tool = 1
		tool_selector.select(1)
	elif key_event.keycode == KEY_G:
		current_tool = 2
		tool_selector.select(2)
	elif key_event.keycode == KEY_I:
		current_tool = 3
		tool_selector.select(3)
	_update_status()
