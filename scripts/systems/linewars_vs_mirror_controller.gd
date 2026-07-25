extends Control

const HUB_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")
const MACHINE_CELL := Vector2i(3, 10)
const ECONOMY := preload("res://scripts/systems/linewars_economy.gd")

@onready var viewport_a: SubViewport = $Layout/Sides/SideA/Header/ViewportContainer/Viewport
@onready var viewport_b: SubViewport = $Layout/Sides/SideB/Header/ViewportContainer/Viewport
@onready var status_label: Label = $Layout/TopBar/Margin/Row/Status
@onready var side_a_status: Label = $Layout/Sides/SideA/Header/Status
@onready var side_b_status: Label = $Layout/Sides/SideB/Header/Status
@onready var switch_a_button: Button = $Layout/TopBar/Margin/Row/SwitchA
@onready var switch_b_button: Button = $Layout/TopBar/Margin/Row/SwitchB
@onready var auto_opening_button: Button = $Layout/TopBar/Margin/Row/AutoOpening
@onready var start_button: Button = $Layout/TopBar/Margin/Row/Start
@onready var gems_button: Button = $Layout/TopBar/Margin/Row/Gems
@onready var send_a_rat_button: Button = $Layout/SendBar/Margin/Row/SendARat
@onready var send_a_trogg_button: Button = $Layout/SendBar/Margin/Row/SendATrogg
@onready var send_b_rat_button: Button = $Layout/SendBar/Margin/Row/SendBRat
@onready var send_b_trogg_button: Button = $Layout/SendBar/Margin/Row/SendBTrogg
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_label: Label = $ResultPanel/Margin/Column/Result
@onready var restart_button: Button = $ResultPanel/Margin/Column/Restart

var hub_a: Node
var hub_b: Node
var world_a: Node2D
var world_b: Node2D
var controller_a: Node
var controller_b: Node
var machine_a: Node
var machine_b: Node
var side_a_ready := false
var side_b_ready := false
var match_started := false
var match_finished := false
var winner_label := ""

func _ready() -> void:
	_wire_buttons()
	_set_send_buttons_enabled(false)
	start_button.disabled = true
	status_label.text = "CREATING TWO INDEPENDENT LINEWARS SIDES..."
	await _create_side(viewport_a, "PLAYER A", 1)
	await _create_side(viewport_b, "PLAYER B", 2)
	_wire_cross_sends()
	status_label.text = "BOTH START AS PEON • P1 WASD + TAB • P2 ARROWS + SLASH • DIG 5 TILES UPWARD"
	_update_status_labels()
	_update_switch_buttons()

func _process(_delta: float) -> void:
	_update_status_labels()
	_update_send_buttons()
	_update_switch_buttons()

func _wire_buttons() -> void:
	switch_a_button.pressed.connect(_toggle_side_front.bind("A"))
	switch_b_button.pressed.connect(_toggle_side_front.bind("B"))
	auto_opening_button.pressed.connect(_complete_both_openings)
	start_button.pressed.connect(_start_match)
	gems_button.pressed.connect(_grant_test_resources)
	send_a_rat_button.pressed.connect(_queue_send.bind("A", "rat_raid"))
	send_a_trogg_button.pressed.connect(_queue_send.bind("A", "trogg_push"))
	send_b_rat_button.pressed.connect(_queue_send.bind("B", "rat_raid"))
	send_b_trogg_button.pressed.connect(_queue_send.bind("B", "trogg_push"))
	restart_button.pressed.connect(_restart_scene)

func _create_side(viewport: SubViewport, side_label: String, player_id: int) -> void:
	var hub := HUB_SCENE.instantiate()
	viewport.add_child(hub)
	await _wait_frames(8)
	var world := hub.get_node("Level") as Node2D
	var selector := hub.get_node("SinglePlayerWorldController")
	var hero := world.get_node("Player") as CharacterBody2D
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	hero.set("player_id", player_id)
	hero.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(0, -7)))
	selector.call("_activate_line_wars")
	await _wait_frames(10)
	var controller := world.get_node("ContinuousLineWarsController")
	controller.call("configure_vs_match", side_label, player_id)
	_apply_starting_economy(world)
	controller.vs_opening_ready.connect(_on_side_ready)
	controller.vs_run_finished.connect(_on_side_finished)
	var machine: Node = controller.get("war_machine_controller")
	if side_label == "PLAYER A":
		hub_a = hub
		world_a = world
		controller_a = controller
		machine_a = machine
	else:
		hub_b = hub
		world_b = world
		controller_b = controller
		machine_b = machine

func _apply_starting_economy(world: Node2D) -> void:
	# linewars_economy defines the VS opening bankroll but nothing applied it, so
	# a side started on zero gems and the War Machine could never afford a send.
	var hud := world.get_node_or_null("HUD")
	if hud == null:
		return
	var gold: Variant = hud.get("total_gold")
	if gold != null and int(gold) < ECONOMY.STARTING_GOLD and hud.has_method("add_gold"):
		hud.call("add_gold", ECONOMY.STARTING_GOLD - int(gold))
	var gems: Variant = hud.get("total_gems")
	if gems != null and int(gems) < ECONOMY.STARTING_GEMS and hud.has_method("add_gems"):
		hud.call("add_gems", ECONOMY.STARTING_GEMS - int(gems))

func _wire_cross_sends() -> void:
	if machine_a != null:
		machine_a.send_dispatched.connect(_route_send.bind("PLAYER A", controller_b))
	if machine_b != null:
		machine_b.send_dispatched.connect(_route_send.bind("PLAYER B", controller_a))

func _route_send(payload: Dictionary, sender_label: String, receiver: Node) -> void:
	if match_finished or receiver == null:
		return
	receiver.call("receive_vs_send", payload, sender_label)
	status_label.text = "%s DISPATCHED %s (HLW CD)" % [sender_label, str(payload.get("label", "PRESSURE"))]

func _toggle_side_front(side: String) -> void:
	var controller: Node = controller_a if side == "A" else controller_b
	if controller == null:
		return
	controller.call("_toggle_front")
	_update_switch_buttons()

func _update_switch_buttons() -> void:
	_apply_switch_button(switch_a_button, controller_a, "A")
	_apply_switch_button(switch_b_button, controller_b, "B")

func _apply_switch_button(button: Button, controller: Node, side: String) -> void:
	if button == null:
		return
	if controller == null:
		button.disabled = true
		button.text = "%s • LOADING" % side
		return
	if not bool(controller.get("opening_build_active")):
		button.disabled = true
		button.text = "%s • HERO" % side
		return
	button.disabled = false
	button.text = "%s → HERO" % side if bool(controller.get("peon_front_active")) else "%s → PEON" % side

func _complete_both_openings() -> void:
	await _complete_opening_for_side("A")
	await _complete_opening_for_side("B")

func _complete_opening_for_side(side: String) -> void:
	var controller: Node = controller_a if side == "A" else controller_b
	var world: Node2D = world_a if side == "A" else world_b
	if controller == null or world == null or not bool(controller.get("opening_build_active")):
		return
	# The shortcut still credits the peon front, so the carved tiles count toward
	# this side's opening exactly like hand-dug ones.
	controller.call("_set_opening_front", true)
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var peon := world.get_node("BuilderPeon") as CharacterBody2D
	var tunnel_exit: Vector2i = controller.get("tunnel_exit_cell")
	# Carving through the world rather than driving the peon's dig timer: a
	# player-controlled peon clears any queued dig on the next input-free frame,
	# so a simulated swing never lands.
	for step in range(1, 6):
		var target_cell := tunnel_exit + Vector2i.UP * step
		_force_solid(world, block_layer, target_cell)
		if world.has_method("on_cell_dug"):
			world.call("on_cell_dug", target_cell)
		peon.global_position = block_layer.to_global(block_layer.map_to_local(target_cell))
		await _wait_frames(3)
	await _wait_frames(6)

func _on_side_ready(side_label: String) -> void:
	if side_label == "PLAYER A":
		side_a_ready = true
	else:
		side_b_ready = true
	_update_switch_buttons()
	start_button.disabled = not (side_a_ready and side_b_ready)
	if side_a_ready and side_b_ready:
		status_label.text = "BOTH PEON OPENINGS DONE • START THE VS MATCH"
	else:
		status_label.text = "%s PEON READY • WAITING FOR THE OTHER OPENING" % side_label

func _start_match() -> void:
	if match_started or not side_a_ready or not side_b_ready:
		return
	match_started = true
	controller_a.call("start_vs_match")
	controller_b.call("start_vs_match")
	_reveal_war_machine(world_a, machine_a)
	_reveal_war_machine(world_b, machine_b)
	_set_send_buttons_enabled(true)
	start_button.disabled = true
	auto_opening_button.disabled = true
	status_label.text = "VS LIVE • BOTH STARTED AS PEON • SENDS USE HLW COOLDOWNS"

func _reveal_war_machine(world: Node2D, machine: Node) -> void:
	if world == null or machine == null:
		return
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	if block_layer.get_cell_source_id(MACHINE_CELL) != -1 and world.has_method("on_cell_dug"):
		world.call("on_cell_dug", MACHINE_CELL)
	if not bool(machine.get("machine_revealed")):
		machine.call("_reveal_machine")

func _grant_test_resources() -> void:
	for world_value in [world_a, world_b]:
		var world := world_value as Node2D
		if world == null:
			continue
		var hud := world.get_node("HUD")
		if hud.has_method("add_gold"):
			hud.call("add_gold", 100)
		if hud.has_method("add_gems"):
			hud.call("add_gems", 4)
	status_label.text = "PLAYTEST BOOST • BOTH SIDES RECEIVED 100 GOLD + 4 GEMS"

func _queue_send(side: String, send_id: String) -> void:
	if not match_started or match_finished:
		return
	var machine: Node = machine_a if side == "A" else machine_b
	if machine == null:
		return
	var queued := bool(machine.call("_queue_reliable_send", send_id))
	if queued:
		var definition: Dictionary = ECONOMY.send(send_id)
		status_label.text = "PLAYER %s SENT %s • CD %.0fs" % [side, str(definition.get("label", "PRESSURE")), float(definition.get("cooldown", 20.0))]

func _on_side_finished(side_label: String, victory: bool, base_health: int) -> void:
	if match_finished:
		return
	if not victory:
		winner_label = "PLAYER B" if side_label == "PLAYER A" else "PLAYER A"
		_finish_match("%s WINS\n%s BASE WAS DESTROYED" % [winner_label, side_label])
		return
	var other_controller: Node = controller_b if side_label == "PLAYER A" else controller_a
	var other_state: Dictionary = other_controller.call("get_vs_state") if other_controller else {}
	if bool(other_state.get("finished", false)):
		var other_health := int(other_state.get("base_health", 0))
		if base_health == other_health:
			_finish_match("DRAW\nBOTH BASES SURVIVED WITH %d HEALTH" % base_health)
		elif base_health > other_health:
			_finish_match("%s WINS ON BASE HEALTH\n%d TO %d" % [side_label, base_health, other_health])
		else:
			_finish_match("%s WINS ON BASE HEALTH\n%d TO %d" % [str(other_state.get("side", "OPPONENT")), other_health, base_health])

func _finish_match(message: String) -> void:
	match_finished = true
	_set_send_buttons_enabled(false)
	result_label.text = message
	result_panel.visible = true
	status_label.text = "MATCH COMPLETE"

func _set_send_buttons_enabled(enabled: bool) -> void:
	send_a_rat_button.disabled = not enabled
	send_a_trogg_button.disabled = not enabled
	send_b_rat_button.disabled = not enabled
	send_b_trogg_button.disabled = not enabled

func _update_send_buttons() -> void:
	var live := match_started and not match_finished
	_apply_send_button(send_a_rat_button, machine_a, "rat_raid", live)
	_apply_send_button(send_a_trogg_button, machine_a, "trogg_push", live)
	_apply_send_button(send_b_rat_button, machine_b, "rat_raid", live)
	_apply_send_button(send_b_trogg_button, machine_b, "trogg_push", live)

func _apply_send_button(button: Button, machine: Node, send_id: String, live: bool) -> void:
	if button == null:
		return
	var definition: Dictionary = ECONOMY.send(send_id)
	var label := str(definition.get("label", send_id))
	var cooldown := float(definition.get("cooldown", 20.0))
	var gem_cost := int(definition.get("gem_cost", 1))
	var remaining := 0.0
	if machine != null:
		var cds: Variant = machine.get("send_cooldowns")
		if cds is Dictionary:
			remaining = float(cds.get(send_id, 0.0))
	if remaining > 0.0:
		button.text = "%s  CD %.0fs" % [label, ceil(remaining)]
		button.disabled = true
	else:
		button.text = "%s  %dg  CD %.0fs" % [label, gem_cost, cooldown]
		var can_queue := live and machine != null and bool(machine.call("_can_queue_send", send_id))
		button.disabled = not can_queue

func _update_status_labels() -> void:
	side_a_status.text = _side_status_text(controller_a, world_a, "PLAYER A")
	side_b_status.text = _side_status_text(controller_b, world_b, "PLAYER B")

func _side_status_text(controller: Node, world: Node2D, label: String) -> String:
	if controller == null or world == null:
		return "%s • LOADING" % label
	var state: Dictionary = controller.call("get_vs_state")
	var build_text := "PEON DIGGING UP" if bool(controller.get("peon_front_active")) else "HERO IN MINE"
	var ready_text := "LIVE" if bool(state.get("started", false)) else ("READY" if bool(state.get("ready", false)) else build_text)
	return "%s • %s • BASE %d • GOLD %d (+%d) • GEMS %d • PRESSURE %d" % [
		label,
		ready_text,
		int(state.get("base_health", 0)),
		int(state.get("gold", 0)),
		int(state.get("passive_gold", ECONOMY.BASE_PASSIVE_GOLD)),
		int(state.get("gems", 0)),
		int(state.get("enemy_pressure", 0)),
	]

func _force_solid(world: Node2D, block_layer: TileMapLayer, cell: Vector2i) -> void:
	block_layer.set_cell(cell, 1, Vector2i.ZERO)
	var astar_value: Variant = world.get("astar")
	if astar_value != null and astar_value.is_in_bounds(cell.x, cell.y):
		astar_value.set_point_solid(cell, true)

func _restart_scene() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
