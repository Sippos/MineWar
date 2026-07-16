extends Node2D

const RUN_SCENE := "res://scenes/boot/main.tscn"
const MAIN_MENU_SCENE := "res://scenes/menus/main/menu.tscn"
const BASE_DISPLAY_NAMES := {
	"default_base": "First Bastion"
}
const UPGRADE_PAD_RADIUS := 74.0
const UPGRADE_DATA := {
	"reinforced_core": {
		"title": "REINFORCED CORE",
		"description": "+15 starting base HP per rank",
		"position": Vector2(-185, -40),
		"color": Color(1.0, 0.45, 0.18, 1.0)
	},
	"starter_cache": {
		"title": "STARTER CACHE",
		"description": "+1 starting gem per rank",
		"position": Vector2(0, -155),
		"color": Color(0.2, 0.95, 1.0, 1.0)
	},
	"miners_harness": {
		"title": "MINER'S HARNESS",
		"description": "+1 free gem carry per rank",
		"position": Vector2(185, -40),
		"color": Color(0.45, 1.0, 0.42, 1.0)
	}
}

@onready var player: CharacterBody2D = $Irlicht
@onready var tunnel_gate: Area2D = $TunnelGate
@onready var loadout_label: Label = $Interface/TopPanel/Margin/VBox/Loadout
@onready var status_label: Label = $Interface/TopPanel/Margin/VBox/Status
@onready var instructions_label: Label = $Interface/Instructions
@onready var fade: ColorRect = $Interface/Fade

var _transitioning := false
var _nearby_upgrade_id := ""

func _ready() -> void:
	_ensure_movement_input()
	_ensure_key_action("p1_interact", KEY_E)
	_ensure_button_action("p1_interact", JOY_BUTTON_Y)
	Global.apply_selected_loadout()
	_update_loadout_text()
	tunnel_gate.body_entered.connect(_on_tunnel_body_entered)
	fade.modulate.a = 0.0
	instructions_label.text = "WASD / Left Stick  •  E / Y upgrades a nearby legacy pad  •  Enter the tunnel to begin  •  Esc / B returns"
	_refresh_nearby_upgrade()
	queue_redraw()

func _process(_delta: float) -> void:
	if _transitioning:
		return
	_refresh_nearby_upgrade()

func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return
	if event.is_action_pressed("p1_interact") and not _nearby_upgrade_id.is_empty():
		_purchase_nearby_upgrade()

func _update_loadout_text() -> void:
	var base_name := str(BASE_DISPLAY_NAMES.get(Global.selected_base_id, Global.selected_base_id.capitalize()))
	loadout_label.text = "Current Loadout  •  %s  •  %s  •  Legacy Ore %d" % [Global.selected_hero_id, base_name, Global.legacy_ore]

func _refresh_nearby_upgrade() -> void:
	var nearest_id := ""
	var nearest_distance := UPGRADE_PAD_RADIUS
	for upgrade_id in UPGRADE_DATA:
		var pad_position: Vector2 = UPGRADE_DATA[upgrade_id]["position"]
		var distance := player.position.distance_to(pad_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_id = upgrade_id
	if nearest_id != _nearby_upgrade_id:
		_nearby_upgrade_id = nearest_id
		queue_redraw()
	_update_status_text()

func _update_status_text() -> void:
	if _nearby_upgrade_id.is_empty():
		status_label.text = "Earn Legacy Ore from every run. Walk to a glowing workshop pad to buy permanent upgrades."
		return
	var data: Dictionary = UPGRADE_DATA[_nearby_upgrade_id]
	var level := Global.get_permanent_upgrade_level(_nearby_upgrade_id)
	var max_level := int(Global.PERMANENT_UPGRADE_MAX_LEVELS[_nearby_upgrade_id])
	if Global.is_permanent_upgrade_maxed(_nearby_upgrade_id):
		status_label.text = "%s  •  MAX LEVEL  •  %s" % [data["title"], data["description"]]
		return
	var cost := Global.get_permanent_upgrade_cost(_nearby_upgrade_id)
	if Global.legacy_ore >= cost:
		status_label.text = "E / Y  •  BUY %s  •  %d ORE  •  Lv %d/%d  •  %s" % [data["title"], cost, level, max_level, data["description"]]
	else:
		status_label.text = "%s  •  NEED %d ORE  •  Lv %d/%d  •  %s" % [data["title"], cost, level, max_level, data["description"]]

func _purchase_nearby_upgrade() -> void:
	var upgrade_id := _nearby_upgrade_id
	if Global.purchase_permanent_upgrade(upgrade_id):
		var data: Dictionary = UPGRADE_DATA[upgrade_id]
		status_label.text = "%s UPGRADED  •  Permanent bonus active next run" % data["title"]
		var sound_fx := get_node_or_null("/root/SoundFX")
		if sound_fx:
			sound_fx.play_upgrade()
		var pulse := create_tween()
		pulse.tween_property(player, "scale", Vector2(1.22, 1.22), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pulse.tween_property(player, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		var cost := Global.get_permanent_upgrade_cost(upgrade_id)
		status_label.text = "Not enough Legacy Ore  •  Need %d" % cost
	_update_loadout_text()
	queue_redraw()

func _on_tunnel_body_entered(body: Node) -> void:
	if _transitioning or body != player:
		return
	_transitioning = true
	player.movement_enabled = false
	Global.apply_selected_loadout()
	Global.save_game()
	status_label.text = "Loadout confirmed. Descending into the mine..."
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.42)
	await tween.finished
	get_tree().change_scene_to_file(RUN_SCENE)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-640, -360, 1280, 760), Color(0.018, 0.028, 0.055, 1.0))
	for x in range(-640, 641, 64):
		draw_line(Vector2(x, -300), Vector2(x, 360), Color(0.09, 0.15, 0.22, 0.24), 1.0)
	for y in range(-300, 361, 64):
		draw_line(Vector2(-640, y), Vector2(640, y), Color(0.09, 0.15, 0.22, 0.24), 1.0)

	draw_circle(Vector2.ZERO, 158.0, Color(0.05, 0.16, 0.24, 0.9))
	draw_arc(Vector2.ZERO, 158.0, 0.0, TAU, 96, Color(0.22, 0.72, 0.9, 0.55), 4.0)
	draw_arc(Vector2.ZERO, 116.0, 0.0, TAU, 96, Color(0.17, 0.45, 0.62, 0.5), 2.0)
	var altar_points := PackedVector2Array([
		Vector2(-58, 48), Vector2(-42, 0), Vector2(-22, -24),
		Vector2(22, -24), Vector2(42, 0), Vector2(58, 48)
	])
	draw_colored_polygon(altar_points, Color(0.12, 0.21, 0.29, 1.0))
	draw_polyline(altar_points + PackedVector2Array([altar_points[0]]), Color(0.48, 0.78, 0.9, 0.8), 3.0)
	draw_circle(Vector2(0, 5), 20.0, Color(0.95, 0.55, 0.16, 0.22))
	draw_circle(Vector2(0, 5), 9.0, Color(1.0, 0.78, 0.3, 0.95))
	draw_string(font, Vector2(-110, 80), "LEGACY WORKSHOP", HORIZONTAL_ALIGNMENT_CENTER, 220, 17, Color(1.0, 0.86, 0.48))
	draw_string(font, Vector2(-105, 103), "ORE  %d" % Global.legacy_ore, HORIZONTAL_ALIGNMENT_CENTER, 210, 15, Color(1.0, 0.68, 0.22))
	draw_string(font, Vector2(-115, 126), "BASE SELECTOR LOCKED", HORIZONTAL_ALIGNMENT_CENTER, 230, 12, Color(0.44, 0.56, 0.65))

	for upgrade_id in UPGRADE_DATA:
		var data: Dictionary = UPGRADE_DATA[upgrade_id]
		var pad_position: Vector2 = data["position"]
		var pad_color: Color = data["color"]
		var level := Global.get_permanent_upgrade_level(upgrade_id)
		var max_level := int(Global.PERMANENT_UPGRADE_MAX_LEVELS[upgrade_id])
		var maxed := Global.is_permanent_upgrade_maxed(upgrade_id)
		var affordable := Global.legacy_ore >= Global.get_permanent_upgrade_cost(upgrade_id)
		var selected: bool = str(upgrade_id) == _nearby_upgrade_id
		var fill_alpha := 0.26 if affordable else 0.12
		if maxed:
			fill_alpha = 0.18
		draw_circle(pad_position, 48.0, Color(pad_color.r, pad_color.g, pad_color.b, fill_alpha))
		draw_arc(pad_position, 48.0, 0.0, TAU, 48, pad_color if selected else Color(pad_color.r, pad_color.g, pad_color.b, 0.55), 5.0 if selected else 3.0)
		draw_circle(pad_position, 13.0, Color(pad_color.r, pad_color.g, pad_color.b, 0.9))
		draw_string(font, pad_position + Vector2(-82, 69), str(data["title"]), HORIZONTAL_ALIGNMENT_CENTER, 164, 13, Color(0.88, 0.94, 1.0))
		draw_string(font, pad_position + Vector2(-68, 88), "Lv %d / %d" % [level, max_level], HORIZONTAL_ALIGNMENT_CENTER, 136, 12, Color(0.65, 0.78, 0.88))
		var price_text := "MAX" if maxed else "%d ORE" % Global.get_permanent_upgrade_cost(upgrade_id)
		draw_string(font, pad_position + Vector2(-58, 106), price_text, HORIZONTAL_ALIGNMENT_CENTER, 116, 12, Color(1.0, 0.78, 0.3) if affordable or maxed else Color(0.6, 0.48, 0.34))

	var plinths := [Vector2(-390, -120), Vector2(390, -120), Vector2(-390, 125), Vector2(390, 125)]
	for plinth in plinths:
		draw_circle(plinth, 52.0, Color(0.055, 0.085, 0.12, 0.95))
		draw_arc(plinth, 52.0, 0.0, TAU, 48, Color(0.19, 0.28, 0.36, 0.7), 3.0)
		draw_line(plinth + Vector2(-13, -13), plinth + Vector2(13, 13), Color(0.33, 0.42, 0.49, 0.75), 4.0)
		draw_line(plinth + Vector2(13, -13), plinth + Vector2(-13, 13), Color(0.33, 0.42, 0.49, 0.75), 4.0)
		draw_string(font, plinth + Vector2(-55, 76), "HERO DORMANT", HORIZONTAL_ALIGNMENT_CENTER, 110, 12, Color(0.36, 0.45, 0.53))

	draw_colored_polygon(PackedVector2Array([
		Vector2(-126, 175), Vector2(126, 175), Vector2(176, 360), Vector2(-176, 360)
	]), Color(0.025, 0.045, 0.075, 1.0))
	draw_line(Vector2(-126, 175), Vector2(-176, 360), Color(0.19, 0.55, 0.72, 0.75), 4.0)
	draw_line(Vector2(126, 175), Vector2(176, 360), Color(0.19, 0.55, 0.72, 0.75), 4.0)
	draw_arc(Vector2(0, 250), 90.0, PI, TAU, 48, Color(0.35, 0.84, 1.0, 0.9), 5.0)
	draw_string(font, Vector2(-95, 296), "ENTER THE MINE", HORIZONTAL_ALIGNMENT_CENTER, 190, 18, Color(0.72, 0.94, 1.0))

func _ensure_movement_input() -> void:
	_ensure_key_action("p1_left", KEY_A)
	_ensure_key_action("p1_right", KEY_D)
	_ensure_key_action("p1_up", KEY_W)
	_ensure_key_action("p1_down", KEY_S)
	_ensure_axis_action("p1_left", JOY_AXIS_LEFT_X, -1.0)
	_ensure_axis_action("p1_right", JOY_AXIS_LEFT_X, 1.0)
	_ensure_axis_action("p1_up", JOY_AXIS_LEFT_Y, -1.0)
	_ensure_axis_action("p1_down", JOY_AXIS_LEFT_Y, 1.0)

func _ensure_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var input_event := InputEventKey.new()
	input_event.physical_keycode = keycode
	InputMap.action_add_event(action, input_event)

func _ensure_button_action(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and existing.button_index == button:
			return
	var input_event := InputEventJoypadButton.new()
	input_event.button_index = button
	input_event.device = 0
	InputMap.action_add_event(action, input_event)

func _ensure_axis_action(action: StringName, axis: JoyAxis, axis_value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadMotion and existing.axis == axis and is_equal_approx(existing.axis_value, axis_value):
			return
	var input_event := InputEventJoypadMotion.new()
	input_event.axis = axis
	input_event.axis_value = axis_value
	input_event.device = 0
	InputMap.action_add_event(action, input_event)
