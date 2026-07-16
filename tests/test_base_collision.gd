@tool
extends McpTestSuite

func suite_name() -> String:
	return "base_collision"

func test_physical_base_collision_stays_inside_visible_sprite() -> void:
	var packed_scene := ResourceLoader.load("res://base.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	assert_false(packed_scene == null, "base.tscn must load")
	if packed_scene == null:
		return
	var base := packed_scene.instantiate() as Area2D
	track(base)
	var sprite := base.get_node("Sprite2D") as Sprite2D
	var solid := base.get_node("SolidBody2D") as StaticBody2D
	var collision := solid.get_node("CollisionShape2D") as CollisionShape2D
	var shape := collision.shape as RectangleShape2D
	assert_false(sprite == null)
	assert_false(solid == null)
	assert_false(shape == null)
	if sprite == null or solid == null or shape == null:
		return

	var image := sprite.texture.get_image()
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.08:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	assert_true(max_x >= min_x and max_y >= min_y, "The base sprite must contain visible pixels")

	var visible_left := sprite.position.x + (float(min_x) - image.get_width() * 0.5) * sprite.scale.x
	var visible_top := sprite.position.y + (float(min_y) - image.get_height() * 0.5) * sprite.scale.y
	var visible_right := sprite.position.x + (float(max_x + 1) - image.get_width() * 0.5) * sprite.scale.x
	var visible_bottom := sprite.position.y + (float(max_y + 1) - image.get_height() * 0.5) * sprite.scale.y
	var collision_center := solid.position + collision.position
	var collision_left := collision_center.x - shape.size.x * 0.5
	var collision_top := collision_center.y - shape.size.y * 0.5
	var collision_right := collision_center.x + shape.size.x * 0.5
	var collision_bottom := collision_center.y + shape.size.y * 0.5

	assert_true(collision_left >= visible_left)
	assert_true(collision_right <= visible_right)
	assert_true(collision_top >= visible_top)
	assert_true(collision_bottom <= visible_bottom)
	assert_true(absf(collision_center.x - sprite.position.x) <= 1.0, "The physical blocker should be horizontally centered in the base")
	assert_true(absf(collision_center.y - sprite.position.y) <= 8.0, "The physical blocker should sit in the middle of the sprite, not below it")
	assert_true(shape.size.x <= 76.0 and shape.size.y <= 36.0, "The physical blocker should remain compact")
