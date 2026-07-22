extends Node

const CONTROLS_PATH := "res://scripts/ui/menus/controls/controls_menu.gd"
const SETTINGS_PATH := "res://scripts/ui/menus/settings_menu.gd"
const FONT_LINE := 'const MENU_FONT: FontFile = preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")\n'

func _ready() -> void:
	var controls := FileAccess.get_file_as_string(CONTROLS_PATH)
	var settings := FileAccess.get_file_as_string(SETTINGS_PATH)
	if controls.is_empty() or settings.is_empty():
		push_error("Missing menu scripts")
		get_tree().quit(1)
		return
	controls = _add_font(controls)
	settings = _add_font(settings)
	controls = controls.replace('process_mode = Node.PROCESS_MODE_ALWAYS\n', 'process_mode = Node.PROCESS_MODE_ALWAYS\n\t_apply_menu_typography()\n') if not controls.contains('_apply_menu_typography()') else controls
	settings = settings.replace('process_mode = Node.PROCESS_MODE_ALWAYS\n', 'process_mode = Node.PROCESS_MODE_ALWAYS\n\t_apply_menu_typography()\n') if not settings.contains('_apply_menu_typography()') else settings
	if not controls.contains('func _apply_menu_typography()'):
		controls = controls.replace('\nfunc _unhandled_input', '\nfunc _apply_menu_typography() -> void:\n\tfor node in get_tree().get_nodes_in_group("ui_text"):\n\t\tnode.add_theme_font_override("font", MENU_FONT)\n\nfunc _unhandled_input')
	if not settings.contains('func _apply_menu_typography()'):
		settings = settings.replace('\nfunc _unhandled_input', '\nfunc _apply_menu_typography() -> void:\n\tfor node in [title_label, hint_label, back_button]:\n\t\tnode.add_theme_font_override("font", MENU_FONT)\n\t\tnode.add_theme_color_override("font_outline_color", Color.BLACK)\n\t\tnode.add_theme_constant_override("outline_size", 3)\n\nfunc _unhandled_input')
	_write(CONTROLS_PATH, controls)
	_write(SETTINGS_PATH, settings)
	print("CONTROLS_SETTINGS_STYLE_APPLIED")
	get_tree().quit()

func _add_font(source: String) -> String:
	if not source.contains("const MENU_FONT"):
		return source.replace("extends ", FONT_LINE + "\nextends ")
	return source

func _write(path: String, data: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(data)
	file.close()
