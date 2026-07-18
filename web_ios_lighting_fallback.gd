extends Node

const MOBILE_CANVAS_MODULATE_COLOR = Color(0.44, 0.47, 0.55, 1.0)
const MOBILE_CONTROLS_SCENE = preload("res://mobile_controls.tscn")

var enabled = false
var apply_timer = 0.0
var mobile_controls_layer = null
const WEB_LOW_MEMORY_META := "web_low_memory_mode"

func _ready() -> void:
	enabled = OS.has_feature("web") and _is_mobile_or_touch_browser()
	if not enabled:
		set_process(false)
		return
	get_tree().root.set_meta(WEB_LOW_MEMORY_META, true)
	get_tree().node_added.connect(_on_node_added)
	set_process(true)
	call_deferred("_apply_mobile_web_fallbacks")

func _process(delta: float) -> void:
	if not enabled:
		return
	apply_timer -= delta
	if apply_timer <= 0.0:
		apply_timer = 1.0
		_update_mobile_controls()

func _is_mobile_or_touch_browser() -> bool:
	if OS.has_feature("ios") or OS.has_feature("web_ios"):
		return true
	if not OS.has_feature("web"):
		return false
	if not Engine.has_singleton("JavaScriptBridge"):
		return false

	var js_bridge = Engine.get_singleton("JavaScriptBridge")
	var ua = str(js_bridge.eval("navigator.userAgent || ''", true))
	var platform = str(js_bridge.eval("navigator.platform || ''", true))
	var max_touch = int(js_bridge.eval("navigator.maxTouchPoints || 0", true))

	return max_touch > 0 or ua.contains("Mobile") or ua.contains("iPhone") or ua.contains("iPad") or ua.contains("iPod") or ua.contains("Android") or (platform == "MacIntel" and max_touch > 1)

func _on_node_added(node: Node) -> void:
	if not enabled:
		return
	call_deferred("_apply_to_subtree", node)

func _apply_mobile_web_fallbacks() -> void:
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
		node.color = MOBILE_CANVAS_MODULATE_COLOR
	elif node is PointLight2D:
		node.shadow_enabled = false
		node.energy = minf(node.energy, 0.72)
		node.visible = true
	elif node is GPUParticles2D:
		# Safari/WebGL2 is much more sensitive to particle overdraw and transient
		# allocations than desktop browsers. Keep the gameplay readable and drop
		# decorative emitters in the low-memory mobile web profile.
		node.emitting = false
	elif node is LightOccluder2D:
		node.visible = false

func _update_mobile_controls() -> void:
	var should_show = _current_scene_has_player()
	if should_show:
		_ensure_mobile_controls()
		if is_instance_valid(mobile_controls_layer):
			mobile_controls_layer.visible = true
	elif is_instance_valid(mobile_controls_layer):
		mobile_controls_layer.visible = false

func _ensure_mobile_controls() -> void:
	if is_instance_valid(mobile_controls_layer):
		return
	mobile_controls_layer = CanvasLayer.new()
	mobile_controls_layer.name = "MobileControlsLayer"
	mobile_controls_layer.layer = 100
	get_tree().root.add_child(mobile_controls_layer)

	var controls = MOBILE_CONTROLS_SCENE.instantiate()
	controls.name = "MobileControls"
	controls.player_id = 1
	mobile_controls_layer.add_child(controls)

func _current_scene_has_player() -> bool:
	var scene = get_tree().current_scene
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
