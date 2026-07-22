extends "res://tools/sprite_lab/golden_tile_lab_preview.gd"

const V3_OUTPUT_DIR := "res://assets/sprites/world/terrain/generated_sprite_lab/golden_v3"
const V3_BOARD_PATHS: Array[String] = [
	V3_OUTPUT_DIR + "/preview_golden_tiles_v3.png",
	V3_OUTPUT_DIR + "/preview_repetition_v3.png",
	V3_OUTPUT_DIR + "/preview_excavation_v3.png",
	V3_OUTPUT_DIR + "/preview_lighting_v3.png",
	V3_OUTPUT_DIR + "/preview_scale_v3.png",
	V3_OUTPUT_DIR + "/preview_compare_v2_v3.png"
]
const V3_BOARD_TITLES: Array[String] = [
	"GOLDEN REFERENCES V3 — 10 TILES",
	"REPETITION V3 — CALMER PACKED EARTH",
	"EXCAVATION V3 — MASKS / WALL DEPTH",
	"LIGHTING V3 — GAME CONDITIONS",
	"PIXEL SCALE V3 — 1× / 1.5× / 2×",
	"V2 LEFT / V3 RIGHT — REPETITION + EXCAVATION"
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_show_board(0)

func _validation_summary() -> String:
	var source: String = FileAccess.get_file_as_string(V3_OUTPUT_DIR + "/validation_report_v3.json")
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return "VALIDATION REPORT MISSING — run build_golden_tile_lab_v3.tscn"
	var report: Dictionary = parsed
	var passed: bool = report.get("passed", false) == true and report.get("files_saved", false) == true
	var generated_value: Variant = report.get("generated", {})
	var generated: Dictionary = generated_value if generated_value is Dictionary else {}
	var metrics_value: Variant = report.get("aesthetic_metrics", {})
	var metrics: Dictionary = metrics_value if metrics_value is Dictionary else {}
	return "%s  •  stamps %d  •  fills %d  •  masks %d  •  fronts %d  •  lower alpha %.1f%%" % [
		"V3 TECHNICAL PASS — ART REVIEW" if passed else "V3 VALIDATION FAIL",
		int(generated.get("stamp_count", 0)),
		int(generated.get("fill_variants", 0)),
		int(generated.get("edge_masks", 0)),
		int(generated.get("front_wall_states", 0)),
		float(metrics.get("average_front_lower_transparency", 0.0)) * 100.0
	]

func _show_board(index: int) -> void:
	board_index = posmod(index, V3_BOARD_PATHS.size())
	title_label.text = V3_BOARD_TITLES[board_index]
	path_label.text = V3_BOARD_PATHS[board_index]
	board_rect.texture = _load_texture(V3_BOARD_PATHS[board_index])

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
	elif key_event.keycode >= KEY_1 and key_event.keycode <= KEY_6:
		_show_board(int(key_event.keycode - KEY_1))
