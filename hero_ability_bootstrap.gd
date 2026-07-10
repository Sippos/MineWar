extends Node

const HERO_ABILITIES_SCRIPT = preload("res://hero_abilities.gd")

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan_existing_nodes")

func _scan_existing_nodes() -> void:
	_scan_branch(get_tree().root)

func _scan_branch(node: Node) -> void:
	_try_attach(node)
	for child in node.get_children():
		_scan_branch(child)

func _on_node_added(node: Node) -> void:
	call_de