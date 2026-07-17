@tool
extends McpTestSuite

const BUTTON_NAMES := [
	"SinglePlayerButton",
	"MazeModeButton",
	"VSModeButton",
	"VSOnlineButton",
	"ControlsButton"
]

func suite_name() -> String:
	return "main_menu_layout"

func _new_menu() -> Control:
	var menu_script := GDScript.new()
	menu_script.source_code = FileAccess.get_file_as_string("res://scripts/ui/menus/main/menu.gd")
	assert_eq(menu_script.reload(), OK, "Fresh main-menu layout source must compile")
	var menu := menu_script.new() as Control
	var panel := Sprite2D.new()
	panel.name = "MenuPanel"
	var nested_panel := Sprite2D.new()
	nested_panel.name = "MenuPanel"
	panel.add_child(nested_panel)
	menu.add_child(panel)
	var title := Label.new()
	title.name = "Label"
	menu.add_child(title)
	for button_name in BUTTON_NAMES:
		var button := Button.new()
		button.name = button_name
		menu.add_child(button)
	var lexicon := TextureButton.new()
	lexicon.name = "LexikonButton"
	menu.add_child(lexicon)
	track(menu)
	return menu

func _buttons(menu: Control) -> Array[Button]:
	var result: Array[Button] = []
	for button_name in BUTTON_NAMES:
		result.append(menu.get_node(button_name) as Button)
	return result

func test_wide_main_menu_buttons_are_narrow_and_centered() -> void:
	var menu := _new_menu()
	var screen_size := Vector2(1152, 648)
	menu.call("_layout_for_screen", screen_size)
	var buttons := _buttons(menu)
	var expected_center_x := screen_size.x * 0.5
	for button in buttons:
		var button_center_x := (button.offset_left + button.offset_right) * 0.5
		var button_width := button.offset_right - button.offset_left
		assert_true(absf(button_center_x - expected_center_x) < 0.01, "%s should be centered on the viewport" % button.name)
		assert_true(button_width <= 232.01, "%s should not stretch to the previous oversized width" % button.name)
		assert_true(button_width >= 190.0, "%s should retain a comfortable click target" % button.name)
	var stack_center := (buttons[0].offset_top + buttons[-1].offset_bottom) * 0.5
	assert_true(absf(stack_center - screen_size.y * 0.51) < 0.1, "The button stack should align with the visual center of the menu panel")
	var title := menu.get_node("Label") as Label
	assert_true(title.get_theme_font_size("font_size") <= 48, "The desktop title should no longer dominate the entire top third")
	assert_true(title.size.x <= 520.01, "The title should use a bounded centered region")
	assert_true(absf((title.offset_left + title.offset_right) * 0.5 - expected_center_x) < 0.01, "The title should remain centered")

	var lexicon := menu.get_node("LexikonButton") as TextureButton
	assert_true(lexicon.size.x >= 84.0 and lexicon.size.x <= 96.01, "The bestiary book should now be a clearly visible secondary action")
	var backdrop := menu.get_node("LexikonBackdrop") as Panel
	assert_true(absf(backdrop.offset_right - (screen_size.x - 20.0)) < 0.01, "The bestiary callout should keep a deliberate desktop safe margin")
	assert_true(backdrop.size.x >= 143.9, "The book should sit inside a readable framed callout")
	var caption := menu.get_node("LexikonCaption") as Label
	assert_eq(caption.text, "BESTIARY", "The book should identify its destination")
	assert_true(caption.offset_bottom <= lexicon.offset_top, "The bestiary caption should sit above the book")
	var hint := menu.get_node("LexikonHint") as Label
	assert_true(hint.text.contains("BASES"), "The callout should advertise the new base collection")

func test_compact_main_menu_keeps_title_clear_and_buttons_on_screen() -> void:
	var menu := _new_menu()
	var screen_size := Vector2(480, 360)
	menu.call("_layout_for_screen", screen_size)
	var buttons := _buttons(menu)
	var title := menu.get_node("Label") as Label
	assert_true(buttons[0].offset_top >= title.offset_bottom + 7.9, "Compact buttons should not collide with the title")
	assert_true(buttons[-1].offset_bottom <= screen_size.y - 17.9, "The final compact button should remain inside the viewport")
	assert_true(buttons[0].size.x < 232.0, "Compact layouts should narrow the buttons further")
	for button in buttons:
		var button_center_x := (button.offset_left + button.offset_right) * 0.5
		assert_true(absf(button_center_x - screen_size.x * 0.5) < 0.01, "%s should remain centered in compact layouts" % button.name)
	assert_true(title.get_theme_font_size("font_size") <= 35, "Compact screens should use a restrained title size")

	var lexicon := menu.get_node("LexikonButton") as TextureButton
	assert_true(lexicon.size.x >= 51.9 and lexicon.size.x <= 68.01, "Compact bestiary access should remain visible without becoming dominant")
	var backdrop := menu.get_node("LexikonBackdrop") as Panel
	assert_true(backdrop.offset_right <= screen_size.x - 11.9 and backdrop.offset_bottom <= screen_size.y - 11.9, "The compact bestiary callout should stay inside the safe area")
	assert_true(backdrop.offset_left >= 7.9 and backdrop.offset_top >= 7.9, "The compact bestiary callout should remain fully on-screen")
	var caption := menu.get_node("LexikonCaption") as Label
	assert_true(caption.offset_left >= 7.9 and caption.offset_right <= screen_size.x - 7.9, "The compact bestiary caption should remain on-screen")
