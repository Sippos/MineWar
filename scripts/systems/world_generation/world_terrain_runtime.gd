extends "res://scripts/systems/world_generation/world.gd"

# Runtime-rasterized SVG terrain avoids stale Godot import-cache assets while
# keeping the source art text-based and editable. All TileMap layers share the
# same TileSet resource, so replacing each atlas source once updates the world.
const TEXTURE_FACTORY = preload("res://scripts/systems/preparation/gem_indicator_texture_factory.gd")
const TERRAIN_TEXTURE_PATHS := {
	0: "res://assets/sprites/world/terrain/cave_floor_tile.svg",
	1: "res://assets/sprites/world/terrain/bricks/Easy_Brick_Rework.svg",
	2: "res://assets/sprites/world/terrain/bricks/Medium_Brick_Rework.svg",
	3: "res://assets/sprites/world/terrain/bricks/Hard_Brick_Rework.svg",
	4: "res://assets/sprites/world/terrain/edges/Easy_Edge_Atlas_Rework.svg",
	5: "res://assets/sprites/world/terrain/edges/Medium_Edge_Atlas_Rework.svg",
	6: "res://assets/sprites/world/terrain/edges/Hard_Edge_Atlas_Rework.svg",
	7: "res://assets/sprites/world/terrain/damage/First_Hitting_Rework.svg",
	8: "res://assets/sprites/world/terrain/damage/Second_Hitting_Rework.svg",
	10: "res://assets/sprites/world/terrain/front_walls/Easy_Brick-Front-Rework.svg",
	11: "res://assets/sprites/world/terrain/front_walls/Medium-Brick-Front-Rework.svg",
	12: "res://assets/sprites/world/terrain/front_walls/Hard-Brick-Front-Rework.svg",
	13: "res://assets/sprites/world/terrain/front_damage/First-Hit-Front-Rework.svg",
	14: "res://assets/sprites/world/terrain/front_damage/Next-Hit-Front-Rework.svg"
}
const GROUND_BACKDROP_PATH := "res://assets/environment/ground/blue_mine_ground.svg"

func _ready() -> void:
	_install_runtime_terrain_textures()
	super._ready()

func _install_runtime_terrain_textures() -> void:
	var tile_set_resource := block_layer.tile_set
	if tile_set_resource == null:
		push_error("Mine terrain TileSet is missing.")
		return
	for source_id: int in TERRAIN_TEXTURE_PATHS:
		if not tile_set_resource.has_source(source_id):
			continue
		var source := tile_set_resource.get_source(source_id) as TileSetAtlasSource
		if source == null:
			continue
		var texture := TEXTURE_FACTORY.load_svg_texture(String(TERRAIN_TEXTURE_PATHS[source_id]))
		if texture != null:
			source.texture = texture
	var ground_backdrop := get_node_or_null("GroundBackdrop") as TextureRect
	if ground_backdrop:
		var backdrop_texture := TEXTURE_FACTORY.load_svg_texture(GROUND_BACKDROP_PATH)
		if backdrop_texture != null:
			ground_backdrop.texture = backdrop_texture
