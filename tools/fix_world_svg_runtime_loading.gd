extends Node

const TARGET_PATH := "res://scripts/systems/world_generation/world.gd"

func _ready() -> void:
	var file := FileAccess.open(TARGET_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open world.gd")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	var replacements: Array[Dictionary] = [
		{
			"from": "const GEM_TOP_TEXTURE: Texture2D = preload(\"res://assets/sprites/world/terrain/gem_embedded_edge.svg\")\nconst GEM_FRONT_TEXTURE: Texture2D = preload(\"res://assets/sprites/world/terrain/gem_embedded_front.svg\")\nconst GEM_INDICATOR_TEXTURE: Texture2D = GEM_TOP_TEXTURE\nconst GEM_INDICATOR_TOP_SCALE := Vector2.ONE\nconst GEM_INDICATOR_FRONT_SCALE := Vector2.ONE\n",
			"to": "const BASE_GEM_TEXTURE_FACTORY = preload(\"res://scripts/systems/preparation/gem_indicator_texture_factory.gd\")\nconst GEM_TOP_TEXTURE_PATH := \"res://assets/sprites/world/terrain/gem_embedded_edge.svg\"\nconst GEM_FRONT_TEXTURE_PATH := \"res://assets/sprites/world/terrain/gem_embedded_front.svg\"\nconst GEM_INDICATOR_TOP_SCALE := Vector2.ONE\nconst GEM_INDICATOR_FRONT_SCALE := Vector2.ONE\n\nvar gem_top_texture: Texture2D\nvar gem_front_texture: Texture2D\n"
		},
		{
			"from": "\t_add_wasd_input()\n\t_configure_mine_lighting()\n",
			"to": "\t_add_wasd_input()\n\t_ensure_base_gem_indicator_textures()\n\t_configure_mine_lighting()\n"
		},
		{
			"from": "func _gem_chance_for_cell(cell: Vector2i, block_type: int) -> float:\n",
			"to": "func _ensure_base_gem_indicator_textures() -> void:\n\tif gem_top_texture == null:\n\t\tgem_top_texture = BASE_GEM_TEXTURE_FACTORY.load_svg_texture(GEM_TOP_TEXTURE_PATH)\n\tif gem_front_texture == null:\n\t\tgem_front_texture = BASE_GEM_TEXTURE_FACTORY.load_svg_texture(GEM_FRONT_TEXTURE_PATH)\n\nfunc _gem_chance_for_cell(cell: Vector2i, block_type: int) -> float:\n"
		}
	]
	for replacement in replacements:
		var from_text := str(replacement["from"])
		var to_text := str(replacement["to"])
		if source.count(from_text) != 1:
			push_error("Unexpected match count while patching world SVG loading")
			get_tree().quit(1)
			return
		source = source.replace(from_text, to_text)
	source = source.replace("sprite.texture = GEM_TOP_TEXTURE", "sprite.texture = gem_top_texture")
	source = source.replace("front_sprite.texture = GEM_FRONT_TEXTURE", "front_sprite.texture = gem_front_texture")
	source = source.replace("top_sprite.texture = GEM_TOP_TEXTURE", "top_sprite.texture = gem_top_texture")
	var output := FileAccess.open(TARGET_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Could not write world.gd")
		get_tree().quit(1)
		return
	output.store_string(source)
	print("WORLD_SVG_RUNTIME_LOADING_PASS")
	get_tree().quit(0)
