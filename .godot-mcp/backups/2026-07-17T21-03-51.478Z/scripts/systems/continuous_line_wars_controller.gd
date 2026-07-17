extends Node

const BUILDER_PEON_SCENE := preload("res://scenes/entities/workers/peon/builder_peon_player.tscn")
const HUD_SCENE := preload("res://scenes/ui/overlays/continuous_line_wars_hud.tscn")
const SURFACE_MIN_CELL := Vector2i(-9, -30)
const SURFACE_MAX_CELL := Vector2i(9, -23)

var breakthrough_position := Vector2.ZERO
var world: Node2D
var block_layer: TileMapLayer
var hero: CharacterBody2D
var peon: CharacterBody2D
var hud: CanvasLayer
var mode_label: Label
var hint_label: Label
var switch_button: Button
var peon_active := true

func _ready() -> void:
	world = get_parent() as Node2D
	block_layer = world.get_node_or_null("BlockLayer") as TileMapLayer
	hero = world.get_node_or_null("Player") as CharacterBody2D
	if world == null or block_layer == null or hero == null:
		push_error("Continuous LineWars requires the persistent mine world")
		queue_free()
		return

	world.set_meta("continuous_line_wars_active", true)
	_ensure_switch_action()
	_spawn_peon()
	_build_hud()
	_apply_control()

func _spawn_peon() -> void:
	peon = BUILDER_PEON_SCENE.instantiate() as CharacterBody2D
	peon.name = "BuilderPeon"
	# Keep both avatars in the same physical location at breakthrough, with a
	# small readable offset. The hero is never moved back to a separate mine.
	peon.global_position = breakthrough_position + Vector2(44, 0)
	peon.set("movement_bounds", _surface_movement_bounds())
	world.add_child(peon)
	peon.call("set_controlled", true)
	peon.set("awaiting_neutral_input", false)

	hero.velocity = Vector2.ZERO
	hero.visible = true

func _build_hud() -> void:
	hud = HUD_SCENE.instantiate() as CanvasLayer
	add_child(hud)
	mode_label = hud.get_node("TopBar/Margin/Row/Mode") as Label
	switch_button = hud.get_node("TopBar/Margin/Row/Switch") as Button
	hint_label = hud.get_node("HintPanel/Margin/Hint") as Label
	switch_button.pressed.connect(_toggle_front)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("switch_front"):
		_toggle_front()

func _toggle_front() -> void:
	peon_active = not peon_active
	_apply_control()

func _apply_control() -> void:
	if peon == null or hero == null:
		return
	peon.call("set_controlled", peon_active)
	peon.visible = true

	hero.velocity = Vector2.ZERO
	hero.visible = true
	hero.process_mode = Node.PROCESS_MODE_DISABLED if peon_active else Node.PROCESS_MODE_INHERIT
	var hero_camera := hero.get_node_or_null("Camera2D") as Camera2D
	if hero_camera:
		hero_camera.enabled = not peon_active

	mode_label.text = "PEON • LINEWARS SURFACE" if peon_active else "HERO • SHARED MINE"
	switch_button.text = "SWITCH TO HERO" if peon_active else "SWITCH TO PEON"
	hint_label.text = (
		"Build and shape the real upper terrain. The hero remains exactly where the breakthrough happened."
		if peon_active
		else
		"Mine downward in the same persistent map, return to the base, or climb back to the surface."
	)

func _surface_movement_bounds() -> Rect2:
	var top_left := block_layer.to_global(block_layer.map_to_local(SURFACE_MIN_CELL)) - Vector2(28, 28)
	var bottom_right := block_layer.to_global(block_layer.map_to_local(SURFACE_MAX_CELL)) + Vector2(28, 28)
	return Rect2(top_left, bottom_right - top_left)

func _ensure_switch_action() -> void:
	if not InputMap.has_action("switch_front"):
		InputMap.add_action("switch_front")
	var has_tab := false
	var has_shoulder := false
	for existing in InputMap.action_get_events("switch_front"):
		if existing is InputEventKey and existing.physical_keycode == KEY_TAB:
			has_tab = true
		elif existing is InputEventJoypadButton and existing.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			has_shoulder = true
	if not has_tab:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_TAB
		InputMap.action_add_event("switch_front", key_event)
	if not has_shoulder:
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = JOY_BUTTON_RIGHT_SHOULDER
		InputMap.action_add_event("switch_front", joy_event)
