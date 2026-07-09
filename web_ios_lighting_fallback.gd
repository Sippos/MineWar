extends Node

const IOS_CANVAS_MODULATE_COLOR := Color(0.35, 0.35, 0.42, 1.0)

var _enabled := false

func _ready() -> void:
	_enabled = OS.has_feature("web") and _is_ios_browser()
	if not _enabled:
		return
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_apply_to_current_scene")

func _is_ios_browser() -> bool:
	if OS.has_feature("ios") or OS.has_feature("web_ios"):
		return true
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
	var js_bridge = Engine.get_singleton("JavaScriptBridge")
	var ua := str(js_bridge.eval("navigator.userAgent || ''"))
	var platform := str(js_bridge.eval("navigator.platform || ''"))
	var max_touch := int(js_bridge.eval("navigator.maxTouchPoints || 0"))
	return ua.contains("iPhone") or ua.contains("iPad") or ua.contains("iPod") or (platform == "MacIntel" and max_touch > 1)

func _on_node_added(node: Node) -> void:
	_apply_to_node(node)

func _apply_to_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene:
		_apply_to_subtree(scene)

func _apply_to_subtree(node: Node) -> void:
	_apply_to_node(node)
	for child in node.get_children():
		_apply_to_subtree(child)

func _apply_to_node(node: Node) -> void:
	if node is CanvasModulate:
		(node as CanvasModulate).color = IOS_CANVAS_MODULATE_COLOR
	elif node is PointLight2D:
		(node as PointLight2D).shadow_enabled = false
