extends Node

const MODE_SIGNS_SCENE := preload("res://scenes/world/preparation/single_player_mode_signs.tscn")
const HUB_HUD_SCENE := preload("res://scenes/ui/overlays/single_player_hub_hud.tscn")
const LINE_WARS_CONTROLLER_SCRIPT := preload("res://scripts/systems/continuous_line_wars_controller.gd")
const STRONGHOLD_AMBIENCE_SCRIPT := preload("res://scripts/systems/stronghold_ambience_controller.gd")
const STRONGHOLD_PRACTICE_GEM_SCRIPT := preload("res://scripts/systems/stronghold_practice_gem_controller.gd")

const LINE_WARS_ENTRY_Y := -6
const MINE_WARS_ENTRY_Y := 7
const ROUTE_X_MIN := -1
const ROUTE_X_MAX := 1
const ADVENTURE_ENTRY_X := 10
const ADVENTURE_MIN_Y := -1
const ADVENTURE_MAX_Y := 1

@export var world_path: NodePath = NodePath("../Level")

var world: Node2D
var player: CharacterBody2D
var block_layer: TileMapLayer
var base: Node2D
var hud: CanvasLayer
var signs: Node2D
var hub_hud: CanvasLayer
var status_label: Label
var hub_camera: Camera2D
var player_camera: Camera2D
var stronghold_ambience: Node2D
var practice_gem_station: Node2D
var _last_ambience_base_id := ""
var _committing := false
var _last_locked_message := ""
var first_run_guide_layer: CanvasLayer
var first_run_route_marker: Node2D

func _ready() -> void:
	world = get_node_or_null(world_path) as Node2D
	if world == null:
		push_error("Single Player world controller could not find Level")
		return
	player = world.get_node_or_null("Player") as CharacterBody2D
	block_layer = world.get_node_or_null("BlockLayer") as TileMapLayer
	base = world.get_node_or_null("Base") as Node2D
	hud = world.get_node_or_null("HUD") as CanvasLayer
	if player == null or block_layer == null or base == null:
		push_error("Single Player world requires Player, BlockLayer, and Base")
		return

	GameMode.set_mode(GameMode.Mode.HUB)
	world.set_meta("single_player_hub_active", true)
	world.set_process(false)
	world.preparation_active = true
	world.preparation_mode = true

	var pending_rewards: Array = Global.consume_pending_unlock_rewards()
	var newly_unlocked_heroes: Array = []
	for reward_value in pending_rewards:
		var reward: Dictionary = reward_value
		var hero_name := str(reward.get("hero", ""))
		if not hero_name.is_empty():
			newly_unlocked_heroes.append(hero_name)
	world.set_meta("newly_unlocked_heroes", newly_unlocked_heroes)
	world.set_meta("stronghold_pending_rewards", pending_rewards)

	Global.apply_selected_loadout()
	base.position = Vector2.ZERO
	player.position = Vector2(0, 150)
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.velocity = Vector2.ZERO
	if player.has_method("update_hero_sprites"):
		player.update_hero_sprites()
	if base.has_method("refresh_base_sprite"):
		base.refresh_base_sprite()
	_refresh_stronghold_ambience()
	_create_practice_gem_station()

	player_camera = player.get_node_or_null("Camera2D") as Camera2D
	if player_camera:
		player_camera.enabled = false
	_create_hub_camera()

	if hud:
		hud.visible = false

	signs = MODE_SIGNS_SCENE.instantiate() as Node2D
	world.add_child(signs)
	hub_hud = HUB_HUD_SCENE.instantiate() as CanvasLayer
	add_child(hub_hud)
	status_label = hub_hud.get_node("StatusPanel/Margin/Status") as Label
	_configure_progression_signs()
	_set_initial_status()
	if Global.minewars_runs_completed == 0 and not Global.prototype_onboarding_completed:
		_create_first_run_stronghold_cue()
	if not pending_rewards.is_empty():
		call_deferred("_play_unlock_ceremony", pending_rewards)

func _create_first_run_stronghold_cue() -> void:
	if world == null or block_layer == null or first_run_route_marker != null:
		return
	first_run_route_marker = Node2D.new()
	first_run_route_marker.name = "FirstRunMineWarsRoute"
	first_run_route_marker.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(0, MINE_WARS_ENTRY_Y - 1)))
	first_run_route_marker.z_index = 35
	world.add_child(first_run_route_marker)

	var glow := Polygon2D.new()
	var glow_points := PackedVector2Array()
	for index in range(33):
		glow_points.append(Vector2.RIGHT.rotated(TAU * float(index) / 32.0) * 48.0)
	glow.polygon = glow_points
	glow.color = Color(0.18, 0.86, 1.0, 0.12)
	first_run_route_marker.add_child(glow)

	for ring_index in range(2):
		var ring := Line2D.new()
		ring.width = 4.0 - float(ring_index)
		ring.default_color = Color(0.28, 0.92, 1.0, 0.9 - float(ring_index) * 0.25)
		var ring_points := PackedVector2Array()
		for index in range(33):
			ring_points.append(Vector2.RIGHT.rotated(TAU * float(index) / 32.0) * (34.0 + float(ring_index) * 13.0))
		ring.points = ring_points
		first_run_route_marker.add_child(ring)

	for chevron_index in range(3):
		var chevron := Line2D.new()
		chevron.width = 5.0
		chevron.default_color = Color(0.48, 0.98, 1.0, 0.95 - float(chevron_index) * 0.18)
		var y := -70.0 + float(chevron_index) * 22.0
		chevron.points = PackedVector2Array([Vector2(-18, y), Vector2(0, y + 15), Vector2(18, y)])
		first_run_route_marker.add_child(chevron)

	var dust := CPUParticles2D.new()
	dust.amount = 18
	dust.lifetime = 1.7
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(34, 5)
	dust.gravity = Vector2(0, -16)
	dust.initial_velocity_min = 5.0
	dust.initial_velocity_max = 18.0
	dust.scale_amount_min = 1.2
	dust.scale_amount_max = 3.2
	dust.color = Color(0.42, 0.9, 1.0, 0.38)
	dust.position = Vector2(0, 28)
	dust.emitting = true
	first_run_route_marker.add_child(dust)

	var pulse := create_tween().bind_node(first_run_route_marker).set_loops()
	pulse.tween_property(first_run_route_marker, "scale", Vector2(1.11, 1.11), 0.62).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(first_run_route_marker, "scale", Vector2.ONE, 0.62).set_trans(Tween.TRANS_SINE)
	var glow_pulse := create_tween().bind_node(glow).set_loops()
	glow_pulse.tween_property(glow, "modulate:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
	glow_pulse.tween_property(glow, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_mine_awaken"):
		sound_fx.play_mine_awaken()

func _create_practice_gem_station() -> void:
	if world == null or player == null:
		return
	var existing := world.get_node_or_null("StrongholdPracticeYard") as Node2D
	if existing != null:
		practice_gem_station = existing
		return
	var station := Node2D.new()
	station.name = "StrongholdPracticeYard"
	station.set_script(STRONGHOLD_PRACTICE_GEM_SCRIPT)
	world.add_child(station)
	practice_gem_station = station

func _create_hub_camera() -> void:
	hub_camera = Camera2D.new()
	hub_camera.name = "HeroHallCamera"
	hub_camera.position = Vector2(0, 20)
	hub_camera.zoom = Vector2(0.82, 0.82)
	hub_camera.position_smoothing_enabled = false
	world.add_child(hub_camera)
	hub_camera.enabled = true

func _refresh_stronghold_ambience() -> void:
	_last_ambience_base_id = Global.selected_base_id
	var selected_base := str(Global.selected_base_id)
	var cart_unlocked := selected_base == Global.DEFAULT_BASE_ID and Global.is_stronghold_ambience_unlocked("dwarf_minecart")
	var signature := "%s:%s" % [selected_base, str(cart_unlocked)]
	if stronghold_ambience != null and is_instance_valid(stronghold_ambience) and str(stronghold_ambience.get_meta("ambience_signature", "")) == signature:
		return
	if stronghold_ambience != null and is_instance_valid(stronghold_ambience):
		stronghold_ambience.queue_free()
	stronghold_ambience = null
	if world == null or base == null:
		return
	var ambience := Node2D.new()
	ambience.name = "StrongholdAmbience"
	ambience.set_script(STRONGHOLD_AMBIENCE_SCRIPT)
	ambience.set("base_id", selected_base)
	ambience.set("dwarf_cart_unlocked", cart_unlocked)
	ambience.set_meta("ambience_signature", signature)
	ambience.position = base.position
	world.add_child(ambience)
	stronghold_ambience = ambience

func _process(_delta: float) -> void:
	if _committing or world == null or player == null:
		return
	if Global.selected_base_id != _last_ambience_base_id:
		_refresh_stronghold_ambience()
	var cell := block_layer.local_to_map(block_layer.to_local(player.global_position))
	var in_vertical_route := cell.x >= ROUTE_X_MIN and cell.x <= ROUTE_X_MAX

	if in_vertical_route and cell.y <= LINE_WARS_ENTRY_Y:
		if _advanced_modes_unlocked():
			_activate_line_wars()
		else:
			_show_locked_message("LINEWARS LOCKED  •  Win MineWars once to awaken this doorway.")
			player.position.y = -220
		return

	if cell.x >= ADVENTURE_ENTRY_X and cell.y >= ADVENTURE_MIN_Y and cell.y <= ADVENTURE_MAX_Y:
		if _advanced_modes_unlocked():
			_activate_standard_mode(GameMode.Mode.EXPLORATION, "Adventure active — explore the eastern mine for nests and artifacts.")
		else:
			_show_locked_message("ADVENTURE LOCKED  •  Win MineWars once to open the eastern doorway.")
			player.position.x = 430
		return

	if in_vertical_route and cell.y >= MINE_WARS_ENTRY_Y:
		_activate_standard_mode(GameMode.Mode.SIEGE, "MineWars active — mine, return resources, and survive the assault.")

func _advanced_modes_unlocked() -> bool:
	return Global.first_level_beaten

func _configure_progression_signs() -> void:
	if signs == null:
		return
	var line_wars := signs.get_node_or_null("LineWars") as Label
	var mine_wars := signs.get_node_or_null("MineWars") as Label
	var adventure := signs.get_node_or_null("Adventure") as Label
	if mine_wars:
		mine_wars.text = "DESCEND TO MINEWARS"
		mine_wars.modulate = Color.WHITE
	if line_wars:
		line_wars.visible = _advanced_modes_unlocked()
		if line_wars.visible:
			line_wars.text = "LINEWARS\nTOP TUNNEL"
			line_wars.modulate = Color.WHITE
	if adventure:
		adventure.visible = _advanced_modes_unlocked()
		if adventure.visible:
			adventure.text = "ADVENTURE\nRIGHT TUNNEL"
			adventure.modulate = Color.WHITE

func _set_initial_status() -> void:
	if Global.minewars_runs_completed == 0:
		_set_status("The lower shaft is awake.")
	elif _advanced_modes_unlocked():
		_set_status("The stronghold is ready.")
	else:
		_set_status("The bastion endures.")

func _play_unlock_ceremony(rewards: Array) -> void:
	if rewards.is_empty() or hub_hud == null or not is_instance_valid(hub_hud):
		return
	for reward_value in rewards:
		var reward: Dictionary = reward_value
		_focus_unlock_target(reward)
		_play_unlock_world_burst(reward)
		var banner := PanelContainer.new()
		banner.name = "StrongholdUnlockBanner"
		banner.process_mode = Node.PROCESS_MODE_ALWAYS
		banner.position = Vector2(326, 82)
		banner.custom_minimum_size = Vector2(500, 104)
		banner.modulate = Color(1, 1, 1, 0)
		hub_hud.add_child(banner)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 18)
		margin.add_theme_constant_override("margin_right", 18)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		banner.add_child(margin)
		var stack := VBoxContainer.new()
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		margin.add_child(stack)
		var title := Label.new()
		title.text = str(reward.get("title", "STRONGHOLD EXPANDED"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 24)
		title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3, 1.0))
		stack.add_child(title)
		var description := Label.new()
		description.text = str(reward.get("description", "A new power has joined the stronghold."))
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 14)
		stack.add_child(description)
		_set_status(description.text)
		var reveal := create_tween().set_parallel(true)
		reveal.tween_property(banner, "modulate", Color.WHITE, 0.3)
		reveal.tween_property(banner, "position:y", 98.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await reveal.finished
		await get_tree().create_timer(2.2).timeout
		var hide := create_tween()
		hide.tween_property(banner, "modulate:a", 0.0, 0.24)
		await hide.finished
		banner.queue_free()
	world.remove_meta("stronghold_pending_rewards")

func _focus_unlock_target(reward: Dictionary) -> void:
	if hub_camera == null or world == null:
		return
	var target_position := Vector2.ZERO
	var hero_name := str(reward.get("hero", ""))
	if not hero_name.is_empty():
		var shrine := world.get_node_or_null("PhysicalHeroShrines/" + hero_name.replace(" ", "") + "Shrine") as Node2D
		if shrine != null:
			target_position = shrine.global_position
	var home := Vector2(0, 20)
	var pan := create_tween().set_parallel(true)
	pan.tween_property(hub_camera, "position", target_position if target_position != Vector2.ZERO else home, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	pan.tween_property(hub_camera, "zoom", Vector2(1.02, 1.02), 0.42)
	_return_unlock_camera_later(home)

func _return_unlock_camera_later(home: Vector2) -> void:
	await get_tree().create_timer(2.7).timeout
	if hub_camera == null or not is_instance_valid(hub_camera):
		return
	var restore := create_tween().set_parallel(true)
	restore.tween_property(hub_camera, "position", home, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	restore.tween_property(hub_camera, "zoom", Vector2(0.82, 0.82), 0.45)

func _play_unlock_world_burst(reward: Dictionary) -> void:
	if world == null:
		return
	var origin := Vector2.ZERO
	var hero_name := str(reward.get("hero", ""))
	if not hero_name.is_empty():
		var shrine := world.get_node_or_null("PhysicalHeroShrines/" + hero_name.replace(" ", "") + "Shrine") as Node2D
		if shrine != null:
			origin = shrine.global_position
	var burst := Node2D.new()
	burst.name = "UnlockWorldBurst"
	burst.global_position = origin
	burst.z_index = 30
	world.add_child(burst)
	for ring_index in range(3):
		var ring := Line2D.new()
		ring.width = 5.0 - float(ring_index)
		ring.default_color = Color(0.4 + float(ring_index) * 0.2, 0.78, 1.0, 0.9)
		var points := PackedVector2Array()
		for index in range(33):
			points.append(Vector2.RIGHT.rotated(TAU * float(index) / 32.0) * (24.0 + float(ring_index) * 12.0))
		ring.points = points
		ring.scale = Vector2(0.25, 0.25)
		burst.add_child(ring)
		var expand := create_tween().set_parallel(true)
		expand.tween_property(ring, "scale", Vector2(1.65, 1.65), 0.7 + float(ring_index) * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		expand.tween_property(ring, "modulate:a", 0.0, 0.7 + float(ring_index) * 0.12)
	await get_tree().create_timer(1.15).timeout
	if is_instance_valid(burst):
		burst.queue_free()

func _show_locked_message(message: String) -> void:
	if message == _last_locked_message:
		return
	_last_locked_message = message
	_set_status(message)

func _activate_standard_mode(mode: GameMode.Mode, message: String) -> void:
	if _committing:
		return
	_committing = true
	GameMode.set_mode(mode)
	_prepare_world_for_run(message)
	if mode == GameMode.Mode.EXPLORATION:
		world.set_process(false)
	_ping_mode_bootstraps()
	queue_free()

func _activate_line_wars() -> void:
	if _committing:
		return
	_committing = true
	GameMode.set_mode(GameMode.Mode.LINE_WARS)
	var breakthrough_position := player.global_position
	_prepare_world_for_run("LineWars reached — dig a minimum opening tunnel with the peon; waves stay paused until it is safe.")
	world.set_process(false)
	var controller := Node.new()
	controller.name = "ContinuousLineWarsController"
	controller.set_script(LINE_WARS_CONTROLLER_SCRIPT)
	controller.set("breakthrough_position", breakthrough_position)
	world.add_child(controller)
	queue_free()

func _prepare_world_for_run(message: String) -> void:
	_set_status(message)
	if first_run_route_marker != null and is_instance_valid(first_run_route_marker):
		first_run_route_marker.queue_free()
	first_run_route_marker = null
	world.remove_meta("single_player_hub_active")
	world.begin_run_from_preparation()
	if hub_camera and is_instance_valid(hub_camera):
		hub_camera.queue_free()
	if player_camera:
		player_camera.enabled = true
		player_camera.zoom = Vector2(1.5, 1.5)
	if hud:
		hud.visible = true
	if signs and is_instance_valid(signs):
		signs.queue_free()
	if hub_hud and is_instance_valid(hub_hud):
		hub_hud.queue_free()

func _set_status(message: String) -> void:
	if status_label:
		status_label.text = message

func _ping_mode_bootstraps() -> void:
	var ping := Node.new()
	ping.name = "ModeBootstrapPing"
	world.add_child(ping)
	ping.queue_free()
