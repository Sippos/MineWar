extends Node

# Shared end-of-match banner for the versus loops (local split-screen and
# online). Base.game_over used to be wired up only in vs_online.gd, and that
# path looked for a "GameOverLabel" node that hud.tscn does not contain, so a
# destroyed base ended nothing. This overlay is built at runtime, sits above
# both SubViewports, and always processes so the paused tree can still dismiss
# it.

const MENU_SCENE := "res://scenes/menus/main/menu.tscn"
const OVERLAY_NAME := "VSMatchResult"

static func show_result(host: Node, headline: String, subline: String, accent: Color) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	if host.has_node(OVERLAY_NAME):
		return

	var layer := CanvasLayer.new()
	layer.name = OVERLAY_NAME
	layer.layer = 128
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)

	box.add_child(_make_label(headline, 64, accent))
	if subline != "":
		box.add_child(_make_label(subline, 26, Color(0.86, 0.86, 0.9, 1.0)))

	var button := Button.new()
	button.text = "Back to Menu"
	button.custom_minimum_size = Vector2(260, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	box.add_child(button)
	button.pressed.connect(func() -> void: _return_to_menu(host))
	button.grab_focus()

	host.get_tree().paused = true

static func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01, 0.96))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

static func _return_to_menu(host: Node) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var tree := host.get_tree()
	tree.paused = false
	var mp := host.multiplayer
	if mp and mp.multiplayer_peer:
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null
	tree.change_scene_to_file(MENU_SCENE)
