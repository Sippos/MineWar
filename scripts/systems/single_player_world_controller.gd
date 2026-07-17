extends Node

const MODE_SIGNS_SCENE := preload("res://scenes/world/preparation/single_player_mode_signs.tscn")
const HUB_HUD_SCENE := preload("res://scenes/ui/overlays/single_player_hub_hud.tscn")
const LINE_WARS_CONTROLLER_SCRIPT := preload("res://scripts/systems/continuous_line_wars_controller.gd")

const MINEWARS_ENTRY_Y := 0
const MINEWARS_MIN_X := 2
const MINEWARS_MAX_X := 4
const LINE_WARS_CAP_Y := -6
const LINE_WARS_APPROACH_Y := -5
const ADVENTURE_ENTRY_X := 10
const ADVENTURE_MIN_Y := -4
const ADVENTURE_MAX_Y := 3

@export var world_path: NodePath = NodePath("../Level")

var world: Node2D
var player: CharacterBody2D
var block_layer: TileMapLayer
var base: Node
var hud: CanvasLayer
var signs: Node2D
var hub_hud: CanvasLayer
var status_label: Label
var _committing := false
var _last_locked_message := ""

func _ready() -> void:
	world = get_node_or_null(world_path) as Node2D
	if world == null:
		push_error("Single Player world controller could not find Level")
		return
	player = world.get_node_or_null("Player") as CharacterBody2D
	block_layer = world.get_node_or_null("BlockLayer") as TileMapLayer
	base = world.get_node_or_null("Base")
	hud = world.get_node_or_null("HUD") as CanvasLayer
	if player == null or block_layer == null or base == null:
		push_error("Single Player world requires Player, BlockLayer, and Base")
		return

	GameMode.set_mode(GameMode.Mode.HUB)
	world.set_meta("single_player_hub_active", true)
	world.set_process(false)
	world.preparation_active = true
	world.preparation_mode = true

	# Older saves may have completed the first level before every implemented
	# hero was part of the reward list. Normalize them when entering the hub.
	if Global.first_level_beaten:
		for hero_name in Global.hero_data.keys():
			Global.unlock_hero(str(hero_name))

	Global.apply_selected_loadout()
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.velocity = Vector2.ZERO
	player.position = Vector2(192, -32)
	if player.has_method("update_hero_sprites"):
		player.update_hero_sprites()
	if base.has_method("refresh_base_sprite"):
		base.refresh_base_sprite()

	var player_camera := player.get_node_or_null("Camera2D") as Camera2D
	if player_camera:
		player_camera.enabled = true

	if hud:
		hud.visible = false
	var prompt := base.get_node_or_null("PromptLabel") as Label
	if prompt:
		prompt.visible = true

	signs = MODE_SIGNS_SCENE.instantiate() as Node2D
	world.add_child(signs)
	hub_hud = HUB_HUD_SCENE.instantiate() as CanvasLayer
	add_child(hub_hud)
	status_label = hub_hud.get_node("StatusPanel/Margin/Status") as Label
	_configure_progression_signs()
	_set_initial_status()

func _process(_delta: float) -> void:
	if _committing or world == null or player == null:
		return
	var cell := block_layer.local_to_map(block_layer.to_local(player.global_position))

	# Switch on the exact breakthrough dig. The upper chamber starts at y=-7 and
	# this cap row at y=-6 is the last solid ceiling between it and the hub shaft.
	# As soon as the cap in the hero's current lane is gone, control becomes peon.
	var in_shared_lane := cell.x >= MINEWARS_MIN_X and cell.x <= MINEWARS_MAX_X
	if in_shared_lane and cell.y <= LINE_WARS_APPROACH_Y:
		var cap_cell := Vector2i(cell.x, LINE_WARS_CAP_Y)
		if block_layer.get_cell_source_id(cap_cell) == -1:
			if _advanced_modes_unlocked():
				_activate_line_wars()
			else:
				_show_locked_message("LINEWARS LOCKED  •  Win MineWars once to unlock the peon maze route.")
			return

	# Adventure is checked before MineWars because its side chamber spans y=0.
	if cell.x >= ADVENTURE_ENTRY_X and cell.y >= ADVENTURE_MIN_Y and cell.y <= ADVENTURE_MAX_Y:
		if _advanced_modes_unlocked():
			_activate_standard_mode(GameMode.Mode.EXPLORATION, "Adventure active — explore the same mine for nests and artifacts.")
		else:
			_show_locked_message("ADVENTURE LOCKED  •  Win MineWars once to open the eastern expedition route.")
	elif cell.y >= MINEWARS_ENTRY_Y and in_shared_lane:
		_activate_standard_mode(GameMode.Mode.SIEGE, "MineWars active — mine, return resources, and survive the assault.")

func _advanced_modes_unlocked() -> bool:
	return Global.first_level_beaten

func _configure_progression_signs() -> void:
	if signs == null:
		return
	var hub_title := signs.get_node_or_null("HubTitle") as Label
	var line_wars := signs.get_node_or_null("LineWars") as Label
	var mine_wars := signs.get_node_or_null("MineWars") as Label
	var adventure := signs.get_node_or_null("Adventure") as Label
	if hub_title:
		hub_title.text = "HERO HALL  •  HEROES AT ALTARS  •  BASE AT THE CORE"
	if mine_wars:
		mine_wars.text = "↓  MINEWARS\nFIRST EXPEDITION • WAVES"
		mine_wars.modulate = Color.WHITE
	if _advanced_modes_unlocked():
		if line_wars:
			line_wars.text = "↑  LINEWARS\nDIG UP THE SAME SHAFT"
			line_wars.modulate = Color.WHITE
		if adventure:
			adventure.text = "ADVENTURE  →\nDIG EAST • EXPLORE"
			adventure.modulate = Color.WHITE
	else:
		if line_wars:
			line_wars.text = "↑  LINEWARS  •  LOCKED\nWIN MINEWARS ONCE"
			line_wars.modulate = Color(0.42, 0.44, 0.48, 0.9)
		if adventure:
			adventure.text = "ADVENTURE  •  LOCKED  →\nWIN MINEWARS ONCE"
			adventure.modulate = Color(0.42, 0.44, 0.48, 0.9)

func _set_initial_status() -> void:
	var base_name := str(Global.base_data.get(Global.selected_base_id, Global.base_data["default_base"]).get("name", "Dwarf Bastion"))
	if _advanced_modes_unlocked():
		_set_status("%s + %s ready. Approach a hero altar to change hero, use the central base to change fortress, then enter a route." % [Global.selected_hero_id, base_name])
	else:
		_set_status("FIRST EXPEDITION  •  Approach the Dwarf altar for abilities. The central base changes your fortress. Then enter MineWars.")

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
	_prepare_world_for_run("LineWars reached — control switched to the peon. Tab / RB returns to the hero.")
	world.set_process(false)

	var controller := Node.new()
	controller.name = "ContinuousLineWarsController"
	controller.set_script(LINE_WARS_CONTROLLER_SCRIPT)
	controller.set("breakthrough_position", breakthrough_position)
	world.add_child(controller)
	queue_free()

func _prepare_world_for_run(message: String) -> void:
	_set_status(message)
	world.remove_meta("single_player_hub_active")
	world.begin_run_from_preparation()
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
