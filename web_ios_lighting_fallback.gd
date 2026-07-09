extends Node

const WEB_CANVAS_MODULATE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const MOBILE_CONTROLS_SCENE := preload("res://mobile_controls.tscn")

var _enabled := false
var _apply_timer := 0.0
var _mobile_controls_layer: CanvasLayer = null

func _ready() -> void:
	_enabled = OS.has_feature("web")
	if not _enabled:
		set_process(false)
		return
	get_tree().node_added.connect(_on_node_added)
	set_process(true)
	call_deferred("_apply_web_fallbacks")

func _process(delta: float) -> void:
	if not _enabled:
		return
	_apply_timer -= delta
	if _apply_timer <= 0.0:
		_apply_timer = 0.5
		_apply_web_fallbacks()

func _on_node_added(node: Node) -> void:
	if not _enabled:
		return
	call_deferred("_apply_to_subtree", node)

func _apply_web_fallbacks() -> void:
	_apply_to_subtree(get_tree().root)
	_update_mobile_controls()

func _apply_to_subtree(node: Node) -> void:
	if not is_instance_valid(node):
		return
	_apply_to_node(node)
	for child in node.get_children():
		_apply_to_subtree(child)

func _apply_to_node(node: Node) -> void:
	if node is CanvasModulate:
		(node as CanvasModulate).color = WEB_CANVAS_MODULATE_COLOR
	elif node is PointLight2D:
		var light := node as PointLight2D
		light.shadow_enabled = false
		light.visible = false

func _update_mobile_controls() -> void:
	var should_show := _current_scene_has_player()
	if should_show:
		_ensure_mobile_controls()
		if _mobile_controls_layer:
			_mobile_controls_layer.visible = true
	elif _mobile_controls_layer:
		_mobile_controls_layer.visible = false

func _ensure_mobile_controls() -> void:
	if is_instance_valid(_mobile_controls_layer):
		return
	_mobile_controls_layer = CanvasLayer.new()
	_mobile_controls_layer.name = "MobileControlsLayer"
	_mobile_controls_layer.layer = 100
	get_tree().root.add_child(_mobile_controls_layer)

	var controls := MOBILE_CONTROLS_SCENE.instantiate()
	controls.name = "MobileControls"
	controls.player_id = 1
	_mobile_controls_layer.add_child(controls)

func _current_scene_has_player() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return _subtree_has_player(scene)

func _subtree_has_player(node: Node) -> bool:
	if node.name == "Player":
		return true
	for child in node.get_children():
		if _subtree_has_player(child):
			return true
	return false
