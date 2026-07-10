extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size_changed.connect(_layout_for_screen)
	call_deferred("_layout_for_screen")
	$Panel/VBoxContainer/BackButton.call_deferred("grab_focus")

func _layout_for_screen() -> void:
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	
	var compact = screen_size.x < 700.0 or screen_size.y < 540.0
	var panel_width = min(640.0, max(280.0, screen_size.x - 24.0))
	var panel_height = min(460.0, max(300.0, screen_size.y - 24.0))
	var panel = $Panel
	panel.offset_left = -panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_bottom = panel_height * 0.5
	
	var content = $Panel/VBoxContainer
	var horizontal_margin = 28.0 if compact else 52.0
	var vertical_margin = 24.0 if compact else 42.0
	content.offset_left = horizontal_margin
	content.offset_top = vertical_margin
	content.offset_right = -horizontal_margin
	content.offset_bottom = -vertical_margin
	content.add_theme_constant_override("separation", 8 if compact else 12)
	
	var title = $Panel/VBoxContainer/Title
	title.custom_minimum_size.y = 36.0 if compact else 42.0
	title.add_theme_font_size_override("font_size", 22 if compact else 26)
	
	var label_height = 30.0 if compact else 34.0
	for label in $Panel/VBoxContainer/ScrollContainer/ControlsList.get_children():
		if label is Label:
			label.custom_minimum_size.y = label_height
	
	var back_button = $Panel/VBoxContainer/BackButton
	back_button.custom_minimum_size = Vector2(min(280.0, panel_width - horizontal_margin * 2.0), 52.0 if compact else 60.0)

func _on_back_pressed() -> void:
	queue_free()
