extends Node2D

# MineWars Keeper prototype:
# mine and carry resources during a readable countdown, then return to the
# surface and defend the core with the selected Warcraft-style RPG hero.

const ENEMY_SCENE := preload("res://enemy.tscn")
const FIXED_ENTRANCE_CELL := Vector2i(-10, -2)
const BASE_TARGET_CELL := Vector2i(0, -1)
const FIRST_MINING_WINDOW := 60.0
const LATER_MINING_WINDOW := 55.0
const SPAWN_GAP := 0.42
const FINAL_WAVE := 10

enum Phase { MINING, ATTACK }

var world: Node2D
var block_layer: TileMapLayer
var player: CharacterBody2D
var hud: Node
var phase := Phase.MINING
var mining_timer := FIRST_MINING_WINDOW
var wave_number := 1
var wave_spawning := false
var warning_stage := -1
var ui_layer: CanvasLayer
var status_label: Label
var hint_label: Label
var entrance_marker: Node2D

func _ready() -> void:
	call_deferred("_activate")

func _activate() -> void:
	world = get_parent() as Node2D
	if world == null or not is_instance_valid(world):
		queue_free()
		return
	if bool(world.get("is_vs_mode")) or not GameMode.is_keeper():
		queue_free()
		return

	block_layer = world.get_node_or_null("BlockLayer") as TileMapLayer
	player = world.get_node_or_null("Player") as CharacterBody2D
	hud = world.get_node_or_null("HUD")
	if block_layer == null or player == null:
		push_error("Keeper Mode requires BlockLayer and Player.")
		queue_free()
		return

	# Replace random breach selection with one readable surface lane.
	world.set_process(false)
	world.set_meta("keeper_mode", true)
	world.set_meta("wave_spawning", false)
	world.current_wave_number = wave_number
	world.enemies_per_wave = 2
	_ensure_fixed_surface_lane()
	_create_ui()
	_create_entrance_marker()
	_update_ui()
	if hud and hud.has_method("show_notice"):
		hud.show_notice("KEEPER MODE: mine, carry resources home, build your hero, and return before the assault.", 6.0)

func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world) or not GameMode.is_keeper():
		return
	if bool(world.get("preparation_active")):
		return

	if phase == Phase.MINING:
		mining_timer = maxf(mining_timer - delta, 0.0)
		_update_warning_stage()
		if mining_timer <= 0.0 and not wave_spawning:
			_start_wave()
	else:
		if not wave_spawning and _count_world_enemies() == 0:
			_complete_wave()

	_update_wave_hud()
	_update_ui()

func _ensure_fixed_surface_lane() -> void:
	var previous_generation_flag := bool(world.world_generation_in_progress)
	world.world_generation_in_progress = true
	for x in range(FIXED_ENTRANCE_CELL.x, 1):
		var cell := Vector2i(x, FIXED_ENTRANCE_CELL.y)
		if block_layer.get_cell_source_id(cell) != -1:
			world.on_cell_dug(cell)
	world.world_generation_in_progress = previous_generation_flag
	world.topology_revision += 1

func _start_wave() -> void:
	phase = Phase.ATTACK
	wave_spawning = true
	world.set_meta("wave_spawning", true)
	world.set_meta("active_wave_number", wave_number)
	world.current_wave_number = wave_number
	warning_stage = -1
	if hud and hud.has_method("notify_wave_started"):
		hud.notify_wave_started(wave_number == FINAL_WAVE, wave_number)
	if hud and hud.has_method("show_notice"):
		hud.show_notice("ASSAULT %d — enemies are entering from the western surface gate!" % wave_number, 4.0)
	_spawn_wave()

func _spawn_wave() -> void:
	var is_boss := wave_number == FINAL_WAVE
	var entrance_position := _cell_world_position(FIXED_ENTRANCE_CELL)
	if world.has_method("_spawn_wave_telegraph"):
		world._spawn_wave_telegraph(entrance_position, is_boss)
	await get_tree().create_timer(0.7).timeout
	var spawn_count := 1 if is_boss else mini(2 + wave_number, 8)
	for i in range(spawn_count):
		if world == null or not is_instance_valid(world):
			return
		var enemy := ENEMY_SCENE.instantiate()
		world.add_child(enemy)
		enemy.global_position = entrance_position + Vector2(0, float((i % 3) - 1) * 9.0)
		if enemy.has_method("initialize"):
			var enemy_type := 4 if is_boss else (0 if wave_number == 1 else int(world.get_random_enemy_type(wave_number)))
			enemy.initialize(wave_number, is_boss, enemy_type)
		if enemy.has_method("begin_breach_emergence"):
			enemy.begin_breach_emergence(0.55 if not is_boss else 1.0)
		await get_tree().create_timer(SPAWN_GAP).timeout
	wave_spawning = false
	world.set_meta("wave_spawning", false)

func _complete_wave() -> void:
	if wave_number >= FINAL_WAVE:
		# MatchFlow sees current_wave_number > 10 and presents the existing result UI.
		world.current_wave_number = FINAL_WAVE + 1
		return
	wave_number += 1
	world.current_wave_number = wave_number
	phase = Phase.MINING
	mining_timer = LATER_MINING_WINDOW
	warning_stage = -1
	if hud and hud.has_method("show_notice"):
		hud.show_notice("Assault cleared. Spend quickly, then make another mining run.", 3.8)

func _update_warning_stage() -> void:
	var new_stage := 0
	if mining_timer <= 8.0:
		new_stage = 3
	elif mining_timer <= 20.0:
		new_stage = 2
	elif mining_timer <= 36.0:
		new_stage = 1
	if new_stage == warning_stage:
		return
	warning_stage = new_stage
	if hud == null or not hud.has_method("show_notice"):
		return
	match warning_stage:
		1:
			hud.show_notice("Distant war drums. You still have time for one careful pocket.", 3.0)
		2:
			hud.show_notice("Enemies are approaching. Start planning your return route.", 3.2)
		3:
			hud.show_notice("ATTACK IMMINENT — return to the surface now!", 3.2)

func _update_wave_hud() -> void:
	if hud == null or not hud.has_method("update_wave_info"):
		return
	var is_boss := wave_number == FINAL_WAVE
	if phase == Phase.ATTACK:
		hud.update_wave_info(wave_number, -1.0, LATER_MINING_WINDOW, is_boss)
	else:
		var maximum := FIRST_MINING_WINDOW if wave_number == 1 else LATER_MINING_WINDOW
		hud.update_wave_info(wave_number, mining_timer, maximum, is_boss)

func _create_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 25
	add_child(ui_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 96)
	panel.custom_minimum_size = Vector2(390, 0)
	ui_layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)
	var title := Label.new()
	title.text = "MINEWARS KEEPER"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3, 1.0))
	stack.add_child(title)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	stack.add_child(status_label)
	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(360, 0)
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.36, 1.0))
	stack.add_child(hint_label)

func _update_ui() -> void:
	if status_label == null or not is_instance_valid(status_label):
		return
	var carry_load := int(player.get_carry_load()) if player.has_method("get_carry_load") else 0
	var overload := int(player.get_carry_overload()) if player.has_method("get_carry_overload") else 0
	var depth := maxi(block_layer.local_to_map(block_layer.to_local(player.global_position)).y, 0)
	if phase == Phase.ATTACK:
		status_label.text = "ASSAULT %d/%d  •  Enemies remaining %d\nDepth %d  •  Carrying %d" % [wave_number, FINAL_WAVE, _count_world_enemies(), depth, carry_load]
		hint_label.text = "Fight at the western surface gate. Your hero build is the defence."
		return
	var danger := _danger_text()
	status_label.text = "Mining trip before Assault %d/%d  •  %s\nDepth %d  •  Carrying %d  •  Overload %d" % [wave_number, FINAL_WAVE, danger, depth, carry_load, overload]
	if warning_stage >= 3:
		hint_label.text = "RETURN NOW. Carried gems only become spendable after you deposit them at the base."
	elif overload > 0:
		hint_label.text = "You are overloaded and slower. Bank the haul or risk a late return."
	elif warning_stage == 2:
		hint_label.text = "One more block may be valuable—but your return path is getting expensive."
	else:
		hint_label.text = "Mine, carry resources home, choose RPG upgrades, then defend directly."

func _danger_text() -> String:
	match warning_stage:
		0: return "CALM"
		1: return "DISTANT MOVEMENT"
		2: return "APPROACHING"
		_: return "IMMINENT"

func _create_entrance_marker() -> void:
	entrance_marker = Node2D.new()
	entrance_marker.name = "KeeperSurfaceGate"
	entrance_marker.global_position = _cell_world_position(FIXED_ENTRANCE_CELL)
	entrance_marker.z_index = 7
	world.add_child(entrance_marker)
	var ring := Line2D.new()
	ring.width = 5.0
	ring.default_color = Color(1.0, 0.28, 0.12, 0.9)
	var points := PackedVector2Array()
	for i in range(25):
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / 24.0) * 28.0)
	ring.points = points
	entrance_marker.add_child(ring)
	var label := Label.new()
	label.text = "FIXED ENEMY GATE"
	label.position = Vector2(-95, -55)
	label.size = Vector2(190, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	entrance_marker.add_child(label)

func _count_world_enemies() -> int:
	var count := 0
	for enemy_value in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_value as Node
		if enemy != null and is_instance_valid(enemy) and world.is_ancestor_of(enemy):
			count += 1
	return count

func _cell_world_position(cell: Vector2i) -> Vector2:
	return block_layer.to_global(block_layer.map_to_local(cell))
