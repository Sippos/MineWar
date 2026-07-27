extends CanvasLayer

# The Legacy Forge's spend screen. The forge used to be five floor pads the
# player walked between, which cost the stronghold its whole floor and could not
# grow past five ranks — Deepening is uncapped, so the list has to. The forge is
# now one object you stand at, and this is what it opens.
#
# The frame lives in legacy_forge_menu.tscn with stable node names; rows are
# instanced from legacy_forge_row.tscn so the list follows the upgrade data
# rather than a hand-placed control per rank.

signal closed

const ROW_SCENE := preload("res://scenes/ui/overlays/legacy_forge/legacy_forge_row.tscn")

const SELECTED_BORDER := 6
const UNSELECTED_BORDER := 3

@onready var ore_label: Label = $Center/Panel/Margin/VBox/Header/Ore
@onready var rows_box: VBoxContainer = $Center/Panel/Margin/VBox/Rows
@onready var effect_label: Label = $Center/Panel/Margin/VBox/Effect

var upgrade_order: Array[String] = []
var upgrade_data: Dictionary = {}
var rows: Array[Button] = []
var selected_index := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Called by the forge with its own PAD_ORDER/PAD_DATA so the menu never keeps a
## second copy of the upgrade table.
func setup(order: Array, data: Dictionary) -> void:
	upgrade_order.clear()
	for id_value in order:
		upgrade_order.append(str(id_value))
	upgrade_data = data
	_build_rows()
	refresh()

func _build_rows() -> void:
	for child in rows_box.get_children():
		child.queue_free()
	rows.clear()
	for index in range(upgrade_order.size()):
		var upgrade_id := upgrade_order[index]
		var entry: Dictionary = upgrade_data.get(upgrade_id, {})
		var row := ROW_SCENE.instantiate() as Button
		row.name = upgrade_id.to_pascal_case() + "Row"
		row.set_meta("upgrade_id", upgrade_id)
		(row.get_node("Margin/HBox/Name") as Label).text = str(entry.get("title", upgrade_id))
		(row.get_node("Margin/HBox/Swatch") as ColorRect).color = entry.get("color", Color.WHITE)
		row.pressed.connect(_on_row_pressed.bind(index))
		row.mouse_entered.connect(_on_row_hovered.bind(index))
		rows_box.add_child(row)
		rows.append(row)
	selected_index = clampi(selected_index, 0, maxi(rows.size() - 1, 0))

func _on_row_pressed(index: int) -> void:
	selected_index = index
	_purchase_selected()

func _on_row_hovered(index: int) -> void:
	if index == selected_index:
		return
	selected_index = index
	refresh()

func _unhandled_input(event: InputEvent) -> void:
	if rows.is_empty():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_move_selection(1)
		return
	if event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_move_selection(-1)
		return
	# p1_interact is the same key that opened the forge, so it also buys here.
	if event.is_action_pressed("ui_accept") or (InputMap.has_action("p1_interact") and event.is_action_pressed("p1_interact")):
		get_viewport().set_input_as_handled()
		_purchase_selected()

func _move_selection(step: int) -> void:
	selected_index = posmod(selected_index + step, rows.size())
	refresh()
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_objective_tick"):
		sound_fx.play_objective_tick(1)

func selected_upgrade_id() -> String:
	if selected_index < 0 or selected_index >= upgrade_order.size():
		return ""
	return upgrade_order[selected_index]

func _purchase_selected() -> bool:
	var upgrade_id := selected_upgrade_id()
	if upgrade_id.is_empty():
		return false
	var sound_fx := get_node_or_null("/root/SoundFX")
	if not Global.purchase_permanent_upgrade(upgrade_id):
		if sound_fx and sound_fx.has_method("play_error"):
			sound_fx.play_error()
		refresh()
		return false
	if sound_fx and sound_fx.has_method("play_upgrade"):
		sound_fx.play_upgrade()
	_play_purchase_pop(selected_index)
	refresh()
	return true

func _play_purchase_pop(index: int) -> void:
	if index < 0 or index >= rows.size():
		return
	var row := rows[index]
	row.pivot_offset = row.size * 0.5
	var pop := create_tween()
	pop.tween_property(row, "scale", Vector2(1.04, 1.04), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(row, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func refresh() -> void:
	ore_label.text = "%d ORE" % Global.legacy_ore
	for index in range(rows.size()):
		var row := rows[index]
		var upgrade_id := str(row.get_meta("upgrade_id"))
		var entry: Dictionary = upgrade_data.get(upgrade_id, {})
		var accent: Color = entry.get("color", Color.WHITE)
		var maxed := Global.is_permanent_upgrade_maxed(upgrade_id)
		var cost := Global.get_permanent_upgrade_cost(upgrade_id)
		var affordable := Global.legacy_ore >= cost
		var selected := index == selected_index

		var rank_label := row.get_node("Margin/HBox/Rank") as Label
		var level := Global.get_permanent_upgrade_level(upgrade_id)
		if Global.PERMANENT_UPGRADE_UNCAPPED.has(upgrade_id):
			rank_label.text = "Lv %d" % level
		else:
			rank_label.text = "Lv %d / %d" % [level, int(Global.PERMANENT_UPGRADE_MAX_LEVELS.get(upgrade_id, 0))]

		var cost_label := row.get_node("Margin/HBox/Cost") as Label
		cost_label.text = "MAX" if maxed else "%d ORE" % cost
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.3, 1.0) if (affordable and not maxed) else Color(0.58, 0.5, 0.4, 1.0))

		var swatch := row.get_node("Margin/HBox/Swatch") as ColorRect
		swatch.color = accent if (affordable or maxed) else Color(accent.r * 0.45, accent.g * 0.45, accent.b * 0.45, 1.0)
		_style_row(row, accent, selected)

	var selected_id := selected_upgrade_id()
	if selected_id.is_empty():
		effect_label.text = ""
		return
	var selected_entry: Dictionary = upgrade_data.get(selected_id, {})
	var effect := str(selected_entry.get("effect", ""))
	if Global.is_permanent_upgrade_maxed(selected_id):
		effect_label.text = "MAX RANK  •  %s" % effect
		return
	var selected_cost := Global.get_permanent_upgrade_cost(selected_id)
	if Global.legacy_ore >= selected_cost:
		effect_label.text = "%s  •  costs %d ore" % [effect, selected_cost]
	else:
		effect_label.text = "%s  •  needs %d ore, you have %d" % [effect, selected_cost, Global.legacy_ore]

func _style_row(row: Button, accent: Color, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.16, accent.g * 0.16, accent.b * 0.16, 0.92) if selected else Color(0.06, 0.08, 0.11, 0.85)
	style.border_width_left = SELECTED_BORDER if selected else UNSELECTED_BORDER
	style.border_color = accent if selected else Color(accent.r, accent.g, accent.b, 0.5)
	style.set_corner_radius_all(6)
	for state in ["normal", "hover", "pressed", "focus"]:
		row.add_theme_stylebox_override(state, style)

func close() -> void:
	closed.emit()
	queue_free()
