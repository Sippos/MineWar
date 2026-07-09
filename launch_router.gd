extends Node

const DEFAULT_SCENE = "res://menu.tscn"
const IPHONE_SAFE_SCENE = "res://boot.tscn"

func _ready() -> void:
	call_deferred("_route_to_start_scene")

func _route_to_start_scene() -> void:
	var target_scene = DEFAULT_SCENE
	if _should_use_iphone_safe_launcher():
		target_scene = IPHONE_SAFE_SCENE
	get_tree().change_scene_to_file(target_scene)

func _should_use_iphone_safe_launcher() -> bool:
	if OS.has_feature("ios") and not OS.has_feature("web"):
		return true
	if not OS.has_feature("web"):
		return false
	if not Engine.has_singleton("JavaScriptBridge"):
		return false

	var js_bridge = Engine.get_singleton("JavaScriptBridge")
	var ua = str(js_bridge.eval("navigator.userAgent || ''", true))
	var platform = str(js_bridge.eval("navigator.platform || ''", true))
	var max_touch = int(js_bridge.eval("navigator.maxTouchPoints || 0", true))
	var css_width = float(js_bridge.eval("Math.min(window.innerWidth || 0, screen.width || 0)", true))
	var css_height = float(js_bridge.eval("Math.min(window.innerHeight || 0, screen.height || 0)", true))
	var short_side = min(css_width, css_height)
	var long_side = max(css_width, css_height)
	var small_touch_screen = max_touch > 0 and short_side > 0.0 and short_side < 600.0 and long_side < 1000.0
	var real_iphone = ua.contains("iPhone") or ua.contains("iPod")
	var ipad_like = ua.contains("iPad") or (platform == "MacIntel" and max_touch > 1 and not small_touch_screen)

	if ipad_like:
		return false
	return real_iphone or (small_touch_screen and ua.contains("Mobile"))
