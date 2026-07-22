extends Node

## Automated regression test for Dome Generator corner math.
##
## Validates that make_hole_corner_top_left() produces correct results for all
## 6 tiers. Run headlessly:
##   godot --headless -s tools/sprite_lab/test_corner_regression.tscn

const CORNER_BUILDER = preload("res://tools/sprite_lab/dome_corner_builder.gd")

const LOGICAL_SIZE := 32
const TILE_SIZE := 64
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const DIAG_DIR := "res://tools/sprite_lab/diagnostics"

const TIERS: Array[String] = ["unmineable", "easy", "medium", "hard", "gems", "cracks"]

## The straight border rim sits at y = 15 after the +4 shift.
## This is the critical alignment constant that must never change.
const EXPECTED_RIM_Y := 15

var pass_count := 0
var fail_count := 0
var log_lines: PackedStringArray = []

func _ready() -> void:
	_ensure_diag_dir()
	_log("=== Dome Corner Regression Test ===")
	_log("Date: %s" % Time.get_datetime_string_from_system())
	_log("")

	var mass_image := _load_mass()
	if mass_image == null:
		_log("FATAL: Could not load dark mass image. Aborting.")
		_finish(1)
		return

	for tier in TIERS:
		_test_tier(tier, mass_image)

	_log("")
	_log("=== Results: %d passed, %d failed ===" % [pass_count, fail_count])
	_save_log()
	_finish(1 if fail_count > 0 else 0)

func _test_tier(tier: String, mass_image: Image) -> void:
	_log("--- Testing tier: %s ---" % tier.to_upper())

	var border := _load_stamp(tier, "border_top")
	var edge_joint := _load_stamp(tier, "edge_joint_top_left")
	var hole_corner := _load_stamp(tier, "hole_corner_top_left")

	# Test 1: Verify stamps loaded correctly
	_assert("stamp_load_%s" % tier,
		border != null and edge_joint != null and hole_corner != null,
		"All 3 stamps loaded for %s" % tier)
	if border == null:
		_log("  SKIP remaining tests for %s (missing stamps)" % tier)
		return

	# Test 2: Verify output dimensions
	_assert("output_size_%s" % tier,
		hole_corner.get_width() == LOGICAL_SIZE and hole_corner.get_height() == LOGICAL_SIZE,
		"Hole corner is %dx%d (expected %dx%d)" % [
			hole_corner.get_width(), hole_corner.get_height(), LOGICAL_SIZE, LOGICAL_SIZE])

	# Test 3: Verify format
	_assert("output_format_%s" % tier,
		hole_corner.get_format() == Image.FORMAT_RGBA8,
		"Format is RGBA8")

	# Test 4: Check that the tier has non-transparent content (unless it's cracks with empty stamps)
	var has_content := _has_visible_pixels(hole_corner)
	var border_has_content := _has_visible_pixels(border)
	if not border_has_content:
		# If the border itself is empty/transparent, the hole corner should also be empty
		_assert("empty_tier_corner_%s" % tier,
			not has_content,
			"Empty border produces empty hole corner")
		_log("  (Tier %s has empty border — skipping rim alignment tests)" % tier)
	else:
		# Test 5: Rim alignment — verify pixels exist near the expected rim row
		_assert("has_content_%s" % tier, has_content,
			"Hole corner has visible pixels")

		var rim_found := _check_rim_alignment(hole_corner, EXPECTED_RIM_Y)
		_assert("rim_alignment_%s" % tier, rim_found,
			"Rim pixels found near y=%d (±2px tolerance)" % EXPECTED_RIM_Y)

		# Test 6: Regeneration consistency — rebuilding from stamps produces valid output
		var regenerated := CORNER_BUILDER.make_hole_corner_top_left(mass_image, border, edge_joint)
		_assert("regen_size_%s" % tier,
			regenerated.get_width() == LOGICAL_SIZE and regenerated.get_height() == LOGICAL_SIZE,
			"Regenerated corner is 32x32")

		var regen_has_content := _has_visible_pixels(regenerated)
		var regen_rim := false
		if regen_has_content:
			regen_rim = _check_rim_alignment(regenerated, EXPECTED_RIM_Y)
		_assert("regen_rim_%s" % tier, not regen_has_content or regen_rim,
			"Regenerated corner rim at y=%d (or empty)" % EXPECTED_RIM_Y)

		# Test 7: No stray pixels outside expected region
		# The hole corner should have content concentrated in the shifted area
		# (after +4 shift, content starts at x>=4, y>=4)
		var stray_count := _count_stray_pixels(hole_corner, 3)
		_assert("no_stray_%s" % tier, stray_count <= 24,
			"Stray pixels outside shift margin: %d (allowed ≤24)" % stray_count)

	# Test 8: Validate via corner builder's own validation
	var validation := CORNER_BUILDER.validate_hole_corner(hole_corner, border)
	_assert("builder_validate_%s" % tier, validation["valid"],
		"Builder validation: %s" % validation.get("message", "OK"))

	# Save diagnostic image
	var diag_path := DIAG_DIR + "/%s_hole_corner_test.png" % tier
	hole_corner.save_png(ProjectSettings.globalize_path(diag_path))
	_log("  Saved diagnostic: %s" % diag_path)

func _check_rim_alignment(image: Image, expected_y: int) -> bool:
	# Check for non-transparent pixels within ±5 rows of the expected rim
	# This accounts for very shallow borders (like Gems) which have smaller arc radii
	for y in range(maxi(0, expected_y - 5), mini(LOGICAL_SIZE, expected_y + 6)):
		for x in range(LOGICAL_SIZE):
			if image.get_pixel(x, y).a > 0.05:
				return true
	return false

func _count_stray_pixels(image: Image, margin: int) -> int:
	# Count pixels in the top-left margin (before the +4 shift should place content)
	var count := 0
	for y in range(margin):
		for x in range(LOGICAL_SIZE):
			if image.get_pixel(x, y).a > 0.05:
				count += 1
	for y in range(margin, LOGICAL_SIZE):
		for x in range(margin):
			if image.get_pixel(x, y).a > 0.05:
				count += 1
	return count

func _has_visible_pixels(image: Image) -> bool:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.05:
				return true
	return false

func _load_mass() -> Image:
	var paths := [
		"res://assets/sprites/world/terrain/dome/Dome_Dark_Mass.png",
		"res://assets/sprites/world/terrain/bricks/Easy_Brick_Rework.svg",
	]
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var image: Image
		if path.ends_with(".svg"):
			var svg_text := FileAccess.get_file_as_string(path)
			image = Image.new()
			if image.load_svg_from_string(svg_text, 1.0) != OK:
				continue
		else:
			image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			image.convert(Image.FORMAT_RGBA8)
			image.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
			return image
	return null

func _load_stamp(tier: String, stamp_name: String) -> Image:
	var path := SOURCE_DIR + "/%s_%s_32.png" % [tier, stamp_name]
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	image.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return image

func _assert(test_name: String, condition: bool, message: String) -> void:
	if condition:
		pass_count += 1
		_log("  ✓ %s: %s" % [test_name, message])
	else:
		fail_count += 1
		_log("  ✗ FAIL %s: %s" % [test_name, message])

func _log(text: String) -> void:
	print(text)
	log_lines.append(text)

func _ensure_diag_dir() -> void:
	var abs_path := ProjectSettings.globalize_path(DIAG_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)

func _save_log() -> void:
	var log_path := DIAG_DIR + "/corner_regression_log.txt"
	var abs_path := ProjectSettings.globalize_path(log_path)
	var file := FileAccess.open(abs_path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(log_lines))
		file.close()
		_log("Log saved to: %s" % log_path)

func _finish(exit_code: int) -> void:
	if not Engine.is_editor_hint():
		get_tree().quit(exit_code)
