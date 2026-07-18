extends Node

signal send_queued(payload: Dictionary)
signal send_dispatched(payload: Dictionary)

const MACHINE_CELL := Vector2i(3, 10)
const INTERACT_RADIUS := 92.0
const MECH_TEXTURE := preload("res://character_sprites/mech_walk_pixelart_spritesheet.png")
const ECONOMY := preload("res://scripts/systems/linewars_economy.gd")

var world: Node2D
var hero: CharacterBody2D
var block_layer: TileMapLayer
var world_hud: CanvasLayer
var machine_root: Node2D
var prompt_label: Label
var status_label: Label
var menu_layer: CanvasLayer
var queue_label: Label
var rat_button: Button
var trogg_button: Button
var elite_button: Button
var gamble_button: Button
var machine_revealed := false
var menu_open := false
var forced_gamble_outcome := ""
var rng := RandomNumberGenerator.new()

# Kept as compatibility state for older tests/tools. Instant sending never leaves
# anything waiting in this array; dispatched_sends is the useful send history.
var send_queue: Array[Dictionary] = []
var dispatched_sends: Array[Dictionary] = []

func setup(p_world: Node2D, p_hero: CharacterBody2D, p_world_hud: CanvasLayer) -> void:
	world = p_world
	hero = p_hero
	world_hud = p_world_hud
	block_layer = world.get_node_or_null("BlockLayer") as TileMapLayer
	rng.randomize()
	_build_machine_visual()
	_build_menu()
	set_process(true)
	set_process_unhandled_input(true)

func _process(_delta: float) -> void:
	if world == null or hero == null or block_layer == null:
		return
	if not machine_revealed and block_layer.get_cell_source_id(MACHINE_CELL) == -1:
		_reveal_machine()
	if not machine_revealed:
		return
	var near := hero.global_position.distance_to(machine_root.global_position) <= INTERACT_RADIUS
	prompt_label.visible = near and not menu_open

func _unhandled_input(event: InputEvent) -> void:
	if not machine_revealed or hero == null:
		return
	if menu_open and event.is_action_pressed("ui_cancel"):
		_close_menu()
		get_viewport().set_input_as_handled()
		return
	if not menu_open and event.is_action_pressed("p1_interact"):
		if hero.global_position.distance_to(machine_root.global_position) <= INTERACT_RADIUS:
			_open_menu()
			get_viewport().set_input_as_handled()
		return
	var press_position := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		press_position = event.position
		pressed = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		press_position = event.position
		pressed = true
	if pressed and not menu_open:
		var world_position := get_viewport().get_canvas_transform().affine_inverse() * press_position
		if world_position.distance_to(machine_root.global_position) <= 68.0:
			_open_menu()
			get_viewport().set_input_as_handled()

func _build_machine_visual() -> void:
	machine_root = Node2D.new()
	machine_root.name = "GoblinWarMachine"
	machine_root.global_position = _cell_world_position(MACHINE_CELL)
	machine_root.z_index = 12
	machine_root.visible = false
	world.add_child(machine_root)

	var glow := Polygon2D.new()
	glow.polygon = _circle_points(46.0, 24)
	glow.color = Color(1.0, 0.52, 0.08, 0.18)
	machine_root.add_child(glow)

	var atlas := AtlasTexture.new()
	atlas.atlas = MECH_TEXTURE
	atlas.region = Rect2(0, 0, 64, 64)
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.scale = Vector2(1.35, 1.35)
	sprite.position = Vector2(0, -4)
	machine_root.add_child(sprite)

	prompt_label = Label.new()
	prompt_label.position = Vector2(-118, 48)
	prompt_label.size = Vector2(236, 30)
	prompt_label.text = "E / TAP • USE WAR MACHINE"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 15)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.34, 1.0))
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 4)
	prompt_label.visible = false
	machine_root.add_child(prompt_label)

	status_label = Label.new()
	status_label.position = Vector2(-110, -76)
	status_label.size = Vector2(220, 28)
	status_label.text = "GOBLIN WAR MACHINE"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.18, 1.0))
	status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	status_label.add_theme_constant_override("outline_size", 4)
	machine_root.add_child(status_label)

func _build_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.name = "WarMachineMenu"
	menu_layer.layer = 90
	menu_layer.visible = false
	add_child(menu_layer)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_layer.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_top = -296
	panel.offset_right = 330
	panel.offset_bottom = 296
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.028, 0.02, 0.98)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.95, 0.48, 0.08, 0.95)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", style)
	menu_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "GOBLIN WAR MACHINE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Gold buys reliable pressure. Risk one rare gem for a volatile Goblin gamble."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 15)
	column.add_child(subtitle)

	queue_label = Label.new()
	queue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	queue_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28, 1.0))
	column.add_child(queue_label)

	rat_button = _send_button("rat_raid", _choose_rat_raid)
	trogg_button = _send_button("trogg_push", _choose_trogg_push)
	elite_button = _send_button("elite_push", _choose_elite_push)
	gamble_button = _choice_button(
		"GOBLIN GAMBLE • %d GEM" % ECONOMY.GEM_GAMBLE_COST,
		"Jackpot attack, rare fighter, gold cache... or malfunction",
		_choose_goblin_gamble
	)
	column.add_child(rat_button)
	column.add_child(trogg_button)
	column.add_child(elite_button)
	column.add_child(gamble_button)
	var close := Button.new()
	close.custom_minimum_size = Vector2(0, 52)
	close.text = "RETURN TO MINE"
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(_close_menu)
	column.add_child(close)

func _choice_button(title: String, description: String, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 70)
	button.text = "%s\n%s" % [title, description]
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	return button

func _send_button(send_id: String, callback: Callable) -> Button:
	var definition: Dictionary = ECONOMY.send(send_id)
	return _choice_button(
		"%s • %d GOLD" % [str(definition.get("label", "SEND")), int(definition.get("gold_cost", 0))],
		str(definition.get("description", "Send pressure now")),
		callback
	)

func _reveal_machine() -> void:
	machine_revealed = true
	machine_root.visible = true
	status_label.text = "GOBLIN WAR MACHINE • ONLINE"
	_announce("WAR MACHINE UNCOVERED\nINSTANT SENDS AVAILABLE")

func _open_menu() -> void:
	if not machine_revealed:
		return
	menu_open = true
	menu_layer.visible = true
	get_tree().paused = true
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_menu()

func _close_menu() -> void:
	menu_open = false
	menu_layer.visible = false
	get_tree().paused = false

func _choose_rat_raid() -> void:
	_queue_reliable_send("rat_raid")

func _choose_trogg_push() -> void:
	_queue_reliable_send("trogg_push")

func _choose_elite_push() -> void:
	_queue_reliable_send("elite_push")

func _choose_goblin_gamble() -> void:
	_execute_gem_gamble()

func _queue_reliable_send(send_id: String) -> bool:
	var definition: Dictionary = ECONOMY.send(send_id)
	if definition.is_empty():
		return false
	return _queue_send(
		str(definition.get("label", "SEND")),
		int(definition.get("count", 1)),
		str(definition.get("enemy_type", "RAT")),
		int(definition.get("gold_cost", 0))
	)

func _queue_send(label: String, count: int, enemy_type: String, gold_cost: int) -> bool:
	if _available_gold() < gold_cost:
		_announce("WAR MACHINE NEEDS %d GOLD" % gold_cost)
		return false
	_spend_gold(gold_cost)
	var send_data := {
		"label": label,
		"count": count,
		"enemy_type": enemy_type,
		"currency": "gold",
		"gold_cost": gold_cost,
		"sent_at_msec": Time.get_ticks_msec()
	}
	_dispatch_payload(send_data)
	_announce("%s SENT\nENEMIES ENTERED THE OPPONENT TUNNEL" % label)
	_refresh_menu()
	if menu_open:
		_close_menu()
	return true

func _execute_gem_gamble() -> Dictionary:
	if _available_gems() < ECONOMY.GEM_GAMBLE_COST:
		_announce("GOBLIN GAMBLE NEEDS %d GEM" % ECONOMY.GEM_GAMBLE_COST)
		return {}
	_spend_gems(ECONOMY.GEM_GAMBLE_COST)
	var outcome: Dictionary = ECONOMY.roll_gamble(rng, forced_gamble_outcome)
	forced_gamble_outcome = ""
	var outcome_id := str(outcome.get("id", "malfunction"))
	if outcome_id == "gold_bonus":
		_add_gold(int(outcome.get("gold_bonus", 0)))
	elif int(outcome.get("count", 0)) > 0:
		var payload := {
			"label": str(outcome.get("label", "GOBLIN GAMBLE")),
			"count": int(outcome.get("count", 1)),
			"enemy_type": str(outcome.get("enemy_type", "RAT")),
			"currency": "gem_gamble",
			"gem_cost": ECONOMY.GEM_GAMBLE_COST,
			"gamble_outcome": outcome_id,
			"sent_at_msec": Time.get_ticks_msec(),
		}
		_dispatch_payload(payload)
	_announce("%s\n%s" % [str(outcome.get("label", "GOBLIN GAMBLE")), str(outcome.get("description", ""))])
	_refresh_menu()
	if menu_open:
		_close_menu()
	return outcome

func _dispatch_payload(send_data: Dictionary) -> void:
	# The signal is the small data boundary used by the mirrored and future
	# network transports. Sends arrive in the opponent tunnel in the same tick.
	send_queued.emit(send_data)
	dispatched_sends.append(send_data)
	send_dispatched.emit(send_data)

func _dispatch_next() -> void:
	# Compatibility helper for old tools. Instant sends leave no pending work.
	if send_queue.is_empty():
		return
	var send_data: Dictionary = send_queue.pop_front()
	dispatched_sends.append(send_data)
	send_dispatched.emit(send_data)
	_refresh_menu()

func _refresh_menu() -> void:
	if queue_label == null:
		return
	var gold := _available_gold()
	var gems := _available_gems()
	queue_label.text = "GOLD %d • GEMS %d • SENDS ARRIVE IMMEDIATELY" % [gold, gems]
	if rat_button:
		rat_button.disabled = gold < int(ECONOMY.send("rat_raid").get("gold_cost", 0))
	if trogg_button:
		trogg_button.disabled = gold < int(ECONOMY.send("trogg_push").get("gold_cost", 0))
	if elite_button:
		elite_button.disabled = gold < int(ECONOMY.send("elite_push").get("gold_cost", 0))
	if gamble_button:
		gamble_button.disabled = gems < ECONOMY.GEM_GAMBLE_COST

func _announce(text: String) -> void:
	var controller := get_parent()
	if controller and controller.has_method("_show_alert"):
		controller.call("_show_alert", text, 2.0)
	if controller:
		controller.set("command_message", text.replace("\n", " "))
		if controller.has_method("_update_interface"):
			controller.call("_update_interface")

func _available_gems() -> int:
	if world_hud == null:
		return 0
	var value: Variant = world_hud.get("total_gems")
	return int(value) if value != null else 0

func _available_gold() -> int:
	if world_hud == null:
		return 0
	var value: Variant = world_hud.get("total_gold")
	return int(value) if value != null else 0

func _spend_gems(amount: int) -> void:
	if world_hud and world_hud.has_method("add_gems"):
		world_hud.call("add_gems", -amount)

func _spend_gold(amount: int) -> void:
	_add_gold(-amount)

func _add_gold(amount: int) -> void:
	if world_hud and world_hud.has_method("add_gold"):
		world_hud.call("add_gold", amount)

func _cell_world_position(cell: Vector2i) -> Vector2:
	return block_layer.to_global(block_layer.map_to_local(cell))

func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
