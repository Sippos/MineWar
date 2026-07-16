@tool
extends McpTestSuite

const HERO_SELECTION_SCENE := preload("res://hero_selection_menu.tscn")

func suite_name() -> String:
	return "hero_selection_layout"

func _compiled_source() -> String:
	var source := FileAccess.get_file_as_string("res://hero_selection_menu.gd")
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "Hero-selection layout source must compile")
	return source

func test_desktop_layout_uses_artwork_safe_content_and_one_footer_row() -> void:
	var source := _compiled_source()
	var menu := HERO_SELECTION_SCENE.instantiate() as Control
	track(menu)
	var footer := menu.get_node("Panel/VBox/Footer") as HBoxContainer
	var back := footer.get_node("BackBtn") as Button
	var start := footer.get_node("StartBtn") as Button
	assert_eq(footer.get_child_count(), 2, "Back and Start should share one footer row")
	assert_eq(footer.get_child(0), back, "Back should be the left footer action")
	assert_eq(footer.get_child(1), start, "Start should be the right primary action")
	assert_true(source.contains("else 86.0"), "Desktop content should respect the ornate panel's 86-pixel safe inset")
	assert_true(source.contains("panel_style.content_margin_left = 18.0"), "Ability content should not retain the old 48-pixel dead inset")
	assert_true(source.contains("Vector2(170, 48)"), "Desktop hero navigation should use readable labeled controls")
	assert_true(source.contains("p1_prev.text = \"◀  Previous\""), "Previous navigation should identify its action")
	assert_true(source.contains("p1_next.text = \"Next  ▶\""), "Next navigation should identify its action")

func test_compact_layout_stays_inside_the_visible_wood_interior() -> void:
	var source := _compiled_source()
	assert_true(source.contains("var horizontal_inset = 40.0 if compact_layout else 86.0"), "Compact layouts should stay clear of both decorative side rails")
	assert_true(source.contains("var bottom_inset = 32.0 if minimal_layout"), "Minimal layouts should keep the footer above the lower frame")
	assert_true(source.contains("var sprite_size = 92.0 if minimal_layout"), "Compact portraits should remain identifiable without forcing desktop dimensions")
	assert_true(source.contains("var ability_panel_width = 150.0 if minimal_layout"), "Compact ability content should fit beside the portrait")
	assert_true(source.contains("Vector2(132, 44) if minimal_layout"), "Compact Back and Start actions should fit on one row")
	assert_true(source.contains("func _layout_for_screen(forced_size: Vector2 = Vector2.ZERO)"), "The responsive layout should remain directly regression-testable")
