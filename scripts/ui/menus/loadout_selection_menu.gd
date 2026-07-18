extends CanvasLayer

const BASE_ORDER: Array[String] = ["default_base", "shaman_base", "nerubian_base", "mech_base", "druid_base", "undead_king_base"]
const BASE_TO_HERO := {
	"default_base": "Dwarf",
	"shaman_base": "Shaman",
	"nerubian_base": "Nerubian",
	"druid_base": "Druid",
	"undead_king_base": "Undead King",
	"mech_base": "Mech",
}
const BASE_DESCRIPTIONS := {
	"default_base": "DWARF ENGINEERING  •  +1 free gem carry and 8 bastion HP repaired after every assault.",
	"shaman_base": "TOTEM SANCTUARY  •  Reveals nearby crystal seams and heals heroes fighting near the lodge.",
	"nerubian_base": "BROOD NEST  •  Warns three seconds earlier and webs the first three attackers.",
	"mech_base": "GOBLIN WORKSHOP  •  +15 bastion HP, faster Mech rebuilding, and an automatic defence turret.",
	"druid_base": "LIVING GROVE  •  Safe regeneration and periodic roots around the bastion.",
	"undead_king_base": "SOUL CITADEL  •  Enemy deaths charge a defensive nova or soul-powered repair.",
}

var world: Node
var player: Node
var base: Node
var selected_base := "default_base"

var shell: PanelContainer
var hero_label: Label
var progression_label: Label
var base_texture: TextureRect
var base_name_label: Label
var base_description_label: Label
var match_label: Label
var confirm_button: Button
var base_buttons: Dictionary = {}

func setup(world_node: Node, player_node: Node, base_node: Node) -> void:
	world = world_node
	player = player_node
	base = base_node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 300
	selected_base = Global.selected_base_id if _base_unlocked(Global.selected_base_id) else "default_base"
	_build_interface()
	_refresh_interface()
	get_tree().root.size_changed.connect(_layout_for_screen)
	call_deferred("_layout_for_screen")
	call_deferred("_focus_selected_base")
	if player != null and player.get("can_move") != null:
		player.set("can_move", false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_close_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_cycle_base(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_cycle_base(1)
		get_viewport().set_input_as_handled()

func _build_interface() -> void:
	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.004, 0.007, 0.012, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	shell = PanelContainer.new()
	shell.name = "BaseSelectionShell"
	shell.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.032, 0.045, 0.99), Color(0.3, 0.78, 1.0, 1.0), 3, 16))
	overlay.add_child(shell)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 24
	body.offset_top = 18
	body.offset_right = -24
	body.offset_bottom = -18
	body.add_theme_constant_override("separation", 8)
	shell.add_child(body)

	var title := Label.new()
	title.text = "CHOOSE YOUR FORTRESS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.62, 0.92, 1.0, 1.0))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	body.add_child(title)

	hero_label = Label.new()
	hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_label.add_theme_font_size_override("font_size", 15)
	hero_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48, 1.0))
	body.add_child(hero_label)

	progression_label = Label.new()
	progression_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progression_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progression_label.custom_minimum_size = Vector2(0, 36)
	progression_label.add_theme_font_size_override("font_size", 13)
	progression_label.add_theme_color_override("font_color", Color(0.72, 0.8, 0.88, 1.0))
	body.add_child(progression_label)

	var showcase := PanelContainer.new()
	showcase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	showcase.custom_minimum_size = Vector2(0, 292)
	showcase.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.055, 0.07, 0.96), Color(0.22, 0.48, 0.64, 0.88), 2, 12))
	body.add_child(showcase)

	var showcase_box := VBoxContainer.new()
	showcase_box.alignment = BoxContainer.ALIGNMENT_CENTER
	showcase_box.add_theme_constant_override("separation", 5)
	showcase.add_child(showcase_box)

	base_texture = TextureRect.new()
	base_texture.custom_minimum_size = Vector2(360, 205)
	base_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	showcase_box.add_child(base_texture)

	base_name_label = Label.new()
	base_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	base_name_label.add_theme_font_size_override("font_size", 23)
	base_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 1.0))
	showcase_box.add_child(base_name_label)

	match_label = Label.new()
	match_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_label.add_theme_font_size_override("font_size", 13)
	showcase_box.add_child(match_label)

	base_description_label = Label.new()
	base_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	base_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	base_description_label.custom_minimum_size = Vector2(520, 64)
	base_description_label.add_theme_font_size_override("font_size", 13)
	base_description_label.add_theme_color_override("font_color", Color(0.76, 0.82, 0.88, 1.0))
	showcase_box.add_child(base_description_label)

	var selector_row := HBoxContainer.new()
	selector_row.alignment = BoxContainer.ALIGNMENT_CENTER
	selector_row.add_theme_constant_override("separation", 10)
	body.add_child(selector_row)

	var previous := Button.new()
	previous.text = "◀"
	previous.tooltip_text = "Previous base"
	previous.custom_minimum_size = Vector2(54, 66)
	previous.pressed.connect(_cycle_base.bind(-1))
	selector_row.add_child(previous)

	for base_id in BASE_ORDER:
		var button := Button.new()
		button.name = base_id.capitalize().replace(" ", "")
		button.custom_minimum_size = Vector2(92, 66)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_select_base.bind(base_id))
		selector_row.add_child(button)
		base_buttons[base_id] = button

	var next := Button.new()
	next.text = "▶"
	next.tooltip_text = "Next base"
	next.custom_minimum_size = Vector2(54, 66)
	next.pressed.connect(_cycle_base.bind(1))
	selector_row.add_child(next)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 18)
	body.add_child(footer)

	var cancel := Button.new()
	cancel.text = "Back to Hub"
	cancel.custom_minimum_size = Vector2(180, 48)
	cancel.pressed.connect(_close_menu)
	footer.add_child(cancel)

	confirm_button = Button.new()
	confirm_button.text = "Use This Base"
	confirm_button.custom_minimum_size = Vector2(220, 48)
	confirm_button.pressed.connect(_confirm_base)
	footer.add_child(confirm_button)

func _layout_for_screen() -> void:
	if shell == null:
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var width := clampf(view_size.x - 30.0, 620.0, 820.0)
	var height := clampf(view_size.y - 24.0, 520.0, 680.0)
	shell.anchor_left = 0.5
	shell.anchor_top = 0.5
	shell.anchor_right = 0.5
	shell.anchor_bottom = 0.5
	shell.offset_left = -width * 0.5
	shell.offset_top = -height * 0.5
	shell.offset_right = width * 0.5
	shell.offset_bottom = height * 0.5

func _refresh_interface() -> void:
	var hero_name := Global.selected_hero_id
	hero_label.text = "CURRENT HERO  •  %s  •  Heroes are chosen physically in the hub" % hero_name
	progression_label.text = (
		"Choose one of the fortresses that has joined your stronghold."
		if Global.unlocked_bases.size() > 1
		else "The Dwarf Bastion is prepared for the expedition."
	)

	var selected_data: Dictionary = Global.base_data.get(selected_base, Global.base_data["default_base"])
	base_texture.texture = selected_data.get("texture") as Texture2D
	base_texture.modulate = Color(1.16, 0.82, 0.46, 1.0) if selected_base == "mech_base" else Color.WHITE
	base_name_label.text = str(selected_data.get("name", selected_base.capitalize()))
	base_description_label.text = str(BASE_DESCRIPTIONS.get(selected_base, "A fortress for the next expedition."))
	var matching_hero := str(BASE_TO_HERO.get(selected_base, "Dwarf"))
	var matches_current := matching_hero == hero_name
	match_label.text = "ORIGIN  •  %s  •  Mix freely with %s" % [matching_hero, hero_name]
	match_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32, 1.0) if matches_current else Color(0.58, 0.78, 0.9, 1.0))
	confirm_button.text = "Use %s" % base_name_label.text

	for base_id in BASE_ORDER:
		var button: Button = base_buttons[base_id]
		var unlocked := _base_unlocked(base_id)
		var is_selected := base_id == selected_base
		var data: Dictionary = Global.base_data.get(base_id, {})
		var short_name := str(data.get("name", base_id.capitalize()))
		button.visible = unlocked
		button.text = short_name
		button.disabled = not unlocked
		button.modulate = Color.WHITE
		button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48, 1.0) if is_selected else Color(0.86, 0.9, 0.95, 1.0))

func _select_base(base_id: String) -> void:
	if not _base_unlocked(base_id):
		return
	selected_base = base_id
	_refresh_interface()

func _cycle_base(direction: int) -> void:
	var available := _available_bases()
	if available.is_empty():
		return
	var index := available.find(selected_base)
	if index < 0:
		index = 0
	selected_base = available[(index + direction + available.size()) % available.size()]
	_refresh_interface()

func _available_bases() -> Array[String]:
	var result: Array[String] = []
	for base_id in BASE_ORDER:
		if _base_unlocked(base_id):
			result.append(base_id)
	return result

func _base_unlocked(base_id: String) -> bool:
	return Global.is_base_unlocked(base_id)

func _confirm_base() -> void:
	Global.set_run_loadout(Global.selected_hero_id, selected_base)
	if base != null and base.has_method("refresh_base_sprite"):
		base.refresh_base_sprite()
	_close_menu()

func _focus_selected_base() -> void:
	if base_buttons.has(selected_base):
		var button: Button = base_buttons[selected_base]
		if not button.disabled:
			button.grab_focus()
			return
	confirm_button.grab_focus()

func _close_menu() -> void:
	if player != null and player.get("can_move") != null:
		player.set("can_move", true)
	queue_free()

func _panel_style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.74)
	style.shadow_size = 9
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
