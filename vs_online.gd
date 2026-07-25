extends Node

const VSMatchResult := preload("res://vs_match_result.gd")

# TODO: world_seed is handed over by the lobby but not consumed yet. Feeding it
# into World.generate_initial_world() is what will make both mines identical.
var world_seed: int = 0

var _match_over := false

@onready var level = $Level

func _enter_tree() -> void:
	# player_id/is_vs_mode must be set before Level._ready() runs, otherwise the
	# mine generates with the single-player layout. vs_online.tscn carries these
	# as instance overrides; this is the belt-and-braces pass (parents enter the
	# tree before children ready).
	var world := get_node_or_null("Level")
	if world == null:
		push_error("VSOnline: missing Level node")
		return
	world.set("player_id", 1) # Always use WASD locally for yourself
	world.set("is_vs_mode", true)

func _ready() -> void:
	if level == null:
		return

	var upg_menu := level.get_node_or_null("UpgradeMenu")
	if upg_menu and upg_menu.has_signal("send_enemy"):
		upg_menu.send_enemy.connect(_on_local_send_enemy)

	var base := level.get_node_or_null("Base")
	if base and base.has_signal("game_over"):
		base.game_over.connect(_on_base_destroyed)

	if multiplayer.multiplayer_peer:
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_local_send_enemy(enemy_type: int) -> void:
	if _match_over or level == null:
		return
	level.income += enemy_type + 1
	# The sent creep only ever spawns on the opponent's side.
	if multiplayer.multiplayer_peer:
		rpc("receive_enemy", enemy_type)

@rpc("any_peer", "call_remote", "reliable")
func receive_enemy(enemy_type: int) -> void:
	if _match_over or level == null or not is_instance_valid(level):
		return
	var block_layer: TileMapLayer = level.get("block_layer")
	if block_layer == null or not level.has_method("get_farthest_open_cell"):
		return
	var enemy: Node2D = level.ENEMY_SCENE.instantiate()
	var target_cell: Vector2i = level.get_farthest_open_cell()
	enemy.global_position = block_layer.to_global(block_layer.map_to_local(target_cell))
	level.add_child(enemy)
	if enemy.has_method("initialize"):
		enemy.initialize(1, false, enemy_type)

func _on_base_destroyed() -> void:
	if _match_over:
		return
	_match_over = true
	if multiplayer.multiplayer_peer:
		rpc("opponent_base_destroyed")
	VSMatchResult.show_result(
		self,
		"DEFEAT",
		"Your base was destroyed.",
		Color(1.0, 0.42, 0.38, 1.0)
	)

@rpc("any_peer", "call_remote", "reliable")
func opponent_base_destroyed() -> void:
	if _match_over:
		return
	_match_over = true
	VSMatchResult.show_result(
		self,
		"VICTORY",
		"The opponent's base was destroyed.",
		Color(0.44, 1.0, 0.55, 1.0)
	)

func _on_peer_disconnected(_peer_id: int) -> void:
	if _match_over:
		return
	_match_over = true
	VSMatchResult.show_result(
		self,
		"OPPONENT LEFT",
		"The connection to your opponent was lost.",
		Color(0.86, 0.86, 0.9, 1.0)
	)
