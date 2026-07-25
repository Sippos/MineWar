extends Node2D

# A small popup that floats over a player's own stronghold in the multiplayer
# hubs. Walk up, click an arrow (or press interact) and the dome changes right
# there in the room - no fullscreen menu and no pause. Every hero fortress is
# offered here, campaign unlocks only gate single player.

signal base_change_requested(base_id: String)

const BASE_ORDER := ["default_base", "shaman_base", "nerubian_base", "mech_base", "druid_base", "undead_king_base"]
const PANEL_WIDTH := 208.0
const HEADER_HEIGHT := 46.0
const UPGRADE_ROW_HEIGHT := 14.0
const UPGRADE_ROWS := 3
const PANEL_HEIGHT := HEADER_HEIGHT + UPGRADE_ROW_HEIGHT * float(UPGRADE_ROWS) + 8.0

var player_id := 1
var owner_tag := ""

var _panel: Panel
var _name_label: Label
var _tag_label: Label
var _previous_button: Button
var _next_button: Button
var _upgrade_rows: Array[Dictionary] = []

func setup(owning_player_id: int, tag: String) -> void:
	player_id = owning_player_id
	owner_tag = tag

func _ready() -> void:
	z_index = 60
	_build()
	refresh()

func _build() -> void:
	_panel = Panel.new()
	_panel.name = "Shell"
	_panel.position = Vector2(-PANEL_WIDTH * 0.5, -PANEL_HEIGHT)
	_panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	_tag_label = _create_label("Owner", Vector2(0, 3), Vector2(PANEL_WIDTH, 12), 8, Color(0.68, 0.82, 0.95, 1.0))
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_name_label = _create_label("BaseName", Vector2(32, 16), Vector2(PANEL_WIDTH - 64.0, 26), 11, Color(1.0, 0.88, 0.56, 1.0))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_previous_button = _create_arrow("◀", Vector2(5, 15))
	_previous_button.pressed.connect(_cycle.bind(-1))
	_next_button = _create_arrow("▶", Vector2(PANEL_WIDTH - 31.0, 15))
	_next_button.pressed.connect(_cycle.bind(1))

	# The upgrade box: one compact line per perk the fortress brings to the run.
	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.position = Vector2(8, HEADER_HEIGHT - 3.0)
	divider.size = Vector2(PANEL_WIDTH - 16.0, 1)
	divider.color = Color(0.95, 0.68, 0.26, 0.35)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(divider)

	for row in range(UPGRADE_ROWS):
		var row_y := HEADER_HEIGHT + 1.0 + float(row) * UPGRADE_ROW_HEIGHT
		var kind := _create_label("UpgradeKind%d" % row, Vector2(9, row_y), Vector2(48, UPGRADE_ROW_HEIGHT), 7, Color(0.62, 0.78, 0.92, 1.0))
		var text := _create_label("UpgradeText%d" % row, Vector2(57, row_y), Vector2(PANEL_WIDTH - 66.0, UPGRADE_ROW_HEIGHT), 7, Color(0.88, 0.92, 0.97, 1.0))
		text.clip_text = true
		_upgrade_rows.append({"kind": kind, "text": text})

func _create_label(node_name: String, label_position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = label_position
	label.size = label_size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	_panel.add_child(label)
	return label

func _create_arrow(glyph: String, arrow_position: Vector2) -> Button:
	var button := Button.new()
	button.text = glyph
	button.position = arrow_position
	button.size = Vector2(26, 26)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	_panel.add_child(button)
	return button

func refresh() -> void:
	if _name_label == null:
		return
	var current := Global.get_base_for_player(player_id)
	var data: Dictionary = Global.base_data.get(current, {})
	_name_label.text = str(data.get("name", current.capitalize()))
	_tag_label.text = owner_tag

	var upgrades: Array = data.get("upgrades", [])
	for row in range(_upgrade_rows.size()):
		var kind_label: Label = _upgrade_rows[row]["kind"]
		var text_label: Label = _upgrade_rows[row]["text"]
		if row < upgrades.size():
			var entry: Array = upgrades[row]
			kind_label.text = str(entry[0])
			text_label.text = str(entry[1])
		else:
			kind_label.text = ""
			text_label.text = ""

	var switchable := available_bases().size() > 1
	_previous_button.visible = switchable
	_next_button.visible = switchable
	# The panel itself must ignore the mouse or it would eat clicks meant for the
	# world, but the arrows sitting on top of it stay interactive.
	_previous_button.mouse_filter = Control.MOUSE_FILTER_STOP if switchable else Control.MOUSE_FILTER_IGNORE
	_next_button.mouse_filter = Control.MOUSE_FILTER_STOP if switchable else Control.MOUSE_FILTER_IGNORE

# Every hero fortress, not just the ones this save has unlocked.
func available_bases() -> Array:
	var result: Array = []
	for base_id in BASE_ORDER:
		if Global.base_data.has(base_id):
			result.append(base_id)
	return result

func cycle_next() -> void:
	_cycle(1)

func _cycle(direction: int) -> void:
	var choices := available_bases()
	if choices.size() <= 1:
		return
	var current := Global.get_base_for_player(player_id)
	var index := choices.find(current)
	if index < 0:
		index = 0
	var next_base := str(choices[(index + direction + choices.size()) % choices.size()])
	base_change_requested.emit(next_base)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.92)
	style.border_color = Color(0.95, 0.68, 0.26, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 6
	return style
