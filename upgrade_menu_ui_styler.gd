extends Node

const MENU_PANEL_TEXTURE := "res://assets/sprites/ui/common/MenuPanel.png"
const BUTTON_TEXTURE := "res://assets/sprites/ui/common/Button.png"
const FRAME_LAYER_NAME := "RuntimeSectionFrames"

var _panel_texture: Texture2D
var _button_texture: Texture2D


func _ready() -> void:
	_panel_texture = load(MENU_PANEL_TEXTURE)
	_button_texture = load(BUTTON_TEXTURE)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_style_existing_tree")


func _style_existing_tree() -> void:
	_style_branch(get_tree().root)


func _style_branch(node: Node) -> void:
	_try_style_node(node)
	for child in node.get_children():
		_style_branch(child)


func _on_node_added(node: Node) -> void:
	call_deferred("_try_style_node", node)


func _try_style_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return

	if node is Button and _find_upgrade_menu(node) != null:
		_style_button(node as Button)

	if node.name == "UpgradeMenu":
		_style_upgrade_menu.call_deferred(node)
	elif node.name == "VSPromptPanel" or node.name == "VSSendPanel":
		_style_vs_panel.call_deferred(node)


func _find_upgrade_menu(node: Node) -> Node:
	var current := node
	while current != null:
		if current.name == "UpgradeMenu":
			return current
		current = current.get_parent()
	return null


func _make_button_style(tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _button_texture
	style.modulate_color = tint
	style.set_content_margin(SIDE_LEFT, 14.0)
	style.set_content_margin(SIDE_TOP, 7.0)
	style.set_content_margin(SIDE_RIGHT, 14.0)
	style.set_content_margin(SIDE_BOTTOM, 7.0)
	return style


func _style_button(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	if button.has_meta("minewars_upgrade_button_styled"):
		return
	button.set_meta("minewars_upgrade_button_styled", true)

	button.add_theme_stylebox_override("normal", _make_button_style(Color(1.0, 1.0, 1.0, 1.0)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(1.14, 1.10, 0.92, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.78, 0.78, 0.78, 1.0)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.45, 0.45, 0.45, 0.72)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.72, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.55, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.60, 0.56, 1.0))


func _make_panel_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _panel_texture
	style.set_texture_margin(SIDE_LEFT, 42.0)
	style.set_texture_margin(SIDE_TOP, 38.0)
	style.set_texture_margin(SIDE_RIGHT, 42.0)
	style.set_texture_margin(SIDE_BOTTOM, 38.0)
	style.set_content_margin(SIDE_LEFT, 24.0)
	style.set_content_margin(SIDE_TOP, 22.0)
	style.set_content_margin(SIDE_RIGHT, 24.0)
	style.set_content_margin(SIDE_BOTTOM, 22.0)
	return style


func _style_vs_panel(panel: Panel) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return

	panel.add_theme_stylebox_override("panel", _make_panel_style())
	var content := panel.get_child(0) if panel.get_child_count() > 0 else null
	if content is VBoxContainer:
		(content as VBoxContainer).add_theme_constant_override("separation", 8)
		for child in content.get_children():
			if child is Button:
				var button := child as Button
				_style_button(button)
				button.custom_minimum_size.y = max(button.custom_minimum_size.y, 38.0)
			elif child is Label:
				var label := child as Label
				label.add_theme_font_size_override("font_size", 20)
				label.add_theme_color_override("font_color", Color(0.98, 0.90, 0.74, 1.0))

	if panel.name == "VSPromptPanel":
		panel.offset_left = -175.0
		panel.offset_top = -132.0
		panel.offset_right = 175.0
		panel.offset_bottom = 132.0
		if content is Control:
			(content as Control).offset_left = 42.0
			(content as Control).offset_top = 42.0
			(content as Control).offset_right = -42.0
			(content as Control).offset_bottom = -42.0


func _style_upgrade_menu(menu: Node) -> void:
	if menu == null or not is_instance_valid(menu):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(menu):
		return

	for child in menu.find_children("*", "Button", true, false):
		_style_button(child as Button)

	var panel := menu.get_node_or_null("Panel") as Control
	if panel == null or panel.get_node_or_null(FRAME_LAYER_NAME) != null:
		return

	var frame_layer := Control.new()
	frame_layer.name = FRAME_LAYER_NAME
	frame_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame_layer)
	panel.move_child(frame_layer, min(1, panel.get_child_count() - 1))

	_add_section_frame(panel, frame_layer, "HUDFrame", [
		NodePath("BranchTitle2"),
		NodePath("UnlockHealthbar"),
		NodePath("UnlockBaseHealth"),
		NodePath("UnlockXP"),
		NodePath("UnlockWaveTimer")
	], Vector2(22, 18))

	_add_section_frame(panel, frame_layer, "FactionFrame", [
		NodePath("FactionTitle"),
		NodePath("BuyRail"),
		NodePath("BuyMinecart"),
		NodePath("BuyPeon")
	], Vector2(20, 18))

	_add_section_frame(panel, frame_layer, "MiscFrame", [
		NodePath("MiscTitle"),
		NodePath("UnlockMinimap"),
		NodePath("UpgradeMinimap")
	], Vector2(20, 18))

	_add_section_frame(panel, frame_layer, "HealthFrame", [
		NodePath("MiscTitle/MiscTitle"),
		NodePath("UpgradeMaxHealth"),
		NodePath("HealPlayer")
	], Vector2(20, 18))

	_add_section_frame(panel, frame_layer, "StatsFrame", [
		NodePath("StatsTitle"),
		NodePath("UpgradeStrength"),
		NodePath("UpgradeAgility"),
		NodePath("UpgradeIntelligence"),
		NodePath("UnlockStats")
	], Vector2(22, 18))


func _add_section_frame(
	panel: Control,
	frame_layer: Control,
	frame_name: String,
	paths: Array,
	padding: Vector2
) -> void:
	var bounds := Rect2()
	var has_bounds := false

	for path in paths:
		var control := panel.get_node_or_null(path) as Control
		if control == null:
			continue
		var global_rect: Rect2 = control.get_global_rect()
		var panel_global_position: Vector2 = panel.get_global_rect().position
		var local_top_left: Vector2 = global_rect.position - panel_global_position
		var local_bottom_right: Vector2 = global_rect.end - panel_global_position
		var local_rect: Rect2 = Rect2(local_top_left, local_bottom_right - local_top_left).abs()
		if local_rect.size.x <= 1.0 or local_rect.size.y <= 1.0:
			continue
		if has_bounds:
			bounds = bounds.merge(local_rect)
		else:
			bounds = local_rect
			has_bounds = true

	if not has_bounds:
		return

	bounds.position -= padding
	bounds.size += padding * 2.0

	var frame := NinePatchRect.new()
	frame.name = frame_name
	frame.texture = _panel_texture
	frame.position = bounds.position
	frame.size = bounds.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate = Color(1.0, 1.0, 1.0, 0.84)
	frame.set_patch_margin(SIDE_LEFT, 42)
	frame.set_patch_margin(SIDE_TOP, 38)
	frame.set_patch_margin(SIDE_RIGHT, 42)
	frame.set_patch_margin(SIDE_BOTTOM, 38)
	frame_layer.add_child(frame)
