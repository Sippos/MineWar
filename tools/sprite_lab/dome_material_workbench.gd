extends Control

const CANVAS_SCRIPT := preload("res://tools/sprite_lab/dome_material_canvas.gd")
const PREVIEW_SCRIPT := preload("res://tools/sprite_lab/dome_material_preview_v2.gd")
const CORNER_BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")

const LOGICAL_SIZE := 32
const EDGE_JOINT_SIZE := 14
const HOLE_CORNER_SIZE := LOGICAL_SIZE
const HOLE_CORNER_ART_ORIGIN := Vector2i(9, 9)
const HOLE_CORNER_LEGACY_SIZE := 14
const TILE_SIZE := 64
const ATLAS_SIZE := 256
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const RUNTIME_DIR := "res://assets/sprites/world/terrain/dome"

const FALLBACK_MASS_PATH := "res://assets/sprites/world/terrain/bricks/Easy_Brick_Rework.svg"
const FALLBACK_UNMINEABLE_PATH := "res://assets/sprites/world/terrain/bricks/Bedrock_Border.svg"
const FALLBACK_EDGE_PATHS := {
	"unmineable": "res://assets/sprites/world/terrain/edges/Unmineable_Edge_Atlas_Rework.svg",
	"easy": "res://assets/sprites/world/terrain/edges/Easy_Edge_Atlas_Rework.svg",
	"medium": "res://assets/sprites/world/terrain/edges/Medium_Edge_Atlas_Rework.svg",
	"hard": "res://assets/sprites/world/terrain/edges/Hard_Edge_Atlas_Rework.svg",
	"gems": "res://assets/sprites/world/terrain/gem_embedded_edge.svg",
	"cracks": "",
}
const RUNTIME_MASS_PATH := RUNTIME_DIR + "/Dome_Dark_Mass.png"
const RUNTIME_BORDER_PATHS := {
	"unmineable": RUNTIME_DIR + "/Unmineable_Border_Atlas.png",
	"easy": RUNTIME_DIR + "/Easy_Border_Atlas.png",
	"medium": RUNTIME_DIR + "/Medium_Border_Atlas.png",
	"hard": RUNTIME_DIR + "/Hard_Border_Atlas.png",
	"gems": RUNTIME_DIR + "/Gems_Border_Atlas.png",
	"cracks": RUNTIME_DIR + "/Cracks_Border_Atlas.png",
}
const RUNTIME_INSIDE_CORNER_PATHS := {
	"unmineable": RUNTIME_DIR + "/Unmineable_Inside_Corners.png",
	"easy": RUNTIME_DIR + "/Easy_Inside_Corners.png",
	"medium": RUNTIME_DIR + "/Medium_Inside_Corners.png",
	"hard": RUNTIME_DIR + "/Hard_Inside_Corners.png",
	"gems": RUNTIME_DIR + "/Gems_Inside_Corners.png",
	"cracks": RUNTIME_DIR + "/Cracks_Inside_Corners.png",
}
const FRONT_SOURCE_PATHS := {
	"unmineable": "res://assets/sprites/world/terrain/front_walls/Unmineable_Brick-Front-Rework.svg",
	"easy": "res://assets/sprites/world/terrain/front_walls/Easy_Brick-Front.png",
	"medium": "res://assets/sprites/world/terrain/front_walls/Medium-Brick-Front.png",
	"hard": "res://assets/sprites/world/terrain/front_walls/Hard-Brick-Front.png",
	"gems": "res://assets/sprites/world/terrain/gem_embedded_front.svg",
	"cracks": "",
}
const RUNTIME_FRONT_PATHS := {
	"unmineable": RUNTIME_DIR + "/Unmineable_Front_Face.png",
	"easy": RUNTIME_DIR + "/Easy_Front_Face.png",
	"medium": RUNTIME_DIR + "/Medium_Front_Face.png",
	"hard": RUNTIME_DIR + "/Hard_Front_Face.png",
	"gems": RUNTIME_DIR + "/Gems_Front_Face.png",
	"cracks": RUNTIME_DIR + "/Cracks_Front_Face.png",
}
const TIERS: Array[String] = ["unmineable", "easy", "medium", "hard", "gems", "cracks"]

var mass_image: Image
var border_images: Dictionary = {}
var corner_images: Dictionary = {}
var convex_images: Dictionary = {}
var front_images: Dictionary = {}
var current_mode := "border"
var current_tier := "easy"
var tool_mode := 0
var brush_size := 1
var stroke_active := false
var last_cell := Vector2i(-1, -1)
var undo_stack: Array[Image] = []
var redo_stack: Array[Image] = []

var canvas: Control
var preview: Control
var title_label: Label
var instruction_label: Label
var status_label: Label
var tier_selector: OptionButton
var color_picker: ColorPickerButton
var tool_selector: OptionButton
var brush_selector: OptionButton
var undo_button: Button
var redo_button: Button
var mode_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_images()
	_build_ui()
	_refresh_workspace()
	# Open large so there's room to paint. F11 toggles true fullscreen.
	var window := get_window()
	if window != null:
		window.mode = Window.MODE_MAXIMIZED

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var window := get_window()
		if window != null:
			window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color.html("0c1018ff")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 14)
	outer_margin.add_theme_constant_override("margin_right", 14)
	outer_margin.add_theme_constant_override("margin_top", 10)
	outer_margin.add_theme_constant_override("margin_bottom", 10)
	add_child(outer_margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	outer_margin.add_child(outer)

	var heading := Label.new()
	heading.text = "MINEWARS • DOME BORDER WORKBENCH"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color.html("8eeeffff"))
	outer.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "NORMAL TILING: dark mass + border + exposed Edge Joint + opposite Hole Corner"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color.html("aebbc6ff"))
	outer.add_child(subtitle)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	outer.add_child(body)
	_build_left_panel(body)
	_build_center_panel(body)
	_build_preview_panel(body)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color.html("9eb1bdff"))
	outer.add_child(status_label)

func _build_left_panel(body: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(255, 0)
	body.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	scroll.add_child(margin)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 7)
	margin.add_child(controls)

	_add_section(controls, "1 • CHOOSE WHAT TO EDIT")
	_add_mode_button(controls, "mass", "DARK MASS • universal fill")
	_add_mode_button(controls, "border", "BORDER • one top stamp")
	_add_mode_button(controls, "convex", "EDGE JOINT • exposed block turn")
	_add_mode_button(controls, "corner", "HOLE CORNER • editable opposite turn")
	_add_mode_button(controls, "front", "FRONT FACE • downward wall")

	_add_section(controls, "2 • MATERIAL TYPE")
	tier_selector = OptionButton.new()
	for label in ["UNMINEABLE", "EASY", "MEDIUM", "HARD", "GEMS", "CRACKS"]:
		tier_selector.add_item(label)
	tier_selector.select(1)
	tier_selector.item_selected.connect(_on_tier_selected)
	controls.add_child(tier_selector)
	var tier_note := Label.new()
	tier_note.text = "Each material has a BORDER, EDGE JOINT, HOLE CORNER and a FRONT SURFACE texture. The front surface is clipped into the exact rounded cave silhouette instead of being drawn as a square tile."
	tier_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tier_note.add_theme_font_size_override("font_size", 10)
	tier_note.add_theme_color_override("font_color", Color.html("8fa2afff"))
	controls.add_child(tier_note)
	var rebuild_corners_button := Button.new()
	rebuild_corners_button.text = "REBUILD JOINT + HOLE FROM BORDER"
	rebuild_corners_button.tooltip_text = "Regenerate this material's Edge Joint and Hole Corner from its current Border. Your current hand-painted corners are snapshotted to backups/ first, so this can always be undone."
	rebuild_corners_button.pressed.connect(_rebuild_current_corners_from_border)
	controls.add_child(rebuild_corners_button)

	_add_section(controls, "3 • PAINT")
	tool_selector = OptionButton.new()
	for tool_name in ["Pencil", "Eraser", "Eyedropper"]:
		tool_selector.add_item(tool_name)
	tool_selector.item_selected.connect(func(index: int) -> void: tool_mode = index)
	controls.add_child(tool_selector)
	brush_selector = OptionButton.new()
	for size_name in ["1 pixel", "2 pixels", "3 pixels"]:
		brush_selector.add_item(size_name)
	brush_selector.item_selected.connect(func(index: int) -> void: brush_size = index + 1)
	controls.add_child(brush_selector)
	color_picker = ColorPickerButton.new()
	color_picker.text = "Paint color"
	color_picker.color = Color.html("887eacff")
	controls.add_child(color_picker)
	var grid_toggle := CheckBox.new()
	grid_toggle.text = "Pixel grid"
	grid_toggle.button_pressed = true
	grid_toggle.toggled.connect(func(value: bool) -> void: canvas.call("set_grid_visible", value))
	controls.add_child(grid_toggle)

	var history := HBoxContainer.new()
	undo_button = Button.new()
	undo_button.text = "Undo"
	undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_button.pressed.connect(_undo)
	history.add_child(undo_button)
	redo_button = Button.new()
	redo_button.text = "Redo"
	redo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	redo_button.pressed.connect(_redo)
	history.add_child(redo_button)
	controls.add_child(history)

	_add_section(controls, "4 • LIVE PREVIEW")
	var rounded_toggle := CheckBox.new()
	rounded_toggle.text = "Use edge joints"
	rounded_toggle.button_pressed = true
	rounded_toggle.toggled.connect(func(value: bool) -> void: preview.call("set_rounded_light_corners", value))
	controls.add_child(rounded_toggle)
	var preview_brush := OptionButton.new()
	for brush_name in ["DIG / EMPTY", "PAINT EASY", "PAINT MEDIUM", "PAINT HARD", "PAINT UNMINEABLE", "PAINT GEMS", "PAINT CRACKS"]:
		preview_brush.add_item(brush_name)
	preview_brush.item_selected.connect(func(index: int) -> void: preview.call("set_preview_brush", index))
	controls.add_child(preview_brush)
	var front_toggle := CheckBox.new()
	front_toggle.text = "Generated shallow front extrusion"
	front_toggle.button_pressed = true
	front_toggle.toggled.connect(func(value: bool) -> void: preview.call("set_front_faces_visible", value))
	controls.add_child(front_toggle)
	var depth_row := HBoxContainer.new()
	var depth_label := Label.new()
	depth_label.text = "Front depth"
	depth_label.custom_minimum_size = Vector2(80, 0)
	depth_row.add_child(depth_label)
	var depth_slider := HSlider.new()
	depth_slider.min_value = 2
	depth_slider.max_value = 32
	depth_slider.step = 1
	depth_slider.value = 10
	depth_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	depth_row.add_child(depth_slider)
	var depth_value := Label.new()
	depth_value.text = "10 px"
	depth_value.custom_minimum_size = Vector2(38, 0)
	depth_row.add_child(depth_value)
	depth_slider.value_changed.connect(func(value: float) -> void:
		preview.call("set_front_depth", roundi(value))
		depth_value.text = "%d px" % roundi(value)
	)
	controls.add_child(depth_row)
	var reset_button := Button.new()
	reset_button.text = "Reset cave layout"
	reset_button.pressed.connect(func() -> void: preview.call("reset_layout"))
	controls.add_child(reset_button)

	_add_section(controls, "5 • SAVE / EXPORT")
	var reload_button := Button.new()
	reload_button.text = "Reload current art"
	reload_button.pressed.connect(_reload_images)
	controls.add_child(reload_button)
	var save_button := Button.new()
	save_button.text = "Save editable sources"
	save_button.pressed.connect(_save_sources)
	controls.add_child(save_button)
	var export_all_button := Button.new()
	export_all_button.text = "EXPORT ALL RUNTIME"
	export_all_button.custom_minimum_size = Vector2(0, 32)
	export_all_button.pressed.connect(_export_runtime_assets)
	controls.add_child(export_all_button)
	var lock_safestate_button := Button.new()
	lock_safestate_button.text = "🔒 LOCK SAFESTATE"
	lock_safestate_button.tooltip_text = "Snapshot the current source + runtime art to safestates/ so this exact good state can be restored later with one copy."
	lock_safestate_button.pressed.connect(_lock_safestate)
	controls.add_child(lock_safestate_button)

	var export_grid := GridContainer.new()
	export_grid.columns = 2
	controls.add_child(export_grid)

	var export_mass_button := Button.new()
	export_mass_button.text = "Export Mass"
	export_mass_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_mass_button.pressed.connect(_export_mass)
	export_grid.add_child(export_mass_button)

	var export_borders_button := Button.new()
	export_borders_button.text = "Export Borders"
	export_borders_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_borders_button.pressed.connect(_export_borders)
	export_grid.add_child(export_borders_button)

	var export_corners_button := Button.new()
	export_corners_button.text = "Export Corners"
	export_corners_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_corners_button.pressed.connect(_export_corners)
	export_grid.add_child(export_corners_button)

	var export_fronts_button := Button.new()
	export_fronts_button.text = "Export Fronts"
	export_fronts_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_fronts_button.pressed.connect(_export_fronts)
	export_grid.add_child(export_fronts_button)

func _build_center_panel(body: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color.html("d8cbffff"))
	column.add_child(title_label)
	instruction_label = Label.new()
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.add_theme_font_size_override("font_size", 10)
	instruction_label.add_theme_color_override("font_color", Color.html("a7eaf5ff"))
	column.add_child(instruction_label)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(center)
	canvas = CANVAS_SCRIPT.new() as Control
	canvas.stroke_started.connect(_stroke_started)
	canvas.stroke_moved.connect(_stroke_moved)
	canvas.stroke_finished.connect(_stroke_finished)
	canvas.hover_changed.connect(_hover_changed)
	center.add_child(canvas)

func _build_preview_panel(body: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(425, 0)
	body.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	_add_section(column, "INTERACTIVE LIVE CAVE")
	var explanation := Label.new()
	explanation.text = "Choose DIG or a material brush, then LEFT-DRAG in the cave. RIGHT-DRAG erases. The shallow front wall is generated from the exact rounded silhouette, so curves and mixed materials remain aligned."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 10)
	explanation.add_theme_color_override("font_color", Color.html("a7eaf5ff"))
	column.add_child(explanation)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(center)
	preview = PREVIEW_SCRIPT.new() as Control
	center.add_child(preview)

func _add_section(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.html("8eeeffff"))
	parent.add_child(label)

func _add_mode_button(parent: VBoxContainer, mode: String, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 38)
	button.pressed.connect(func() -> void: _select_mode(mode))
	parent.add_child(button)
	mode_buttons[mode] = button

func _load_images() -> void:
	mass_image = _load_png_or_svg_logical(RUNTIME_MASS_PATH, FALLBACK_MASS_PATH)
	border_images.clear()
	corner_images.clear()
	convex_images.clear()
	front_images.clear()
	for tier in TIERS:
		var fallback_edge := String(FALLBACK_EDGE_PATHS.get(tier, FALLBACK_EDGE_PATHS["easy"]))
		border_images[tier] = _load_editable_border_stamp(tier, fallback_edge)
		convex_images[tier] = _load_convex_stamp(tier, border_images[tier])
		corner_images[tier] = _load_hole_corner_stamp(tier, convex_images[tier])
		front_images[tier] = _load_front_face_stamp(tier)

func _load_front_face_stamp(tier: String) -> Image:
	var editable_path := SOURCE_DIR + "/%s_front_face_32.png" % tier
	var runtime_path := String(RUNTIME_FRONT_PATHS[tier])
	var path := editable_path
	if not FileAccess.file_exists(path):
		path = runtime_path if FileAccess.file_exists(runtime_path) else String(FRONT_SOURCE_PATHS[tier])
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		image = Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
	else:
		image.convert(Image.FORMAT_RGBA8)
		image.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return image

func _load_editable_border_stamp(tier: String, fallback_path: String) -> Image:
	var editable_path := SOURCE_DIR + "/%s_border_top_32.png" % tier
	if FileAccess.file_exists(editable_path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(editable_path))
		if image != null and not image.is_empty():
			image.convert(Image.FORMAT_RGBA8)
			image.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
			for y in range(11, LOGICAL_SIZE):
				for x in range(LOGICAL_SIZE):
					image.set_pixel(x, y, Color.TRANSPARENT)
			return image
	return _load_top_stamp(String(RUNTIME_BORDER_PATHS.get(tier, "")), fallback_path)

func _load_hole_corner_stamp(tier: String, edge_joint: Image) -> Image:
	var editable_path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
	var joint: Image
	if FileAccess.file_exists(editable_path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(editable_path))
		if img != null and not img.is_empty():
			joint = img
	if joint == null or joint.is_empty():
		# All tiers use the same corner generation pipeline. If the border
		# stamp is empty/transparent, the builder naturally produces an empty
		# corner — no special-casing needed for overlay tiers.
		joint = CORNER_BUILDER.make_hole_corner_top_left(mass_image, border_images[tier], edge_joint)
	var corner: Image = joint
	corner.convert(Image.FORMAT_RGBA8)
	corner.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return corner

func _load_top_stamp(runtime_path: String, fallback_path: String) -> Image:
	var source := _load_png_or_svg_full(runtime_path, fallback_path)
	var source_rect := Rect2i(Vector2i(TILE_SIZE, 0), Vector2i(TILE_SIZE, TILE_SIZE)) if source.get_width() >= ATLAS_SIZE else Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE))
	var stamp := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	stamp.fill(Color.TRANSPARENT)
	stamp.blit_rect(source, source_rect, Vector2i.ZERO)
	stamp.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	# Only the authored top band is valid. This also converts old full bedrock art
	# into a straight unmineable border stamp.
	for y in range(11, LOGICAL_SIZE):
		for x in range(LOGICAL_SIZE):
			stamp.set_pixel(x, y, Color.TRANSPARENT)
	return stamp

func _load_corner_stamp(tier: String, runtime_path: String, fallback_border: Image) -> Image:
	# Hole Corner is authored only inside the canonical top-left 14x14 patch.
	# Clearing everything outside that patch prevents floating fragments in preview/runtime.
	var editable_path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
	var source: Image
	if FileAccess.file_exists(editable_path):
		source = Image.load_from_file(ProjectSettings.globalize_path(editable_path))
	else:
		var joint := _load_convex_stamp(tier, fallback_border)
		source = _make_hole_corner_from_joint(joint)
	source.convert(Image.FORMAT_RGBA8)
	source.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	var clean := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	clean.fill(Color.TRANSPARENT)
	for y in range(14):
		for x in range(14):
			clean.set_pixel(x, y, source.get_pixel(x, y))
	return clean

func _make_hole_corner_from_joint(joint: Image) -> Image:
	var result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(14):
		for x in range(14):
			result.set_pixel(13 - x, 13 - y, joint.get_pixel(x, y))
	return result

func _load_convex_stamp(tier: String, fallback_border: Image) -> Image:
	# Internal name kept for scene compatibility; this is the authored EDGE JOINT.
	var editable_path := SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % tier
	var joint: Image
	if FileAccess.file_exists(editable_path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(editable_path))
		if img != null and not img.is_empty():
			joint = img
	if joint == null or joint.is_empty():
		# All tiers use the same edge joint pipeline. If the border is
		# empty/transparent, the builder produces an empty joint.
		joint = CORNER_BUILDER.make_edge_joint_top_left(mass_image, fallback_border)
	joint.convert(Image.FORMAT_RGBA8)
	joint.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return joint

func _make_cave_base() -> Image:
	# The Hole Corner stamp replaces an EMPTY cell, so transparent pixels reveal
	# cave space. All authored border endpoints and the rounded join are painted
	# directly on this complete 32x32 canvas.
	var image := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.html("111725ff"))
	
	# Show faint top/left straight borders as an alignment guide.
	# The straight borders are drawn positioned exactly where they meet the Hole Corner.
	var tier := _visual_tier()
	if border_images.has(tier):
		var top := CORNER_BUILDER.rotate_quarters(border_images[tier] as Image, 2)
		var left := CORNER_BUILDER.rotate_quarters(border_images[tier] as Image, 1)
		for guide: Image in [top, left]:
			guide.convert(Image.FORMAT_RGBA8)
			for y in range(LOGICAL_SIZE):
				for x in range(LOGICAL_SIZE):
					var color := guide.get_pixel(x, y)
					color.a *= 0.24
					guide.set_pixel(x, y, color)
		
		# For HOLE_VERTEX_OFFSET = 16, the rim is at 15.
		# The rotated tiles have their rims at 31.
		# Drawing them at offset -16 places the rim exactly at 15.
		image.blend_rect(top, Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE)), Vector2i(0, -16))
		image.blend_rect(left, Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE)), Vector2i(-16, 0))

	return image

func _make_convex_base(tier: String) -> Image:
	# Show only a faint top/left alignment guide beneath the authored joint.
	# The old full-tile reference exposed mass decorations from other tiles and
	# looked like Easy/Medium/Unmineable artwork was leaking into each other.
	var reference := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	reference.fill(Color.TRANSPARENT)
	var top := (border_images[tier] as Image).duplicate()
	var left := CORNER_BUILDER.rotate_quarters(top, 3)
	for guide: Image in [top, left]:
		guide.convert(Image.FORMAT_RGBA8)
		for y in range(LOGICAL_SIZE):
			for x in range(LOGICAL_SIZE):
				var color := guide.get_pixel(x, y)
				color.a *= 0.24
				guide.set_pixel(x, y, color)
		reference.blend_rect(guide, Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE)), Vector2i.ZERO)
	for y in range(EDGE_JOINT_SIZE):
		for x in range(EDGE_JOINT_SIZE):
			# Transparent pixels in this core are real silhouette cutouts.
			reference.set_pixel(x, y, Color(0.067, 0.09, 0.145, 0.48))
	return reference

func _load_png_or_svg_logical(png_path: String, svg_path: String) -> Image:
	var image := _load_png_or_svg_full(png_path, svg_path)
	image.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return image

func _load_png_or_svg_full(png_path: String, svg_path: String) -> Image:
	if FileAccess.file_exists(png_path):
		var png_image := Image.load_from_file(ProjectSettings.globalize_path(png_path))
		if png_image != null and not png_image.is_empty():
			png_image.convert(Image.FORMAT_RGBA8)
			return png_image
	var svg_image := Image.new()
	var svg_text := FileAccess.get_file_as_string(svg_path)
	var load_error: Error = svg_image.load_svg_from_string(svg_text, 1.0) if not svg_text.is_empty() else ERR_FILE_NOT_FOUND
	if load_error != OK or svg_image.is_empty():
		svg_image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		svg_image.fill(Color.TRANSPARENT)
	svg_image.convert(Image.FORMAT_RGBA8)
	return svg_image

func _select_mode(mode: String) -> void:
	current_mode = mode
	undo_stack.clear()
	redo_stack.clear()
	_refresh_workspace()

func _on_tier_selected(index: int) -> void:
	current_tier = TIERS[clampi(index, 0, TIERS.size() - 1)]
	undo_stack.clear()
	redo_stack.clear()
	_refresh_workspace()

func _rebuild_current_corners_from_border() -> void:
	var tier := _visual_tier()
	if not border_images.has(tier):
		status_label.text = "No border source exists for %s." % tier.to_upper()
		return
	# Snapshot the current hand-painted corners BEFORE regenerating, so the
	# destructive rebuild is always recoverable from backups/.
	_backup_current_images("pre_rebuild")
	var border := (border_images[tier] as Image).duplicate()
	var rebuilt_joint := CORNER_BUILDER.make_edge_joint_top_left(mass_image, border)
	var rebuilt_hole := CORNER_BUILDER.make_hole_corner_top_left(mass_image, border, rebuilt_joint)
	convex_images[tier] = rebuilt_joint
	corner_images[tier] = rebuilt_hole
	undo_stack.clear()
	redo_stack.clear()
	_refresh_workspace()
	status_label.text = "Rebuilt %s corners (previous art backed up to backups/auto_pre_rebuild_*). Save/export when approved." % tier.to_upper()

func _visual_tier() -> String:
	# Every material, including Unmineable, owns independent authored artwork.
	return current_tier

func _active_image() -> Image:
	if current_mode == "mass":
		return mass_image
	var tier := _visual_tier()
	if current_mode == "corner":
		return corner_images[tier]
	if current_mode == "front":
		return front_images[tier]
	if current_mode == "convex":
		return convex_images[tier]
	return border_images[tier]

func _active_region() -> Rect2i:
	if current_mode == "mass":
		return Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))
	if current_mode == "corner":
		return Rect2i(Vector2i.ZERO, Vector2i(HOLE_CORNER_SIZE, HOLE_CORNER_SIZE))
	if current_mode == "convex":
		# The 14x14 corner remains the destructive silhouette/cutout core, but the
		# whole tile is paintable overscan for highlights, chips and long curves.
		return Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))
	if current_mode == "front":
		return Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))
	return Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, 11))

func _workspace_title() -> String:
	if current_mode == "mass":
		return "UNIVERSAL DARK MASS"
	if current_mode == "convex":
		return "%s EDGE JOINT • FULL 32x32 OVERSCAN" % current_tier.to_upper()
	if current_mode == "corner":
		return "%s HOLE CORNER • FULL 32x32 OVERSCAN" % current_tier.to_upper()
	if current_mode == "front":
		return "%s FRONT FACE • AUTHOR DOWNWARD WALL" % current_tier.to_upper()
	return "%s BORDER • AUTHOR TOP ONLY" % current_tier.to_upper()
func _refresh_workspace() -> void:
	var visual_tier := _visual_tier()
	var base: Image = null
	if current_mode == "border":
		base = mass_image.duplicate()
	elif current_mode == "corner":
		base = _make_cave_base()
	elif current_mode == "convex":
		base = _make_convex_base(visual_tier)
	elif current_mode == "front":
		base = mass_image.duplicate()
	canvas.call("set_read_only", false)
	canvas.call("set_workspace_images", _active_image(), base, _active_region(), _workspace_title())
	preview.call("set_material_library", mass_image, border_images, corner_images, convex_images, front_images)
	preview.call("set_primary_preview_tier", visual_tier)
	title_label.text = _workspace_title()
	if current_mode == "mass":
		instruction_label.text = "Paint the one dark full tile used under every rock type."
	elif current_mode == "convex":
		instruction_label.text = "Paint the EDGE JOINT on the full 32x32 overscan tile. The top-left 14x14 area is the silhouette-cutout core; the faint tile beneath is reference only, so erased pixels remain clearly visible."
	elif current_mode == "corner":
		instruction_label.text = "Paint the independent HOLE CORNER on the full 32x32 overscan stamp. The old curve is centered automatically, leaving room on the left, top, right and bottom for outer-corner continuation."
	elif current_mode == "front":
		instruction_label.text = "Paint a seamless FRONT SURFACE texture for this material. The generator clips and shades it inside the shallow extrusion derived from the exact rounded cave silhouette."
	else:
		instruction_label.text = "Paint only the CYAN TOP BAND. The game rotates it for all four straight edges."
	for mode_value: Variant in mode_buttons.keys():
		var mode := String(mode_value)
		var button: Button = mode_buttons[mode]
		button.modulate = Color.WHITE if mode == current_mode else Color(0.68, 0.68, 0.74, 1.0)
	tier_selector.disabled = current_mode == "mass"
	undo_button.disabled = undo_stack.is_empty()
	redo_button.disabled = redo_stack.is_empty()
	status_label.text = "%s  •  cave preview updates immediately" % _workspace_title()
func _stroke_started(cell: Vector2i, mouse_button: int) -> void:
	if not _active_region().has_point(cell):
		status_label.text = "Locked area. Paint only inside the cyan authored region for this workspace."
		return
	if tool_mode == 2 and mouse_button == MOUSE_BUTTON_LEFT:
		color_picker.color = _active_image().get_pixelv(cell)
		return
	undo_stack.append(_active_image().duplicate())
	if undo_stack.size() > 40:
		undo_stack.pop_front()
	redo_stack.clear()
	stroke_active = true
	last_cell = cell
	_apply_brush(cell, mouse_button)
	_refresh_workspace()

func _stroke_moved(cell: Vector2i, mouse_button: int) -> void:
	if not stroke_active or tool_mode == 2:
		return
	var steps := maxi(absi(cell.x - last_cell.x), absi(cell.y - last_cell.y))
	for index in range(steps + 1):
		var amount := 0.0 if steps == 0 else float(index) / float(steps)
		var point := Vector2i(roundi(lerpf(float(last_cell.x), float(cell.x), amount)), roundi(lerpf(float(last_cell.y), float(cell.y), amount)))
		_apply_brush(point, mouse_button)
	last_cell = cell
	_refresh_workspace()

func _stroke_finished() -> void:
	stroke_active = false
	last_cell = Vector2i(-1, -1)
	_refresh_workspace()

func _apply_brush(cell: Vector2i, mouse_button: int) -> void:
	var erase := mouse_button == MOUSE_BUTTON_RIGHT or tool_mode == 1
	var color := Color.TRANSPARENT if erase else color_picker.color
	var start_offset := -int(floor(float(brush_size - 1) * 0.5))
	var image := _active_image()
	var region := _active_region()
	for oy in range(brush_size):
		for ox in range(brush_size):
			var point := cell + Vector2i(start_offset + ox, start_offset + oy)
			if region.has_point(point):
				image.set_pixelv(point, color)

func _hover_changed(cell: Vector2i) -> void:
	if cell.x >= 0:
		status_label.text = "%s  •  pixel %s%s" % [_workspace_title(), str(cell), " • paintable" if _active_region().has_point(cell) else " • locked"]

func _undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(_active_image().duplicate())
	_set_active_image(undo_stack.pop_back())
	_refresh_workspace()

func _redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(_active_image().duplicate())
	_set_active_image(redo_stack.pop_back())
	_refresh_workspace()

func _set_active_image(image: Image) -> void:
	if current_mode == "mass":
		mass_image = image
		return
	var tier := _visual_tier()
	if current_mode == "corner":
		corner_images[tier] = image
	elif current_mode == "convex":
		convex_images[tier] = image
	elif current_mode == "front":
		front_images[tier] = image
	else:
		border_images[tier] = image

func _reload_images() -> void:
	_load_images()
	undo_stack.clear()
	redo_stack.clear()
	_refresh_workspace()
	status_label.text = "Reloaded current runtime art."

func _ensure_output_dirs() -> Error:
	var source_result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOURCE_DIR))
	if source_result != OK and source_result != ERR_ALREADY_EXISTS:
		return source_result
	var runtime_result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RUNTIME_DIR))
	if runtime_result != OK and runtime_result != ERR_ALREADY_EXISTS:
		return runtime_result
	return OK

## ── Safety net ──────────────────────────────────────────────────────────
## Every save/export/rebuild snapshots first, so a good state can never be
## silently overwritten. Backups land in SOURCE_DIR/backups/auto_<tag>_<ts>.
func _safe_stamp() -> String:
	return Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")

## Copy the CURRENT ON-DISK source PNGs aside before they get overwritten.
func _backup_source_dir(tag: String) -> void:
	var dir := DirAccess.open(SOURCE_DIR)
	if dir == null:
		return
	var dest := SOURCE_DIR + "/backups/auto_%s_%s" % [tag, _safe_stamp()]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest)) not in [OK, ERR_ALREADY_EXISTS]:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if dir.current_is_dir() or not name.ends_with(".png"):
			continue
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(SOURCE_DIR + "/" + name),
			ProjectSettings.globalize_path(dest + "/" + name))
	dir.list_dir_end()

## Snapshot the LIVE IN-MEMORY art (what you currently see) to PNGs. Used
## before the rebuild button touches your hand-painted corners.
func _backup_current_images(tag: String) -> void:
	var dest := SOURCE_DIR + "/backups/auto_%s_%s" % [tag, _safe_stamp()]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest)) not in [OK, ERR_ALREADY_EXISTS]:
		return
	var base := ProjectSettings.globalize_path(dest)
	if mass_image != null:
		mass_image.save_png(base + "/dark_mass_32.png")
	for tier in TIERS:
		if border_images.has(tier):
			(border_images[tier] as Image).save_png(base + "/%s_border_top_32.png" % tier)
		if convex_images.has(tier):
			(convex_images[tier] as Image).save_png(base + "/%s_edge_joint_top_left_32.png" % tier)
		if corner_images.has(tier):
			(corner_images[tier] as Image).save_png(base + "/%s_hole_corner_top_left_32.png" % tier)
		if front_images.has(tier):
			(front_images[tier] as Image).save_png(base + "/%s_front_face_32.png" % tier)

func _copy_dir_pngs(source_dir: String, dest_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest_dir))
	var dir := DirAccess.open(source_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if dir.current_is_dir() or not name.ends_with(".png"):
			continue
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(source_dir + "/" + name),
			ProjectSettings.globalize_path(dest_dir + "/" + name))
	dir.list_dir_end()

## One-click snapshot of the whole good state (source + runtime) to safestates/.
func _lock_safestate() -> void:
	# Persist the current in-memory art to disk first, then archive it.
	_save_sources()
	_export_runtime_assets()
	var root := "res://tools/sprite_lab/safestates/manual_%s" % _safe_stamp()
	_copy_dir_pngs(SOURCE_DIR, root + "/source")
	_copy_dir_pngs(RUNTIME_DIR, root + "/runtime")
	status_label.text = "🔒 Locked safestate → %s (source + runtime archived)." % root

func _save_sources() -> void:
	var directory_result: Error = _ensure_output_dirs()
	if directory_result != OK:
		status_label.text = "Could not create output folders: %s" % error_string(directory_result)
		return
	# Snapshot the previous on-disk sources before overwriting them.
	_backup_source_dir("pre_save")
	var result: Error = mass_image.save_png(SOURCE_DIR + "/dark_mass_32.png")
	for tier in TIERS:
		if result == OK:
			result = (border_images[tier] as Image).save_png(SOURCE_DIR + "/%s_border_top_32.png" % tier)
		if result == OK:
			result = (convex_images[tier] as Image).save_png(SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % tier)
		if result == OK:
			result = (corner_images[tier] as Image).save_png(SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier)
		if result == OK:
			result = (front_images[tier] as Image).save_png(SOURCE_DIR + "/%s_front_face_32.png" % tier)
	status_label.text = "Saved one mass plus four fully independent material sets: borders, edge joints, hole corners and front surfaces." if result == OK else "Could not save sources: %s" % error_string(result)

func _export_runtime_assets() -> void:
	var directory_result: Error = _ensure_output_dirs()
	if directory_result != OK:
		status_label.text = "Could not create runtime folder: %s" % error_string(directory_result)
		return
	var mass_export := mass_image.duplicate()
	mass_export.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
	var result: Error = mass_export.save_png(RUNTIME_MASS_PATH)
	for tier in TIERS:
		if result != OK:
			break
		var atlas := _build_border_atlas(border_images[tier], convex_images[tier], tier)
		result = atlas.save_png(String(RUNTIME_BORDER_PATHS[tier]))
		if result == OK:
			var corner_atlas := _build_inside_corner_atlas(corner_images[tier], border_images[tier], tier)
			result = corner_atlas.save_png(String(RUNTIME_INSIDE_CORNER_PATHS[tier]))
		if result == OK:
			var front_export := (front_images[tier] as Image).duplicate()
			front_export.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
			result = front_export.save_png(String(RUNTIME_FRONT_PATHS[tier]))
	_save_sources()
	status_label.text = "Exported four fully independent border, Hole Corner and front-surface material sets." if result == OK else "Runtime export failed: %s" % error_string(result)

func _export_mass() -> void:
	var directory_result: Error = _ensure_output_dirs()
	if directory_result != OK:
		status_label.text = "Could not create runtime folder: %s" % error_string(directory_result)
		return
	var mass_export := mass_image.duplicate()
	mass_export.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
	var result: Error = mass_export.save_png(RUNTIME_MASS_PATH)
	status_label.text = "Exported mass only." if result == OK else "Export failed: %s" % error_string(result)

func _export_borders() -> void:
	var directory_result: Error = _ensure_output_dirs()
	if directory_result != OK:
		status_label.text = "Could not create runtime folder: %s" % error_string(directory_result)
		return
	var atlas := _build_border_atlas(border_images[current_tier], convex_images[current_tier], current_tier)
	var result: Error = atlas.save_png(String(RUNTIME_BORDER_PATHS[current_tier]))
	status_label.text = "Exported %s borders only." % current_tier if result == OK else "Export failed: %s" % error_string(result)

func _export_corners() -> void:
	var directory_result: Error = _ensure_output_dirs()
	if directory_result != OK:
		status_label.text = "Could not create runtime folder: %s" % error_string(directory_result)
		return
	var corner_atlas := _build_inside_corner_atlas(corner_images[current_tier], border_images[current_tier], current_tier)
	var result: Error = corner_atlas.save_png(String(RUNTIME_INSIDE_CORNER_PATHS[current_tier]))
	status_label.text = "Exported %s corners only." % current_tier if result == OK else "Export failed: %s" % error_string(result)

func _export_fronts() -> void:
	var directory_result: Error = _ensure_output_dirs()
	if directory_result != OK:
		status_label.text = "Could not create runtime folder: %s" % error_string(directory_result)
		return
	var front_export := (front_images[current_tier] as Image).duplicate()
	front_export.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
	var result: Error = front_export.save_png(String(RUNTIME_FRONT_PATHS[current_tier]))
	status_label.text = "Exported %s fronts only." % current_tier if result == OK else "Export failed: %s" % error_string(result)

func _is_overlay_tier(tier: String) -> bool:
	## Overlay tiers (cracks, gems in overlay mode) use a transparent base
	## instead of dark mass, so their atlas contains only the border/joint art
	## without baked-in rock fill. The runtime composites them on top of the
	## underlying rock tier.
	return tier == "cracks"

func _build_border_atlas(top_stamp: Image, convex_top_left: Image, tier: String = "") -> Image:
	var base_mass := mass_image
	if _is_overlay_tier(tier):
		base_mass = Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
		base_mass.fill(Color.TRANSPARENT)
	# The authored convex replacement patch supplies the real alpha cutout and
	# rounded rim. It is rotated into all four outward corners automatically.
	return CORNER_BUILDER.build_composite_atlas(base_mass, top_stamp, convex_top_left)

func _border_depth(top_border: Image) -> int:
	var deepest := -1
	for y in range(LOGICAL_SIZE):
		for x in range(LOGICAL_SIZE):
			if top_border.get_pixel(x, y).a > 0.05:
				deepest = maxi(deepest, y)
	return clampi(deepest + 1, 3, 14)

func _average_border_row(image: Image, row: int) -> Color:
	var total := Color(0, 0, 0, 0)
	var count := 0
	for x in range(LOGICAL_SIZE):
		var color := image.get_pixel(x, clampi(row, 0, LOGICAL_SIZE - 1))
		if color.a > 0.05:
			total += color
			count += 1
	if count == 0:
		return Color.TRANSPARENT
	return total / float(count)

func _make_inside_corner_top_left(top_border: Image) -> Image:
	var result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var depth := _border_depth(top_border)
	for y in range(depth + 1):
		for x in range(depth + 1):
			var distance := Vector2(float(x) + 0.5, float(y) + 0.5).length()
			if distance > float(depth):
				continue
			var color := _average_border_row(top_border, clampi(floori(distance), 0, depth - 1))
			if color.a > 0.05:
				result.set_pixel(x, y, color)
	return result

func _build_inside_corner_atlas(hole_source: Image, top_border: Image = null, tier: String = "") -> Image:
	var border: Image = top_border if top_border != null else border_images.get("easy", null) as Image
	var logical_size := LOGICAL_SIZE * 2
	var rendered_size := TILE_SIZE * 2
	var base := Image.create(logical_size, logical_size, false, Image.FORMAT_RGBA8)
	base.fill(Color.TRANSPARENT)
	var hole := hole_source.duplicate()
	hole.convert(Image.FORMAT_RGBA8)
	if hole.get_width() != LOGICAL_SIZE or hole.get_height() != LOGICAL_SIZE:
		hole.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	var origin := LOGICAL_SIZE - 16 # HOLE_VERTEX_OFFSET
	# Use the hand-painted Hole Corner sprite AS-IS: transparent background plus its
	# rim + rock elements. No solid mass backing is added - the sprite's own
	# transparency is preserved so only the painted rock (incl. the bits that sit on
	# the OUTSIDE of the corner, over the neighbour dark-mass tiles) is drawn. The
	# InsideCorner layers render above the border (z_index 3) so that outside rock
	# is visible instead of being buried under the neighbouring tiles.
	for y in range(HOLE_CORNER_SIZE):
		for x in range(HOLE_CORNER_SIZE):
			var color: Color = hole.get_pixel(x, y)
			if color.a > 0.05:
				base.set_pixel(origin + x, origin + y, color)
	var atlas := Image.create(rendered_size * 2, rendered_size * 2, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for frame in range(4):
		var rendered := _rotate_vertex_composite(base, frame)
		rendered.resize(rendered_size, rendered_size, Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(rendered, Rect2i(Vector2i.ZERO, Vector2i(rendered_size, rendered_size)), Vector2i(frame % 2, frame / 2) * rendered_size)
	return atlas
func _rotate_vertex_composite(source: Image, turns: int) -> Image:
	# The 2x2 composite's terrain vertex lies between pixels 31 and 32. Pixel
	# indices therefore rotate around (31.5, 31.5), using the normal size - 1
	# quarter-turn mapping. Rotating indices around integer 32 shifts the 90°,
	# 180° and 270° Hole Corner frames by one logical pixel.
	var normalized := posmod(turns, 4)
	var size := source.get_width()
	var result := Image.create(size, size, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(size):
		for x in range(size):
			var destination := Vector2i(x, y)
			match normalized:
				1: destination = Vector2i(size - 1 - y, x)
				2: destination = Vector2i(size - 1 - x, size - 1 - y)
				3: destination = Vector2i(y, size - 1 - x)
			result.set_pixelv(destination, source.get_pixel(x, y))
	return result
func _rotate_export_corner_patch(source: Image, turns: int) -> Image:
	var normalized := posmod(turns, 4)
	var result := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(14):
		for x in range(14):
			var destination := Vector2i(x, y)
			match normalized:
				1: destination = Vector2i(13 - y, x)
				2: destination = Vector2i(13 - x, 13 - y)
				3: destination = Vector2i(y, 13 - x)
			result.set_pixelv(destination, source.get_pixel(x, y))
	return result

func _find_brightest_color(image: Image) -> Color:
	var best := Color.html("b9afe0ff")
	var best_value := -1.0
	for y in range(11):
		for x in range(LOGICAL_SIZE):
			var color := image.get_pixel(x, y)
			var value: float = color.r + color.g + color.b
			if color.a > 0.1 and value > best_value:
				best_value = value
				best = color
	return best

func _add_rounded_corner_caps(tile: Image, mask: int, color: Color) -> void:
	if (mask & 1) != 0 and (mask & 8) != 0:
		_draw_corner_arc(tile, Vector2i(4, 4), PI, PI * 1.5, color)
	if (mask & 1) != 0 and (mask & 2) != 0:
		_draw_corner_arc(tile, Vector2i(27, 4), PI * 1.5, TAU, color)
	if (mask & 4) != 0 and (mask & 2) != 0:
		_draw_corner_arc(tile, Vector2i(27, 27), 0.0, PI * 0.5, color)
	if (mask & 4) != 0 and (mask & 8) != 0:
		_draw_corner_arc(tile, Vector2i(4, 27), PI * 0.5, PI, color)

func _draw_corner_arc(image: Image, center: Vector2i, start_angle: float, end_angle: float, color: Color) -> void:
	for step in range(13):
		var angle := lerpf(start_angle, end_angle, float(step) / 12.0)
		for radius in [4.0, 5.0]:
			var point := center + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius))
			if point.x >= 0 and point.y >= 0 and point.x < LOGICAL_SIZE and point.y < LOGICAL_SIZE:
				image.set_pixelv(point, color)

func _rotate_quarters(source: Image, turns: int) -> Image:
	var normalized_turns := posmod(turns, 4)
	var result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(LOGICAL_SIZE):
		for x in range(LOGICAL_SIZE):
			var destination := Vector2i(x, y)
			match normalized_turns:
				1:
					destination = Vector2i(LOGICAL_SIZE - 1 - y, x)
				2:
					destination = Vector2i(LOGICAL_SIZE - 1 - x, LOGICAL_SIZE - 1 - y)
				3:
					destination = Vector2i(y, LOGICAL_SIZE - 1 - x)
			result.set_pixelv(destination, source.get_pixel(x, y))
	return result
