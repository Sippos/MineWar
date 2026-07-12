extends Control

func _ready() -> void:
	_layout_for_screen()
	get_tree().root.size_changed.connect(_layout_for_screen)
	$Center/VBox/StartButton.pressed.connect(_on_start_pressed)
	$Center/VBox/MenuButton.pressed.connect(_on_menu_pressed)
	$Center/VBox/StartButton.call_deferred("grab_focus")

func _layout_for_screen() -> void:
	var size = get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var compact = size.x < 700.0 or size.y < 520.0
	$Center.offset_left = 0.0
	$Center.offset_top = 0.0
	$Center.offset_right = 0.0
	$Center.offset_bottom = 0.0
	$Center/VBox.add_theme_constant_override("separation", 10 if compact else 16)
	$Center/VBox/Title.add_theme_font_size_override("font_size", 38 if compact else 56)
	$Center/VBox/Hint.add_theme_font_size_override("font_size", 16 if compact else 22)
	var button_size = Vector2(clamp(size.x * 0.72, 220.0, 320.0), 48.0 if compact else 58.0)
	$Center/VBox/StartButton.custom_minimum_size = button_size
	$Center/VBox/MenuButton.custom_minimum_size = button_size

func _on_start_pressed() -> void:
	Global.hero_p1 = "Dwarf"
	Global.hero_p2 = "Dwarf"
	Global.current_hero = "Dwarf"
	get_tree().change_scene_to_file("res://scenes/boot/main.tscn")

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main/menu.tscn")
