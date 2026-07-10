extends Node

const STATUS_LABEL_NAME := "JobStatus"
const CARRY_MARKER_NAME := "CarryMarker"
const RESERVATION_META := "minewar_reserved_by_peon"

var active_world: Node = null
var reconcile_timer := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	reconcile_timer -= delta
	if reconcile_timer > 0.0:
		return
	reconcile_timer = 0.2
	var world := _find_single_player_world()
	if world != active_world:
		active_world = world
	if active_world == null or not is_instance_valid(active_world):
		return
	_reconcile_peons(active_world)

func _find_single_player_world() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return _find_world_recursive(scene)

func _find_world_recursive(node: Node) -> Node:
	if node.has_node("Base") and node.has_node("HUD") and node.get("current_wave_number") != null:
		if not bool(node.get("is_vs_mode")):
			return node
	for child in node.get_children():
		var found := _find_world_recursive(child)
		if found:
			return found
	return null

func _reconcile_peons(world: Node) -> void:
	var peons: Array[Node] = []
	for peon in get_tree().get_nodes_in_group("peons"):
		if is_instance_valid(peon) and world.is_ancestor_of(peon):
			peons.append(peon)
	
	var claimed := {}
	for peon in peons:
		_ensure_status_ui(peon)
		var state := str(peon.get("state"))
		var target = peon.get("target_gem")
		if state == "MOVE_TO_GEM" and is_instance_valid(target):
			var target_id: int = target.get_instance_id()
			if claimed.has(target_id):
				_release_duplicate_assignment(peon)
			else:
				claimed[target_id] = peon
				target.set_meta(RESERVATION_META, peon.get_instance_id())
		_update_status(peon)
	
	for gem in get_tree().get_nodes_in_group("gems"):
		if not is_instance_valid(gem) or not world.is_ancestor_of(gem):
			continue
		if gem.has_meta(RESERVATION_META):
			var owner_id := int(gem.get_meta(RESERVATION_META))
			var owner_valid := false
			for peon in peons:
				if peon.get_instance_id() == owner_id and peon.get("target_gem") == gem:
					owner_valid = true
					break
			if not owner_valid:
				gem.remove_meta(RESERVATION_META)

func _release_duplicate_assignment(peon: Node) -> void:
	peon.set("target_gem", null)
	peon.set("state", "IDLE")
	var path = peon.get("astar_path")
	if path is Array:
		path.clear()
	peon.set("velocity", Vector2.ZERO)

func _ensure_status_ui(peon: Node) -> void:
	if peon.has_node(STATUS_LABEL_NAME):
		return
	var label := Label.new()
	label.name = STATUS_LABEL_NAME
	label.position = Vector2(-38, -70)
	label.size = Vector2(76, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.68, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 30
	peon.add_child(label)

func _update_status(peon: Node) -> void:
	var label := peon.get_node_or_null(STATUS_LABEL_NAME) as Label
	if label == null:
		return
	var state := str(peon.get("state"))
	match state:
		"MOVE_TO_GEM":
			label.text = "MINING"
			label.modulate = Color(0.55, 0.9, 1.0, 1.0)
			_remove_carry_marker(peon)
		"RETURN_TO_BASE":
			label.text = "DELIVERING"
			label.modulate = Color(1.0, 0.82, 0.3, 1.0)
			_ensure_carry_marker(peon)
		_:
			label.text = "SEARCHING"
			label.modulate = Color(0.8, 0.8, 0.8, 0.85)
			_remove_carry_marker(peon)

func _ensure_carry_marker(peon: Node) -> void:
	if peon.has_node(CARRY_MARKER_NAME):
		return
	var marker := Polygon2D.new()
	marker.name = CARRY_MARKER_NAME
	marker.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(7, 0), Vector2(0, 8), Vector2(-7, 0)
	])
	marker.color = Color(0.2, 0.85, 1.0, 0.95)
	marker.position = Vector2(0, -48)
	marker.z_index = 20
	peon.add_child(marker)

func _remove_carry_marker(peon: Node) -> void:
	var marker := peon.get_node_or_null(CARRY_MARKER_NAME)
	if marker:
		marker.queue_free()
