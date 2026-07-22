extends Control

const CANVAS_SCRIPT := preload("res://tools/sprite_lab/tile_workspace_canvas.gd")
const PREVIEW_SCRIPT := preload("res://tools/sprite_lab/dome_tile_live_preview.gd")

const LOGICAL_SIZE := 32
const TILE_SIZE := 64
const EDGE_ATLAS_SIZE := 256
const OUTPUT_DIR := "res://tools/sprite_lab/source/workspaces"

const TIERS: Array[String] = ["easy", "medium", "hard"]
const TIER_LABELS := {"easy": "EASY", "medium": "MEDIUM", "hard": "HARD"}
const PARTS: Array[String] = ["mass", "top", "right", "bottom", "left"]
const PART_LABELS := {
	"mass": "DARK MASS",
	"top": "TOP EDGE",
	"right": "RIGHT EDGE",
	"bottom": "BOTTOM / FRONT",
	"left": "LEFT EDGE"
}

const MASS_PATHS := {
	"easy_mass": "res://assets/sprites/world/terrain/bricks/Easy_Brick_Rework.svg",
	"medium_mass": "res://assets/sprites/world/terrain/bricks/Medium_Brick_Rework.svg",
	"hard_mass": "res://assets/sprites/world/terrain/bricks/Hard_Brick_Rework.svg",
	"bedrock": "res://assets/sprites/world/terrain/bricks/Bedrock_Border.svg"
}
const EDGE_PATHS := {
	"easy": "res://assets/sprites/world/terrain/edges/Easy_Edge_Atlas_Rework.svg",
	"medium": "res://assets/sprites/world/terrain/edges/Medium_Edge_Atlas_Rework.svg",
	"hard": "res://assets/sprites/world/terrain/edges/Hard_Edge_Atlas_Rework.svg"
}
const GEM_ATLAS_PATH := "res://assets/sprites/world/terrain/gem_overlays/minewars_buried_gem_overlays_exact_256x128.png"

var images: Dictionary = {}
var current_tier := "easy"
var current_part := "mass"
var current_key := "easy_mass"
var current_special := ""
var tool_mode := 0
var brush_size := 1
var stroke_active := false
var last_cell := Vector2i(-1, -1)
var undo_stack: Array[Image] = []
var redo_stack: Array[Image] = []

var tier_selector: OptionButton
var part_buttons: Dictionary = {}
var special_buttons: Dictionary = {}
var tool_selector: OptionButton
var brush_selector: OptionButton
var color_picker: ColorPickerButton
var canvas: Control
var preview: Control
var composed_preview: TextureRect
var title_label: Label
var instruction_label: Label
var help_label: Label
var usage_label: Label
var status_label: Label
var undo_button: Button
var redo_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_workspace_images()
	_build_ui()
	_select_part("mass")

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color.html("0d1119ff")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	margin.add_child(outer)

	var heading := Label.new()
	heading.text = "MINEWARS DOME TILE WORKBENCH"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 21)
	heading.add_theme_color_override("font_color", Color.html("8eeeffff"))
	outer.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "1. Choose rock tier  →  2. Choose the part of the tile  →  3. Paint only inside the cyan edit area"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color.html("a9bac6ff"))
	outer.add_child(subtitle)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 9)
	outer.add_child(body)

	_build_controls_panel(body)
	_build_canvas_panel(body)
	_build_preview_panel(body)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color.html("9db0bcff"))
	outer.add_child(status_label)

func _build_controls_panel(body: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 0)
	body.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	scroll.add_child(margin)

	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 5)
	margin.add_child(controls)

	_add_section(controls, "1 • ROCK TIER")
	tier_selector = OptionButton.new()
	for tier: String in TIERS:
		tier_selector.add_item(String(TIER_LABELS[tier]))
	tier_selector.item_selected.connect(_on_tier_selected)
	controls.add_child(tier_selector)

	_add_section(controls, "2 • TILE PART")
	var diagram := GridContainer.new()
	diagram.columns = 3
	diagram.add_theme_constant_override("h_separation", 4)
	diagram.add_theme_constant_override("v_separation", 4)
	controls.add_child(diagram)
	_add_diagram_spacer(diagram)
	_add_part_button(diagram, "top", "TOP")
	_add_diagram_spacer(diagram)
	_add_part_button(diagram, "left", "LEFT")
	_add_part_button(diagram, "mass", "MASS")
	_add_part_button(diagram, "right", "RIGHT")
	_add_diagram_spacer(diagram)
	_add_part_button(diagram, "bottom", "BOTTOM\nFRONT")
	_add_diagram_spacer(diagram)

	var diagram_note := Label.new()
	diagram_note.text = "The four edge pieces are automatically combined into all 16 tunnel shapes."
	diagram_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diagram_note.add_theme_font_size_override("font_size", 9)
	diagram_note.add_theme_color_override("font_color", Color.html("8fa2afff"))
	controls.add_child(diagram_note)

	_add_section(controls, "SPECIAL SPRITES")
	_add_special_button(controls, "bedrock", "BEDROCK • unmineable")
	_add_special_button(controls, "gem_top", "GEM • top / side vein")
	_add_special_button(controls, "gem_bottom", "GEM • bottom / front vein")

	_add_section(controls, "PAINT")
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
	color_picker.color = Color.html("746b99ff")
	controls.add_child(color_picker)

	var grid_toggle := CheckBox.new()
	grid_toggle.text = "Pixel grid"
	grid_toggle.button_pressed = true
	grid_toggle.toggled.connect(func(value: bool) -> void: canvas.call("set_grid_visible", value))
	controls.add_child(grid_toggle)

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
	controls.add_child(history_row)

	_add_section(controls, "OUTPUT")
	var reload_button := Button.new()
	reload_button.text = "Restore original sprites"
	reload_button.pressed.connect(_reload_all)
	controls.add_child(reload_button)
	var save_button := Button.new()
	save_button.text = "Save editable drafts"
	save_button.pressed.connect(_save_all_workspaces)
	controls.add_child(save_button)
	var atlas_button := Button.new()
	atlas_button.text = "BUILD 16-MASK PREVIEW ATLASES"
	atlas_button.custom_minimum_size = Vector2(0, 38)
	atlas_button.pressed.connect(_export_generated_assets)
	controls.add_child(atlas_button)

	help_label = Label.new()
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_font_size_override("font_size", 9)
	help_label.add_theme_color_override("font_color", Color.html("9eb0bcff"))
	controls.add_child(help_label)

func _build_canvas_panel(body: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color.html("d7c7ffff"))
	column.add_child(title_label)

	instruction_label = Label.new()
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.add_theme_font_size_override("font_size", 10)
	instruction_label.add_theme_color_override("font_color", Color.html("a9f4ffff"))
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
	panel.custom_minimum_size = Vector2(420, 0)
	body.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	_add_section(column, "HOW THIS SPRITE IS USED")
	usage_label = Label.new()
	usage_label.text = "Cyan boxes mark every tile currently using the selected sprite."
	usage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	usage_label.add_theme_font_size_override("font_size", 10)
	usage_label.add_theme_color_override("font_color", Color.html("a9f4ffff"))
	column.add_child(usage_label)

	var mode_selector := OptionButton.new()
	for mode_name in ["Wide chamber", "Vertical shaft", "Overhang / pillars"]:
		mode_selector.add_item(mode_name)
	mode_selector.item_selected.connect(func(index: int) -> void: preview.call("set_preview_mode", index))
	column.add_child(mode_selector)

	var preview_center := CenterContainer.new()
	preview_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(preview_center)
	preview = PREVIEW_SCRIPT.new() as Control
	preview_center.add_child(preview)

	var composition_row := HBoxContainer.new()
	composition_row.alignment = BoxContainer.ALIGNMENT_CENTER
	composition_row.add_theme_constant_override("separation", 8)
	column.add_child(composition_row)
	var composition_text := VBoxContainer.new()
	var composition_heading := Label.new()
	composition_heading.text = "COMPOSED 64×64 TILE"
	composition_heading.add_theme_font_size_override("font_size", 10)
	composition_text.add_child(composition_heading)
	var composition_note := Label.new()
	composition_note.text = "This is the selected sprite placed on its real dirt tile—not the transparent layer by itself."
	composition_note.custom_minimum_size = Vector2(210, 0)
	composition_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	composition_note.add_theme_font_size_override("font_size", 9)
	composition_note.add_theme_color_override("font_color", Color.html("8fa2afff"))
	composition_text.add_child(composition_note)
	composition_row.add_child(composition_text)
	composed_preview = TextureRect.new()
	composed_preview.custom_minimum_size = Vector2(112, 112)
	composed_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	composed_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	composed_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	composition_row.add_child(composed_preview)

func _add_section(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.html("8eeeffff"))
	parent.add_child(label)

func _add_diagram_spacer(parent: GridContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(68, 38)
	parent.add_child(spacer)

func _add_part_button(parent: GridContainer, part: String, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(68, 38)
	button.add_theme_font_size_override("font_size", 9)
	button.pressed.connect(_select_part.bind(part))
	parent.add_child(button)
	part_buttons[part] = button

func _add_special_button(parent: VBoxContainer, key: String, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(_select_special.bind(key))
	parent.add_child(button)
	special_buttons[key] = button

func _on_tier_selected(index: int) -> void:
	current_tier = TIERS[clampi(index, 0, TIERS.size() - 1)]
	_select_part(current_part)

func _select_part(part: String) -> void:
	current_special = ""
	current_part = part
	current_key = "%s_%s" % [current_tier, current_part]
	_prepare_workspace_change()

func _select_special(key: String) -> void:
	current_special = key
	current_key = key
	_prepare_workspace_change()

func _prepare_workspace_change() -> void:
	undo_stack.clear()
	redo_stack.clear()
	_refresh_selection_state()
	_refresh_views()

func _refresh_selection_state() -> void:
	for part_value: Variant in part_buttons.keys():
		var part := String(part_value)
		var part_button: Button = part_buttons[part]
		part_button.modulate = Color.WHITE if current_special.is_empty() and part == current_part else Color(0.68, 0.68, 0.74, 1.0)
	for key_value: Variant in special_buttons.keys():
		var key := String(key_value)
		var special_button: Button = special_buttons[key]
		special_button.modulate = Color.WHITE if current_special == key else Color(0.68, 0.68, 0.74, 1.0)

func _workspace_title() -> String:
	if current_special == "bedrock":
		return "BEDROCK • UNMINEABLE FULL TILE"
	if current_special == "gem_top":
		return "GEM • TOP / SIDE EMBEDDED VEIN"
	if current_special == "gem_bottom":
		return "GEM • BOTTOM / FRONT EMBEDDED VEIN"
	return "%s • %s" % [String(TIER_LABELS[current_tier]), String(PART_LABELS[current_part])]

func _edit_region() -> Rect2i:
	if current_key.ends_with("_top"):
		return Rect2i(0, 0, LOGICAL_SIZE, 9)
	if current_key.ends_with("_right"):
		return Rect2i(23, 0, 9, LOGICAL_SIZE)
	if current_key.ends_with("_bottom") and not current_key.begins_with("gem_"):
		return Rect2i(0, 21, LOGICAL_SIZE, 11)
	if current_key.ends_with("_left"):
		return Rect2i(0, 0, 9, LOGICAL_SIZE)
	return Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))

func _focus_component() -> String:
	if current_special == "bedrock":
		return "bedrock"
	if current_special.begins_with("gem_"):
		return "gem"
	return current_part

func _refresh_views() -> void:
	if not images.has(current_key):
		return
	var active: Image = images[current_key]
	var region := _edit_region()
	canvas.call("set_preview_image", active)
	canvas.call("set_edit_region", region, _workspace_title())
	title_label.text = _workspace_title()
	_update_instruction_text(region)
	_update_help_text()
	_update_usage_text()

	var gem_visible := current_special.begins_with("gem_")
	var preview_gem: Image = active if gem_visible else images["gem_top"]
	preview.call("set_material_images",
		images["%s_mass" % current_tier],
		images["%s_top" % current_tier],
		images["%s_right" % current_tier],
		images["%s_bottom" % current_tier],
		images["%s_left" % current_tier],
		images["bedrock"],
		preview_gem,
		gem_visible
	)
	preview.call("set_focus_component", _focus_component())

	var composed := _compose_selected_tile()
	composed.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
	composed_preview.texture = ImageTexture.create_from_image(composed)
	undo_button.disabled = undo_stack.is_empty()
	redo_button.disabled = redo_stack.is_empty()
	status_label.text = "%s  •  cyan editor box = paintable  •  dark editor area = locked transparent" % _workspace_title()

func _update_instruction_text(region: Rect2i) -> void:
	if region.size == Vector2i(LOGICAL_SIZE, LOGICAL_SIZE):
		instruction_label.text = "Paint the complete tile. The cave preview updates immediately."
	else:
		instruction_label.text = "Paint only the cyan rim. The rest is locked because an edge sprite must stay transparent."

func _update_help_text() -> void:
	match _focus_component():
		"mass":
			help_label.text = "Dark mass is the quiet interior of all undug blocks. Keep it seamless and low contrast; the bright edge sprites reveal the tunnel."
		"top":
			help_label.text = "Top edge appears on a solid block when the cell above has been dug out. Paint only the upper rim."
		"right":
			help_label.text = "Right edge appears when the cell to the right has been dug out. Paint only the right rim."
		"bottom":
			help_label.text = "Bottom/front edge appears when the cell below has been dug out. It can be slightly thicker, but it stays inside the same tile."
		"left":
			help_label.text = "Left edge appears when the cell to the left has been dug out. Paint only the left rim."
		"bedrock":
			help_label.text = "Bedrock is the full-color outer map ring and is never mineable. It should be unmistakable from hard but breakable stone."
		"gem":
			help_label.text = "Gem sprites are transparent overlays. Crystals must look embedded in the exposed dirt face, not like floating pickups."

func _update_usage_text() -> void:
	match _focus_component():
		"mass": usage_label.text = "Cyan boxes mark every mineable solid block using this dark mass texture."
		"top": usage_label.text = "Cyan boxes mark solid blocks with DUG SPACE ABOVE. The top-edge sprite is drawn there."
		"right": usage_label.text = "Cyan boxes mark solid blocks with DUG SPACE TO THE RIGHT. The right-edge sprite is drawn there."
		"bottom": usage_label.text = "Cyan boxes mark solid blocks with DUG SPACE BELOW. This is the thicker bottom/front rim—no projected second tile."
		"left": usage_label.text = "Cyan boxes mark solid blocks with DUG SPACE TO THE LEFT. The left-edge sprite is drawn there."
		"bedrock": usage_label.text = "Cyan boxes mark the full-color, unmineable ring around the playable mine."
		"gem": usage_label.text = "The cyan example tile shows where this transparent embedded gem overlay is composed with dirt and an exposed rim."

func _compose_selected_tile() -> Image:
	var result: Image
	if current_special == "bedrock":
		return (images["bedrock"] as Image).duplicate()
	result = (images["%s_mass" % current_tier] as Image).duplicate()
	if current_special == "gem_top":
		result.blend_rect(images["%s_top" % current_tier], Rect2i(0, 0, LOGICAL_SIZE, LOGICAL_SIZE), Vector2i.ZERO)
		result.blend_rect(images["gem_top"], Rect2i(0, 0, LOGICAL_SIZE, LOGICAL_SIZE), Vector2i.ZERO)
	elif current_special == "gem_bottom":
		result.blend_rect(images["%s_bottom" % current_tier], Rect2i(0, 0, LOGICAL_SIZE, LOGICAL_SIZE), Vector2i.ZERO)
		result.blend_rect(images["gem_bottom"], Rect2i(0, 0, LOGICAL_SIZE, LOGICAL_SIZE), Vector2i.ZERO)
	elif current_part != "mass":
		result.blend_rect(images[current_key], Rect2i(0, 0, LOGICAL_SIZE, LOGICAL_SIZE), Vector2i.ZERO)
	return result

func _load_workspace_images() -> void:
	images.clear()
	for key_value: Variant in MASS_PATHS.keys():
		var key := String(key_value)
		images[key] = _load_svg_logical(String(MASS_PATHS[key]))
	for tier_value: Variant in EDGE_PATHS.keys():
		var tier := String(tier_value)
		var atlas := _load_svg_image(String(EDGE_PATHS[tier]))
		images["%s_top" % tier] = _extract_tile(atlas, Vector2i(1, 0))
		images["%s_right" % tier] = _extract_tile(atlas, Vector2i(2, 0))
		images["%s_bottom" % tier] = _extract_tile(atlas, Vector2i(0, 1))
		images["%s_left" % tier] = _extract_tile(atlas, Vector2i(0, 2))
	var gem_atlas := Image.load_from_file(ProjectSettings.globalize_path(GEM_ATLAS_PATH))
	images["gem_top"] = _extract_tile(gem_atlas, Vector2i(0, 0))
	images["gem_bottom"] = _extract_tile(gem_atlas, Vector2i(0, 1))

func _load_svg_image(path: String) -> Image:
	var image := Image.new()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() or image.load_svg_from_string(text, 1.0) != OK:
		image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
	image.convert(Image.FORMAT_RGBA8)
	return image

func _load_svg_logical(path: String) -> Image:
	var image := _load_svg_image(path)
	image.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return image

func _extract_tile(atlas: Image, atlas_cell: Vector2i) -> Image:
	var result := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	if atlas != null and not atlas.is_empty():
		result.blit_rect(atlas, Rect2i(atlas_cell * TILE_SIZE, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i.ZERO)
	result.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return result

func _stroke_started(cell: Vector2i, mouse_button: int) -> void:
	if tool_mode == 2 and mouse_button == MOUSE_BUTTON_LEFT:
		color_picker.color = (images[current_key] as Image).get_pixelv(cell)
		return
	undo_stack.append((images[current_key] as Image).duplicate())
	if undo_stack.size() > 40:
		undo_stack.pop_front()
	redo_stack.clear()
	stroke_active = true
	last_cell = cell
	_apply_brush(cell, mouse_button)
	_refresh_views()

func _stroke_moved(cell: Vector2i, mouse_button: int) -> void:
	if not stroke_active or tool_mode == 2:
		return
	var steps := maxi(absi(cell.x - last_cell.x), absi(cell.y - last_cell.y))
	for index in range(steps + 1):
		var amount := 0.0 if steps == 0 else float(index) / float(steps)
		var point := Vector2i(roundi(lerpf(float(last_cell.x), float(cell.x), amount)), roundi(lerpf(float(last_cell.y), float(cell.y), amount)))
		_apply_brush(point, mouse_button)
	last_cell = cell
	_refresh_views()

func _stroke_finished() -> void:
	stroke_active = false
	last_cell = Vector2i(-1, -1)
	_refresh_views()

func _apply_brush(cell: Vector2i, mouse_button: int) -> void:
	var erase := mouse_button == MOUSE_BUTTON_RIGHT or tool_mode == 1
	var paint_color := Color.TRANSPARENT if erase else color_picker.color
	var start := -int(floor(float(brush_size - 1) * 0.5))
	var image: Image = images[current_key]
	var region := _edit_region()
	for oy in range(brush_size):
		for ox in range(brush_size):
			var point := cell + Vector2i(start + ox, start + oy)
			if point.x >= 0 and point.y >= 0 and point.x < LOGICAL_SIZE and point.y < LOGICAL_SIZE and region.has_point(point):
				image.set_pixelv(point, paint_color)

func _hover_changed(cell: Vector2i) -> void:
	if cell.x < 0:
		return
	var editable := _edit_region().has_point(cell)
	status_label.text = "%s  •  pixel %s  •  %s" % [_workspace_title(), str(cell), "PAINTABLE" if editable else "LOCKED TRANSPARENT"]

func _undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append((images[current_key] as Image).duplicate())
	images[current_key] = undo_stack.pop_back()
	_refresh_views()

func _redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append((images[current_key] as Image).duplicate())
	images[current_key] = redo_stack.pop_back()
	_refresh_views()

func _reload_all() -> void:
	_load_workspace_images()
	undo_stack.clear()
	redo_stack.clear()
	_refresh_views()
	status_label.text = "Restored the original runtime sprites."

func _save_all_workspaces() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	for key_value: Variant in images.keys():
		var key := String(key_value)
		var image: Image = images[key]
		var export_image := image.duplicate()
		export_image.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
		var save_error: Error = export_image.save_png("%s/%s.png" % [OUTPUT_DIR, key])
		if save_error != OK:
			status_label.text = "Could not save %s: %s" % [key, error_string(save_error)]
			return
	status_label.text = "Saved editable draft PNGs to tools/sprite_lab/source/workspaces/."

func _export_generated_assets() -> void:
	_save_all_workspaces()
	for tier: String in TIERS:
		var atlas := Image.create(EDGE_ATLAS_SIZE, EDGE_ATLAS_SIZE, false, Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		var directions: Array[Image] = [images["%s_top" % tier], images["%s_right" % tier], images["%s_bottom" % tier], images["%s_left" % tier]]
		for mask in range(16):
			var tile := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
			tile.fill(Color.TRANSPARENT)
			for direction_index in range(4):
				if (mask & (1 << direction_index)) != 0:
					tile.blend_rect(directions[direction_index], Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE)), Vector2i.ZERO)
			tile.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
			atlas.blit_rect(tile, Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i(mask % 4, mask / 4) * TILE_SIZE)
		var atlas_error: Error = atlas.save_png("%s/%s_edge_atlas_256.png" % [OUTPUT_DIR, tier])
		if atlas_error != OK:
			status_label.text = "Could not build %s atlas: %s" % [tier, error_string(atlas_error)]
			return
	status_label.text = "Built Easy, Medium and Hard 16-mask preview atlases."
