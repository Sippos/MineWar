extends Node

@export var world_path: NodePath = NodePath("../Level")

const RUN_SCENE := "res://scenes/boot/main.tscn"
const LINE_WARS_SCENE := "res://maze_vs_prototype.tscn"
const MINEWARS_GATE_Y := 104.0
const MINEWARS_GATE_HALF_WIDTH := 112.0
const LINE_WARS_GATE_Y := -270.0
const LINE_WARS_GATE_HALF_WIDTH := 92.0
const ADVENTURE_GATE_X := 338.0
const ADVENTURE_GATE_MIN_Y := -36.0
const ADVENTURE_GATE_MAX_Y := 108.0
const HERO_SELECT_RADIUS := 58.0
const BASE_SELECT_RADIUS := 56.0
const CHOICE_INSPECT_RADIUS := 104.0
const PREPARATION_PLAYER_START := Vector2(0, 28)
const HERO_FLOOR_CENTER := Vector2(0, 14)
const BASE_FLOAT_AMPLITUDE := 3.0
const BASE_FLOAT_SPEED := 1.55

# The characters stand like statues along the two side walls. The player has to
# physically walk around the room and approach one, rather than selecting from
# a flat row of portraits.
const HERO_ORDER := ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King", "Mech"]
const HERO_POSITIONS := [
	Vector2(-274, -202),
	Vector2(-286, -124),
	Vector2(-274, -46),
	Vector2(274, -202),
	Vector2(286, -124),
	Vector2(274, -46)
]

# Base models live on the back wall, entirely inside the carved surface room.
# Their old lower arc crossed the solid first underground row, which made
# several choices impossible to reach with the player's collision shape.
const BASE_ORDER := ["shaman_base", "nerubian_base", "default_base", "druid_base", "undead_king_base"]
const BASE_POSITIONS := [
	Vector2(-188, -222),
	Vector2(-94, -222),
	Vector2(0, -222),
	Vector2(94, -222),
	Vector2(188, -222)
]

const HERO_DETAILS := {
	"Dwarf": {
		"role": "FRONTLINE MINER",
		"summary": "Reliable close-range miner and the easiest all-round starting hero.",
		"kit": "Hammer auto-defense  •  Standard digging  •  Balanced carry"
	},
	"Shaman": {
		"role": "TOTEM SPECIALIST",
		"summary": "Controls the mine with temporary support zones.",
		"kit": "Hold E / Y  •  Dig, Heal, Radar, and Gem Totems"
	},
	"Nerubian": {
		"role": "BROOD COMMANDER",
		"summary": "Trades direct mining for a growing pack of summoned helpers.",
		"kit": "E / Y spawns Brood Spiders  •  Up to five active minions"
	},
	"Druid": {
		"role": "NATURE CASTER",
		"summary": "A flexible magic miner with a shapeshifting identity.",
		"kit": "Magic orbs while working  •  Mole-form ability slot"
	},
	"Undead King": {
		"role": "SOUL CASTER",
		"summary": "A ranged monarch built around undead pressure and control.",
		"kit": "Staff casting  •  Soul ability slot"
	},
	"Mech": {
		"role": "HEAVY FRAME",
		"summary": "An armored mining platform reserved for a later unlock.",
		"kit": "Weapon modules  •  Utility modules  •  Future unlock"
	}
}

const BASE_DETAILS := {
	"default_base": {
		"archetype": "DWARF ENGINEERING",
		"summary": "The dependable all-round bastion.",
		"upgrades": "MINECART  •  Build a cart for the dwarf rail network."
	},
	"shaman_base": {
		"archetype": "TOTEM SANCTUARY",
		"summary": "A support-focused lodge for utility-heavy runs.",
		"upgrades": "PEON  •  Recruit a worker to support the mine."
	},
	"nerubian_base": {
		"archetype": "BROOD NEST",
		"summary": "A living fortress designed around summoned defenders.",
		"upgrades": "BROOD WORKER  •  Planned faction helper for tunnel control."
	},
	"druid_base": {
		"archetype": "LIVING GROVE",
		"summary": "A regenerative base with nature-driven utility.",
		"upgrades": "GROVE WISP  •  Planned faction support for regeneration."
	},
	"undead_king_base": {
		"archetype": "SOUL CITADEL",
		"summary": "A dark stronghold built for attrition and summoned pressure.",
		"upgrades": "SOUL THRALL  •  Planned faction servant for base defense."
	}
}

var world: Node2D
var player: CharacterBody2D
var base: Node
var upgrade_menu: CanvasLayer
var hero_pads: Array[Dictionary] = []
var base_pads: Array[Dictionary] = []
var interface: CanvasLayer
var loadout_label: Label
var status_label: Label
var detail_panel: Panel
var detail_title: Label
var detail_subtitle: Label
var detail_body: Label
var detail_hint: Label
var detail_style: StyleBoxFlat
var _started := false
var _float_time := 0.0
var _nearby_kind := ""
var _nearby_id := ""

func _ready() -> void:
	world = get_node_or_null(world_path) as Node2D
	if world == null:
		push_error("Preparation controller could not find the mine world")
		return
	player = world.get_node_or_null("Player") as CharacterBody2D
	base = world.get_node_or_null("Base")
	upgrade_menu = world.get_node_or_null("UpgradeMenu") as CanvasLayer
	if player == null or base == null:
		push_error("Preparation controller requires the normal Player and Base nodes")
		return

	_disable_runtime_upgrade_menu()
	Global.apply_selected_loadout()
	player.position = PREPARATION_PLAYER_START
	player.velocity = Vector2.ZERO
	player.update_hero_sprites()
	base.refresh_base_sprite()
	# The real base remains the central showcase, but its normal upgrade prompt
	# and deposit behavior stay dormant until the run actually begins.
	base.set_process(false)
	base.set_process_input(false)
	var prompt := base.get_node_or_null("PromptLabel") as Label
	if prompt:
		prompt.visible = false
	var hud := world.get_node_or_null("HUD")
	if hud and hud.has_method("hide_objective"):
		hud.hide_objective()

	_carve_mode_routes()
	_build_world_choices()
	_build_interface()
	_refresh_selection_visuals()
	_update_loadout_text()
	_update_nearby_choice()

func _disable_runtime_upgrade_menu() -> void:
	if upgrade_menu == null:
		return
	if upgrade_menu.has_method("hide_menu"):
		upgrade_menu.hide_menu()
	upgrade_menu.set_process(false)
	upgrade_menu.set_process_input(false)

func _enable_runtime_upgrade_menu() -> void:
	if upgrade_menu == null:
		return
	upgrade_menu.visible = true
	upgrade_menu.set_process(true)
	upgrade_menu.set_process_input(true)
	if upgrade_menu.has_method("hide_menu"):
		upgrade_menu.hide_menu()

func _process(delta: float) -> void:
	if _started or world == null or player == null:
		return
	_float_time += delta
	_animate_base_previews()
	_update_nearby_choice()
	if player.position.y >= MINEWARS_GATE_Y and absf(player.position.x) <= MINEWARS_GATE_HALF_WIDTH:
		_begin_mode(GameMode.Mode.SIEGE, RUN_SCENE, "Descending into MineWars...")
	elif player.position.y <= LINE_WARS_GATE_Y and absf(player.position.x) <= LINE_WARS_GATE_HALF_WIDTH:
		_begin_mode(GameMode.Mode.LINE_WARS, LINE_WARS_SCENE, "Marching to the Line Wars battlefield...")
	elif player.position.x >= ADVENTURE_GATE_X and player.position.y >= ADVENTURE_GATE_MIN_Y and player.position.y <= ADVENTURE_GATE_MAX_Y:
		_begin_mode(GameMode.Mode.EXPLORATION, RUN_SCENE, "Setting out on an Adventure...")

func _carve_mode_routes() -> void:
	# Extend the already-existing preparation room into three readable exits.
	# Down remains the mine shaft, up becomes the battlefield road, and the
	# eastern corridor leads to Adventure.
	var previous_generation_flag := bool(world.world_generation_in_progress)
	world.world_generation_in_progress = true
	for x in range(-1, 2):
		for y in range(-7, -4):
			world.on_cell_dug(Vector2i(x, y))
	for x in range(5, 9):
		for y in range(-2, 2):
			world.on_cell_dug(Vector2i(x, y))
	world.world_generation_in_progress = previous_generation_flag

func _build_world_choices() -> void:
	var choices_root := Node2D.new()
	choices_root.name = "LoadoutChoices"
	choices_root.z_index = 7
	world.add_child(choices_root)

	var back_wall_guide := Line2D.new()
	back_wall_guide.name = "BackWallGuide"
	back_wall_guide.points = PackedVector2Array([Vector2(-224, -236), Vector2(224, -236)])
	back_wall_guide.width = 2.0
	back_wall_guide.default_color = Color(1.0, 0.68, 0.24, 0.24)
	choices_root.add_child(back_wall_guide)

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
		base_pads.append({"id": base_id, "node": pad, "phase": float(index) * 0.85})

	var tunnel_marker := Node2D.new()
	tunnel_marker.name = "MineWarsGateMarker"
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
	gate_label.text = "MINEWARS"
	gate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gate_label.add_theme_font_size_override("font_size", 15)
	gate_label.add_theme_color_override("font_color", Color(0.7, 0.96, 1.0, 1.0))
	gate_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	gate_label.add_theme_constant_override("outline_size", 4)
	tunnel_marker.add_child(gate_label)

	_create_mode_gate(choices_root, "LineWarsGateMarker", Vector2(0, -292), "LINE WARS", Color(1.0, 0.48, 0.2, 1.0), false)
	_create_mode_gate(choices_root, "AdventureGateMarker", Vector2(368, 36), "ADVENTURE", Color(0.42, 1.0, 0.48, 1.0), true)

func _create_mode_gate(parent: Node2D, gate_name: String, gate_position: Vector2, gate_text: String, accent: Color, points_right: bool) -> void:
	var marker := Node2D.new()
	marker.name = gate_name
	marker.position = gate_position
	marker.z_index = 8
	parent.add_child(marker)
	var glow := Polygon2D.new()
	if points_right:
		glow.polygon = PackedVector2Array([Vector2(-30, -66), Vector2(42, -66), Vector2(92, 0), Vector2(42, 66), Vector2(-30, 66)])
	else:
		glow.polygon = PackedVector2Array([Vector2(-92, 32), Vector2(-44, -34), Vector2(0, -78), Vector2(44, -34), Vector2(92, 32)])
	glow.color = Color(accent.r, accent.g, accent.b, 0.2)
	marker.add_child(glow)
	var outline := Line2D.new()
	outline.closed = true
	outline.points = glow.polygon
	outline.width = 4.0
	outline.default_color = Color(accent.r, accent.g, accent.b, 0.92)
	marker.add_child(outline)
	var label := Label.new()
	label.position = Vector2(-100, -12) if points_right else Vector2(-105, 20)
	label.size = Vector2(200, 30)
	label.text = gate_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", accent)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	marker.add_child(label)

func _create_hero_pad(hero_id: String, pad_position: Vector2, unlocked: bool) -> Node2D:
	var pad := Node2D.new()
	pad.name = "Hero_%s" % hero_id.replace(" ", "_")
	pad.position = pad_position

	var plinth := Polygon2D.new()
	plinth.name = "Plinth"
	plinth.polygon = PackedVector2Array([
		Vector2(-28, 5), Vector2(28, 5), Vector2(22, 23), Vector2(-22, 23)
	])
	plinth.color = Color(0.045, 0.09, 0.12, 0.88) if unlocked else Color(0.035, 0.045, 0.055, 0.78)
	pad.add_child(plinth)

	var disk := Polygon2D.new()
	disk.name = "Disk"
	disk.position = HERO_FLOOR_CENTER
	disk.polygon = _ellipse_points(Vector2(31, 13))
	disk.color = Color(0.03, 0.13, 0.17, 0.72) if unlocked else Color(0.025, 0.04, 0.055, 0.58)
	pad.add_child(disk)

	var ring := Line2D.new()
	ring.name = "Ring"
	ring.position = HERO_FLOOR_CENTER
	ring.closed = true
	ring.points = _ellipse_points(Vector2(35, 16))
	ring.width = 2.0
	ring.default_color = Color(0.28, 0.78, 0.92, 0.72) if unlocked else Color(0.25, 0.3, 0.34, 0.48)
	pad.add_child(ring)

	var sprite := Sprite2D.new()
	sprite.name = "Preview"
	var texture := Global.hero_data[hero_id]["walk"] as Texture2D
	sprite.texture = texture
	sprite.hframes = 8
	sprite.vframes = 8
	var frame_width := maxf(float(texture.get_width()) / 8.0, 1.0)
	var frame_height := maxf(float(texture.get_height()) / 8.0, 1.0)
	var fitted_scale := minf(64.0 / frame_width, 76.0 / frame_height)
	fitted_scale = clampf(fitted_scale, 0.22, 0.92)
	sprite.scale = Vector2(fitted_scale, fitted_scale)
	sprite.position = Vector2(0, -25)
	# Statues on opposite walls look inward toward the room and player.
	sprite.frame = (6 if pad_position.x < 0.0 else 2) * 8
	sprite.modulate = Color.WHITE if unlocked else Color(0.34, 0.38, 0.42, 0.66)
	pad.add_child(sprite)

	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(-62, 34)
	label.size = Vector2(124, 24)
	label.text = hero_id
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.84, 0.94, 1.0, 1.0) if unlocked else Color(0.42, 0.49, 0.54, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.96))
	label.add_theme_constant_override("outline_size", 3)
	pad.add_child(label)

	if not unlocked:
		var locked_label := Label.new()
		locked_label.name = "LockedLabel"
		locked_label.position = Vector2(-42, -70)
		locked_label.size = Vector2(84, 18)
		locked_label.text = "LOCKED"
		locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked_label.add_theme_font_size_override("font_size", 8)
		locked_label.add_theme_color_override("font_color", Color(0.5, 0.56, 0.6, 0.96))
		locked_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.96))
		locked_label.add_theme_constant_override("outline_size", 2)
		pad.add_child(locked_label)
	return pad

func _create_base_pad(base_id: String, pad_position: Vector2) -> Node2D:
	var pad := Node2D.new()
	pad.name = "Base_%s" % base_id
	pad.position = pad_position

	var disk := Polygon2D.new()
	disk.name = "Disk"
	disk.position = Vector2(0, 13)
	disk.polygon = _ellipse_points(Vector2(31, 12))
	disk.color = Color(0.18, 0.105, 0.025, 0.58)
	pad.add_child(disk)

	var ring := Line2D.new()
	ring.name = "Ring"
	ring.position = Vector2(0, 13)
	ring.closed = true
	ring.points = _ellipse_points(Vector2(35, 15))
	ring.width = 2.0
	ring.default_color = Color(0.95, 0.62, 0.2, 0.7)
	pad.add_child(ring)

	var hover := Node2D.new()
	hover.name = "Hover"
	pad.add_child(hover)

	var sprite := Sprite2D.new()
	sprite.name = "Preview"
	var texture := Global.base_data[base_id]["texture"] as Texture2D
	sprite.texture = texture
	var texture_width := maxf(float(texture.get_width()), 1.0)
	var texture_height := maxf(float(texture.get_height()), 1.0)
	var fitted_scale := minf(78.0 / texture_width, 64.0 / texture_height)
	sprite.scale = Vector2(fitted_scale, fitted_scale)
	sprite.position = Vector2(0, -18)
	hover.add_child(sprite)

	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(-66, 31)
	label.size = Vector2(132, 26)
	label.text = str(Global.base_data[base_id]["name"])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.52, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.96))
	label.add_theme_constant_override("outline_size", 3)
	hover.add_child(label)
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
	panel_style.bg_color = Color(0.025, 0.035, 0.045, 0.9)
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
	title.text = "PREPARE, THEN CHOOSE YOUR PATH"
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
	status_label.text = "Choose a hero and base, then go up, down, or right to begin."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.84, 0.88, 0.92, 1.0))
	top_panel.add_child(status_label)

	detail_panel = Panel.new()
	detail_panel.name = "ChoiceDetails"
	detail_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	detail_panel.offset_left = 220.0
	detail_panel.offset_top = 108.0
	detail_panel.offset_right = -220.0
	detail_panel.offset_bottom = 216.0
	detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.018, 0.028, 0.04, 0.94)
	detail_style.border_color = Color(0.32, 0.78, 0.96, 0.9)
	detail_style.set_border_width_all(2)
	detail_style.set_corner_radius_all(8)
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	interface.add_child(detail_panel)

	detail_title = Label.new()
	detail_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	detail_title.offset_left = 14.0
	detail_title.offset_top = 7.0
	detail_title.offset_right = -14.0
	detail_title.offset_bottom = 32.0
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_title.add_theme_font_size_override("font_size", 17)
	detail_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	detail_title.add_theme_constant_override("outline_size", 3)
	detail_panel.add_child(detail_title)

	detail_subtitle = Label.new()
	detail_subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	detail_subtitle.offset_left = 14.0
	detail_subtitle.offset_top = 31.0
	detail_subtitle.offset_right = -14.0
	detail_subtitle.offset_bottom = 51.0
	detail_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_subtitle.add_theme_font_size_override("font_size", 11)
	detail_panel.add_child(detail_subtitle)

	detail_body = Label.new()
	detail_body.set_anchors_preset(Control.PRESET_TOP_WIDE)
	detail_body.offset_left = 18.0
	detail_body.offset_top = 51.0
	detail_body.offset_right = -18.0
	detail_body.offset_bottom = 84.0
	detail_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body.add_theme_font_size_override("font_size", 12)
	detail_body.add_theme_color_override("font_color", Color(0.84, 0.9, 0.94, 1.0))
	detail_panel.add_child(detail_body)

	detail_hint = Label.new()
	detail_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	detail_hint.offset_left = 14.0
	detail_hint.offset_top = 84.0
	detail_hint.offset_right = -14.0
	detail_hint.offset_bottom = 104.0
	detail_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_hint.add_theme_font_size_override("font_size", 10)
	detail_panel.add_child(detail_hint)
	detail_panel.visible = false

	var instructions := Label.new()
	instructions.name = "Instructions"
	instructions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	instructions.offset_left = 90.0
	instructions.offset_top = -58.0
	instructions.offset_right = -90.0
	instructions.offset_bottom = -18.0
	instructions.text = "↑ LINE WARS   •   ↓ MINEWARS   •   → ADVENTURE   •   Approach statues to change hero or base"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 14)
	instructions.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0, 1.0))
	instructions.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.94))
	instructions.add_theme_constant_override("outline_size", 4)
	interface.add_child(instructions)

func _update_nearby_choice() -> void:
	var nearest_kind := ""
	var nearest_entry: Dictionary = {}
	var nearest_distance := CHOICE_INSPECT_RADIUS

	for entry in hero_pads:
		var pad := entry["node"] as Node2D
		var distance := player.position.distance_to(pad.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_kind = "hero"
			nearest_entry = entry

	for entry in base_pads:
		var pad := entry["node"] as Node2D
		var distance := player.position.distance_to(pad.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_kind = "base"
			nearest_entry = entry

	var nearest_id := str(nearest_entry.get("id", ""))
	if nearest_kind != _nearby_kind or nearest_id != _nearby_id:
		_nearby_kind = nearest_kind
		_nearby_id = nearest_id
		_refresh_selection_visuals()

	if nearest_entry.is_empty():
		detail_panel.visible = false
		status_label.text = "Choose a hero and base, then go up, down, or right to begin."
		return

	if nearest_kind == "hero" and nearest_distance <= HERO_SELECT_RADIUS:
		_select_hero(nearest_entry)
	elif nearest_kind == "base" and nearest_distance <= BASE_SELECT_RADIUS:
		_select_base(nearest_entry)
	_show_choice_details(nearest_kind, nearest_entry, nearest_distance)

func _select_hero(entry: Dictionary) -> void:
	if not bool(entry["unlocked"]):
		return
	var hero_id := str(entry["id"])
	if Global.selected_hero_id == hero_id:
		return
	Global.selected_hero_id = hero_id
	Global.apply_selected_loadout()
	player.update_hero_sprites()
	_refresh_selection_visuals()
	_update_loadout_text()

func _select_base(entry: Dictionary) -> void:
	var base_id := str(entry["id"])
	if Global.selected_base_id == base_id:
		return
	Global.selected_base_id = base_id
	base.refresh_base_sprite()
	_refresh_selection_visuals()
	_update_loadout_text()

func _show_choice_details(kind: String, entry: Dictionary, distance: float) -> void:
	detail_panel.visible = true
	var choice_id := str(entry["id"])
	if kind == "hero":
		var data: Dictionary = HERO_DETAILS.get(choice_id, {})
		var unlocked := bool(entry["unlocked"])
		var selected := Global.selected_hero_id == choice_id
		detail_style.border_color = Color(0.3, 0.86, 1.0, 0.95) if unlocked else Color(0.38, 0.43, 0.48, 0.9)
		detail_title.text = choice_id.to_upper()
		detail_title.add_theme_color_override("font_color", Color(0.62, 0.95, 1.0, 1.0) if unlocked else Color(0.56, 0.6, 0.64, 1.0))
		detail_subtitle.text = str(data.get("role", "HERO"))
		detail_subtitle.add_theme_color_override("font_color", Color(0.4, 0.8, 0.94, 1.0) if unlocked else Color(0.48, 0.52, 0.56, 1.0))
		detail_body.text = "%s\nKIT PREVIEW  •  %s" % [str(data.get("summary", "")), str(data.get("kit", ""))]
		if not unlocked:
			var unlock_text := "Complete the first level to unlock." if Global.FIRST_LEVEL_REWARD_HEROES.has(choice_id) else "Reserved for a future unlock."
			detail_hint.text = "LOCKED  •  %s" % unlock_text
			detail_hint.add_theme_color_override("font_color", Color(0.66, 0.68, 0.7, 1.0))
			status_label.text = "%s is locked, but its kit can still be inspected." % choice_id
		elif selected:
			detail_hint.text = "SELECTED  •  This hero will enter the selected destination."
			detail_hint.add_theme_color_override("font_color", Color(0.38, 1.0, 0.68, 1.0))
			status_label.text = "%s selected. Walk to another statue to change hero." % choice_id
		else:
			detail_hint.text = "MOVE CLOSER TO SELECT  •  %.0f px" % maxf(distance - HERO_SELECT_RADIUS, 0.0)
			detail_hint.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0, 1.0))
			status_label.text = "Inspecting %s. Step inside its floor marker to select." % choice_id
	else:
		var data: Dictionary = BASE_DETAILS.get(choice_id, {})
		var base_name := str(Global.base_data[choice_id]["name"])
		var selected := Global.selected_base_id == choice_id
		detail_style.border_color = Color(1.0, 0.7, 0.24, 0.95)
		detail_title.text = base_name.to_upper()
		detail_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5, 1.0))
		detail_subtitle.text = str(data.get("archetype", "BASE"))
		detail_subtitle.add_theme_color_override("font_color", Color(1.0, 0.66, 0.25, 1.0))
		detail_body.text = "%s\nUPGRADE PREVIEW  •  %s" % [str(data.get("summary", "")), str(data.get("upgrades", ""))]
		if selected:
			detail_hint.text = "SELECTED  •  This base will anchor the run."
			detail_hint.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38, 1.0))
			status_label.text = "%s selected. Its upgrade path is previewed below." % base_name
		else:
			detail_hint.text = "MOVE CLOSER TO SELECT  •  %.0f px" % maxf(distance - BASE_SELECT_RADIUS, 0.0)
			detail_hint.add_theme_color_override("font_color", Color(1.0, 0.84, 0.55, 1.0))
			status_label.text = "Inspecting %s. Step inside its floor marker to select." % base_name

func _refresh_selection_visuals() -> void:
	for entry in hero_pads:
		var hero_id := str(entry["id"])
		var selected := hero_id == Global.selected_hero_id
		var hovered := _nearby_kind == "hero" and hero_id == _nearby_id
		var unlocked := bool(entry["unlocked"])
		var pad := entry["node"] as Node2D
		var ring := pad.get_node("Ring") as Line2D
		var disk := pad.get_node("Disk") as Polygon2D
		if selected:
			ring.default_color = Color(0.35, 1.0, 0.72, 1.0)
			ring.width = 5.0
			disk.color = Color(0.05, 0.28, 0.2, 0.94)
			pad.scale = Vector2(1.08, 1.08)
		elif hovered:
			ring.default_color = Color(0.36, 0.9, 1.0, 1.0) if unlocked else Color(0.48, 0.52, 0.56, 0.9)
			ring.width = 4.0
			disk.color = Color(0.045, 0.18, 0.23, 0.92) if unlocked else Color(0.04, 0.055, 0.065, 0.9)
			pad.scale = Vector2(1.04, 1.04)
		else:
			ring.default_color = Color(0.28, 0.7, 0.86, 0.68) if unlocked else Color(0.25, 0.3, 0.34, 0.55)
			ring.width = 2.0
			disk.color = Color(0.04, 0.09, 0.13, 0.9) if unlocked else Color(0.025, 0.04, 0.055, 0.88)
			pad.scale = Vector2.ONE

	for entry in base_pads:
		var base_id := str(entry["id"])
		var selected := base_id == Global.selected_base_id
		var hovered := _nearby_kind == "base" and base_id == _nearby_id
		var pad := entry["node"] as Node2D
		var ring := pad.get_node("Ring") as Line2D
		var disk := pad.get_node("Disk") as Polygon2D
		if selected:
			ring.default_color = Color(1.0, 0.82, 0.28, 1.0)
			ring.width = 5.0
			disk.color = Color(0.34, 0.18, 0.035, 0.94)
			pad.scale = Vector2(1.08, 1.08)
		elif hovered:
			ring.default_color = Color(1.0, 0.72, 0.28, 1.0)
			ring.width = 4.0
			disk.color = Color(0.24, 0.13, 0.03, 0.92)
			pad.scale = Vector2(1.04, 1.04)
		else:
			ring.default_color = Color(0.92, 0.58, 0.18, 0.72)
			ring.width = 2.0
			disk.color = Color(0.12, 0.075, 0.025, 0.84)
			pad.scale = Vector2.ONE

func _update_loadout_text() -> void:
	var base_name := str(Global.base_data.get(Global.selected_base_id, Global.base_data["default_base"])["name"])
	loadout_label.text = "Hero: %s   •   Base: %s   •   Legacy Ore: %d" % [Global.selected_hero_id, base_name, Global.legacy_ore]

func _begin_mode(mode: GameMode.Mode, scene_path: String, transition_text: String) -> void:
	if _started:
		return
	_started = true
	GameMode.set_mode(mode)
	Global.apply_selected_loadout()
	Global.save_game()
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	status_label.text = transition_text
	await get_tree().create_timer(0.16).timeout
	get_tree().change_scene_to_file(scene_path)

func _animate_base_previews() -> void:
	for entry in base_pads:
		var pad := entry["node"] as Node2D
		var hover := pad.get_node_or_null("Hover") as Node2D
		if hover == null:
			continue
		var phase := float(entry.get("phase", 0.0))
		hover.position.y = sin(_float_time * BASE_FLOAT_SPEED + phase) * BASE_FLOAT_AMPLITUDE

func _ellipse_points(radii: Vector2, point_count: int = 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points
