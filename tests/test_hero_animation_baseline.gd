@tool
extends McpTestSuite

const SHAMAN_WALK_PATH := "res://character_sprites/shaman_walk_spritesheet_25d.png"
const SHAMAN_ATTACK_PATH := "res://character_sprites/shaman_attack_spritesheet_25d.png"
const NERUBIAN_WALK_PATH := "res://character_sprites/nerubian_walk_spritesheet_25d.png"
const NERUBIAN_ATTACK_PATH := "res://character_sprites/nerubian_attack_spritesheet_25d.png"
const DRUID_WALK_PATH := "res://character_sprites/druid_walk_spritesheet_25d.png"
const DRUID_ATTACK_PATH := "res://character_sprites/druid_humanoid_staff_swing_spritesheet_25d.png"
const MOLE_CRAWL_PATH := "res://character_sprites/druid_mole_crawl_spritesheet_25d.png"
const MOLE_ATTACK_PATH := "res://character_sprites/druid_mole_attack_spritesheet_25d.png"
const UNDEAD_MINION_WALK_PATH := "res://character_sprites/undead_minion_walk_spritesheet_25d.png"

func suite_name() -> String:
	return "hero_animation_regression"

func _new_player_with_sprite() -> CharacterBody2D:
	var player_script := GDScript.new()
	player_script.source_code = FileAccess.get_file_as_string("res://player.gd")
	assert_eq(player_script.reload(), OK, "Fresh player.gd source must compile")
	var player := player_script.new() as CharacterBody2D
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.hframes = 8
	sprite.vframes = 8
	player.add_child(sprite)
	track(player)
	return player

func test_reviewed_animation_sheets_are_present_and_importable() -> void:
	for path in [SHAMAN_WALK_PATH, SHAMAN_ATTACK_PATH, NERUBIAN_WALK_PATH, NERUBIAN_ATTACK_PATH, DRUID_WALK_PATH, DRUID_ATTACK_PATH, MOLE_CRAWL_PATH, MOLE_ATTACK_PATH, UNDEAD_MINION_WALK_PATH]:
		assert_true(FileAccess.file_exists(path), "%s must exist" % path)
		var texture := load(path) as Texture2D
		assert_true(texture != null, "%s must import as a Texture2D" % path)
		assert_eq(texture.get_size(), Vector2(1024, 1024), "%s must remain an 8x8 sheet of 128 px frames" % path)

func test_dwarf_attack_keeps_walk_silhouette_size() -> void:
	var player := _new_player_with_sprite()
	player.set("current_hero_name", "Dwarf")
	player.call("_apply_sprite_visuals", false)
	var walk_scale: Vector2 = player.get("current_sprite_scale")
	var walk_position: Vector2 = player.get("current_sprite_position")
	player.call("_apply_sprite_visuals", true)
	var attack_scale: Vector2 = player.get("current_sprite_scale")
	var attack_position: Vector2 = player.get("current_sprite_position")
	assert_true(attack_scale.x > walk_scale.x * 1.25, "The smaller attack artwork needs an independent corrective scale")
	assert_true(attack_position.y < walk_position.y, "The enlarged swing should retain the Dwarf's foot anchor")

func test_shaman_attack_uses_matching_direction_row_without_mirroring() -> void:
	var player := _new_player_with_sprite()
	var sprite := player.get_node("Sprite2D") as Sprite2D
	player.set("current_hero_name", "Shaman")
	player.set("tex_attack", load(SHAMAN_ATTACK_PATH) as Texture2D)
	player.set("current_anim_row", 2) # World-facing left.
	sprite.texture = player.get("tex_attack") as Texture2D
	player.call("_apply_sprite_visuals", true)
	player.call("_update_action_animation", 0.1)
	assert_false(sprite.flip_h, "The corrected staff swing already uses the walk sheet's weapon hand")
	assert_eq(sprite.frame / 8, 2, "The corrected action sheet must use the same direction row as walking")

func test_shaman_walk_and_attack_keep_one_world_space_foot_anchor() -> void:
	var player := _new_player_with_sprite()
	player.set("current_hero_name", "Shaman")
	player.call("_apply_sprite_visuals", false)
	assert_eq(player.get("current_sprite_scale"), Vector2(0.64, 0.64))
	assert_eq(player.get("current_sprite_position"), Vector2(0, -5))
	player.call("_apply_sprite_visuals", true)
	assert_eq(player.get("current_sprite_scale"), Vector2(0.64, 0.64))
	assert_eq(player.get("current_sprite_position"), Vector2(0, -5))

func _frame_change_ratio(texture_path: String, row: int, first_frame: int, second_frame: int, start_y := 0) -> float:
	var texture := load(texture_path) as Texture2D
	var image := texture.get_image()
	var frame_size := Vector2i(image.get_width() / 8, image.get_height() / 8)
	var changed := 0
	var visible := 0
	for y in range(clampi(start_y, 0, frame_size.y - 1), frame_size.y):
		for x in range(frame_size.x):
			var first := image.get_pixel(first_frame * frame_size.x + x, row * frame_size.y + y)
			var second := image.get_pixel(second_frame * frame_size.x + x, row * frame_size.y + y)
			if first.a > 0.05 or second.a > 0.05:
				visible += 1
				var largest_delta: float = maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), maxf(absf(first.b - second.b), absf(first.a - second.a))))
				if largest_delta > 0.05:
					changed += 1
	return float(changed) / float(maxi(visible, 1))

func test_shaman_and_nerubian_walk_sheets_contain_real_body_motion() -> void:
	var shaman_ratio := _frame_change_ratio(SHAMAN_WALK_PATH, 6, 0, 4)
	var nerubian_leg_ratio := _frame_change_ratio(NERUBIAN_WALK_PATH, 6, 0, 4, 64)
	assert_true(shaman_ratio > 0.5, "Shaman walk must contain the approved Druid body gait rather than a static arm pose (ratio %.3f)" % shaman_ratio)
	assert_true(nerubian_leg_ratio > 0.25, "Nerubian walk must contain visible lower-body leg motion across the stride (ratio %.3f)" % nerubian_leg_ratio)

func test_nerubian_melee_and_brood_cast_both_use_action_state() -> void:
	var player := _new_player_with_sprite()
	player.set("current_hero_name", "Nerubian")
	var enemy := Node2D.new()
	player.set("currently_attacking_enemy", enemy)
	player.set("nerubian_cast_timer", 0.0)
	assert_true(bool(player.call("_is_currently_performing_action")), "Normal Nerubian melee contact must activate the attack sheet")
	player.set("currently_attacking_enemy", null)
	player.set("nerubian_cast_timer", 0.5)
	assert_true(bool(player.call("_is_currently_performing_action")), "Brood summoning must retain its cast animation")
	player.set("nerubian_cast_timer", 0.0)
	assert_false(bool(player.call("_is_currently_performing_action")))
	enemy.free()

func test_nerubian_walk_and_attack_use_the_same_source_render_fit() -> void:
	var player := _new_player_with_sprite()
	var sprite := player.get_node("Sprite2D") as Sprite2D
	player.set("current_hero_name", "Nerubian")
	player.set("tex_walk", load(NERUBIAN_WALK_PATH) as Texture2D)
	player.set("tex_attack", load(NERUBIAN_ATTACK_PATH) as Texture2D)
	player.call("_use_walk_animation_state")
	assert_eq(sprite.texture.resource_path, NERUBIAN_WALK_PATH)
	assert_eq(player.get("current_sprite_scale"), Vector2(0.46, 0.46))
	assert_eq(player.get("current_sprite_position"), Vector2(0, -9))
	player.call("_use_action_animation_state")
	assert_eq(sprite.texture.resource_path, NERUBIAN_ATTACK_PATH)
	assert_eq(player.get("current_sprite_scale"), Vector2(0.46, 0.46))
	assert_eq(player.get("current_sprite_position"), Vector2(0, -9))

func test_druid_humanoid_movement_selects_walk_sheet_before_frames_advance() -> void:
	var player := _new_player_with_sprite()
	var sprite := player.get_node("Sprite2D") as Sprite2D
	player.set("current_hero_name", "Druid")
	player.set("tex_walk", load(DRUID_WALK_PATH) as Texture2D)
	player.set("tex_attack", load(DRUID_ATTACK_PATH) as Texture2D)
	sprite.texture = player.get("tex_attack") as Texture2D
	sprite.flip_h = true
	player.call("_use_walk_animation_state")
	player.call("_update_direction_row", Vector2.RIGHT)
	player.call("_update_walk_animation", 0.2)
	assert_eq(sprite.texture.resource_path, DRUID_WALK_PATH)
	assert_false(sprite.flip_h)
	assert_eq(sprite.frame / 8, 6)
	assert_true(sprite.frame % 8 > 0, "Humanoid movement must advance through the walk cycle")

func test_mole_uses_separate_bright_crawl_and_attack_states() -> void:
	var player := _new_player_with_sprite()
	var sprite := player.get_node("Sprite2D") as Sprite2D
	player.set("current_hero_name", "Druid")
	player.set("druid_mole_active", true)
	player.set("tex_druid_mole", load(MOLE_CRAWL_PATH) as Texture2D)
	player.set("tex_druid_mole_attack", load(MOLE_ATTACK_PATH) as Texture2D)
	player.call("_use_druid_mole_animation_state", false)
	assert_eq(sprite.texture.resource_path, MOLE_CRAWL_PATH)
	player.call("_update_mole_walk_animation", 0.2)
	assert_true(sprite.frame % 8 > 0)
	player.call("_use_druid_mole_animation_state", true)
	assert_eq(sprite.texture.resource_path, MOLE_ATTACK_PATH)
	player.call("_update_mole_attack_animation", 0.2)
	assert_true(sprite.frame % 8 > 0)

func test_undead_minion_uses_the_safe_margin_walk_atlas() -> void:
	var scene_text := FileAccess.get_file_as_string("res://undead_minion.tscn")
	assert_true(scene_text.contains("scale = Vector2(0.56, 0.56)"), "The scene must fit the narrower safe-margin atlas")
	assert_true(scene_text.contains("position = Vector2(0, -8)"), "The rerendered feet must sit on the minion shadow")
	var minion_script := GDScript.new()
	minion_script.source_code = FileAccess.get_file_as_string("res://undead_minion.gd")
	assert_eq(minion_script.reload(), OK, "Fresh undead_minion.gd source must compile")
	var minion := minion_script.new() as CharacterBody2D
	track(minion)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(UNDEAD_MINION_WALK_PATH) as Texture2D
	sprite.hframes = 8
	sprite.vframes = 8
	sprite.scale = Vector2(0.56, 0.56)
	sprite.position = Vector2(0, -8)
	minion.add_child(sprite)
	minion.set("velocity", Vector2.RIGHT * 100.0)
	minion.call("_update_animation", 0.2)
	assert_eq(sprite.frame / 8, 6)
	assert_true(sprite.frame % 8 > 0, "The uncropped minion sheet must still advance through the walk cycle")
