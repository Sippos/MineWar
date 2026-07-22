extends Node2D

@export_enum("Masks", "GemDamage") var audit_mode: int = 0

const LEVEL_SCENE: PackedScene = preload("res://scenes/world/mine/level.tscn")
const TILE := 64

var level: Node2D
var block_layer: TileMapLayer
var edge_layer: TileMapLayer
var damage_layer: TileMapLayer
var front_layer: TileMapLayer
var front_damage_layer: TileMapLayer
var fog_layer: TileMapLayer

func _ready() -> void:
	level = LEVEL_SCENE.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	_prepare_blank_level()
	if audit_mode == 0:
		_build_mask_matrix()
	else:
		_build_gem_damage_matrix()
	_install_audit_camera()
	print("TERRAIN_VISUAL_AUDIT_READY mode=", audit_mode)

func _prepare_blank_level() -> void:
	level.set_process(false)
	level.wave_timer = 99999.0
	level.canvas_modulate.color = Color.WHITE
	block_layer = level.get_node("BlockLayer") as TileMapLayer
	edge_layer = level.get_node("EdgeLayer") as TileMapLayer
	damage_layer = level.get_node("DamageLayer") as TileMapLayer
	front_layer = level.get_node("FrontWallLayer") as TileMapLayer
	front_damage_layer = level.get_node("FrontDamageLayer") as TileMapLayer
	fog_layer = level.get_node("FogLayer") as TileMapLayer
	for layer in [level.get_node("BackgroundLayer"), block_layer, edge_layer, damage_layer, front_layer, front_damage_layer, fog_layer, level.get_node("RailLayer")]:
		(layer as TileMapLayer).clear()
	fog_layer.visible = false
	for node_name in ["HUD", "UpgradeMenu", "Base"]:
		var node := level.get_node_or_null(node_name)
		if node:
			node.visible = false
	var player := level.get_node_or_null("Player") as CharacterBody2D
	if player:
		player.visible = false
		player.set_process(false)
		player.set_physics_process(false)
		var player_camera := player.get_node_or_null("Camera2D") as Camera2D
		if player_camera:
			player_camera.enabled = false
	for raw_entry: Variant in level.gem_blocks.values():
		var entry: Dictionary = raw_entry
		for key in ["top", "front"]:
			var sprite := entry.get(key) as Sprite2D
			if is_instance_valid(sprite):
				sprite.queue_free()
	level.gem_blocks.clear()
	for child in level.get_children():
		if child is Sprite2D and (child.name.begins_with("GemTop_") or child.name.begins_with("GemFront_")):
			child.queue_free()

func _install_audit_camera() -> void:
	var camera := Camera2D.new()
	camera.name = "AuditCamera"
	camera.enabled = true
	camera.position = Vector2.ZERO
	camera.zoom = Vector2(0.62, 0.62) if audit_mode == 0 else Vector2(0.72, 0.72)
	add_child(camera)

func _set_block(cell: Vector2i, block_type := 1) -> void:
	block_layer.set_cell(cell, block_type, Vector2i.ZERO)

func _add_label(text: String, cell: Vector2i, offset := Vector2(-30, -48)) -> void:
	var label := Label.new()
	label.text = text
	label.position = block_layer.map_to_local(cell) + offset
	label.z_index = 30
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	level.add_child(label)

func _build_mask_matrix() -> void:
	var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var bits := [1, 2, 4, 8]
	for mask in range(16):
		var col := mask % 4
		var row := mask / 4
		var center := Vector2i(-9 + col * 6, -9 + row * 6)
		_set_block(center)
		for i in range(4):
			if (mask & bits[i]) == 0:
				_set_block(center + directions[i])
		level.update_fog_mask(center)
		level.update_front_wall(center)
		_add_label("mask %02d" % mask, center)

func _configure_exposure(cell: Vector2i, open_top: bool, open_right: bool, open_bottom: bool, open_left: bool, block_type := 1) -> void:
	_set_block(cell, block_type)
	var specs := [
		[Vector2i.UP, open_top],
		[Vector2i.RIGHT, open_right],
		[Vector2i.DOWN, open_bottom],
		[Vector2i.LEFT, open_left],
	]
	for spec in specs:
		var neighbor: Vector2i = cell + spec[0]
		if not bool(spec[1]):
			_set_block(neighbor, block_type)
	level.update_fog_mask(cell)
	level.update_front_wall(cell)

func _add_gem(cell: Vector2i) -> void:
	level.gem_blocks[cell] = {"top": null, "front": null}
	level.update_fog_mask(cell)
	level.update_front_wall(cell)
	level._refresh_gem_indicator(cell)

func _build_gem_damage_matrix() -> void:
	# Directional gem faces and ambiguous exposure combinations.
	var directional := [
		[Vector2i(-9, -6), "TOP", true, false, false, false],
		[Vector2i(-5, -6), "LEFT", false, false, false, true],
		[Vector2i(-1, -6), "RIGHT", false, true, false, false],
		[Vector2i(3, -6), "FRONT", false, false, true, false],
		[Vector2i(7, -6), "ALL OPEN", true, true, true, true],
	]
	for item in directional:
		var cell: Vector2i = item[0]
		_configure_exposure(cell, item[2], item[3], item[4], item[5])
		_add_gem(cell)
		_add_label(item[1], cell)

	# Damage progression on each hardness tier.
	for tier in range(1, 4):
		for stage in range(3):
			var cell := Vector2i(-9 + (tier - 1) * 7 + stage * 2, -1)
			_configure_exposure(cell, true, false, false, false, tier)
			if stage == 1:
				damage_layer.set_cell(cell, 7, Vector2i.ZERO)
			elif stage == 2:
				damage_layer.set_cell(cell, 8, Vector2i.ZERO)
			_add_label("T%d D%d" % [tier, stage], cell)

	# Front-wall damage states.
	for stage in range(3):
		var cell := Vector2i(-8 + stage * 4, 4)
		_configure_exposure(cell, false, false, true, false)
		if stage > 0:
			front_damage_layer.set_cell(cell + Vector2i.DOWN, 12 + stage, Vector2i.ZERO)
		_add_label("FRONT D%d" % stage, cell)

	# Connected resource seams: single, pair, three-line, and 2x2 motherlode.
	var clusters: Array = [
		[Vector2i(4, 3), [Vector2i.ZERO], "SINGLE"],
		[Vector2i(7, 3), [Vector2i.ZERO, Vector2i.RIGHT], "PAIR"],
		[Vector2i(4, 7), [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.RIGHT * 2], "LINE 3"],
		[Vector2i(9, 7), [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1)], "2x2"],
	]
	for cluster in clusters:
		var origin: Vector2i = cluster[0]
		var cells: Array = cluster[1]
		for relative: Vector2i in cells:
			var cell := origin + relative
			_set_block(cell)
			level.gem_blocks[cell] = {"top": null, "front": null}
		for relative: Vector2i in cells:
			var cell := origin + relative
			level.update_fog_mask(cell)
			level.update_front_wall(cell)
			level._refresh_gem_indicator(cell)
		_add_label(cluster[2], origin)
