extends CanvasLayer

signal upgrade_selected(upgrade_type: String)

var options_container: VBoxContainer
var hero_controller: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(_legacy_has_stomp = false) -> void:
	call_deferred("_build_hero_upgrade_menu")

func _build_hero_upgrade_menu() -> void:
	hero_controller = _find_hero_controller()
	var panel := $Panel
	panel.offset_left = -310.0
	panel.offset_top = -260.0
	panel.offset_right = 310.0
	panel.offset_bottom = 260.0
	var old_vbox := panel.get_node_or_null("VBoxContainer")
	if old_vbox:
		old_vbox.queue_free()
	options_container = VBoxContainer.new()
	options_container.name = "HeroUpgradeOptions"
	options_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	options_container.offset_left = 42.0
	options_container.offset_top = 54.0
	options_container.offset_right = -42.0
	options_container.offset_bottom = -34.0
	options_container.add_theme_constant_override("separation", 8)
	panel.add_child(options_container)
	var title := Label.new()
	title.text = "Choose Hero Ability"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
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
	for child in options_container.get_children():
		if child is Button and not child.disabled:
			child.call_deferred("grab_focus")
			break

func _find_hero_controller() -> Node:
	var world := get_parent()
	if world:
		var player := world.get_node_or_null("Player")
		if player:
			var controller := player.get_node_or_null("HeroAbilities")
			if controller:
				return controller
	for node in get_tree().get_nodes_in_group("hero_ability_controllers"):
		return node
	return null

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
		button.icon_max_width = 62
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_spacing", 12)
	var upgrade_id := str(option.get("id", ""))
	button.pressed.connect(func(): _choose_upgrade(upgrade_id))
	return button

func _choose_upgrade(upgrade_id: String) -> void:
	upgrade_selected.emit(upgrade_id)
	if hero_controller and hero_controller.has_method("_on_upgrade_selected"):
		hero_controller.call("_on_upgrade_selected", upgrade_id)
	hide_and_unpause()

func hide_and_unpause() -> void:
	get_tree().paused = false
	queue_free()
