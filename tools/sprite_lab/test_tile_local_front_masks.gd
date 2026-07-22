extends Node

const PREVIEW_SCRIPT := preload("res://tools/sprite_lab/dome_material_preview_v2.gd")
const RUNTIME_SCRIPT := preload("res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd")

func _make_mask(size: int) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(size):
		var t := 0.0 if size <= 1 else float(y) / float(size - 1)
		var inset := roundi(sin(t * PI) * float(size) * 0.18)
		for x in range(inset, size - inset):
			image.set_pixel(x, y, Color.WHITE)
	return image

func _make_full(size: int, color: Color) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image

func _ready() -> void:
	var preview := PREVIEW_SCRIPT.new() as Control
	add_child(preview)
	await get_tree().process_frame
	var mask32 := _make_mask(32)
	var full32 := _make_full(32, Color.WHITE)
	preview.mass_image = full32
	preview.front_images = {
		"easy": full32,
		"medium": full32,
		"hard": full32,
		"unmineable": full32,
	}
	var frames: Array[Image] = []
	for _i in range(16):
		frames.append(mask32)
	preview.composite_images = {
		"easy": frames,
		"medium": frames,
		"hard": frames,
		"unmineable": frames,
	}
	preview.inside_corner_images = {
		"easy": [], "medium": [], "hard": [], "unmineable": []
	}
	preview.cells.clear()
	for y in range(8):
		for x in range(12):
			preview.cells[Vector2i(x, y)] = 0
	preview.cells[Vector2i(5, 3)] = 2
	preview.front_depth = 32
	preview.call("_rebuild_extrusion_texture")
	var preview_image := (preview.extrusion_texture as ImageTexture).get_image()
	var face_x := 5 * 32
	var face_y := 4 * 32
	if preview_image.get_pixel(face_x, face_y).a <= 0.95:
		push_error("Preview top-left edge should begin full width")
		get_tree().quit(1)
		return
	if preview_image.get_pixel(face_x, face_y + 16).a > 0.05:
		push_error("Preview left edge did not warp inward at mid-depth")
		get_tree().quit(1)
		return
	if preview_image.get_pixel(face_x + 16, face_y + 16).a <= 0.95:
		push_error("Preview centre was incorrectly removed by the side mask")
		get_tree().quit(1)
		return
	if preview_image.get_pixel(face_x + 31, face_y + 16).a > 0.05:
		push_error("Preview right edge did not warp inward at mid-depth")
		get_tree().quit(1)
		return

	var renderer := RUNTIME_SCRIPT.new() as Node2D
	renderer.depth = 32
	var atlas := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var mask64 := _make_mask(64)
	for frame in range(16):
		atlas.blit_rect(mask64, Rect2i(Vector2i.ZERO, Vector2i(64, 64)), Vector2i(frame % 4, frame / 4) * 64)
	renderer.atlas_images[1] = atlas
	renderer.front_images[1] = _make_full(64, Color.WHITE)
	var runtime_image := renderer.call("_build_extrusion_image", 1, 4) as Image
	if runtime_image.get_pixel(0, 64).a <= 0.95:
		push_error("Runtime top-left edge should begin full width")
		get_tree().quit(1)
		return
	if runtime_image.get_pixel(0, 80).a > 0.05:
		push_error("Runtime left edge did not warp inward at mid-depth")
		get_tree().quit(1)
		return
	if runtime_image.get_pixel(32, 80).a <= 0.95:
		push_error("Runtime centre was incorrectly removed by the side mask")
		get_tree().quit(1)
		return
	if runtime_image.get_pixel(63, 80).a > 0.05:
		push_error("Runtime right edge did not warp inward at mid-depth")
		get_tree().quit(1)
		return
	print("PASS: only tile-local left/right front edges warp; centre remains complete")
	get_tree().quit(0)
