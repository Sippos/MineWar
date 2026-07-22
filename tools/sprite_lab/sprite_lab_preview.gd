extends Control

const OUTPUT_DIR := "res://assets/sprites/world/terrain/generated_sprite_lab"
const BOARD_PATHS: Array[String] = [
	OUTPUT_DIR + "/preview_mask_board.png",
	OUTPUT_DIR + "/preview_damage_board.png",
	OUTPUT_DIR + "/preview_dig_scenarios.png"
]
const BOARD_TITLES: Array[String] = [
	"16-MASK EXPOSURE BOARD",
	"DIRECTIONAL DAMAGE: 3 STAGES × 4 DIRECTIONS",
	"DIGGING SHAPE / FRONT-WALL STRESS TEST"
]

var board_index: int = 0
var title_label: Label
var status_label: Label
var board_rect: TextureRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_show_board(0)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color.html("18232cff")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color.html("8eeeffff"))
	layout.add_child(title_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color.html("c7d7e2ff"))
	status_label.text = _validation_summary()
	layout.add_child(status_label)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(panel)

	var center := CenterContainer.new()
	panel.add_child(center)

	board_rect = TextureRect.new()
	board_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	board_rect.custom_minimum_size = Vector2(860, 480)
	center.add_child(board_rect)

	var instructions := Label.new()
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.text = "← / → or 1–3: switch board     Generated from JSON recipes with fixed seeds"
	instructions.add_theme_font_size_override("font_size", 16)
	instructions.add_theme_color_override("font_color", Color.html("9eb0bcff"))
	layout.add_child(instructions)

func _validation_summary() -> String:
	var source: String = FileAccess.get_file_as_string(OUTPUT_DIR + "/validation_report.json")
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return "VALIDATION REPORT MISSING — run build_sprite_lab.tscn"
	var report: Dictionary = parsed
	var passed: bool = report.get("passed", false) == true and report.get("files_saved", false) == true
	var generated_value: Variant = report.get("generated", {})
	var generated: Dictionary = generated_value if generated_value is Dictionary else {}
	return "%s  •  fills %d  •  masks %d  •  fronts %d  •  damage %d + %d" % [
		"VALIDATION PASS" if passed else "VALIDATION FAIL",
		int(generated.get("fill_variants", 0)),
		int(generated.get("edge_masks", 0)),
		int(generated.get("front_wall_states", 0)),
		int(generated.get("directional_damage_frames", 0)),
		int(generated.get("front_damage_frames", 0))
	]

func _load_texture(path: String) -> Texture2D:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _show_board(index: int) -> void:
	board_index = posmod(index, BOARD_PATHS.size())
	title_label.text = BOARD_TITLES[board_index]
	board_rect.texture = _load_texture(BOARD_PATHS[board_index])

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_LEFT:
		_show_board(board_index - 1)
	elif key_event.keycode == KEY_RIGHT:
		_show_board(board_index + 1)
	elif key_event.keycode >= KEY_1 and key_event.keycode <= KEY_3:
		_show_board(int(key_event.keycode - KEY_1))
