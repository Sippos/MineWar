extends Node

const PROTOTYPE_SCRIPT := preload("res://scripts/systems/world_generation/enemy_approach_prototype.gd")

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan_tree")

func _scan_tree() -> void:
	_attach_to_levels(get_tree().root)

func _attach_to_levels(node: Node) -> void:
	_try_attach(node)
	for child in node.get_children():
		_attach_to_levels(child)

func _on_node_added(node: Node) -> void:
	call_deferred("_try_attach", node)

func _try_attach(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.name != "Level":
		return
	if not node.has_node("BlockLayer") or not node.has_node("Base") or not node.has_node("Player"):
		return
	if node.has_node("EnemyApproachPrototype"):
		return
	var prototype := Node2D.new()
	prototype.name = "EnemyApproachPrototype"
	prototype.set_script(PROTOTYPE_SCRIPT)
	node.add_child(prototype)
