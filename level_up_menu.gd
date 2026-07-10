extends CanvasLayer

signal upgrade_selected(upgrade_type: String)

var options_container: VBoxContainer
var hero_controller: Node
var owning_player: Node
var build_attempts := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size_changed.connect(_layout_for_viewport)

func setup(_legacy_has_stomp = false) -> void:
	call_deferred("_build_hero_upgrade_menu")

func _build_hero_upgrade_menu() -> void:
	owning_player = _find_owning_player()
	hero_controller = owning_player.get_node_or_null("HeroAbilities") if owning_player else null
	if hero_controller == null and build_attempts < 4:
		build_attempts += 1
		await get_tree().process_frame
		_build_hero_upgrade_menu()
		return

	var panel := $Panel
	var old_vbox := panel.get_node_or_null("VBoxContainer")
	if old_vbox:
		old_vbox.visible = false
		old_vbox.queue_free()
	var old_label := panel.get_node_or_null("Label")
	if old_label:
		old_label.visible = false

	options_container = VBoxContainer.new()
	options_container.name = "HeroUpgradeOptions"
	options_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	options_container.offset_left = 30.0
	options_container.offset_top = 28.0
	options_container.offset_right = -30.0
	options_container.offset_bottom = -24.0
	options_container.add_theme_constant_override("separation", 8)
	panel.add_child(options_container)

	var title := Label.new()
	title.text = "%s — Choose Ability" % _hero_name()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	options_container.add_child(title)

	var options: Array = []
	if hero_controller and hero_controller.has_method("get_level_up_options"):
		options = hero_controller.get_level_up_options()
	if options.is_empty():
		options = [
			{"id":"health", "title":"Vitality", "description":"Increase maximum health", "level":0, "max_level":99, "enabled":true, "reason":"", "icon_path":""},
			{"id":"damage", "title":"Strength", "description":"Increase attack damage", "level":0, "max_level":99, "enabled":true, "reason":"", "icon_path":""}
		]

	for option in options:
		options_container.add_child(_make_option_button(option))

	_layout_for_viewport()
	for child in options_container.get_children():
		if child is Button and not child.disabled:
			child.call_deferred("grab_focus")
			break

func _find_owning_player() -> Node:
	var world := get_parent()
	if world:
		var direct_player := world.get_node_or_null("Player")
		if direct_player:
			return direct_player
	var node := get_parent()
	while node:
		var player := node.get_node_or_null("Player")
		if player:
			return player
		node = node.get_parent()
	return null

func _hero_name() -> String:
	if owning_player:
		return str(owning_player.get("current_hero_name"))
	return "Hero"

func _layout_for_viewport() -> void:
	if not is_instance_valid($Panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var compact := viewport_size.x < 700.0 or viewport_size.y < 600.0
	var margin := 16.0 if compact else 28.0
	var panel_width := min(620.0, max(300.0, viewport_size.x - margin * 2.0))
	var panel_height := min(570.0, max(350.0, viewport_size.y - margin * 2.0))
	var panel := $Panel
	panel.offset_left = -panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_bottom = panel_height * 0.5
	if options_container:
		options_container.offset_left = 22.0 if compact else 34.0
		options_container.offset_top = 20.0 if compact else 30.0
		options_container.offset_right = -22.0 if compact else -34.0
		options_container.offset_bottom = -18.0 if compact else -26.0
		options_container.add_theme_constant_override("separation", 6 if compact else 10)
		for child in options_container.get_children():
			if child is Button:
				child.custom_minimum_size = Vector2(0, 68.0 if compact else 88.0)

func _make_option_button(option: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 82)
	button.disabled = not bool(option.get("enabled", true))
	var level_value := int(option.get("level", 0))
	var max_level := int(option.get("max_level", 1))
	var level_text := ""
	if max_level > 1:
		level_text = "  [Level %d/%d]" % [level_value, max_level]
	var reason := str(option.get("reason", ""))
	button.text = "%s%s\n%s%s" % [
		str(option.get("title", "Ability")),
		level_text,
		str(option.get("description", "")),
		(" — " + reason) if reason != "" else ""
	]
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var icon_path := str(option.get("icon_path", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		button.icon = load(icon_path)
		button.expand_icon = true
		button.icon_max_width = 58
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_spacing", 12)
	var upgrade_id := str(option.get("id", ""))
	button.pressed.connect(func(): _choose_upgrade(upgrade_id))
	return button

func _choose_upgrade(upgrade_id: String) -> void:
	upgrade_selected.emit(upgrade_id)
	hide_and_unpause()

# Compatibility handlers for the legacy scene connections. These controls are
# removed as soon as the hero-specific menu is built.
func _on_button_stomp_pressed() -> void:
	_choose_upgrade("stomp")

func _on_button_health_pressed() -> void:
	_choose_upgrade("health")

func _on_button_damage_pressed() -> void:
	_choose_upgrade("damage")

func hide_and_unpause() -> void:
	get_tree().paused = false
	queue_free()
