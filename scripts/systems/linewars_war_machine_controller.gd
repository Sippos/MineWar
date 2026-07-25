extends Node

signal send_queued(payload: Dictionary)
signal send_dispatched(payload: Dictionary)

const MACHINE_CELL := Vector2i(3, 10)
const INTERACT_RADIUS := 92.0
const DISPATCH_INTERVAL := 4.0
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
var machine_revealed := false
var menu_open := false
var auto_pressure := false
var dispatch_timer := DISPATCH_INTERVAL
var send_queue: Array[Dictionary] = []
var dispatched_sends: Array[Dictionary] = []
# HLW-style per-send cooldowns (seconds remaining).
var send_cooldowns: Dictionary = {
	"rat_raid": 0.0,
	"trogg_push": 0.0,
	"elite_push": 0.0,
}

func setup(p_world: Node2D, p_hero: CharacterBody2D, p_world_hud: CanvasLayer) -> void:
	world = p_world
	hero = p_hero
	world_hud = p_world_hud
	block_layer = world.get_node_or_null("BlockLayer") as TileMapLayer
	_build_machine_visual()
	_build_menu()
	set_process(true)
	set_process_unhandled_input(true)

func _process(delta: float) -> void:
	if world == null or hero == null or block_layer == null:
		return
	# Tick cooldowns even before the machine is revealed so the first send
	# after reveal still respects the HLW gate.
	for send_id in send_cooldowns.keys():
		send_cooldowns[send_id] = maxf(float(send_cooldowns[send_id]) - delta, 0.0)
	if not machine_revealed and block_layer.get_cell_source_id(MACHINE_CELL) == -1:
		_reveal_machine()
	if not machine_revealed:
		return
	var near := hero.global_position.distance_to(machine_root.global_position) <= INTERACT_RADIUS
	prompt_label.visible = near and not menu_open
	if menu_open:
		_refresh_menu()
	if auto_pressure and send_queue.is_empty() and _can_queue_send("rat_raid"):
		_queue_reliable_send("rat_raid")
	if send_queue.is_empty():
		dispatch_timer = DISPATCH_INTERVAL
		return
	dispatch_timer = maxf(dispatch_timer - delta, 0.0)
	if dispatch_timer <= 0.0:
		_dispatch_next()
		dispatch_timer = DISPATCH_INTERVAL

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
	panel.offset_top = -235
	panel.offset_right = 330
	panel.offset_bottom = 235
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
	subtitle.text = "HLW-style sends. Each unit type has its own cooldown. Gems still matter, but the cooldown is the real gate."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 15)
	column.add_child(subtitle)

	queue_label = Label.new()
	queue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	queue_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28, 1.0))
	column.add_child(queue_label)

	rat_button = _choice_button("RAT RAID", _choose_rat_raid)
	trogg_button = _choice_button("TROGG PUSH", _choose_trogg_push)
	column.add_child(rat_button)
	column.add_child(trogg_button)
	column.add_child(_choice_button("AUTO PRESSURE", _toggle_auto_pressure))
	var close := Button.new()
	close.custom_minimum_size = Vector2(0, 52)
	close.text = "RETURN TO MINE"
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(_close_menu)
	column.add_child(close)

func _choice_button(title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 70)
	button.text = title
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	return button

func _reveal_machine() -> void:
	machine_revealed = true
	machine_root.visible = true
	status_label.text = "GOBLIN WAR MACHINE • ONLINE"
	_announce("WAR MACHINE UNCOVERED\nHLW COOLDOWNS ACTIVE")

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

func _toggle_auto_pressure() -> void:
	auto_pressure = not auto_pressure
	_refresh_menu()

func _can_queue_send(send_id: String) -> bool:
	var definition: Dictionary = ECONOMY.send(send_id)
	if definition.is_empty():
		return false
	var gem_cost := int(definition.get("gem_cost", 1))
	if _available_gems() < gem_cost:
		return false
	if float(send_cooldowns.get(send_id, 0.0)) > 0.0:
		return false
	return true

func _queue_reliable_send(send_id: String) -> bool:
	var definition: Dictionary = ECONOMY.send(send_id)
	if definition.is_empty():
		_announce("UNKNOWN SEND")
		return false
	var gem_cost := int(definition.get("gem_cost", 1))
	var cooldown := float(definition.get("cooldown", 20.0))
	var remaining := float(send_cooldowns.get(send_id, 0.0))
	if remaining > 0.0:
		_announce("%s ON COOLDOWN\n%.0fs LEFT" % [str(definition.get("label", send_id)), ceil(remaining)])
		return false
	if _available_gems() < gem_cost:
		_announce("WAR MACHINE NEEDS %d GEM%s" % [gem_cost, "S" if gem_cost != 1 else ""])
		return false
	_spend_gems(gem_cost)
	send_cooldowns[send_id] = cooldown
	var payload := {
		"id": send_id,
		"label": str(definition.get("label", send_id)),
		"count": int(definition.get("count", 1)),
		"enemy_type": str(definition.get("enemy_type", "RAT")),
		"gem_cost": gem_cost,
		"cooldown": cooldown,
		"queued_at_msec": Time.get_ticks_msec()
	}
	send_queue.append(payload)
	send_queued.emit(payload)
	_announce("%s QUEUED\nCOOLDOWN %.0fs • DISPATCH SOON" % [payload["label"], cooldown])
	_refresh_menu()
	return true

func _dispatch_next() -> void:
	if send_queue.is_empty():
		return
	var payload: Dictionary = send_queue.pop_front()
	dispatched_sends.append(payload)
	send_dispatched.emit(payload)
	_announce("%s DISPATCHED\nENEMY PRESSURE SENT" % str(payload.get("label", "SEND")))
	_refresh_menu()

func _refresh_menu() -> void:
	if queue_label == null:
		return
	var rat_cd := float(send_cooldowns.get("rat_raid", 0.0))
	var trogg_cd := float(send_cooldowns.get("trogg_push", 0.0))
	queue_label.text = "QUEUE %d • GEMS %d • AUTO %s" % [send_queue.size(), _available_gems(), "ON" if auto_pressure else "OFF"]
	if rat_button:
		var rat_def: Dictionary = ECONOMY.send("rat_raid")
		if rat_cd > 0.0:
			rat_button.text = "RAT RAID  •  CD %.0fs\n5 fast rats" % ceil(rat_cd)
			rat_button.disabled = true
		else:
			rat_button.text = "RAT RAID  •  %d GEM  •  CD %.0fs\n5 fast rats" % [int(rat_def.get("gem_cost", 1)), float(rat_def.get("cooldown", 22.0))]
			rat_button.disabled = not _can_queue_send("rat_raid")
	if trogg_button:
		var trogg_def: Dictionary = ECONOMY.send("trogg_push")
		if trogg_cd > 0.0:
			trogg_button.text = "TROGG PUSH  •  CD %.0fs\n2 durable troggs" % ceil(trogg_cd)
			trogg_button.disabled = true
		else:
			trogg_button.text = "TROGG PUSH  •  %d GEMS  •  CD %.0fs\n2 durable troggs" % [int(trogg_def.get("gem_cost", 2)), float(trogg_def.get("cooldown", 32.0))]
			trogg_button.disabled = not _can_queue_send("trogg_push")

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

func _spend_gems(amount: int) -> void:
	if world_hud and world_hud.has_method("add_gems"):
		world_hud.call("add_gems", -amount)

func _cell_world_position(cell: Vector2i) -> Vector2:
	return block_layer.to_global(block_layer.map_to_local(cell))

func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
