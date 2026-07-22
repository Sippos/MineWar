extends Node

func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var audit := get_parent()
	var level := audit.get_node_or_null("Level")
	if level == null:
		print("GEM_RUNTIME_PROBE no level")
		return
	var script := level.get_script() as Script
	print("GEM_RUNTIME_PROBE script=", script.resource_path if script else "<none>", " ensure_method=", level.has_method("_ensure_gem_textures"))
	if level.has_method("_ensure_gem_textures"):
		print("GEM_RUNTIME_PROBE ensure_result=", level.call("_ensure_gem_textures"))
	print("GEM_RUNTIME_PROBE count=", level.gem_blocks.size(), " atlas=", level.get("gem_overlay_atlas"))
	for raw_cell: Variant in level.gem_blocks.keys():
		var cell := Vector2i(raw_cell)
		if level.has_method("_refresh_gem_indicator"):
			level.call("_refresh_gem_indicator", cell)
		var entry: Dictionary = level.gem_blocks[cell]
		var top := entry.get("top") as Sprite2D
		var front := entry.get("front") as Sprite2D
		print("GEM_ENTRY cell=", cell,
			" top_valid=", is_instance_valid(top),
			" top_visible=", top.visible if is_instance_valid(top) else false,
			" top_region=", top.region_rect if is_instance_valid(top) else Rect2(),
			" top_pos=", top.global_position if is_instance_valid(top) else Vector2.ZERO,
			" front_valid=", is_instance_valid(front),
			" front_visible=", front.visible if is_instance_valid(front) else false,
			" front_region=", front.region_rect if is_instance_valid(front) else Rect2(),
			" front_pos=", front.global_position if is_instance_valid(front) else Vector2.ZERO)
