extends Control


const VSMatchResult = preload("res://vs_match_result.gd")

@onready var viewport1: SubViewport = $HBoxContainer/SubViewportContainer1/SubViewport1
@onready var viewport2: SubViewport = $HBoxContainer/SubViewportContainer2/SubViewport2
@onready var level1 = viewport1.get_node("Level1")
@onready var level2 = viewport2.get_node("Level2")

var _routing_level_up_input := false
var _match_over := false

func _enter_tree() -> void:
	# World.gd reads is_vs_mode/player_id throughout _ready() and
	# generate_initial_world(). Godot readies children before their parent, so
	# setting them from _ready() below lands AFTER both mines have already been
	# generated - they would build with the single-player layout. vs_mode.tscn now
	# carries both as instance overrides; this pass keeps them correct even if the
	# overrides are lost, because _enter_tree runs before any child readies.
	var paths := {
		1: "HBoxContainer/SubViewportContainer1/SubViewport1/Level1",
		2: "HBoxContainer/SubViewportContainer2/SubViewport2/Level2",
	}
	for player_number in paths:
		var level := get_node_or_null(NodePath(paths[player_number]))
		if level == null:
			push_error("VSMode: missing level for player %d at %s" % [player_number, paths[player_number]])
			continue
		level.set("is_vs_mode", true)
		level.set("player_id", player_number)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_level_base(level1)
	_refresh_level_base(level2)


	_connect_level_signals(level1, 1)
	_connect_level_signals(level2, 2)

func _connect_level_signals(level, player_number: int) -> void:
	if level == null:
		return
	var menu = level.get_node_or_null("UpgradeMenu")
	if menu and menu.has_signal("send_enemy"):
		menu.send_enemy.connect(_on_send_enemy.bind(player_number))
	# Base.game_over was previously connected nowhere in split-screen, so
	# destroying the opponent's base ended nothing at all.
	var base = level.get_node_or_null("Base")
	if base and base.has_signal("game_over"):
		base.game_over.connect(_on_base_destroyed.bind(player_number))

func _level_for(player_number: int):
	return level1 if player_number == 1 else level2

func _opponent_of(player_number: int) -> int:
	return 2 if player_number == 1 else 1

func _input(event: InputEvent) -> void:
	if _match_over or _routing_level_up_input or not get_tree().paused:
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



func _refresh_level_base(level) -> void:
	var base = level.get_node_or_null("Base")
	if base and base.has_method("refresh_base_sprite"):
		base.call_deferred("refresh_base_sprite")

func _on_send_enemy(enemy_type: int, sender_id: int) -> void:
	if _match_over:
		return
	var sender = _level_for(sender_id)
	var target = _level_for(_opponent_of(sender_id))
	if sender == null or target == null or not is_instance_valid(sender) or not is_instance_valid(target):
		return
	sender.income += enemy_type + 1
	var block_layer = target.block_layer
	if block_layer == null or not target.has_method("get_farthest_open_cell"):
		return
	var e = target.ENEMY_SCENE.instantiate()
	var target_cell = target.get_farthest_open_cell()
	e.global_position = block_layer.to_global(block_layer.map_to_local(target_cell))
	target.add_child(e)
	if e.has_method("initialize"):
		e.initialize(1, false, enemy_type)

func _on_base_destroyed(loser_id: int) -> void:
	if _match_over:
		return
	_match_over = true
	VSMatchResult.show_result(
		self,
		"PLAYER %d WINS" % _opponent_of(loser_id),
		"Player %d's base was destroyed." % loser_id,
		Color(1.0, 0.86, 0.42, 1.0)
	)
