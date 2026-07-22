extends Node

const SIEGE_SCRIPT := preload("res://scripts/systems/world_generation/siege_mode_controller.gd")

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan_tree")

func _scan_tree() -> void:
	if not is_inside_tree():
		return
	_attach_to_levels(get_tree().root)

func _attach_to_levels(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_try_attach(node)
	for child in node.get_children():
		_attach_to_levels(child)

func _on_node_added(_node: Node) -> void:
	call_deferred("_scan_tree")

func _try_attach(node: Node) -> void:
	if not GameMode.is_siege():
		return
	if node == null or not is_instance_valid(node) or node.name != "Level":
		return
	if not node.has_node("BlockLayer") or not node.has_node("Base") or not node.has_node("Player"):
		return
	if node.get("is_vs_mode") == true or node.get("preparation_mode") == true or node.has_node("SiegeModeController"):
		return
	var controller := Node2D.new()
	controller.name = "SiegeModeController"
	controller.set_script(SIEGE_SCRIPT)
	node.add_child(controller)
