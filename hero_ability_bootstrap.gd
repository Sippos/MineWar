extends Node

const HERO_ABILITIES_SCRIPT = preload("res://hero_abilities.gd")
const PLAYER_SCRIPT_PATH := "res://player.gd"

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan_existing_nodes")

func _scan_existing_nodes() -> void:
	_scan_branch(get_tree().root)

func _scan_branch(node: Node) -> void:
	if not is_instance_valid(node):
		return
	_try_attach(node)
	for child in node.get