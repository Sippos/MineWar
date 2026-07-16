extends Node

@export var world_path: NodePath = NodePath("../Level")

const START_Y := 104.0
const START_HALF_WIDTH := 112.0
const HERO_SELECT_RADIUS := 58.0
const BASE_SELECT_RADIUS := 50.0
const HERO_ORDER := ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King", "Mech"]
const HERO_POSITIONS := [
	Vector2(-260, -78),
	Vector2(-158, -144),
	Vector2(-54, -170),
	Vector2(54, -170),
	Vector2(158, -144),
	Vector2(260, -78)
]
const BASE_ORDER := ["default_base", "shaman_base", "nerubian_base", "druid_base", "undead_king_base"]
const BASE_POSITIONS := [
	Vector2(-280, 26),
	Vector2(-165, 46),
	Vector2(-75, 58),
	Vector2(165, 46),
	Vector2(280, 26)
]

var world: Node2D
var player: CharacterBody2D
var base: Node
var hero_pads: Array[Dictionary] = []
var base_pads: Array[Dictionary] = []
var interface: CanvasLayer
var loadout_label: Label
var status_label: Label
var _started := false

func _ready() -> void:
	world = get_node_or_null(world_path) as Node2D
	if world == null:
		push_error("Preparation controller could not find the mine world")
		return
	player = world.get_node_or_null("Player") as CharacterBody2D
	base = world.get_node_or_null("Base")
	if player == null or base == null:
		push_error("Preparation controller requires the normal Player and Base nodes")
		return
	Global.apply_selected_loadout()
	player.update_hero_sprites()
	base.refresh_base_sprite()
	_build_world_choices()
	_build_interface()
	_refresh_selection_visuals()
	_update_loadout_text()

func _process(_delta: float) -> void:
	if _started or world == null or player == null:
		return
	_check_hero_selection()
	_check_base_selection()
	if player.position.y >= START_Y and absf(player.position.x) <= START_HALF_WIDTH:
		_begin_run()

func _build_world_choices() -> void:
	var choices_root := Node2D.new()
	choices_root.name = "LoadoutChoices"
	choices_root.z_index = 7
	world.add_child(choices_root)

	for index in range(HERO_ORDER.size()):
		var hero_id: String = HERO_ORDER[index]
		if not Global.hero_data.has(hero_id):
			continue
		var unlocked := Global.is_hero_playable_in_single_player(hero_id)
		var pad := _create_hero_pad(hero_id, HERO_POSITIONS[index], unlocked)
		choices_root.add_child(pad)
		hero_pads.append({"id": hero_id, "node": pad, "unlocked": unlocked})

	for index in range(BASE_ORDER.size()):
		var base_id: String = BASE_ORDER[index]
		if not Global.base_data.has(base_id):
			continue
		var pad := _create_base_pad(base_id, BASE_POSITIONS[index])
		choices_root.add_child(pad)
		base_pads.append({"id": base_id, "node": pad})

	var tunnel_marker := Node2D.new()
	tunnel_marker.name = "TunnelStartMarker"
	tunnel_marker.position = Vector2(0, 112)
	choices_root.add_child(tunnel_marker)
	var gate := Polygon2D.new()
	gate.name = "GateGlow"
	gate.polygon = PackedVector2Array([
		Vector2(-88, -22), Vector2(88, -22), Vector2(112, 38), Vector2(-112, 38)
	])
	gate.color = Color(0.08, 0.38, 0.52, 0.28)
	tunnel_marker.add_child(gate)
	var gate_line := Line2D.new()
	gate_line.name = "GateLine"
	gate_line.points = PackedVector2Array([Vector2(-88, -22), Vector2(88, -22)])
	gate_line.width = 4.0
	gate_line.default_color = Color(0.35, 0.88, 1.0, 0.92)
	tunnel_marker.add_child(gate_line)
	var gate_label := Label.new()
	gate_label.name = "GateLabel"
	gate_label.position = Vector2(-105, -10)
	gate_label.size = Vector2(210, 28)
	gate_label.text = "DESCEND TO START"
	gate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gate_label.add_theme_font_size_override("font_size", 15)
	gate_label.add_theme_color_override("font_color", Color(0.7, 0.96, 1.0, 1.0))
	gate_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	gate_label.add_theme_constant_override("outline_size", 4)
	tunnel_marker.add_child(gate_label)

func _create_hero_pad(hero_id: String, pad_position: Vector2, unlocked: bool) -> Node2D:
	var pad := Node2D.new()
	pad.name = "Hero_%s" % hero_id.replace(" ", "_")
	pad.position = pad_position

	var disk := Polygon2D.new()
	disk.name = "Disk"
	disk.polygon = _circle_points(38.0)
	disk.color = Color(0.04, 0.09, 0.13, 0.9) if unlocked else Color(0.025, 0.04, 0.055, 0.88)
	pad.add_child(disk)

	var ring := Line2D.new()
	ring.name = "Ring"
	ring.closed = true
	ring.points = _circle_points(40.0)
	ring.width = 3.0
	ring.default_color = Color(0.28, 0.7, 0.86, 0.68) if unlocked else Color(0.25, 0.3, 0.34, 0.55)
	pad.add_child(ring)

	var sprite := Sprite2D.new()
	sprite.name = "Preview"
	var texture := Global.hero_data[hero_id]["walk"] as Texture2D
	sprite.texture = texture
	sprite.hframes = 8
	sprite.vframes = 8
	sprite.frame = 0
	var frame_height := maxf(float(texture.get_height()) / 8.0, 1.0)
	var fitted_scale := clampf(62.0 / frame_height, 0.22, 0.9)
	sprite.scale = Vector2(fitted_scale, fitted_scale)
	sprite.position = Vector2(0, -7)
	sprite.modulate = Color.WHITE if unlocked else Color(0.38, 0.42, 0.46, 0.72)
	pad.add_child(sprite)

	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(-62, 43)
	label.size = Vector2(124, 34)
	label.text = hero_id if unlocked else "%s  •  LOCKED" % hero_id
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.84, 0.94, 1.0, 1.0) if unlocked else Color(0.42, 0.49, 0.54, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.96))
	label.add_theme_constant_override("outline_size", 3)
	pad.add_child(label)
	return pad

func _create_base_pad(base_id: String, pad_position: Vector2) -> Node2D:
	var pad := Node2D.new()
	pad.name = "Base_%s" % base_id
	pad.position = pad_position

	var disk := Polygon2D.new()
	disk.name = "Disk"
	disk.polygon = _circle_points(31.0)
	disk.color = Color(0.12, 0.075, 0.025, 0.84)
	pad.add_child(disk)

	var ring := Line2D.new()
	ring.name = "Ring"
	ring.closed = true
	ring.points = _circle_points(33.0)
	ring.width = 3.0
	ring.default_color = Color(0.92, 0.58, 0.18, 0.72)
	pad.add_child(ring)

	var sprite := Sprite2D.new()
	sprite.name = "Preview"
	var texture := Global.base_data[base_id]["texture"] as Texture2D
	sprite.texture = texture
	var max_dimension := maxf(float(texture.get_width()), float(texture.get_height()))
	var fitted_scale := 66.0 / maxf(max_dimension, 1.0)
	sprite.scale = Vector2(fitted_scale, fitted_scale)
	sprite.position = Vector2(0, -3)
	pad.add_child(sprite)

	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(-66, 35)
	label.size = Vector2(132, 30)
	label.text = str(Global.base_data[base_id]["name"])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.52, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.96))
	label.add_theme_constant_override("outline_size", 3)
	pad.add_child(label)
	return pad

func _build_interface() -> void:
	interface = CanvasLayer.new()
	interface.name = "PreparationInterface"
	interface.layer = 30
	add_child(interface)

	var top_panel := Panel.new()
	top_panel.name = "TopPanel"
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 150.0
	top_panel.offset_top = 12.0
	top_panel.offset_right = -150.0
	top_panel.offset_bottom = 100.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.035, 0.045, 0.88)
	panel_style.border_color = Color(0.38, 0.68, 0.82, 0.82)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	top_panel.add_theme_stylebox_override("panel", panel_style)
	interface.add_child(top_panel)

	var title := Label.new()
	title.name = "Title"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 8.0
	title.offset_bottom = 36.0
	title.text = "PREPARE AT THE MINE ENTRANCE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.78, 0.95, 1.0, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 3)
	top_panel.add_child(title)

	loadout_label = Label.new()
	loadout_label.name = "Loadout"
	loadout_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	loadout_label.offset_top = 37.0
	loadout_label.offset_bottom = 61.0
	loadout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loadout_label.add_theme_font_size_override("font_size", 15)
	top_panel.add_child(loadout_label)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_label.offset_top = 61.0
	status_label.offset_bottom = 84.0
	status_label.text = "Walk close to a hero or base sprite to select it."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.84, 0.88, 0.92, 1.0))
	top_panel.add_child(status_label)

	var instructions := Label.new()
	instructions.name = "Instructions"
	instructions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	instructions.offset_left = 90.0
	instructions.offset_top = -58.0
	instructions.offset_right = -90.0
	instructions.offset_bottom = -18.0
	instructions.text = "Move normally  •  Choose hero and base in the real map  •  Walk down the center shaft to begin"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 14)
	instructions.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0, 1.0))
	instructions.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.94))
	instructions.add_theme_constant_override("outline_size", 4)
	interface.add_child(instructions)

func _check_hero_selection() -> void:
	var nearest: Dictionary = {}
	var nearest_distance := HERO_SELECT_RADIUS
	for entry in hero_pads:
		if not bool(entry["unlocked"]):
			continue
		var pad := entry["node"] as Node2D
		var distance := player.position.distance_to(pad.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = entry
	if nearest.is_empty():
		return
	var hero_id := str(nearest["id"])
	if Global.selected_hero_id == hero_id:
		return
	Global.selected_hero_id = hero_id
	Global.apply_selected_loadout()
	player.update_hero_sprites()
	_refresh_selection_visuals()
	_update_loadout_text()
	status_label.text = "%s selected. The player sprite changed immediately." % hero_id

func _check_base_selection() -> void:
	var nearest: Dictionary = {}
	var nearest_distance := BASE_SELECT_RADIUS
	for entry in base_pads:
		var pad := entry["node"] as Node2D
		var distance := player.position.distance_to(pad.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = entry
	if nearest.is_empty():
		return
	var base_id := str(nearest["id"])
	if Global.selected_base_id == base_id:
		return
	Global.selected_base_id = base_id
	base.refresh_base_sprite()
	_refresh_selection_visuals()
	_update_loadout_text()
	status_label.text = "%s selected. The real base sprite changed immediately." % str(Global.base_data[base_id]["name"])

func _refresh_selection_visuals() -> void:
	for entry in hero_pads:
		var selected := str(entry["id"]) == Global.selected_hero_id
		var unlocked := bool(entry["unlocked"])
		var pad := entry["node"] as Node2D
		var ring := pad.get_node("Ring") as Line2D
		var disk := pad.get_node("Disk") as Polygon2D
		if selected:
			ring.default_color = Color(0.35, 1.0, 0.72, 1.0)
			ring.width = 5.0
			disk.color = Color(0.05, 0.28, 0.2, 0.92)
		else:
			ring.default_color = Color(0.28, 0.7, 0.86, 0.68) if unlocked else Color(0.25, 0.3, 0.34, 0.55)
			ring.width = 3.0
			disk.color = Color(0.04, 0.09, 0.13, 0.9) if unlocked else Color(0.025, 0.04, 0.055, 0.88)

	for entry in base_pads:
		var selected := str(entry["id"]) == Global.selected_base_id
		var pad := entry["node"] as Node2D
		var ring := pad.get_node("Ring") as Line2D
		var disk := pad.get_node("Disk") as Polygon2D
		if selected:
			ring.default_color = Color(1.0, 0.82, 0.28, 1.0)
			ring.width = 5.0
			disk.color = Color(0.34, 0.18, 0.035, 0.94)
		else:
			ring.default_color = Color(0.92, 0.58, 0.18, 0.72)
			ring.width = 3.0
			disk.color = Color(0.12, 0.075, 0.025, 0.84)

func _update_loadout_text() -> void:
	var base_name := str(Global.base_data.get(Global.selected_base_id, Global.base_data["default_base"])["name"])
	loadout_label.text = "Hero: %s   •   Base: %s   •   Legacy Ore: %d" % [Global.selected_hero_id, base_name, Global.legacy_ore]

func _begin_run() -> void:
	_started = true
	Global.apply_selected_loadout()
	Global.save_game()
	var choices := world.get_node_or_null("LoadoutChoices")
	if choices:
		choices.queue_free()
	if interface:
		interface.queue_free()
	world.begin_run_from_preparation()
	var hud := world.get_node_or_null("HUD")
	if hud and hud.has_method("show_notice"):
		hud.show_notice("Loadout confirmed. The run starts now.", 2.2)
	queue_free()

func _circle_points(radius: float, point_count: int = 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / float(point_count)) * radius)
	return points
