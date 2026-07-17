extends Node

@export_range(0, 2, 1) var probe_mode: int = 0

const LEVEL_SCENE: PackedScene = preload("res://scenes/world/mine/level.tscn")
const GEM_CELL := Vector2i(0, 2)

func _ready() -> void:
	var level := LEVEL_SCENE.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	level.wave_timer = 99999.0
	level.canvas_modulate.color = Color.WHITE
	level.fog_layer.visible = false

	var hud := level.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	var upgrade_menu := level.get_node_or_null("UpgradeMenu")
	if upgrade_menu:
		upgrade_menu.visible = false
	var base := level.get_node_or_null("Base")
	if base:
		base.visible = false

	var player := level.get_node("Player") as CharacterBody2D
	player.set_physics_process(false)
	player.set_process(false)
	player.visible = false
	player.position = level.block_layer.map_to_local(Vector2i(0, 1))
	var camera := player.get_node("Camera2D") as Camera2D
	camera.zoom = Vector2(5.0, 5.0)
	camera.position = Vector2(0.0, 20.0)

	if probe_mode >= 1:
		level.on_cell_dug(Vector2i(-1, 2))
	if probe_mode >= 2:
		level.on_cell_dug(Vector2i(1, 2))

	var overlay := CanvasLayer.new()
	add_child(overlay)
	var label := Label.new()
	label.text = "GEM TILE PROBE — MODE %d" % probe_mode
	label.position = Vector2(18, 18)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	overlay.add_child(label)

	print("Tile artifact probe ready. Mode=", probe_mode, " gem cell=", GEM_CELL)
