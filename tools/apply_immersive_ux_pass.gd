extends Node

var failures: Array[String] = []

func _ready() -> void:
	_patch_sound_fx()
	_patch_single_player_hub()
	_patch_world_onboarding()
	_patch_gem_prompt()
	_patch_base_prompts()
	_patch_hud()
	_patch_minewars_controller()
	if failures.is_empty():
		print("IMMERSIVE_UX_PASS_OK")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _patch_sound_fx() -> void:
	var path := "res://sound_fx.gd"
	_replace_once(path,
		"\t_streams[\"error\"] = _make_error_stream(0.18)\n",
		"\t_streams[\"error\"] = _make_error_stream(0.18)\n\t_streams[\"mine_awaken\"] = _make_chime_stream([240.0, 360.0, 520.0], 0.48, 0.11)\n\t_streams[\"warning_drum\"] = _make_impact_stream(0.26, 62.0, 0.24, 404)\n\t_streams[\"warning_horn\"] = _make_chime_stream([218.0, 178.0], 0.58, 0.20)\n\t_streams[\"breach\"] = _make_break_stream(0.52, 505)\n\t_streams[\"objective_tick\"] = _make_chime_stream([620.0, 820.0], 0.16, 0.055)\n")
	_replace_function(path, "func play_level_up() -> void:", '''func play_level_up() -> void:
	_play("upgrade", 0.0, 0.0, 0.08)

func play_mine_awaken() -> void:
	_play("mine_awaken", -7.0, 0.015)

func play_warning_drum(stage: int = 1) -> void:
	_play("warning_drum", -5.0, 0.02, clampf(float(stage - 1) * 0.055, 0.0, 0.16))

func play_warning_horn() -> void:
	_play("warning_horn", -3.0, 0.01)

func play_breach() -> void:
	_play("breach", -1.5, 0.015)

func play_objective_tick(progress: int = 1) -> void:
	_play("objective_tick", -8.0, 0.015, clampf(float(progress - 1) * 0.035, 0.0, 0.18))''')

func _patch_single_player_hub() -> void:
	var path := "res://scripts/systems/single_player_world_controller.gd"
	_replace_once(path,
		"var first_run_guide_layer: CanvasLayer\nvar first_run_route_marker: Node2D\n",
		"var first_run_route_marker: Node2D\n")
	_replace_once(path, "_create_first_run_stronghold_guide()", "_create_first_run_stronghold_cue()")
	_replace_function(path, "func _create_first_run_stronghold_cue() -> void:", '''func _create_first_run_stronghold_cue() -> void:
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
		sound_fx.play_mine_awaken()''')
	_replace_function(path, "func _set_initial_status() -> void:", '''func _set_initial_status() -> void:
	if Global.minewars_runs_completed == 0:
		_set_status("The lower shaft is awake.")
	elif _advanced_modes_unlocked():
		_set_status("The stronghold is ready.")
	else:
		_set_status("The bastion endures.")''')
	_replace_function(path, "func _prepare_world_for_run(message: String) -> void:", '''func _prepare_world_for_run(message: String) -> void:
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
		hub_hud.queue_free()''')

func _patch_world_onboarding() -> void:
	var path := "res://scripts/systems/world_generation/world.gd"
	_replace_once(path, "var onboarding_entry_marker: Label\n", "var onboarding_entry_marker: Node2D\n")
	_replace_function(path, "func _create_entry_marker() -> void:", '''func _create_entry_marker() -> void:
	if onboarding_entry_marker and is_instance_valid(onboarding_entry_marker):
		return
	onboarding_entry_marker = Node2D.new()
	onboarding_entry_marker.name = "FirstRunDigMarker"
	onboarding_entry_marker.position = block_layer.map_to_local(TUTORIAL_GEM_CELL) + Vector2(0, -34)
	onboarding_entry_marker.z_index = 30
	add_child(onboarding_entry_marker)
	var glow := Polygon2D.new()
	var glow_points := PackedVector2Array()
	for index in range(25):
		glow_points.append(Vector2.RIGHT.rotated(TAU * float(index) / 24.0) * 28.0)
	glow.polygon = glow_points
	glow.color = Color(0.25, 0.94, 1.0, 0.12)
	onboarding_entry_marker.add_child(glow)
	for chevron_index in range(2):
		var chevron := Line2D.new()
		chevron.width = 5.0
		chevron.default_color = Color(0.38, 0.96, 1.0, 0.96 - float(chevron_index) * 0.22)
		var y := -18.0 + float(chevron_index) * 17.0
		chevron.points = PackedVector2Array([Vector2(-14, y), Vector2(0, y + 12), Vector2(14, y)])
		onboarding_entry_marker.add_child(chevron)
	onboarding_entry_marker_tween = create_tween().bind_node(onboarding_entry_marker).set_loops()
	onboarding_entry_marker_tween.tween_property(onboarding_entry_marker, "position:y", onboarding_entry_marker.position.y + 7.0, 0.55).set_trans(Tween.TRANS_SINE)
	onboarding_entry_marker_tween.tween_property(onboarding_entry_marker, "position:y", onboarding_entry_marker.position.y, 0.55).set_trans(Tween.TRANS_SINE)''')
	_replace_function(path, "func _set_onboarding_stage(stage: int) -> void:", '''func _set_onboarding_stage(stage: int) -> void:
	onboarding_stage = stage
	var hud := get_node_or_null("HUD")
	if hud == null or not hud.has_method("show_objective"):
		return
	match stage:
		OnboardingStage.DIG_DOWN:
			hud.show_objective("I", "DIG  ▼", "")
		OnboardingStage.FIND_GEM:
			hud.show_objective("II", "CRYSTAL SEAM", "")
		OnboardingStage.PICK_UP_GEM:
			hud.show_objective("III", "SPACE / A", "")
		OnboardingStage.BANK_GEM:
			hud.show_objective("IV", "RETURN  ◇", "")
		OnboardingStage.OPEN_UPGRADES:
			hud.show_objective("V", "FORGE  E / Y", "")
		OnboardingStage.COMPLETE:
			hud.show_objective("READY", "MINE  •  RETURN  •  DEFEND", "")
			Global.complete_prototype_onboarding()
			var objective_hud := hud
			get_tree().create_timer(2.2).timeout.connect(func():
				if is_instance_valid(objective_hud) and objective_hud.has_method("hide_objective"):
					objective_hud.hide_objective()
			)''')
	_replace_function(path, "func _play_first_crystal_discovery(gem: Node) -> void:", '''func _play_first_crystal_discovery(gem: Node) -> void:
	if gem == null or bool(get_meta("first_crystal_discovery_played", false)):
		return
	set_meta("first_crystal_discovery_played", true)
	var position := (gem as Node2D).global_position if gem is Node2D else Vector2.ZERO
	_spawn_resource_burst(position, Color(0.24, 1.0, 0.95, 1.0), "FirstCrystalDiscovery", 34)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_objective_tick"):
		sound_fx.play_objective_tick(2)
	var player := get_node_or_null("Player")
	var camera := player.get_node_or_null("Camera2D") as Camera2D if player else null
	if camera != null:
		var rest := camera.offset
		var shake := create_tween()
		shake.tween_property(camera, "offset", rest + Vector2(3, -2), 0.04)
		shake.tween_property(camera, "offset", rest + Vector2(-2, 2), 0.04)
		shake.tween_property(camera, "offset", rest, 0.07)''')
	_replace_function(path, "func notify_tutorial_gems_deposited(amount: int) -> void:", '''func notify_tutorial_gems_deposited(amount: int) -> void:
	if amount <= 0:
		return
	if not first_deposit_received:
		first_deposit_received = true
		wave_timer = min(wave_timer, 18.0)
	if onboarding_active and onboarding_stage <= OnboardingStage.OPEN_UPGRADES:
		_set_onboarding_stage(OnboardingStage.OPEN_UPGRADES)''')
	_replace_function(path, "func notify_tutorial_upgrade_opened() -> void:", '''func notify_tutorial_upgrade_opened() -> void:
	if not onboarding_active or onboarding_stage != OnboardingStage.OPEN_UPGRADES:
		return
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("show_objective"):
		hud.show_objective("V", "CHOOSE  STR  •  AGI  •  INT", "")''')

func _patch_gem_prompt() -> void:
	var path := "res://scripts/gameplay/collectibles/gems/gem.gd"
	_replace_once(path, "pickup_prompt.text = \"SPACE / A  •  PICK UP\"", "pickup_prompt.text = \"SPACE / A\"")
	_replace_once(path, "pickup_prompt.position = Vector2(-82, -58)", "pickup_prompt.position = Vector2(-52, -58)")
	_replace_once(path, "pickup_prompt.size = Vector2(164, 28)", "pickup_prompt.size = Vector2(104, 28)")

func _patch_base_prompts() -> void:
	var path := "res://base.gd"
	_replace_once(path, "const PROMPT_TEXT := \"E / Y  •  UPGRADE BASE\"", "const PROMPT_TEXT := \"E / Y  •  FORGE\"")
	_replace_once(path, "const HUB_PROMPT_TEXT := \"E / Y  •  INSPECT BASTION\"", "const HUB_PROMPT_TEXT := \"E / Y  •  STRONGHOLD\"")
	_replace_once(path, "const DEPOSIT_PROMPT_TEXT := \"RETURN HERE  •  GEMS AUTO-DEPOSIT\"", "const DEPOSIT_PROMPT_TEXT := \"◇  AUTO-BANK\"")
	_replace_once(path, "\"E / Y  •  MANAGE STRONGHOLD\"", "\"E / Y  •  LOADOUT\"")

func _patch_hud() -> void:
	var path := "res://hud.gd"
	_replace_function(path, "func _setup_objective_ui() -> void:", '''func _setup_objective_ui() -> void:
	objective_panel = PanelContainer.new()
	objective_panel.name = "FirstRunObjective"
	objective_panel.visible = false
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_panel.offset_left = -190
	objective_panel.offset_top = 74
	objective_panel.offset_right = 190
	objective_panel.offset_bottom = 132
	objective_panel.pivot_offset = Vector2(190, 29)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.035, 0.055, 0.82)
	panel_style.border_color = Color(0.18, 0.78, 1.0, 0.8)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 7
	panel_style.content_margin_bottom = 7
	objective_panel.add_theme_stylebox_override("panel", panel_style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	objective_panel.add_child(box)
	objective_step_label = Label.new()
	objective_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_step_label.add_theme_font_size_override("font_size", 9)
	objective_step_label.add_theme_color_override("font_color", Color(0.38, 0.82, 1.0, 0.9))
	box.add_child(objective_step_label)
	objective_title_label = Label.new()
	objective_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_title_label.add_theme_font_size_override("font_size", 17)
	objective_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68, 1.0))
	box.add_child(objective_title_label)
	objective_body_label = Label.new()
	objective_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_body_label.add_theme_font_size_override("font_size", 11)
	objective_body_label.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98, 1.0))
	box.add_child(objective_body_label)
	add_child(objective_panel)''')
	_replace_function(path, "func _setup_return_cue_ui() -> void:", '''func _setup_return_cue_ui() -> void:
	return_cue = Control.new()
	return_cue.name = "GemReturnCue"
	return_cue.visible = false
	return_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return_cue.size = Vector2(76, 46)
	var background := ColorRect.new()
	background.color = Color(0.015, 0.07, 0.085, 0.78)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return_cue.add_child(background)
	return_cue_arrow = Label.new()
	return_cue_arrow.text = "▶"
	return_cue_arrow.position = Vector2(4, 7)
	return_cue_arrow.size = Vector2(30, 30)
	return_cue_arrow.pivot_offset = Vector2(15, 15)
	return_cue_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return_cue_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return_cue_arrow.add_theme_font_size_override("font_size", 24)
	return_cue_arrow.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0, 1.0))
	return_cue.add_child(return_cue_arrow)
	return_cue_label = Label.new()
	return_cue_label.text = "◇"
	return_cue_label.position = Vector2(36, 7)
	return_cue_label.size = Vector2(36, 30)
	return_cue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return_cue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return_cue_label.add_theme_font_size_override("font_size", 16)
	return_cue_label.add_theme_color_override("font_color", Color(0.45, 1.0, 1.0, 1.0))
	return_cue_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	return_cue_label.add_theme_constant_override("outline_size", 3)
	return_cue.add_child(return_cue_label)
	add_child(return_cue)''')
	_replace_function(path, "func show_objective(step_text: String, title_text: String, body_text: String) -> void:", '''func show_objective(step_text: String, title_text: String, body_text: String) -> void:
	if not objective_panel:
		return
	objective_step_label.text = step_text
	objective_title_label.text = title_text
	objective_body_label.text = body_text
	objective_body_label.visible = not body_text.strip_edges().is_empty()
	objective_panel.visible = true
	if objective_tween and objective_tween.is_running():
		objective_tween.kill()
	objective_panel.scale = Vector2(0.96, 0.96)
	objective_panel.modulate = Color(1.18, 1.18, 1.18, 1.0)
	objective_tween = create_tween().set_parallel(true)
	objective_tween.tween_property(objective_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	objective_tween.tween_property(objective_panel, "modulate", Color.WHITE, 0.22)''')
	_replace_function(path, "func _update_carry_status() -> void:", '''func _update_carry_status() -> void:
	if not carry_status_panel or not carry_status_label:
		return
	var player := _get_player_node()
	var carry_load := int(player.get_carry_load()) if player and player.has_method("get_carry_load") else 0
	if carry_load == last_carry_load:
		return
	last_carry_load = carry_load
	carry_status_panel.visible = carry_load > 0
	if carry_load <= 0:
		return
	var allowance := int(player.get_free_carry_allowance()) if player.has_method("get_free_carry_allowance") else 0
	var overload: int = maxi(carry_load - allowance, 0)
	var penalty_percent: int = int(round(float(player.get_weight_penalty()) * 100.0)) if player.has_method("get_weight_penalty") else 0
	carry_status_label.text = "◇ %d   -%d%%" % [carry_load, penalty_percent] if overload > 0 else "◇ %d" % carry_load
	carry_status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3, 1.0) if overload > 0 else Color(0.55, 1.0, 1.0, 1.0))''')
	_replace_function(path, "func _update_return_cue() -> void:", '''func _update_return_cue() -> void:
	if not return_cue or not return_cue_arrow:
		return
	var world := get_parent()
	var player := world.get_node_or_null("Player") if world else null
	var base := world.get_node_or_null("Base") if world else null
	var carry_load := int(player.get_carry_load()) if player and player.has_method("get_carry_load") else 0
	var force_return := bool(world.get_meta("minewars_force_return_cue", false)) if world else false
	if not player or not base or (carry_load <= 0 and not force_return):
		return_cue.visible = false
		return
	var to_base: Vector2 = base.global_position - player.global_position
	var hide_distance := 190.0 if force_return else 330.0
	if to_base.length() < hide_distance:
		return_cue.visible = false
		return
	var direction := to_base.normalized()
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var half_extent := Vector2(max(viewport_size.x * 0.5 - 52.0, 20.0), max(viewport_size.y * 0.5 - 46.0, 20.0))
	var edge_scale := 1000000.0
	if abs(direction.x) > 0.001:
		edge_scale = min(edge_scale, half_extent.x / abs(direction.x))
	if abs(direction.y) > 0.001:
		edge_scale = min(edge_scale, half_extent.y / abs(direction.y))
	var cue_position := center + direction * edge_scale - return_cue.size * 0.5
	cue_position.x = clamp(cue_position.x, 8.0, max(viewport_size.x - return_cue.size.x - 8.0, 8.0))
	cue_position.y = clamp(cue_position.y, 8.0, max(viewport_size.y - return_cue.size.y - 8.0, 8.0))
	return_cue.position = cue_position
	return_cue_arrow.rotation = direction.angle()
	if force_return:
		return_cue_label.text = "!"
		return_cue_arrow.add_theme_color_override("font_color", Color(1.0, 0.36, 0.16, 1.0))
		return_cue_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.2, 1.0))
		var pulse := 1.0 + sin(float(Time.get_ticks_msec()) / 120.0) * 0.055
		return_cue.scale = Vector2.ONE * pulse
	else:
		return_cue_label.text = str(carry_load)
		return_cue_arrow.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0, 1.0))
		return_cue_label.add_theme_color_override("font_color", Color(0.45, 1.0, 1.0, 1.0))
		return_cue.scale = Vector2.ONE
	return_cue.visible = true''')

func _patch_minewars_controller() -> void:
	var path := "res://scripts/systems/world_generation/siege_mode_controller.gd"
	_replace_once(path,
		"var first_run_training_active := false\nvar muster_arrival_announced := false\n",
		"var muster_arrival_announced := false\n")
	_replace_function(path, "func _activate() -> void:", '''func _activate() -> void:
	world = get_parent() as Node2D
	if world == null or not is_instance_valid(world):
		queue_free()
		return
	if world.get("is_vs_mode") == true or not GameMode.is_siege():
		queue_free()
		return

	block_layer = world.get_node_or_null("BlockLayer") as TileMapLayer
	player = world.get_node_or_null("Player") as CharacterBody2D
	base = world.get_node_or_null("Base") as Node2D
	hud = world.get_node_or_null("HUD")
	upgrade_menu = world.get_node_or_null("UpgradeMenu")
	if block_layer == null or player == null or base == null:
		push_error("MineWars Expedition requires BlockLayer, Player, and Base.")
		queue_free()
		return

	world.set_process(false)
	world.set_meta("siege_mode", true)
	world.set_meta("minewars_expedition", true)
	world.set_meta("minewars_final_stage", FINAL_STAGE)
	world.set_meta("wave_spawning", false)
	world.set_meta("minewars_force_return_cue", false)
	world.set_meta("minewars_return_seconds", -1)
	if world.has_method("ensure_minewars_motherlodes"):
		world.ensure_minewars_motherlodes()
	world.current_wave_number = stage_number
	world.enemies_per_wave = int(STAGE_ENEMY_COUNTS.get(stage_number, 3))
	mining_timer = _mining_window_for(stage_number)
	_set_phase_meta("mining")
	_ensure_surface_lanes()
	_create_ui()
	_create_primary_entrance_marker()
	_initialize_stage_objective()
	_update_ui()
	_spawn_base_signal(Color(0.28, 0.88, 1.0, 0.9), 1, 58.0)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_mine_awaken"):
		sound_fx.play_mine_awaken()''')
	_replace_function(path, "func _play_opening_banner() -> void:", '''func _spawn_base_signal(signal_color: Color, pulse_count: int = 2, radius: float = 72.0) -> void:
	if base == null or not is_instance_valid(base):
		return
	var signal := Node2D.new()
	signal.name = "BastionSignal"
	signal.global_position = base.global_position
	signal.z_index = 24
	world.add_child(signal)
	var glow := Polygon2D.new()
	var glow_points := PackedVector2Array()
	for index in range(33):
		glow_points.append(Vector2.RIGHT.rotated(TAU * float(index) / 32.0) * radius * 0.74)
	glow.polygon = glow_points
	glow.color = Color(signal_color.r, signal_color.g, signal_color.b, 0.1)
	signal.add_child(glow)
	for pulse_index in range(maxi(pulse_count, 1)):
		var ring := Line2D.new()
		ring.width = 5.0
		ring.default_color = signal_color
		var points := PackedVector2Array()
		for index in range(33):
			points.append(Vector2.RIGHT.rotated(TAU * float(index) / 32.0) * radius)
		ring.points = points
		ring.scale = Vector2(0.42, 0.42)
		signal.add_child(ring)
		var pulse := create_tween()
		pulse.tween_interval(float(pulse_index) * 0.13)
		pulse.set_parallel(true)
		pulse.tween_property(ring, "scale", Vector2(1.08, 1.08), 0.66).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pulse.tween_property(ring, "modulate:a", 0.0, 0.7)
	var fade := create_tween()
	fade.tween_interval(0.65 + float(maxi(pulse_count - 1, 0)) * 0.13)
	fade.tween_property(glow, "modulate:a", 0.0, 0.28)
	fade.tween_callback(signal.queue_free)''')
	_replace_function(path, "func _finish_first_run_training() -> void:", '''func _pulse_entrance_marker(signal_color: Color, pulse_count: int = 2) -> void:
	if entrance_marker == null or not is_instance_valid(entrance_marker):
		return
	entrance_marker.modulate = signal_color
	var pulse := create_tween().set_loops(maxi(pulse_count, 1))
	pulse.tween_property(entrance_marker, "scale", Vector2(1.24, 1.24), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(entrance_marker, "scale", Vector2.ONE, 0.24)
	pulse.finished.connect(func():
		if is_instance_valid(entrance_marker):
			entrance_marker.modulate = Color.WHITE
	)''')
	_replace_function(path, "func _check_muster_arrival() -> void:", '''func _check_muster_arrival() -> void:
	if muster_arrival_announced or assault_muster_timer <= 0.0:
		return
	if player.global_position.distance_to(base.global_position) > RECOVERY_BASE_DISTANCE * 1.65:
		return
	muster_arrival_announced = true
	world.set_meta("minewars_force_return_cue", false)
	_spawn_base_signal(Color(0.32, 1.0, 0.58, 0.94), 2, 78.0)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_objective_tick"):
		sound_fx.play_objective_tick(2)''')
	_replace_function(path, "func _play_assault_warning_feedback() -> void:", '''func _play_assault_warning_feedback() -> void:
	_spawn_base_signal(Color(1.0, 0.28, 0.12, 0.94), 3, 86.0)
	_pulse_entrance_marker(Color(1.0, 0.42, 0.18, 1.0), 4)
	_spawn_breach_dust(0.7)
	_shake_camera(5.0)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_warning_horn"):
		sound_fx.play_warning_horn()''')
	_replace_function(path, "func _show_center_banner(title_text: String, body_text: String, accent: Color, hold_time: float) -> void:", '''func _spawn_breach_dust(strength: float = 1.0) -> void:
	if entrance_marker == null or not is_instance_valid(entrance_marker):
		return
	var dust := CPUParticles2D.new()
	dust.name = "BreachDust"
	dust.one_shot = true
	dust.amount = maxi(12, int(32.0 * strength))
	dust.lifetime = 0.65
	dust.explosiveness = 0.92
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 18.0
	dust.gravity = Vector2(0, 105)
	dust.initial_velocity_min = 55.0
	dust.initial_velocity_max = 145.0
	dust.scale_amount_min = 1.6
	dust.scale_amount_max = 5.0
	dust.color = Color(0.78, 0.48, 0.27, 0.88)
	dust.global_position = entrance_marker.global_position
	dust.z_index = 22
	world.add_child(dust)
	dust.emitting = true
	get_tree().create_timer(0.9).timeout.connect(dust.queue_free)

func _shake_camera(amount: float) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var rest := camera.offset
	var shake := create_tween()
	shake.tween_property(camera, "offset", rest + Vector2(amount, -amount * 0.55), 0.045)
	shake.tween_property(camera, "offset", rest + Vector2(-amount * 0.85, amount * 0.45), 0.045)
	shake.tween_property(camera, "offset", rest + Vector2(amount * 0.45, amount * 0.3), 0.045)
	shake.tween_property(camera, "offset", rest, 0.08)

func _play_breach_open_feedback() -> void:
	_spawn_breach_dust(1.35)
	_pulse_entrance_marker(Color(1.0, 0.22, 0.08, 1.0), 5)
	_shake_camera(8.0)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_breach"):
		sound_fx.play_breach()''')
	_replace_function(path, "func _process_mining(delta: float) -> void:", '''func _process_mining(delta: float) -> void:
	mining_timer = maxf(mining_timer - delta, 0.0)
	_update_stage_objective()
	_update_warning_stage()
	_sync_return_guidance()
	if mining_timer <= 0.0 and not wave_spawning:
		_start_assault()''')
	_replace_function(path, "func _start_assault() -> void:", '''func _start_assault() -> void:
	phase = Phase.ATTACK
	wave_spawning = true
	assault_muster_timer = float(STAGE_MUSTER_TIMES.get(stage_number, 8.0))
	assault_spawn_started = false
	muster_arrival_announced = false
	world.set_meta("wave_spawning", true)
	world.set_meta("minewars_force_return_cue", true)
	world.set_meta("minewars_return_seconds", ceili(assault_muster_timer))
	world.set_meta("active_wave_number", stage_number)
	world.current_wave_number = stage_number
	warning_stage = -1
	_set_phase_meta("attack")
	if not objective_completed and not objective_missed_announced:
		objective_missed_announced = true
		var sound_fx := get_node_or_null("/root/SoundFX")
		if sound_fx and sound_fx.has_method("play_error"):
			sound_fx.play_error()
	_play_assault_warning_feedback()
	if hud and hud.has_method("notify_wave_started"):
		hud.notify_wave_started(stage_number == FINAL_STAGE, stage_number)''')
	_replace_function(path, "func _spawn_assault() -> void:", '''func _spawn_assault() -> void:
	_play_breach_open_feedback()
	var is_boss := stage_number == FINAL_STAGE
	var entrance_position := _cell_world_position(FIXED_ENTRANCE_CELL)
	if world.has_method("_spawn_wave_telegraph"):
		world._spawn_wave_telegraph(entrance_position, is_boss)
	await get_tree().create_timer(0.8).timeout
	var roster: Array = [4] if is_boss else STAGE_ENEMY_ROSTERS.get(stage_number, [0, 0, 0])
	for index in range(roster.size()):
		if world == null or not is_instance_valid(world):
			return
		var enemy := _spawn_enemy(int(roster[index]), entrance_position + Vector2(0, float((index % 3) - 1) * 9.0), is_boss)
		if is_boss and enemy != null:
			_attach_boss_behavior(enemy)
		await get_tree().create_timer(SPAWN_GAP).timeout
	wave_spawning = false
	world.set_meta("wave_spawning", false)''')
	_replace_function(path, "func _complete_assault() -> void:", '''func _complete_assault() -> void:
	world.set_meta("minewars_force_return_cue", false)
	world.set_meta("minewars_return_seconds", -1)
	assault_muster_timer = 0.0
	assault_spawn_started = false
	_award_stage_clear_reward(stage_number)
	_spawn_base_signal(Color(0.34, 1.0, 0.58, 0.92), 2, 82.0)
	if stage_number >= FINAL_STAGE:
		_set_phase_meta("complete")
		world.current_wave_number = FINAL_STAGE + 1
		return

	stage_number += 1
	world.current_wave_number = stage_number
	world.enemies_per_wave = int(STAGE_ENEMY_COUNTS.get(stage_number, 1))
	phase = Phase.RECOVERY
	warning_stage = -1
	recovery_player_reached_base = false
	recovery_arrival_announced = false
	recovery_upgrade_opened = false
	_reset_stage_objective_state()
	_set_phase_meta("recovery")''')
	_replace_function(path, "func _award_stage_clear_reward(cleared_stage: int) -> void:", '''func _award_stage_clear_reward(cleared_stage: int) -> void:
	if hud == null or not hud.has_method("add_gems"):
		return
	var reward := int(STAGE_CLEAR_GEM_REWARDS.get(cleared_stage, 0))
	if reward <= 0:
		return
	hud.add_gems(reward)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_deposit"):
		sound_fx.play_deposit(reward)''')
	_replace_function(path, "func _begin_next_expedition() -> void:", '''func _begin_next_expedition() -> void:
	world.set_meta("minewars_force_return_cue", false)
	world.set_meta("minewars_return_seconds", -1)
	phase = Phase.MINING
	mining_timer = _mining_window_for(stage_number)
	warning_stage = -1
	recovery_player_reached_base = false
	recovery_arrival_announced = false
	recovery_upgrade_opened = false
	_initialize_stage_objective()
	_set_phase_meta("mining")
	_spawn_base_signal(Color(0.28, 0.88, 1.0, 0.82), 1, 58.0)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_mine_awaken"):
		sound_fx.play_mine_awaken()''')
	_replace_function(path, "func notify_objective_gem_dug(cell: Vector2i) -> void:", '''func notify_objective_gem_dug(cell: Vector2i) -> void:
	if phase != Phase.MINING or objective_completed or objective_dug_cells.has(cell):
		return
	if not _is_current_motherlode_cell(cell):
		return
	objective_dug_cells[cell] = true
	objective_progress = mini(objective_progress + 1, int(STAGE_MOTHERLODE_COUNTS.get(stage_number, objective_progress + 1)))
	world.set_meta("minewars_objective_progress", objective_progress)
	world.set_meta("minewars_objective_target", _objective_target())
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_objective_tick"):
		sound_fx.play_objective_tick(objective_progress)
	if objective_progress >= _objective_target():
		_complete_stage_objective()''')
	_replace_function(path, "func _complete_stage_objective() -> void:", '''func _complete_stage_objective() -> void:
	if objective_completed:
		return
	objective_completed = true
	world.set_meta("minewars_objective_complete", true)
	_award_objective_reward()
	_play_objective_completion_feedback()
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_upgrade"):
		sound_fx.play_upgrade()''')
	_replace_function(path, "func _update_warning_stage() -> void:", '''func _update_warning_stage() -> void:
	var maximum := _mining_window_for(stage_number)
	var new_stage := 0
	if mining_timer <= maxf(9.0, maximum * 0.12):
		new_stage = 3
	elif mining_timer <= maximum * 0.30:
		new_stage = 2
	elif mining_timer <= maximum * 0.55:
		new_stage = 1
	if new_stage == warning_stage:
		return
	warning_stage = new_stage
	if warning_stage <= 0:
		return
	var sound_fx := get_node_or_null("/root/SoundFX")
	match warning_stage:
		1:
			if sound_fx and sound_fx.has_method("play_warning_drum"):
				sound_fx.play_warning_drum(1)
			_pulse_entrance_marker(Color(1.0, 0.68, 0.28, 0.82), 1)
		2:
			if sound_fx and sound_fx.has_method("play_warning_drum"):
				sound_fx.play_warning_drum(2)
			_spawn_base_signal(Color(1.0, 0.62, 0.2, 0.88), 1, 68.0)
			_pulse_entrance_marker(Color(1.0, 0.5, 0.18, 0.92), 2)
		3:
			if sound_fx and sound_fx.has_method("play_warning_horn"):
				sound_fx.play_warning_horn()
			_spawn_base_signal(Color(1.0, 0.25, 0.1, 0.94), 3, 82.0)
			_pulse_entrance_marker(Color(1.0, 0.24, 0.08, 1.0), 3)
			_spawn_breach_dust(0.45)
			_shake_camera(3.5)''')
	_replace_function(path, "func _create_ui() -> void:", '''func _create_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 25
	add_child(ui_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 96)
	panel.custom_minimum_size = Vector2(304, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.032, 0.045, 0.78)
	style.border_color = Color(0.22, 0.54, 0.68, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	ui_layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)
	var title := Label.new()
	title.text = "MINEWARS"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3, 0.9))
	stack.add_child(title)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	stack.add_child(status_label)
	objective_label = Label.new()
	objective_label.add_theme_font_size_override("font_size", 12)
	objective_label.add_theme_color_override("font_color", Color(0.42, 0.94, 1.0, 1.0))
	stack.add_child(objective_label)
	build_label = Label.new()
	build_label.add_theme_font_size_override("font_size", 11)
	stack.add_child(build_label)
	hint_label = Label.new()
	hint_label.visible = false
	stack.add_child(hint_label)''')
	_replace_function(path, "func _update_ui() -> void:", '''func _update_ui() -> void:
	if status_label == null or not is_instance_valid(status_label):
		return
	var carry_load := int(player.get_carry_load()) if player.has_method("get_carry_load") else 0
	var depth := _player_depth()
	_update_build_label()
	_update_objective_label()

	if phase == Phase.ATTACK:
		if assault_muster_timer > 0.0:
			status_label.text = "ASSAULT  •  BREACHING\nD %d   ◇ %d" % [depth, carry_load]
		else:
			status_label.text = "ASSAULT  •  ENEMIES %d\nD %d   ◇ %d" % [_count_world_enemies(), depth, carry_load]
		return

	if phase == Phase.RECOVERY:
		status_label.text = "STRONGHOLD  •  SAFE\n◇ %d" % _banked_gems()
		return

	status_label.text = "%s  •  %s\nD %d   ◇ %d" % [_stage_name(stage_number), _danger_text(), depth, carry_load]''')
	_replace_function(path, "func _update_objective_label() -> void:", '''func _update_objective_label() -> void:
	if objective_label == null:
		return
	if phase == Phase.RECOVERY:
		objective_label.text = "NEXT  •  %s" % _objective_title()
		return
	var state := "✓" if objective_completed else "%d/%d" % [mini(objective_progress, _objective_target()), _objective_target()]
	objective_label.text = "%s   %s   +%s" % [_objective_title(), state, _objective_reward_text()]''')
	_replace_function(path, "func _update_build_label() -> void:", '''func _update_build_label() -> void:
	if build_label == null or player == null:
		return
	var rpg := player.get_node_or_null("HeroRPGController")
	if rpg == null or not rpg.has_method("get_build_identity"):
		build_label.text = "STR %d   AGI %d   INT %d" % [int(player.get("strength")), int(player.get("agility")), int(player.get("intelligence"))]
		return
	var identity: Dictionary = rpg.call("get_build_identity")
	build_label.text = str(identity.get("title", "UNSHAPED"))
	build_label.add_theme_color_override("font_color", identity.get("color", Color.WHITE))''')
	_replace_function(path, "func _play_objective_completion_feedback() -> void:", '''func _play_objective_completion_feedback() -> void:
	if ui_layer == null or not is_instance_valid(ui_layer):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.position = Vector2.ZERO
	flash.size = viewport_size
	flash.color = Color(0.25, 0.9, 1.0, 0.0)
	ui_layer.add_child(flash)
	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "color:a", 0.16, 0.07)
	flash_tween.tween_property(flash, "color:a", 0.0, 0.24)
	flash_tween.finished.connect(flash.queue_free)

	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(360, 54)
	badge.position = Vector2((viewport_size.x - 360.0) * 0.5, viewport_size.y * 0.22)
	badge.pivot_offset = Vector2(180, 27)
	badge.scale = Vector2(0.78, 0.78)
	badge.modulate = Color(1, 1, 1, 0)
	ui_layer.add_child(badge)
	var label := Label.new()
	label.text = "%s   ✓   %s" % [_objective_title(), _objective_reward_text()]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.45, 0.96, 1.0))
	badge.add_child(label)
	var badge_tween := create_tween().set_parallel(true)
	badge_tween.tween_property(badge, "modulate", Color.WHITE, 0.12)
	badge_tween.tween_property(badge, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	badge_tween.chain().tween_interval(0.9)
	badge_tween.chain().tween_property(badge, "modulate:a", 0.0, 0.2)
	badge_tween.finished.connect(badge.queue_free)
	_shake_camera(3.0)''')
	_replace_function(path, "func _create_primary_entrance_marker() -> void:", '''func _create_primary_entrance_marker() -> void:
	entrance_marker = _create_entrance_marker(FIXED_ENTRANCE_CELL, "", Color(1.0, 0.28, 0.12, 0.9))''')
	_replace_function(path, "func _create_entrance_marker(cell: Vector2i, caption: String, color: Color) -> Node2D:", '''func _create_entrance_marker(cell: Vector2i, caption: String, color: Color) -> Node2D:
	var marker := Node2D.new()
	marker.global_position = _cell_world_position(cell)
	marker.z_index = 7
	world.add_child(marker)
	var glow := Polygon2D.new()
	var glow_points := PackedVector2Array()
	for index in range(25):
		glow_points.append(Vector2.RIGHT.rotated(TAU * float(index) / 24.0) * 30.0)
	glow.polygon = glow_points
	glow.color = Color(color.r, color.g, color.b, 0.08)
	marker.add_child(glow)
	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = color
	var points := PackedVector2Array()
	for index in range(25):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / 24.0) * 28.0)
	ring.points = points
	marker.add_child(ring)
	if not caption.is_empty():
		var label := Label.new()
		label.text = caption
		label.position = Vector2(-70, -50)
		label.size = Vector2(140, 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", color.lightened(0.28))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		marker.add_child(label)
	return marker''')

func _replace_once(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		failures.append("Could not read %s" % path)
		return
	if source.contains(new_text):
		return
	if not source.contains(old_text):
		failures.append("Patch target missing in %s: %s" % [path, old_text.left(100)])
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write %s" % path)
		return
	file.store_string(source.replace(old_text, new_text))
	file.close()

func _replace_function(path: String, signature: String, replacement: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		failures.append("Could not read %s" % path)
		return
	var start := source.find(signature)
	if start < 0:
		failures.append("Function target missing in %s: %s" % [path, signature])
		return
	var next := source.find("\nfunc ", start + signature.length())
	var tail := ""
	if next >= 0:
		tail = source.substr(next + 1)
	var result := source.substr(0, start) + replacement.strip_edges(false, true) + "\n\n" + tail
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write %s" % path)
		return
	file.store_string(result)
	file.close()
