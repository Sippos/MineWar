extends Node2D

const TILE_SIZE := 64
## Must match FRONT_FACE_HEIGHT in world_terrain_runtime.gd so the front crack lines
## up with the scaled front-face tile.
const FRONT_FACE_HEIGHT := 34
var crack_shader := preload("res://assets/shaders/damage_crack_overlay.gdshader")

var border_atlas: Texture2D
var inside_corners_atlas: Texture2D
var front_face: Texture2D

var _active_overlays: Dictionary = {}

@onready var world: Node2D = get_parent()

func _ready() -> void:
	z_index = 20 # Ensure it draws above terrain
	border_atlas = load("res://assets/sprites/world/terrain/dome/Cracks_Border_Atlas.png")
	inside_corners_atlas = load("res://assets/sprites/world/terrain/dome/Cracks_Inside_Corners.png")
	# Scale the crack front art the SAME way the front-face tile is scaled (64px art
	# squished into the shallow strip) so the crack pattern aligns with the face.
	front_face = _scale_front_crack(load("res://assets/sprites/world/terrain/dome/Cracks_Front_Face.png"))

func _scale_front_crack(tex: Texture2D) -> Texture2D:
	if tex == null:
		return tex
	var img := tex.get_image()
	img.resize(TILE_SIZE, FRONT_FACE_HEIGHT, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

func set_damage(cell: Vector2i, progress: float, is_front: bool = false) -> void:
	if progress <= 0.0 or progress >= 1.0:
		clear_damage(cell, is_front)
		return

	var key = str(cell) + ("_front" if is_front else "_top")
	if not _active_overlays.has(key):
		_create_overlay(cell, is_front, key)
	
	if _active_overlays.has(key):
		var overlay_data = _active_overlays[key]
		for sprite in overlay_data.sprites:
			var mat = sprite.material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("damage_progress", progress)

func clear_damage(cell: Vector2i, is_front: bool = false) -> void:
	var key = str(cell) + ("_front" if is_front else "_top")
	if _active_overlays.has(key):
		var overlay_data = _active_overlays[key]
		for sprite in overlay_data.sprites:
			sprite.queue_free()
		_active_overlays.erase(key)

func _create_overlay(cell: Vector2i, is_front: bool, key: String) -> void:
	if world == null: return
	var block_layer = world.get_node_or_null("BlockLayer") as TileMapLayer
	var edge_layer = world.get_node_or_null("EdgeLayer") as TileMapLayer
	var front_layer = world.get_node_or_null("FrontWallLayer") as TileMapLayer
	var corners = [
		world.get_node_or_null("InsideCornerTL") as TileMapLayer,
		world.get_node_or_null("InsideCornerTR") as TileMapLayer,
		world.get_node_or_null("InsideCornerBL") as TileMapLayer,
		world.get_node_or_null("InsideCornerBR") as TileMapLayer
	]
	
	if block_layer == null: return
	
	var sprites: Array[Sprite2D] = []
	var cell_pos = block_layer.map_to_local(cell)
	
	if is_front:
		if front_layer != null and front_layer.get_cell_source_id(cell) != -1:
			# Match the scaled front-face TILE. Its tile uses region (64, h) and
			# texture_origin (0, 32 - h/2); a Sprite2D centres its texture on position,
			# and a TileMapLayer tile's texture centre sits at cell_centre - origin, so
			# the sprite offset is -(32 - h/2). The whole (already-scaled) crack strip
			# is used. It inherits the manager's z (like the top cracks) instead of the
			# old absolute z=-1, which hid it behind the front wall (also z=-1).
			var sprite = _make_sprite(front_face, Rect2(0, 0, TILE_SIZE, FRONT_FACE_HEIGHT))
			sprite.position = cell_pos
			sprite.offset = Vector2(0, -(32 - FRONT_FACE_HEIGHT / 2))
			add_child(sprite)
			sprites.append(sprite)
	else:
		if edge_layer != null and edge_layer.get_cell_source_id(cell) != -1:
			var atlas_coords = edge_layer.get_cell_atlas_coords(cell)
			var rect = Rect2(atlas_coords.x * TILE_SIZE, atlas_coords.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var sprite = _make_sprite(border_atlas, rect)
			sprite.position = cell_pos
			add_child(sprite)
			sprites.append(sprite)
			
		for corner_layer in corners:
			if corner_layer != null and corner_layer.get_cell_source_id(cell) != -1:
				var atlas_coords = corner_layer.get_cell_atlas_coords(cell)
				var rect = Rect2(atlas_coords.x * TILE_SIZE * 2, atlas_coords.y * TILE_SIZE * 2, TILE_SIZE * 2, TILE_SIZE * 2)
				var sprite = _make_sprite(inside_corners_atlas, rect)
				sprite.position = cell_pos
				# Replicate the TileSet's texture_origin offsets for inside corners
				if atlas_coords == Vector2i(0, 0): sprite.offset = Vector2(32, 32)
				elif atlas_coords == Vector2i(1, 0): sprite.offset = Vector2(-32, 32)
				elif atlas_coords == Vector2i(0, 1): sprite.offset = Vector2(32, -32)
				elif atlas_coords == Vector2i(1, 1): sprite.offset = Vector2(-32, -32)
				add_child(sprite)
				sprites.append(sprite)
				
	if not sprites.is_empty():
		_active_overlays[key] = {"sprites": sprites}

func _make_sprite(tex: Texture2D, region: Rect2) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.region_enabled = true
	sprite.region_rect = region
	
	var mat = ShaderMaterial.new()
	mat.shader = crack_shader
	mat.set_shader_parameter("damage_progress", 0.0)
	mat.set_shader_parameter("use_color_alpha_as_damage", false)
	sprite.material = mat
	return sprite
