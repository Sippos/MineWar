extends Control

const COMPACT_VS_MENU = preload("res://compact_vs_upgrade_menu.gd")

@onready var viewport1: SubViewport = $HBoxContainer/SubViewportContainer1/SubViewport1
@onready var viewport2: SubViewport = $HBoxContainer/SubViewportContainer2/SubViewport2
@onready var level1 = viewport1.get_node("Level1")
@onready var level2 = viewport2.get_node("Level2")

var _routing_level_up_input := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level1.player_id = 1
	level1.is_vs_mode = true
	level2.player_id = 2
	level2.is_vs_mode = true
	_refresh_level_base(level1)
	_refresh_level_base(level2)
	_attach_compact_upgrade_menu(level1)
	_attach_compact_upgrade_menu(level2)

	var menu1 = level1.get_node_or_null("UpgradeMenu")
	if menu1:
		menu1.connect("send_enemy", Callable(self, "_on_p1_send_enemy"))
	var menu2 = level2.get_node_or_null("UpgradeMenu")
	if menu2:
		menu2.connect("send_enemy", Callable(self, "_on_p2_send_enemy"))

func _input(event: InputEvent) -> void:
	if _routing_level_up_input or not get_tree().paused:
		return
	var context := _active_level_up_context()
	if context.is_empty():
		return
	var player_number := int(context["player_id"])
	var source_action := _level_up_source_action(event, player_number)
	if source_action == "":
		return
	var ui_action := _level_up_ui_action(source_action, player_number)
	if ui_action == "":
		return
	var forwarded := InputEventAction.new()
	forwarded.action = ui_action
	forwarded.pressed = event.is_pressed()
	forwarded.strength = 1.0 if forwarded.pressed else 0.0
	forwarded.device = event.device
	_routing_level_up_input = true
	(context["viewport"] as SubViewport).push_input(forwarded)
	_routing_level_up_input = false
	get_viewport().set_input_as_handled()

func _active_level_up_context() -> Dictionary:
	if level1.get_node_or_null("LevelUpMenu") != null:
		return {"viewport": viewport1, "player_id": 1}
	if level2.get_node_or_null("LevelUpMenu") != null:
		return {"viewport": viewport2, "player_id": 2}
	return {}

func _level_up_source_action(event: InputEvent, player_number: int) -> String:
	var prefix := "p%d_" % player_number
	var actions := [
		"ui_up", "ui_down", "ui_left", "ui_right", "ui_accept",
		prefix + "up", prefix + "down", prefix + "left", prefix + "right", prefix + "interact"
	]
	for action_name in actions:
		if InputMap.has_action(action_name) and event.is_action(action_name):
			return action_name
	return ""

func _level_up_ui_action(action_name: String, player_number: int) -> String:
	var prefix := "p%d_" % player_number
	if action_name == "ui_up" or action_name == prefix + "up":
		return "ui_up"
	if action_name == "ui_down" or action_name == prefix + "down":
		return "ui_down"
	if action_name == "ui_left" or action_name == prefix + "left":
		return "ui_left"
	if action_name == "ui_right" or action_name == prefix + "right":
		return "ui_right"
	if action_name == "ui_accept" or action_name == prefix + "interact":
		return "ui_accept"
	return ""

func _attach_compact_upgrade_menu(level) -> void:
	var menu = level.get_node_or_null("UpgradeMenu")
	if menu == null or level.get_node_or_null("CompactVSUpgradeMenu"):
		return
	var compact := CanvasLayer.new()
	compact.name = "CompactVSUpgradeMenu"
	compact.set_script(COMPACT_VS_MENU)
	level.add_child(compact)
	compact.call_deferred("setup", menu)

func _refresh_level_base(level) -> void:
	var base = level.get_node_or_null("Base")
	if base and base.has_method("refresh_base_sprite"):
		base.call_deferred("refresh_base_sprite")

func _on_p1_send_enemy(enemy_type: int) -> void:
	level1.income += enemy_type + 1
	var e = level2.ENEMY_SCENE.instantiate()
	var target_cell = level2.get_farthest_open_cell()
	e.global_position = level2.block_layer.to_global(level2.block_layer.map_to_local(target_cell))
	level2.add_child(e)
	if e.has_method("initialize"):
		e.initialize(1, false, enemy_type)

func _on_p2_send_enemy(enemy_type: int) -> void:
	level2.income += enemy_type + 1
	var e = level1.ENEMY_SCENE.instantiate()
	var target_cell = level1.get_farthest_open_cell()
	e.global_position = level1.block_layer.to_global(level1.block_layer.map_to_local(target_cell))
	level1.add_child(e)
	if e.has_method("initialize"):
		e.initialize(1, false, enemy_type)
