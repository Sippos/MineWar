extends RefCounted

## Shared typography + button styling used by the Main Menu and every other
## menu so the look stays consistent (Cinzel weight 900 + embolden, gold palette,
## outline + shadow).

const MENU_FONT: FontFile = preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")
const DECORATIVE_FONT: FontFile = preload("res://assets/fonts/grenze_gotisch/GrenzeGotisch-Variable.ttf")

const FONT_COLOR := Color(1.0, 0.94, 0.8, 1.0)
const FONT_HOVER := Color(1.0, 0.98, 0.82, 1.0)
const FONT_PRESSED := Color(1.0, 0.72, 0.32, 1.0)
const FONT_FOCUS := Color(0.73, 0.93, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.03, 0.012, 0.006, 0.98)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.82)

const TITLE_GOLD := Color(1.0, 0.84, 0.32, 1.0)


static func make_font_variation(base_font: Font, weight: float, embolden: float = 0.0) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = base_font
	font.variation_opentype = {"wght": weight}
	font.variation_embolden = embolden
	return font


static func primary_button_font() -> FontVariation:
	return make_font_variation(MENU_FONT, 900.0, 0.85)


static func detail_font() -> FontVariation:
	# Heavy like primary buttons so body labels stay readable on dark wood panels
	return make_font_variation(MENU_FONT, 850.0, 0.55)


static func apply_option_style(control: Control, font_size: int = 14) -> void:
	if not is_instance_valid(control):
		return
	control.add_theme_font_override("font", primary_button_font())
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", FONT_COLOR)
	control.add_theme_color_override("font_hover_color", FONT_HOVER)
	control.add_theme_color_override("font_pressed_color", FONT_PRESSED)
	control.add_theme_color_override("font_focus_color", FONT_FOCUS)
	control.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	control.add_theme_constant_override("outline_size", 3)
	control.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	control.add_theme_constant_override("shadow_offset_x", 1)
	control.add_theme_constant_override("shadow_offset_y", 1)
	control.add_theme_constant_override("shadow_outline_size", 1)


static func decorative_heading_font() -> FontVariation:
	return make_font_variation(DECORATIVE_FONT, 760.0)


static func decorative_detail_font() -> FontVariation:
	return make_font_variation(DECORATIVE_FONT, 600.0)


static func apply_primary_button_style(button: Button, font_size: int = 20) -> void:
	if not is_instance_valid(button):
		return
	button.add_theme_font_override("font", primary_button_font())
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", FONT_COLOR)
	button.add_theme_color_override("font_hover_color", FONT_HOVER)
	button.add_theme_color_override("font_pressed_color", FONT_PRESSED)
	button.add_theme_color_override("font_focus_color", FONT_FOCUS)
	button.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	button.add_theme_constant_override("shadow_offset_x", 1)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.add_theme_constant_override("shadow_outline_size", 1)


static func apply_title_style(label: Label, font_size: int = 28) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_font_override("font", primary_button_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TITLE_GOLD)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 4)


static func apply_detail_style(label: Label, font_size: int = 14) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_font_override("font", detail_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 0.96))
	label.add_theme_constant_override("outline_size", 2)
