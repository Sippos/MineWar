extends Node2D

const WIDTH := 1280
const HEIGHT := 720
const OUTPUT_PATH := "res://Hero_Showdown_Background.png"

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 246813579
	DisplayServer.window_set_size(Vector2i(WIDTH, HEIGHT))
	get_window().size = Vector2i(WIDTH, HEIGHT)

	var canvas := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	_build_background(canvas)
	_build_centerpiece(canvas)

	# Left team: use the right-facing directional row.
	_place_hero(canvas, "res://character_sprites/druid_walk_spritesheet_25d.png", 6, 2, 128, 128, Vector2i(128, 574), 252, Color8(236, 169, 72, 185))
	_place_hero(canvas, "res://assets/sprites/characters/dwarf/dwarf_walk_highres_spritesheet.png", 6, 3, 128, 128, Vector2i(318, 596), 282, Color8(241, 91, 61, 195))
	_place_hero(canvas, "res://character_sprites/mech_walk_pixelart_spritesheet.png", 6, 2, 64, 64, Vector2i(510, 610), 318, Color8(255, 195, 72, 205))

	# Right team: use the left-facing directional row.
	_place_hero(canvas, "res://character_sprites/undead_king_float_idle_spritesheet_25d_review.png", 2, 2, 128, 128, Vector2i(770, 610), 318, Color8(94, 166, 255, 210))
	_place_hero(canvas, "res://character_sprites/shaman_walk_spritesheet_25d.png", 2, 3, 128, 128, Vector2i(974, 596), 278, Color8(56, 214, 177, 195))
	_place_hero(canvas, "res://character_sprites/nerubian_walk_spritesheet_25d_review.png", 2, 2, 128, 128, Vector2i(1150, 574), 252, Color8(151, 101, 255, 195))

	_add_foreground(canvas)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	var save_error := canvas.save_png(output_absolute)
	if save_error != OK:
		push_error("Could not save hero background: %s" % error_string(save_error))
	else:
		print("Hero showdown background saved to: %s" % output_absolute)

	var preview := Sprite2D.new()
	preview.texture = ImageTexture.create_from_image(canvas)
	preview.position = Vector2(WIDTH / 2.0, HEIGHT / 2.0)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(preview)


func _build_background(img: Image) -> void:
	# Block-stepped cavern gradient.
	for y in range(0, HEIGHT, 8):
		var t := float(y) / float(HEIGHT)
		var top := Color8(7, 10, 22)
		var middle := Color8(16, 25, 39)
		var bottom := Color8(30, 22, 31)
		var color := top.lerp(middle, min(t * 1.65, 1.0)) if t < 0.61 else middle.lerp(bottom, (t - 0.61) / 0.39)
		img.fill_rect(Rect2i(0, y, WIDTH, 8), color)

	# Distant masonry silhouettes.
	for y in range(104, 520, 48):
		var offset := 0 if ((y / 48) as int) % 2 == 0 else 24
		for x in range(-offset, WIDTH, 72):
			var shade := Color8(19 + rng.randi_range(0, 8), 29 + rng.randi_range(0, 8), 43 + rng.randi_range(0, 9), 150)
			img.fill_rect(Rect2i(x + 2, y + 2, 66, 42), shade)
			img.fill_rect(Rect2i(x + 8, y + 7, 38, 4), Color8(49, 58, 72, 78))

	# Cave ceiling and stalactites.
	img.fill_rect(Rect2i(0, 0, WIDTH, 56), Color8(8, 8, 14))
	for x in range(0, WIDTH, 32):
		var depth := rng.randi_range(24, 116)
		img.fill_rect(Rect2i(x, 32, 32, depth), Color8(12, 13, 22))
		img.fill_rect(Rect2i(x + 5, 46, 7, max(4, depth - 20)), Color8(24, 26, 38, 180))
		if x % 96 == 0:
			var spike_h := rng.randi_range(34, 104)
			_draw_pixel_triangle(img, Vector2i(x + 16, 54 + depth), spike_h, 18, Color8(9, 10, 17), true)

	# Heavy side walls frame the confrontation.
	for side in [0, 1]:
		var base_x := 0 if side == 0 else WIDTH - 104
		img.fill_rect(Rect2i(base_x, 62, 104, 520), Color8(12, 15, 24))
		for y in range(80, 560, 42):
			var inset := rng.randi_range(8, 24)
			var bx := base_x + inset if side == 0 else base_x + 104 - inset - 58
			img.fill_rect(Rect2i(bx, y, 58, 32), Color8(29, 34, 47))
			img.fill_rect(Rect2i(bx + 6, y + 5, 34, 4), Color8(53, 59, 72, 125))

	# Pixel torches: warm on the left, arcane-blue on the right.
	_draw_torch(img, Vector2i(71, 235), Color8(255, 173, 56), Color8(255, 76, 34))
	_draw_torch(img, Vector2i(1209, 235), Color8(92, 216, 255), Color8(74, 95, 255))

	# Stone floor, seams and scattered chunks.
	img.fill_rect(Rect2i(0, 540, WIDTH, 180), Color8(20, 18, 25))
	img.fill_rect(Rect2i(0, 552, WIDTH, 13), Color8(50, 43, 50))
	img.fill_rect(Rect2i(0, 565, WIDTH, 8), Color8(14, 14, 20))
	for y in range(576, HEIGHT, 42):
		var offset := 0 if ((y / 42) as int) % 2 == 0 else 36
		for x in range(-offset, WIDTH, 94):
			var shade := 29 + rng.randi_range(0, 13)
			img.fill_rect(Rect2i(x + 3, y + 3, 86, 34), Color8(shade, shade - 3, shade + 5))
			img.fill_rect(Rect2i(x + 9, y + 8, 45, 4), Color8(72, 64, 72, 105))

	for i in range(45):
		var px := rng.randi_range(18, WIDTH - 20)
		var py := rng.randi_range(578, HEIGHT - 14)
		var size := rng.randi_range(3, 10)
		img.fill_rect(Rect2i(px, py, size, max(2, size / 2)), Color8(67, 57, 66, rng.randi_range(80, 175)))


func _build_centerpiece(img: Image) -> void:
	var center := Vector2i(WIDTH / 2, 345)

	# Two opposing pools of colored atmosphere.
	for radius in range(190, 30, -16):
		var alpha := int(3 + (190 - radius) * 0.08)
		_draw_diamond(img, center + Vector2i(-62, 8), radius, Color8(255, 116, 45, alpha))
		_draw_diamond(img, center + Vector2i(62, 8), radius, Color8(68, 174, 255, alpha))

	# Central split crystal and its stepped glow.
	for radius in range(116, 20, -12):
		_draw_diamond(img, center, radius, Color8(125, 111, 255, 10))
	_draw_diamond(img, center, 78, Color8(24, 29, 52, 230))
	_draw_diamond(img, center, 62, Color8(43, 49, 82, 245))
	_draw_diamond(img, center + Vector2i(-10, 2), 44, Color8(242, 120, 58, 245))
	_draw_diamond(img, center + Vector2i(10, 2), 44, Color8(65, 188, 239, 245))
	_draw_diamond(img, center, 23, Color8(239, 239, 255, 255))

	# Pixel sparks directed inward from both factions.
	for i in range(34):
		var py := rng.randi_range(205, 520)
		var left_x := rng.randi_range(500, 620)
		var right_x := rng.randi_range(660, 780)
		var size := rng.randi_range(2, 6)
		img.fill_rect(Rect2i(left_x, py, size * 2, size), Color8(255, 157, 72, rng.randi_range(100, 235)))
		img.fill_rect(Rect2i(right_x, py, size * 2, size), Color8(87, 205, 255, rng.randi_range(100, 235)))

	# A strong horizon line makes the poster usable behind menus.
	img.fill_rect(Rect2i(168, 524, WIDTH - 336, 4), Color8(115, 101, 125, 115))
	img.fill_rect(Rect2i(244, 530, WIDTH - 488, 2), Color8(245, 196, 134, 80))


func _place_hero(canvas: Image, path: String, row: int, column: int, cell_w: int, cell_h: int, anchor: Vector2i, target_height: int, glow_color: Color) -> void:
	var sheet := Image.load_from_file(path)
	if sheet == null or sheet.is_empty():
		push_error("Could not load hero sheet: %s" % path)
		return
	sheet.convert(Image.FORMAT_RGBA8)
	var frame_rect := Rect2i(column * cell_w, row * cell_h, cell_w, cell_h)
	var frame := sheet.get_region(frame_rect)
	frame = _crop_transparent(frame)
	if frame.is_empty():
		push_error("Hero frame was empty: %s row %d column %d" % [path, row, column])
		return

	var target_width := max(1, int(round(float(frame.get_width()) * float(target_height) / float(frame.get_height()))))
	frame.resize(target_width, target_height, Image.INTERPOLATE_NEAREST)

	var position := Vector2i(anchor.x - frame.get_width() / 2, anchor.y - frame.get_height())
	_draw_shadow(canvas, Vector2i(anchor.x, anchor.y - 5), max(44, frame.get_width() / 2), Color8(0, 0, 0, 155))

	var dark_outline := _alpha_tint(frame, Color8(4, 5, 9, 235))
	for offset in [Vector2i(-4, 0), Vector2i(4, 0), Vector2i(0, -4), Vector2i(0, 4), Vector2i(-3, -3), Vector2i(3, -3), Vector2i(-3, 3), Vector2i(3, 3)]:
		canvas.blend_rect(dark_outline, Rect2i(Vector2i.ZERO, dark_outline.get_size()), position + offset)

	var glow := _alpha_tint(frame, glow_color)
	for offset in [Vector2i(-9, 0), Vector2i(9, 0), Vector2i(0, -9), Vector2i(0, 9), Vector2i(-7, -7), Vector2i(7, -7), Vector2i(-7, 7), Vector2i(7, 7)]:
		canvas.blend_rect(glow, Rect2i(Vector2i.ZERO, glow.get_size()), position + offset)

	canvas.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), position)

	# Tiny ground-contact pixels keep every character seated in the scene.
	canvas.fill_rect(Rect2i(anchor.x - 25, anchor.y + 1, 50, 4), Color8(126, 109, 112, 82))


func _crop_transparent(source: Image) -> Image:
	var min_x := source.get_width()
	var min_y := source.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			if source.get_pixel(x, y).a > 0.025:
				min_x = min(min_x, x)
				min_y = min(min_y, y)
				max_x = max(max_x, x)
				max_y = max(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var margin := 2
	min_x = max(0, min_x - margin)
	min_y = max(0, min_y - margin)
	max_x = min(source.get_width() - 1, max_x + margin)
	max_y = min(source.get_height() - 1, max_y + margin)
	return source.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))


func _alpha_tint(source: Image, tint: Color) -> Image:
	var result := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	result.fill(Color(0, 0, 0, 0))
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var alpha := source.get_pixel(x, y).a
			if alpha > 0.01:
				result.set_pixel(x, y, Color(tint.r, tint.g, tint.b, alpha * tint.a))
	return result


func _draw_shadow(img: Image, center: Vector2i, radius: int, color: Color) -> void:
	var half_height := max(7, radius / 5)
	for dy in range(-half_height, half_height + 1, 3):
		var normalized := abs(float(dy)) / float(half_height)
		var half_width := int(radius * (1.0 - normalized * normalized))
		img.fill_rect(Rect2i(center.x - half_width, center.y + dy, half_width * 2, 3), color)


func _draw_diamond(img: Image, center: Vector2i, radius: int, color: Color) -> void:
	for dy in range(-radius, radius + 1, 4):
		var half_width := radius - abs(dy)
		if half_width > 0:
			img.fill_rect(Rect2i(center.x - half_width, center.y + dy, half_width * 2, 4), color)


func _draw_pixel_triangle(img: Image, tip: Vector2i, height: int, half_width: int, color: Color, points_down: bool) -> void:
	for step in range(0, height, 4):
		var progress := float(step) / float(height)
		var width_here := int(half_width * progress)
		var y := tip.y - step if points_down else tip.y + step
		img.fill_rect(Rect2i(tip.x - width_here, y, max(2, width_here * 2), 4), color)


func _draw_torch(img: Image, center: Vector2i, core: Color, edge: Color) -> void:
	# Stepped light halo.
	for radius in range(82, 12, -10):
		_draw_diamond(img, center, radius, Color(core.r, core.g, core.b, 0.012))
	img.fill_rect(Rect2i(center.x - 5, center.y + 28, 10, 70), Color8(78, 55, 42))
	img.fill_rect(Rect2i(center.x - 9, center.y + 25, 18, 9), Color8(124, 88, 55))
	_draw_diamond(img, center + Vector2i(0, 3), 24, edge)
	_draw_diamond(img, center + Vector2i(0, -3), 15, core)
	_draw_diamond(img, center + Vector2i(0, -7), 7, Color8(255, 244, 190))


func _add_foreground(img: Image) -> void:
	# Lower fog/dust strips, kept sparse so the heroes remain readable.
	for i in range(18):
		var x := rng.randi_range(20, WIDTH - 100)
		var y := rng.randi_range(612, 704)
		var width := rng.randi_range(35, 120)
		img.fill_rect(Rect2i(x, y, width, rng.randi_range(2, 5)), Color8(130, 119, 133, rng.randi_range(18, 50)))

	# Crisp pixel-art frame.
	img.fill_rect(Rect2i(0, 0, WIDTH, 8), Color8(2, 3, 8))
	img.fill_rect(Rect2i(0, HEIGHT - 8, WIDTH, 8), Color8(2, 3, 8))
	img.fill_rect(Rect2i(0, 0, 8, HEIGHT), Color8(2, 3, 8))
	img.fill_rect(Rect2i(WIDTH - 8, 0, 8, HEIGHT), Color8(2, 3, 8))
	img.fill_rect(Rect2i(12, 12, WIDTH - 24, 3), Color8(97, 82, 111, 90))
	img.fill_rect(Rect2i(12, HEIGHT - 15, WIDTH - 24, 3), Color8(97, 82, 111, 90))
