extends Node

const SINGLE_PLAYER_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")

var failures := 0

func _ready() -> void:
	await _run_test()
	if failures == 0:
		print("LINEWARS_TOUCH_COMMAND_SMOKE_PASS")
		get_tree().quit(0)
	else:
		push_error("LINEWARS_TOUCH_COMMAND_SMOKE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

func _run_test() -> void:
	var hub := SINGLE_PLAYER_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(6)
	var world := hub.get_node("Level") as Node2D
	var selector := hub.get_node("SinglePlayerWorldController")
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var hero := world.get_node("Player") as CharacterBody2D
	world.set_meta("force_touch_commands", true)
	hero.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(0, -7)))
	selector.call("_activate_line_wars")
	await _wait_frames(8)

	var line_wars := world.get_node_or_null("ContinuousLineWarsController")
	var peon := world.get_node_or_null("BuilderPeon") as CharacterBody2D
	_expect(line_wars != null and bool(line_wars.get("touch_command_mode")), "Forced touch mode should activate the mobile command flow")
	_expect(line_wars != null and line_wars.get("touch_action_panel") != null, "Touch mode should create the large confirm and cancel strip")
	if line_wars == null or peon == null:
		return

	var tunnel_exit: Vector2i = line_wars.get("tunnel_exit_cell")
	for step in range(1, 6):
		var previous_cell := tunnel_exit + Vector2i.UP * (step - 1)
		var target_cell := tunnel_exit + Vector2i.UP * step
		_force_solid(world, block_layer, target_cell)
		peon.global_position = block_layer.to_global(block_layer.map_to_local(previous_cell))
		var event := InputEventScreenTouch.new()
		event.pressed = true
		event.position = get_viewport().get_canvas_transform() * block_layer.to_global(block_layer.map_to_local(target_cell))
		var handled := bool(line_wars.call("_handle_touch_opening_input", event))
		_expect(handled, "An opening tap should be consumed as a peon carve command")
		_expect(bool(peon.call("is_order_active")), "An opening tap should start exactly one adjacent dig order")
		await _wait_for_order(peon, 120)
		await _wait_frames(3)
		_expect(block_layer.get_cell_source_id(target_cell) == -1, "The touch-assisted opening should carve the tapped direction")

	await _wait_frames(6)
	_expect(not bool(line_wars.get("opening_build_active")), "Five touch-assisted blocks should complete the protected opening")
	_expect(hero.process_mode == Node.PROCESS_MODE_INHERIT, "Touch opening completion should return control to the hero")

	var remote_target := tunnel_exit + Vector2i.UP * 6
	_force_solid(world, block_layer, remote_target)
	line_wars.call("_begin_command_view", "DIG")
	await _wait_frames(2)
	var panel := line_wars.get("touch_action_panel") as PanelContainer
	var confirm := line_wars.get("touch_confirm_button") as Button
	_expect(panel != null and panel.visible, "The mobile command strip should appear in peon targeting view")
	_expect(confirm != null and confirm.disabled, "Confirm should stay disabled until a valid target is selected")

	var touch_event := InputEventScreenTouch.new()
	touch_event.pressed = true
	touch_event.position = get_viewport().get_canvas_transform() * block_layer.to_global(block_layer.map_to_local(remote_target))
	line_wars.call("_unhandled_input", touch_event)
	await _wait_frames(2)
	_expect(Vector2i(line_wars.get("touch_selected_cell")) == remote_target, "A touch should select and preview the snapped dirt target")
	_expect(not bool(peon.call("is_order_active")), "Selecting a mobile target must not immediately commit the order")
	_expect(confirm != null and not confirm.disabled, "A valid selected target should enable the large confirm button")

	line_wars.call("_confirm_touch_command")
	await _wait_frames(2)
	_expect(not bool(line_wars.get("command_view_active")), "Confirming should immediately return the camera to the hero")
	_expect(bool(peon.call("is_order_active")), "Confirming should commission the selected peon route")
	await _wait_for_order(peon, 180)
	_expect(block_layer.get_cell_source_id(remote_target) == -1, "The confirmed touch order should excavate its destination")

	hub.queue_free()
	await _wait_frames(4)

func _force_solid(world: Node, block_layer: TileMapLayer, cell: Vector2i) -> void:
	block_layer.set_cell(cell, 1, Vector2i.ZERO)
	if world.get("astar") != null and world.astar.is_in_bounds(cell.x, cell.y):
		world.astar.set_point_solid(cell, true)

func _wait_for_order(peon: Node, max_frames: int) -> void:
	for _index in max_frames:
		if not bool(peon.call("is_order_active")):
			return
		await get_tree().process_frame

func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
