extends CharacterBody2D

signal work_order_finished(kind: String, cell: Vector2i)
signal work_order_failed(message: String)

const INVALID_CELL := Vector2i(99999, 99999)
const DIG_IMPACT_FRAME := 4

@export var move_speed := 190.0
@export var movement_bounds := Rect2(-560.0, -520.0, 1120.0, 660.0)
@export var surface_dig_time := 0.42

@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D

var controlled := true
var awaiting_neutral_input := false
var animation_timer := 0.0
var animation_row := 0

var world_digging_enabled := false
var dig_world: Node2D
var dig_block_layer: TileMapLayer
var dig_damage_layer: TileMapLayer
var dig_front_damage_layer: TileMapLayer
var dig_front_layer: TileMapLayer
var dig_min_cell := Vector2i.ZERO
var dig_max_cell := Vector2i.ZERO
var current_dig_cell := INVALID_CELL
var dig_timer := 0.0
var dig_break_queued := false
var dig_animation_last_frame := -1
var dig_animation_last_cycle := -1

# LineWars no longer asks the player to steer this unit in real time. A remote
# order is a short Warcraft-style macro decision: select one destination, then
# return to the hero while the peon walks and digs the complete route.
var order_active := false
var order_kind := ""
var order_cells: Array[Vector2i] = []
var order_index := 0
var order_target_cell := INVALID_CELL
var order_total_steps := 0

func _ready() -> void:
	add_to_group("builder_peon")
	set_controlled(controlled)

func set_controlled(value: bool) -> void:
	controlled = value
	velocity = Vector2.ZERO
	awaiting_neutral_input = value
	if not value and not order_active:
		_clear_dig_progress()
	if camera:
		camera.enabled = value
		if value:
			camera.reset_smoothing()

func set_command_camera_enabled(value: bool) -> void:
	if camera:
		camera.enabled = value
		if value:
			camera.reset_smoothing()

func configure_world_digging(world_node: Node2D, min_cell: Vector2i, max_cell: Vector2i) -> void:
	dig_world = world_node
	dig_block_layer = world_node.get_node_or_null("BlockLayer") as TileMapLayer
	dig_damage_layer = world_node.get_node_or_null("DamageLayer") as TileMapLayer
	dig_front_damage_layer = world_node.get_node_or_null("FrontDamageLayer") as TileMapLayer
	dig_front_layer = world_node.get_node_or_null("FrontWallLayer") as TileMapLayer
	dig_min_cell = min_cell
	dig_max_cell = max_cell
	world_digging_enabled = dig_block_layer != null
	# The continuous-world peon must collide with and mine the real TileMap.
	collision_mask = 1

func issue_dig_order(target_cell: Vector2i) -> bool:
	if order_active:
		_emit_order_failure("The peon is already working.")
		return false
	if not world_digging_enabled or dig_block_layer == null:
		_emit_order_failure("No diggable LineWars field was found.")
		return false
	if not _is_command_cell(target_cell):
		_emit_order_failure("Choose dirt inside the LineWars field.")
		return false

	var start_cell := _nearest_open_cell_from_position(6)
	if start_cell == INVALID_CELL:
		_emit_order_failure("The peon cannot reach an open starting tile.")
		return false
	if start_cell == target_cell:
		_emit_order_failure("Choose a more distant dirt block.")
		return false

	var horizontal_first: bool = abs(target_cell.x - start_cell.x) >= abs(target_cell.y - start_cell.y)
	var planned_path := _build_axis_path(start_cell, target_cell, horizontal_first)
	if planned_path.is_empty():
		_emit_order_failure("No valid tunnel order could be planned.")
		return false
	_begin_order("DIG", target_cell, planned_path)
	return true

func issue_build_order(target_cell: Vector2i, kind: String = "RADAR") -> bool:
	if order_active:
		_emit_order_failure("The peon is already working.")
		return false
	if not world_digging_enabled or dig_world == null or dig_block_layer == null:
		_emit_order_failure("No LineWars field was found.")
		return false
	if not _is_command_cell(target_cell):
		_emit_order_failure("Choose a tunnel tile inside the LineWars field.")
		return false
	if dig_block_layer.get_cell_source_id(target_cell) != -1:
		_emit_order_failure("Build gadgets inside an open tunnel.")
		return false

	var start_cell := _nearest_open_cell_from_position(8)
	if start_cell == INVALID_CELL:
		_emit_order_failure("The peon cannot reach the tunnel network.")
		return false
	var planned_path: Array[Vector2i] = []
	if start_cell != target_cell:
		if dig_world.get("astar") == null:
			_emit_order_failure("Tunnel navigation is not ready.")
			return false
		var raw_path: Array[Vector2i] = dig_world.astar.get_id_path(start_cell, target_cell)
		if raw_path.size() < 2:
			_emit_order_failure("That tunnel tile is not connected to the peon.")
			return false
		for index in range(1, raw_path.size()):
			planned_path.append(raw_path[index])
	_begin_order(kind, target_cell, planned_path)
	return true

func cancel_order() -> void:
	if not order_active:
		return
	order_active = false
	order_kind = ""
	order_cells.clear()
	order_index = 0
	order_target_cell = INVALID_CELL
	order_total_steps = 0
	velocity = Vector2.ZERO
	_clear_dig_progress()

func is_order_active() -> bool:
	return order_active

func get_order_kind() -> String:
	return order_kind

func get_order_progress_text() -> String:
	if not order_active:
		return "IDLE"
	var completed := mini(order_index, order_total_steps)
	return "%s %d/%d" % [order_kind, completed, maxi(order_total_steps, 1)]

func _begin_order(kind: String, target_cell: Vector2i, planned_path: Array[Vector2i]) -> void:
	order_active = true
	order_kind = kind
	order_target_cell = target_cell
	order_cells = planned_path.duplicate()
	order_index = 0
	order_total_steps = order_cells.size()
	controlled = false
	awaiting_neutral_input = false
	velocity = Vector2.ZERO
	_clear_dig_progress()
	if order_cells.is_empty():
		call_deferred("_finish_order")

func _physics_process(delta: float) -> void:
	if order_active:
		_process_remote_order(delta)
		_update_animation(delta)
		return
	if not controlled:
		velocity = Vector2.ZERO
		_update_animation(delta)
		return

	var input_vector := Vector2.ZERO
	if InputMap.has_action("p1_left") and InputMap.has_action("p1_right") and InputMap.has_action("p1_up") and InputMap.has_action("p1_down"):
		input_vector = Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
	if input_vector.length_squared() < 0.01:
		input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if awaiting_neutral_input:
		if input_vector.length_squared() >= 0.01:
			velocity = Vector2.ZERO
			_update_animation(delta)
			return
		awaiting_neutral_input = false

	var direction := input_vector.normalized()
	if world_digging_enabled and _process_surface_dig(direction, delta):
		velocity = Vector2.ZERO
		_update_direction_from_vector(direction)
		_update_animation(delta)
		return

	_clear_dig_progress()
	velocity = direction * move_speed
	move_and_slide()
	global_position.x = clampf(global_position.x, movement_bounds.position.x, movement_bounds.end.x)
	global_position.y = clampf(global_position.y, movement_bounds.position.y, movement_bounds.end.y)
	_update_direction_from_vector(direction)
	_update_animation(delta)

func _process_remote_order(delta: float) -> void:
	if order_index >= order_cells.size():
		_finish_order()
		return
	var target_cell := order_cells[order_index]
	if not _is_command_cell(target_cell):
		_fail_active_order("The planned route left the LineWars field.")
		return

	var target_position := dig_block_layer.to_global(dig_block_layer.map_to_local(target_cell))
	var target_delta := target_position - global_position
	var distance := target_delta.length()

	if dig_block_layer.get_cell_source_id(target_cell) != -1:
		# Consecutive command cells keep the peon on the previous open tile while it
		# mines the next one. This is the same terrain damage flow as manual mining.
		velocity = Vector2.ZERO
		_update_direction_from_vector(target_delta.normalized())
		_process_order_dig_cell(target_cell, delta)
		return

	_clear_dig_progress()
	if distance < 7.0:
		global_position = target_position
		order_index += 1
		velocity = Vector2.ZERO
		if order_index >= order_cells.size():
			_finish_order()
		return

	var direction := target_delta / maxf(distance, 0.001)
	velocity = direction * move_speed
	move_and_slide()
	global_position.x = clampf(global_position.x, movement_bounds.position.x, movement_bounds.end.x)
	global_position.y = clampf(global_position.y, movement_bounds.position.y, movement_bounds.end.y)
	_update_direction_from_vector(direction)

func _process_surface_dig(direction: Vector2, delta: float) -> bool:
	if direction.length_squared() < 0.01 or dig_block_layer == null:
		return false
	var cardinal := Vector2.ZERO
	if absf(direction.x) > absf(direction.y):
		cardinal.x = signf(direction.x)
	else:
		cardinal.y = signf(direction.y)
	var probe_position := global_position + cardinal * 38.0
	var cell := dig_block_layer.local_to_map(dig_block_layer.to_local(probe_position))
	if not _is_command_cell(cell):
		return false
	if dig_block_layer.get_cell_source_id(cell) == -1:
		return false
	_process_order_dig_cell(cell, delta)
	return true

func _process_order_dig_cell(cell: Vector2i, delta: float) -> void:
	if current_dig_cell != cell:
		_clear_dig_progress()
		current_dig_cell = cell
	dig_timer += delta

	var progress := clampf(dig_timer / surface_dig_time, 0.0, 1.0)
	var crack_overlay_manager = dig_world.get_node_or_null("CrackOverlayManager")
	if crack_overlay_manager:
		crack_overlay_manager.set_damage(cell, progress, false)
	if dig_front_layer:
		var below_cell := cell + Vector2i.DOWN
		if dig_front_layer.get_cell_source_id(below_cell) != -1:
			if crack_overlay_manager:
				crack_overlay_manager.set_damage(below_cell, progress, true)

	if dig_timer < surface_dig_time:
		return
	dig_timer = surface_dig_time
	dig_break_queued = true

func _finish_queued_dig_at_contact() -> void:
	if current_dig_cell == INVALID_CELL or dig_world == null:
		return
	var cell := current_dig_cell
	var cell_had_gem := bool(dig_world.call("has_gem", cell)) if dig_world.has_method("has_gem") else false
	_emit_dig_impact(true, cell, cell_had_gem)
	if dig_world.has_method("on_cell_dug"):
		dig_world.call("on_cell_dug", cell)
	var crack_overlay_manager = dig_world.get_node_or_null("CrackOverlayManager")
	if crack_overlay_manager:
		crack_overlay_manager.clear_damage(cell + Vector2i.DOWN, true)
	_clear_dig_progress()

func _finish_order() -> void:
	if not order_active:
		return
	var finished_kind := order_kind
	var finished_cell := order_target_cell
	order_active = false
	order_kind = ""
	order_cells.clear()
	order_index = 0
	order_target_cell = INVALID_CELL
	order_total_steps = 0
	velocity = Vector2.ZERO
	_clear_dig_progress()
	work_order_finished.emit(finished_kind, finished_cell)

func _fail_active_order(message: String) -> void:
	cancel_order()
	_emit_order_failure(message)

func _emit_order_failure(message: String) -> void:
	work_order_failed.emit(message)

func _build_axis_path(start_cell: Vector2i, target_cell: Vector2i, horizontal_first: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cursor := start_cell
	if horizontal_first:
		_append_axis_steps(result, cursor, target_cell, true)
		cursor = Vector2i(target_cell.x, cursor.y)
		_append_axis_steps(result, cursor, target_cell, false)
	else:
		_append_axis_steps(result, cursor, target_cell, false)
		cursor = Vector2i(cursor.x, target_cell.y)
		_append_axis_steps(result, cursor, target_cell, true)
	return result

func _append_axis_steps(result: Array[Vector2i], start_cell: Vector2i, target_cell: Vector2i, horizontal: bool) -> void:
	var cursor := start_cell
	if horizontal:
		var step_x := signi(target_cell.x - cursor.x)
		while cursor.x != target_cell.x:
			cursor.x += step_x
			if _is_command_cell(cursor):
				result.append(cursor)
	else:
		var step_y := signi(target_cell.y - cursor.y)
		while cursor.y != target_cell.y:
			cursor.y += step_y
			if _is_command_cell(cursor):
				result.append(cursor)

func _nearest_open_cell_from_position(max_radius: int) -> Vector2i:
	if dig_block_layer == null:
		return INVALID_CELL
	var center := dig_block_layer.local_to_map(dig_block_layer.to_local(global_position))
	if _is_open_command_cell(center):
		return center
	for radius in range(1, max_radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			for y in range(center.y - radius, center.y + radius + 1):
				if x != center.x - radius and x != center.x + radius and y != center.y - radius and y != center.y + radius:
					continue
				var cell := Vector2i(x, y)
				if _is_open_command_cell(cell):
					return cell
	return INVALID_CELL

func _is_command_cell(cell: Vector2i) -> bool:
	return cell.x >= dig_min_cell.x and cell.x <= dig_max_cell.x and cell.y >= dig_min_cell.y and cell.y <= dig_max_cell.y

func _is_open_command_cell(cell: Vector2i) -> bool:
	return _is_command_cell(cell) and dig_block_layer.get_cell_source_id(cell) == -1

func _clear_dig_progress() -> void:
	if current_dig_cell != INVALID_CELL:
		var crack_overlay_manager = dig_world.get_node_or_null("CrackOverlayManager") if dig_world != null else null
		if crack_overlay_manager:
			crack_overlay_manager.clear_damage(current_dig_cell, false)
			crack_overlay_manager.clear_damage(current_dig_cell + Vector2i.DOWN, true)
		current_dig_cell = INVALID_CELL
		dig_timer = 0.0
	dig_break_queued = false
	dig_animation_last_frame = -1
	dig_animation_last_cycle = -1

func _update_direction_from_vector(direction: Vector2) -> void:
	if direction.length_squared() < 0.01:
		return
	var angle := direction.angle()
	var pi_8 := PI / 8.0
	if angle > -pi_8 and angle <= pi_8:
		animation_row = 6
	elif angle > pi_8 and angle <= 3.0 * pi_8:
		animation_row = 7
	elif angle > 3.0 * pi_8 and angle <= 5.0 * pi_8:
		animation_row = 0
	elif angle > 5.0 * pi_8 and angle <= 7.0 * pi_8:
		animation_row = 1
	elif angle > 7.0 * pi_8 or angle <= -7.0 * pi_8:
		animation_row = 2
	elif angle > -7.0 * pi_8 and angle <= -5.0 * pi_8:
		animation_row = 3
	elif angle > -5.0 * pi_8 and angle <= -3.0 * pi_8:
		animation_row = 4
	else:
		animation_row = 5

func _update_animation(delta: float) -> void:
	if sprite == null:
		return
	if velocity.length_squared() > 0.01 or current_dig_cell != INVALID_CELL:
		animation_timer += delta * 12.0
		var frame_index := int(animation_timer) % 8
		sprite.frame = animation_row * 8 + frame_index
		_sync_dig_animation_impact(frame_index)
	else:
		animation_timer = 0.0
		sprite.frame = animation_row * 8

func _sync_dig_animation_impact(frame_index: int) -> void:
	if current_dig_cell == INVALID_CELL:
		dig_animation_last_frame = frame_index
		return
	var cycle := int(animation_timer / 8.0)
	var crossed_contact := frame_index >= DIG_IMPACT_FRAME and (dig_animation_last_frame < DIG_IMPACT_FRAME or cycle != dig_animation_last_cycle)
	if crossed_contact:
		if dig_break_queued:
			_finish_queued_dig_at_contact()
		else:
			_emit_dig_impact(false, current_dig_cell)
	dig_animation_last_frame = frame_index
	dig_animation_last_cycle = cycle

func _emit_dig_impact(strong: bool, cell: Vector2i, gem_reveal := false) -> void:
	if dig_block_layer == null:
		return
	var target_position := dig_block_layer.to_global(dig_block_layer.map_to_local(cell))
	var contact_direction := global_position.direction_to(target_position)
	var impact_position := target_position - contact_direction * 22.0
	if dig_world and dig_world.has_method("spawn_mining_feedback"):
		dig_world.call("spawn_mining_feedback", impact_position, strong, gem_reveal, contact_direction)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx:
		if strong:
			sound_fx.play_block_break(gem_reveal)
		else:
			sound_fx.play_dig_hit(dig_block_layer.get_cell_source_id(cell))
