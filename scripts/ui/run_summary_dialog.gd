class_name RunSummaryDialog
extends Control

## End-of-Run Retrospective & Score Breakdown Dialog.
## Displays comprehensive performance metrics, Quantic Foundry completion scores,
## and itemized Legacy Ore persistence ledger with zero unskippable downtime.

signal retry_requested
signal loadout_requested
signal workshop_requested
signal menu_requested

const MENU_PANEL_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/MenuPanel.png")
const MENU_BUTTON_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/Button.png")
const STRENGTH_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/stats/Strenght.png")
const AGILITY_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/stats/Agility.png")
const INTELLIGENCE_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/stats/Int.png")
const GEM_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/stats/StatRessources.png")
const GOLD_TEXTURE: Texture2D = preload("res://GoldCoin.png")
const MENU_FONT: FontFile = preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")
const DECORATIVE_FONT: FontFile = preload("res://assets/fonts/grenze_gotisch/GrenzeGotisch-Variable.ttf")

const HERO_PORTRAIT_TEXTURES := {
	"Dwarf": preload("res://character_sprites/hero_idle/dwarf_idle_front.png"),
	"Mech": preload("res://character_sprites/hero_idle/mech_idle_front.png"),
	"Shaman": preload("res://character_sprites/hero_idle/shaman_idle_front.png"),
	"Nerubian": preload("res://character_sprites/hero_idle/nerubian_idle_front.png"),
	"Druid": preload("res://character_sprites/hero_idle/druid_idle_front.png"),
	"Undead King": preload("res://character_sprites/hero_idle/undead_king_idle_front.png")
}

const HERO_BASE_TEXTURES := {
	"Dwarf": preload("res://DwarfBase.png"),
	"Shaman": preload("res://ShamanBase.png"),
	"Nerubian": preload("res://NerubianBase.png"),
	"Druid": preload("res://DruidBase.png"),
	"Undead King": preload("res://UndeadKingBase.png")
}

const RUN_SUMMARY_DATA_SCRIPT := preload("res://scripts/systems/gameplay/run_summary_data.gd")

var summary_data: RefCounted = null

var _on_retry_callback: Callable
var _on_loadout_callback: Callable
var _on_workshop_callback: Callable
var _on_menu_callback: Callable

@onready var panel: Panel = $Panel
@onready var content: VBoxContainer = $Panel/Content
@onready var title_label: Label = $Panel/Content/Title
@onready var subtitle_label: Label = $Panel/Content/Subtitle
@onready var result_body: HBoxContainer = $Panel/Content/ResultBody
@onready var hero_card: PanelContainer = $Panel/Content/ResultBody/HeroCard
@onready var run_summary_card: PanelContainer = $Panel/Content/ResultBody/RunSummaryCard
@onready var actions_container: GridContainer = $Panel/Content/Actions
@onready var retry_button: Button = $Panel/Content/Actions/RetryButton
@onready var change_loadout_button: Button = $Panel/Content/Actions/ChangeLoadoutButton
@onready var workshop_button: Button = $Panel/Content/Actions/WorkshopButton
@onready var main_menu_button: Button = $Panel/Content/Actions/MainMenuButton

func setup(
	data: RefCounted,
	retry_cb: Callable = Callable(),
	loadout_cb: Callable = Callable(),
	workshop_cb: Callable = Callable(),
	menu_cb: Callable = Callable()
) -> void:
	summary_data = data
	_on_retry_callback = retry_cb
	_on_loadout_callback = loadout_cb
	_on_workshop_callback = workshop_cb
	_on_menu_callback = menu_cb
	_render_summary()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 500
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if summary_data != null:
		_render_summary()
	call_deferred("_setup_focus")

func _setup_focus() -> void:
	if retry_button != null and is_instance_valid(retry_button):
		retry_button.grab_focus()

func _render_summary() -> void:
	if summary_data == null:
		return

	var vp := get_viewport()
	var viewport_size: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(1280.0, 720.0)
	var compact := viewport_size.x < 820.0 or viewport_size.y < 570.0

	var victory: bool = bool(summary_data.get("victory"))
	if title_label:
		title_label.text = "EXPEDITION VICTORY" if victory else "EXPEDITION DEFEAT"
		title_label.add_theme_color_override(
			"font_color",
			Color(0.96, 0.78, 0.22, 1.0) if victory else Color(1.0, 0.22, 0.16, 1.0)
		)

	if subtitle_label:
		if victory:
			subtitle_label.text = "The subterranean assault has been broken. Your spoils fuel the Stronghold."
		else:
			subtitle_label.text = "The bastion has fallen, but your harvested ore endures."

	_populate_hero_card(compact)
	_populate_run_summary_card(compact)
	_populate_banners(compact)
	_configure_buttons(compact)

func _populate_hero_card(compact: bool) -> void:
	if hero_card == null:
		return
	for child in hero_card.get_children():
		child.queue_free()

	var victory: bool = bool(summary_data.get("victory"))
	var hero_name: String = str(summary_data.get("hero_name"))
	var hero_level: int = int(summary_data.get("hero_level"))
	var strength: int = int(summary_data.get("strength"))
	var agility: int = int(summary_data.get("agility"))
	var intelligence: int = int(summary_data.get("intelligence"))

	hero_card.custom_minimum_size = Vector2(210 if compact else 238, 230)
	hero_card.add_theme_stylebox_override(
		"panel",
		_make_flat_panel_style(Color(0.035, 0.028, 0.025, 0.88), Color(0.58, 0.38, 0.18, 0.9))
	)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 5)
	hero_card.add_child(box)

	var status := Label.new()
	status.text = "EXPEDITION TRIUMPH" if victory else "EXPEDITION LOST"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_override("font", MENU_FONT)
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28) if victory else Color(1.0, 0.32, 0.24))
	box.add_child(status)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(96 if compact else 114, 96 if compact else 114)
	portrait_frame.add_theme_stylebox_override(
		"panel",
		_make_flat_panel_style(Color(0.02, 0.024, 0.03, 0.96), Color(0.82, 0.66, 0.28, 0.92) if victory else Color(0.72, 0.18, 0.14, 0.92))
	)
	box.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.name = "HeroPortrait"
	portrait.texture = HERO_PORTRAIT_TEXTURES.get(hero_name, null) as Texture2D
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.modulate = Color.WHITE if victory else Color(0.72, 0.58, 0.58, 1.0)
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 8
	portrait.offset_top = 8
	portrait.offset_right = -8
	portrait.offset_bottom = -8
	portrait_frame.add_child(portrait)

	var name_label := Label.new()
	name_label.text = hero_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", MENU_FONT)
	name_label.add_theme_font_size_override("font_size", 18 if compact else 21)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78, 1.0))
	box.add_child(name_label)

	var level_label := Label.new()
	level_label.text = "HERO LEVEL %d" % hero_level
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_override("font", MENU_FONT)
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", Color(0.76, 0.72, 0.66, 1.0))
	box.add_child(level_label)

	var stat_row := HBoxContainer.new()
	stat_row.name = "HeroStats"
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_row.add_theme_constant_override("separation", 7)
	box.add_child(stat_row)
	stat_row.add_child(_make_hero_stat_chip(STRENGTH_TEXTURE, "Strength", strength, Color(1.0, 0.45, 0.28)))
	stat_row.add_child(_make_hero_stat_chip(AGILITY_TEXTURE, "Agility", agility, Color(0.42, 1.0, 0.48)))
	stat_row.add_child(_make_hero_stat_chip(INTELLIGENCE_TEXTURE, "Intelligence", intelligence, Color(0.48, 0.72, 1.0)))

func _populate_run_summary_card(compact: bool) -> void:
	if run_summary_card == null:
		return
	for child in run_summary_card.get_children():
		child.queue_free()

	var score: int = int(summary_data.get("score"))
	var waves_survived: int = int(summary_data.get("waves_survived"))
	var final_wave: int = int(summary_data.get("final_wave"))
	var elapsed_time_string: String = str(summary_data.get("elapsed_time_string"))
	var base_integrity: int = int(summary_data.get("base_integrity"))
	var total_gems: int = int(summary_data.get("total_gems"))
	var total_gold: int = int(summary_data.get("total_gold"))
	var blocks_mined: int = int(summary_data.get("blocks_mined"))
	var caches_unlocked: int = int(summary_data.get("caches_unlocked"))
	var horn_greed_multiplier: float = float(summary_data.get("horn_greed_multiplier"))
	var horn_soundings: int = int(summary_data.get("horn_soundings"))
	var hero_name: String = str(summary_data.get("hero_name"))

	run_summary_card.custom_minimum_size = Vector2(430 if compact else 485, 230)
	run_summary_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_summary_card.add_theme_stylebox_override(
		"panel",
		_make_flat_panel_style(Color(0.03, 0.025, 0.02, 0.84), Color(0.46, 0.34, 0.22, 0.82))
	)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	run_summary_card.add_child(box)

	var header_row := HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(header_row)

	var heading := Label.new()
	heading.text = "EXPEDITION RETROSPECTIVE"
	heading.add_theme_font_override("font", MENU_FONT)
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(0.96, 0.79, 0.46, 1.0))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(heading)

	var score_label := Label.new()
	score_label.text = "SCORE: %d PTS" % score
	score_label.add_theme_font_override("font", MENU_FONT)
	score_label.add_theme_font_size_override("font_size", 14)
	score_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
	header_row.add_child(score_label)

	var stats := GridContainer.new()
	stats.name = "SummaryRows"
	stats.columns = 3
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_constant_override("h_separation", 10 if compact else 16)
	stats.add_theme_constant_override("v_separation", 3)
	box.add_child(stats)

	var base_icon := HERO_BASE_TEXTURES.get(hero_name, HERO_BASE_TEXTURES["Dwarf"]) as Texture2D

	_add_result_row(stats, null, "TIME", "Run time", elapsed_time_string)
	_add_result_row(stats, null, "STAGE", "Stage reached", "%d / %d" % [waves_survived, final_wave])
	_add_result_row(stats, base_icon, "", "Base integrity", "%d%%" % base_integrity)
	_add_result_row(stats, GEM_TEXTURE, "", "Gems banked", str(total_gems))
	_add_result_row(stats, GOLD_TEXTURE, "", "Gold banked", str(total_gold))
	_add_result_row(stats, null, "MINE", "Blocks mined", str(blocks_mined))
	_add_result_row(stats, null, "SEAM", "Caches unlocked", "%d claimed" % caches_unlocked, Color(0.4, 0.88, 1.0))
	var greed_text := "%.2fx" % horn_greed_multiplier
	if horn_soundings > 0:
		greed_text += " (%d horn)" % horn_soundings
	_add_result_row(stats, null, "HORN", "Greed multiplier", greed_text, Color(1.0, 0.65, 0.2))

func _populate_banners(compact: bool) -> void:
	var legacy_banner := content.get_node_or_null("LegacyReward") as PanelContainer
	if legacy_banner == null:
		legacy_banner = PanelContainer.new()
		legacy_banner.name = "LegacyReward"
		content.add_child(legacy_banner)
		content.move_child(legacy_banner, actions_container.get_index())

	legacy_banner.custom_minimum_size = Vector2(0, 42 if compact else 46)
	legacy_banner.add_theme_stylebox_override(
		"panel",
		_make_flat_panel_style(Color(0.16, 0.085, 0.02, 0.94), Color(1.0, 0.62, 0.15, 0.98))
	)
	for child in legacy_banner.get_children():
		child.queue_free()

	var base_survival_ore: int = int(summary_data.get("base_survival_ore"))
	var victory_bonus_ore: int = int(summary_data.get("victory_bonus_ore"))
	var horn_bonus_ore: int = int(summary_data.get("horn_bonus_ore"))
	var legacy_ore_earned: int = int(summary_data.get("legacy_ore_earned"))
	var total_legacy_ore: int = int(summary_data.get("total_legacy_ore"))
	var milestone_title: String = str(summary_data.get("milestone_title"))

	var legacy_box := HBoxContainer.new()
	legacy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	legacy_box.add_theme_constant_override("separation", 18)
	legacy_banner.add_child(legacy_box)

	var breakdown_text := "SURVIVAL +%d" % base_survival_ore
	if victory_bonus_ore > 0:
		breakdown_text += "  •  VICTORY +%d" % victory_bonus_ore
	if horn_bonus_ore > 0:
		breakdown_text += "  •  HORN +%d" % horn_bonus_ore

	var breakdown_label := Label.new()
	breakdown_label.text = breakdown_text
	breakdown_label.add_theme_font_override("font", MENU_FONT)
	breakdown_label.add_theme_font_size_override("font_size", 13 if compact else 14)
	breakdown_label.add_theme_color_override("font_color", Color(0.9, 0.74, 0.5, 1.0))
	legacy_box.add_child(breakdown_label)

	var legacy_label := Label.new()
	legacy_label.text = "LEGACY ORE  +%d     TOTAL  %d" % [legacy_ore_earned, total_legacy_ore]
	legacy_label.add_theme_font_override("font", MENU_FONT)
	legacy_label.add_theme_font_size_override("font_size", 16 if compact else 18)
	legacy_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4, 1.0))
	legacy_box.add_child(legacy_label)

	var milestone_banner := content.get_node_or_null("MilestoneReward") as PanelContainer
	if not milestone_title.is_empty():
		if milestone_banner == null:
			milestone_banner = PanelContainer.new()
			milestone_banner.name = "MilestoneReward"
			content.add_child(milestone_banner)
			content.move_child(milestone_banner, legacy_banner.get_index())
		milestone_banner.visible = true
		milestone_banner.custom_minimum_size = Vector2(0, 44 if compact else 48)
		milestone_banner.add_theme_stylebox_override(
			"panel",
			_make_flat_panel_style(Color(0.035, 0.09, 0.12, 0.96), Color(0.28, 0.82, 1.0, 0.98))
		)
		for child in milestone_banner.get_children():
			child.queue_free()
		var milestone_label := Label.new()
		milestone_label.text = "STRONGHOLD MILESTONE  •  %s" % milestone_title
		milestone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		milestone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		milestone_label.add_theme_font_override("font", MENU_FONT)
		milestone_label.add_theme_font_size_override("font_size", 14 if compact else 16)
		milestone_label.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0, 1.0))
		milestone_banner.add_child(milestone_label)
	elif milestone_banner != null:
		milestone_banner.visible = false

func _configure_buttons(compact: bool) -> void:
	if actions_container == null:
		return
	actions_container.columns = 2 if compact else 4
	var button_width := 220.0 if compact else 176.0

	_style_button(retry_button, button_width)
	_style_button(change_loadout_button, button_width)
	_style_button(workshop_button, button_width)
	_style_button(main_menu_button, button_width)

	if workshop_button:
		workshop_button.text = "Stronghold" if Global.is_legacy_workshop_unlocked() else "Return Home"

	_connect_button(retry_button, _on_retry_pressed)
	_connect_button(change_loadout_button, _on_loadout_pressed)
	_connect_button(workshop_button, _on_workshop_pressed)
	_connect_button(main_menu_button, _on_menu_pressed)

func _style_button(button: Button, width: float) -> void:
	if button == null:
		return
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.custom_minimum_size = Vector2(width, 42)
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", _make_texture_style(MENU_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("hover", _make_texture_style(MENU_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("pressed", _make_texture_style(MENU_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _connect_button(button: Button, method: Callable) -> void:
	if button == null:
		return
	if not button.is_connected("pressed", method):
		button.pressed.connect(method)

func _on_retry_pressed() -> void:
	retry_requested.emit()
	if _on_retry_callback.is_valid():
		_on_retry_callback.call()

func _on_loadout_pressed() -> void:
	loadout_requested.emit()
	if _on_loadout_callback.is_valid():
		_on_loadout_callback.call()

func _on_workshop_pressed() -> void:
	workshop_requested.emit()
	if _on_workshop_callback.is_valid():
		_on_workshop_callback.call()

func _on_menu_pressed() -> void:
	menu_requested.emit()
	if _on_menu_callback.is_valid():
		_on_menu_callback.call()

func _add_result_row(
	stats: GridContainer,
	texture: Texture2D,
	marker: String,
	stat_name: String,
	stat_value: String,
	value_color: Color = Color(1.0, 0.94, 0.82, 1.0)
) -> void:
	var icon_cell := Control.new()
	icon_cell.custom_minimum_size = Vector2(28, 28)
	icon_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 2
		icon.offset_top = 2
		icon.offset_right = -2
		icon.offset_bottom = -2
		icon_cell.add_child(icon)
	else:
		var marker_label := Label.new()
		marker_label.text = marker
		marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker_label.add_theme_font_override("font", MENU_FONT)
		marker_label.add_theme_font_size_override("font_size", 8 if marker.length() > 3 else 10)
		marker_label.add_theme_color_override("font_color", Color(0.95, 0.66, 0.28, 1.0))
		marker_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_cell.add_child(marker_label)
	stats.add_child(icon_cell)

	var name_label := Label.new()
	name_label.text = stat_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", MENU_FONT)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.78, 0.7, 0.58, 1.0))
	stats.add_child(name_label)

	var value_label := Label.new()
	value_label.text = stat_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_override("font", MENU_FONT)
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", value_color)
	stats.add_child(value_label)

func _make_hero_stat_chip(texture: Texture2D, tooltip: String, value: int, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(56, 58)
	chip.tooltip_text = tooltip
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.add_theme_stylebox_override("panel", _make_flat_panel_style(Color(0.02, 0.025, 0.03, 0.94), accent.darkened(0.28)))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	chip.add_child(box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var value_label := Label.new()
	value_label.text = str(value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_override("font", MENU_FONT)
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", accent)
	box.add_child(value_label)
	return chip

func _make_flat_panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_texture_style(texture: Texture2D) -> StyleBox:
	if texture == null:
		return _make_flat_panel_style(Color(0.12, 0.07, 0.035, 0.97), Color(0.65, 0.44, 0.18, 1.0))
	var style := StyleBoxTexture.new()
	style.texture = texture
	return style
