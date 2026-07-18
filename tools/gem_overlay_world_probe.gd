extends Node

const LEVEL_SCENE: PackedScene = preload("res://scenes/world/mine/level.tscn")
const GEM_CELL := Vector2i(0, 2)

func _ready() -> void:
	_register_probe_inputs()
	var level := LEVEL_SCENE.instantiate()
	# Keep the real scene and world generation, but disable gameplay loops so the
	# close-up probe is stable and does not depend on player input.
	level.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

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
	player.visible = false
	player.position = level.block_layer.map_to_local(Vector2i(0, 1))
	var camera := player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.zoom = Vector2(5.0, 5.0)
	camera.position = Vector2(0.0, 34.0)

	# Force a predictable top-exposed tutorial gem and refresh its real runtime
	# overlay using the same code path as normal mining.
	level.on_cell_dug(Vector2i(0, 1))
	level.block_layer.set_cell(GEM_CELL, 1, Vector2i.ZERO)
	if not level.gem_blocks.has(GEM_CELL):
		level.gem_blocks[GEM_CELL] = {"top": null, "front": null}
	level._normalize_gem_indicator_sprites()
	level._refresh_gem_indicator(GEM_CELL)

	var overlay := CanvasLayer.new()
	add_child(overlay)
	var label := Label.new()
	label.text = "ACTUAL WORLD GEM OVERLAY"
	label.position = Vector2(18, 18)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	overlay.add_child(label)

func _register_probe_inputs() -> void:
	for action_name in [
		"p1_left", "p1_right", "p1_up", "p1_down", "p1_interact",
		"p1_grab", "p1_drop", "p1_stomp"
	]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
