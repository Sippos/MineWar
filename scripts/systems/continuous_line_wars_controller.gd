extends Node

const BUILDER_PEON_SCENE := preload("res://scenes/entities/workers/peon/builder_peon_player.tscn")
const HUD_SCENE := preload("res://scenes/ui/overlays/continuous_line_wars_hud.tscn")
const ENEMY_SCENE := preload("res://enemy.tscn")

# The LineWars layer begins as solid rock. The peon enters through the narrow
# lower pocket and can excavate the full height into a winding defence route.
const SURFACE_MIN_CELL := Vector2i(-10, -33)
const SURFACE_MAX_CELL := Vector2i(10, -6)
const SEARCH_MIN_CELL := Vector2i(-10, -33)
const SEARCH_MAX_CELL := Vector2i(10, 0)
const BASE_TARGET_CELL := Vector2i(0, -1)
const FIRST_INVASION_DELAY := 28.0
const INVASION_INTERVAL := 24.0
const TELEGRAPH_DURATION := 2.2
const FINAL_WAVE := 10
const CARDINAL_DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var breakthrough_position := Vector2.ZERO
var world: Node2D
var block_layer: TileMapLayer
var hero: CharacterBody2D
var peon: CharacterBody2D
var base: Node2D
var hud: CanvasLayer
var mode_label: Label
var hint_label: Label
var threat_label: Label
var switch_button: Button
var peon_active := true

var invasion_timer := FIRST_INVASION_DELAY
var next_wave := 1
var current_wave := 0
var completed_wave := 0
var spawning := false
var wave_in_progress := false
var run_finished := false
var last_spawn_cell := Vector2i.ZERO

func _ready() -> void:
	world = get_parent() as Node2D
	if world:
		block_layer = world.get_node_or_null("BlockLayer") as TileMapLayer
		hero = world.get_node_or_null("Player") as CharacterBody2D
		base = world.get_node_or_null("Base") as Node2D
	if world == null or block_layer == null or hero == null or base == null:
		push_error("Continuous LineWars requires the persistent mine world")
		queue_free()
		return

	world.set_meta("continuous_line_wars_active", true)
	_ensure_switch_action()
	_spawn_peon()
	_build_hud()
	_apply_control()
	# Breaking through is the handoff. The same held direction may immediately
	# begin excavating with the peon instead of requiring a neutral input frame.
	peon.set("awaiting_neutral_input", false)
	_update_interface()

func _spawn_peon() -> void:
	peon = BUILDER_PEON_SCENE.instantiate() as CharacterBody2D
	peon.name = "BuilderPeon"
	world.add_child(peon)
	# Stay inside the one-tile breakthrough instead of entering a pre-carved room.
	# A small offset keeps the peon readable while remaining inside the same cell.
	peon.global_position = breakthrough_position + Vector2(18, 0)
	peon.set("movement_bounds", _surface_movement_bounds())
	peon.call("configure_world_digging", world, SURFACE_MIN_CELL, SURFACE_MAX_CELL)

	hero.velocity = Vector2.ZERO
	hero.visible = true

func _build_hud() -> void:
	hud = HUD_SCENE.instantiate() as CanvasLayer
	add_child(hud)
	mode_label = hud.get_node("TopBar/Margin/Row/Mode") as Label
	switch_button = hud.get_node("TopBar/Margin/Row/Switch") as Button
	threat_label = hud.get_node("TopBar/Margin/Row/Threat") as Label
	hint_label = hud.get_node("HintPanel/Margin/Hint") as Label
	switch_button.pressed.connect(_toggle_front)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("switch_front"):
		_toggle_front()

	if run_finished:
		return
	var base_health: Variant = base.get("health") if base else null
	if base_health != null and int(base_health) <= 0:
		_finish_run(false)
		return

	if wave_in_progress:
		if not spawning and _count_world_enemies() == 0:
			wave_in_progress = false
			if completed_wave >= FINAL_WAVE:
				_finish_run(true)
				return
			invasion_timer = INVASION_INTERVAL
	else:
		invasion_timer = maxf(invasion_timer - delta, 0.0)
		if invasion_timer <= 0.0 and next_wave <= FINAL_WAVE:
			_begin_invasion(next_wave)

	_update_interface()

func _begin_invasion(wave_number: int) -> void:
	if spawning or wave_in_progress or run_finished:
		return
	spawning = true
	wave_in_progress = true
	current_wave = wave_number
	last_spawn_cell = _find_farthest_tunnel_cell()
	var spawn_position := block_layer.to_global(block_layer.map_to_local(last_spawn_cell))
	var is_boss := wave_number == FINAL_WAVE
	if world.has_method("_spawn_wave_telegraph"):
		world.call("_spawn_wave_telegraph", spawn_position, is_boss)
	_update_interface()

	# The endpoint is locked when the warning appears. The peon has time to switch
	# to the hero or retreat before enemies emerge from that announced location.
	await get_tree().create_timer(TELEGRAPH_DURATION).timeout
	if not is_instance_valid(self) or run_finished:
		return

	var spawn_count := 1 if is_boss else mini(1 + int((wave_number - 1) / 2), 6)
	for index in range(spawn_count):
		_spawn_enemy_at_endpoint(wave_number, is_boss, index, spawn_count, spawn_position)
		await get_tree().create_timer(0.28).timeout

	completed_wave = wave_number
	next_wave = wave_number + 1
	spawning = false
	_update_interface()

func _spawn_enemy_at_endpoint(wave_number: int, is_boss: bool, index: int, count: int, spawn_position: Vector2) -> void:
	var enemy := ENEMY_SCENE.instantiate() as CharacterBody2D
	if enemy == null:
		return
	enemy.set("target_base_cell", BASE_TARGET_CELL)
	var angle := TAU * float(index) / float(maxi(count, 1))
	var offset := Vector2(cos(angle), sin(angle)) * (8.0 if count > 1 else 0.0)
	enemy.position = world.to_local(spawn_position + offset)
	world.add_child(enemy)
	if enemy.has_method("initialize"):
		var enemy_type := 0 if wave_number == 1 else int(world.call("get_random_enemy_type", wave_number))
		enemy.call("initialize", wave_number, is_boss, enemy_type)
	if enemy.has_method("begin_breach_emergence"):
		enemy.call("begin_breach_emergence", 0.65 if not is_boss else 0.9)

func _find_farthest_tunnel_cell() -> Vector2i:
	# Breadth-first distance from the base gives the true shortest route through
	# the player's tunnels. The farthest connected dead end becomes the invasion
	# point, so extending or winding the maze directly increases travel distance.
	if block_layer.get_cell_source_id(BASE_TARGET_CELL) != -1:
		return Vector2i(3, -7)

	var queue: Array[Vector2i] = [BASE_TARGET_CELL]
	var head := 0
	var distance_by_cell: Dictionary = {BASE_TARGET_CELL: 0}
	var farthest_any := BASE_TARGET_CELL
	var farthest_any_distance := 0
	var farthest_endpoint := Vector2i(3, -7)
	var farthest_endpoint_distance := -1

	while head < queue.size():
		var cell := queue[head]
		head += 1
		var distance := int(distance_by_cell[cell])
		if cell.y <= -7:
			if distance > farthest_any_distance:
				farthest_any = cell
				farthest_any_distance = distance
			if _count_open_neighbors(cell) <= 1 and distance > farthest_endpoint_distance:
				farthest_endpoint = cell
				farthest_endpoint_distance = distance

		for direction_value in CARDINAL_DIRECTIONS:
			var direction: Vector2i = direction_value
			var neighbor: Vector2i = cell + direction
			if not _is_search_cell(neighbor):
				continue
			if distance_by_cell.has(neighbor):
				continue
			if block_layer.get_cell_source_id(neighbor) != -1:
				continue
			distance_by_cell[neighbor] = distance + 1
			queue.append(neighbor)

	return farthest_endpoint if farthest_endpoint_distance >= 0 else farthest_any

func _count_open_neighbors(cell: Vector2i) -> int:
	var count := 0
	for direction_value in CARDINAL_DIRECTIONS:
		var direction: Vector2i = direction_value
		var neighbor: Vector2i = cell + direction
		if _is_search_cell(neighbor) and block_layer.get_cell_source_id(neighbor) == -1:
			count += 1
	return count

func _is_search_cell(cell: Vector2i) -> bool:
	return (
		cell.x >= SEARCH_MIN_CELL.x and cell.x <= SEARCH_MAX_CELL.x
		and cell.y >= SEARCH_MIN_CELL.y and cell.y <= SEARCH_MAX_CELL.y
	)

func _count_world_enemies() -> int:
	var count := 0
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(candidate) and world.is_ancestor_of(candidate):
			count += 1
	return count

func _toggle_front() -> void:
	if run_finished:
		return
	peon_active = not peon_active
	_apply_control()
	_update_interface()

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

func _update_interface() -> void:
	if mode_label == null or threat_label == null or hint_label == null:
		return
	mode_label.text = "PEON • DIG THE DEFENCE" if peon_active else "HERO • DEFEND BELOW"
	switch_button.text = "SWITCH TO HERO" if peon_active else "SWITCH TO PEON"

	if spawning:
		threat_label.text = "WAVE %d BREACHING AT %s" % [current_wave, _format_cell(last_spawn_cell)]
	elif wave_in_progress:
		threat_label.text = "WAVE %d • %d ENEMIES" % [current_wave, _count_world_enemies()]
	else:
		threat_label.text = "WAVE %d IN %ds • FARTHEST ENDPOINT" % [next_wave, int(ceil(invasion_timer))]

	hint_label.text = (
		"Dig upward from the narrow entrance, then turn and branch. The farthest connected dead end becomes the next spawn."
		if peon_active
		else
		"Enemies follow the dug route to the base. Fight in the same map, then switch back to extend the maze."
	)

func _format_cell(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _finish_run(victory: bool) -> void:
	run_finished = true
	spawning = false
	wave_in_progress = false
	if threat_label:
		threat_label.text = "LINEWARS COMPLETE" if victory else "BASE DESTROYED"
	if hint_label:
		hint_label.text = (
			"Victory: the base survived all ten invasions through the tunnel you excavated."
			if victory
			else
			"Defeat: the invasion reached and destroyed the shared base."
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
