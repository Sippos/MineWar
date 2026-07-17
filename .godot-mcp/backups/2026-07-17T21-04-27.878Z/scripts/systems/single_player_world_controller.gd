extends Node

const MODE_SIGNS_SCENE := preload("res://scenes/world/preparation/single_player_mode_signs.tscn")
const HUB_HUD_SCENE := preload("res://scenes/ui/overlays/single_player_hub_hud.tscn")
const LINE_WARS_CONTROLLER_SCRIPT := preload("res://scripts/systems/continuous_line_wars_controller.gd")

const MINEWARS_ENTRY_Y := 0
const LINE_WARS_ENTRY_Y := -22
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

	# The base remains functional as the loadout/upgrade anchor. The normal run
	# HUD stays hidden until a route is committed, keeping the room readable as
	# an in-world Single Player menu rather than another menu screen.
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
	_set_status("Choose through play: dig down for MineWars, east for Adventure, or up for LineWars.")

func _process(_delta: float) -> void:
	if _committing or world == null or player == null:
		return
	var cell := block_layer.local_to_map(block_layer.to_local(player.global_position))
	if cell.y <= LINE_WARS_ENTRY_Y:
		_activate_line_wars()
	elif cell.y >= MINEWARS_ENTRY_Y:
		_activate_standard_mode(GameMode.Mode.SIEGE, "MineWars active — mine, return resources, and survive the assault.")
	elif cell.x >= ADVENTURE_ENTRY_X and cell.y >= ADVENTURE_MIN_Y and cell.y <= ADVENTURE_MAX_Y:
		_activate_standard_mode(GameMode.Mode.EXPLORATION, "Adventure active — explore the same mine for nests and artifacts.")

func _activate_standard_mode(mode: GameMode.Mode, message: String) -> void:
	if _committing:
		return
	_committing = true
	GameMode.set_mode(mode)
	_prepare_world_for_run(message)

	# Adventure's controller takes ownership on its deferred bootstrap scan. Keep
	# the inherited wave loop dormant during that handoff.
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
	_prepare_world_for_run("LineWars surface reached — peon and hero now share this one persistent world.")
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
