extends Node

const HERO_ORDER: Array[String] = ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King", "Mech"]
const HERO_TEXTURES := {
	"Dwarf": preload("res://character_sprites/hero_idle/dwarf_idle_front.png"),
	"Shaman": preload("res://character_sprites/hero_idle/shaman_idle_front.png"),
	"Nerubian": preload("res://character_sprites/hero_idle/nerubian_idle_front.png"),
	"Druid": preload("res://character_sprites/hero_idle/druid_idle_front.png"),
	"Undead King": preload("res://character_sprites/hero_idle/undead_king_idle_front.png"),
	"Mech": preload("res://character_sprites/hero_idle/mech_idle_front.png"),
}
const HERO_ACCENTS := {
	"Dwarf": Color(1.0, 0.61, 0.18, 1.0),
	"Shaman": Color(0.34, 0.88, 1.0, 1.0),
	"Nerubian": Color(0.72, 0.38, 1.0, 1.0),
	"Druid": Color(0.42, 1.0, 0.48, 1.0),
	"Undead King": Color(0.52, 0.72, 1.0, 1.0),
	"Mech": Color(1.0, 0.46, 0.16, 1.0),
}
const SELECT_DISTANCE := 54.0
const LEFT_SHRINE_POSITION := Vector2(-205, -54)
const RIGHT_SHRINE_POSITION := Vector2(205, -54)

@export var world_path: NodePath = NodePath("../Level")

var world: Node2D
var player_one: CharacterBody2D
var player_two: CharacterBody2D
var shrine_root: Node2D
var hero_nodes: Dictionary = {}
var displayed_heroes: Array[String] = []
var _p1_last_zone := ""
var _p2_last_zone := ""

func _ready() -> void:
	world = get_node_or_null(world_path) as Node2D
	if world == null:
		push_error("Compact local multiplayer hero selector could not find Level")
		return
	player_one = world.get_node_or_null("Player") as CharacterBody2D
	displayed_heroes = _compact_hero_choices()
	_build_hero_shrines()
	call_deferred("_bind_player_two")

func _bind_player_two() -> void:
	player_two = world.get_node_or_null("Player2") as CharacterBody2D
	_refresh_shrines()

func _process(_delta: float) -> void:
	if player_one == null or not is_instance_valid(player_one):
		return
	if player_two == null or not is_instance_valid(player_two):
		player_two = world.get_node_or_null("Player2") as CharacterBody2D
	_process_player_selection(player_one, 1)
	if player_two != null and is_instance_valid(player_two):
		_process_player_selection(player_two, 2)

func _compact_hero_choices() -> Array[String]:
	var choices: Array[String] = []
	_add_choice_if_available(choices, str(Global.hero_p1))
	_add_choice_if_available(choices, str(Global.hero_p2))
	_add_choice_if_available(choices, str(Global.selected_hero_id))
	for hero_name in HERO_ORDER:
		_add_choice_if_available(choices, hero_name)
		if choices.size() >= 2:
			break
	return choices

func _add_choice_if_available(choices: Array[String], hero_name: String) -> void:
	if choices.size() >= 2:
		return
	if hero_name.is_empty() or choices.has(hero_name):
		return
	if not Global.is_hero_unlocked(hero_name):
		return
	choices.append(hero_name)

func _process_player_selection(target: CharacterBody2D, player_id: int) -> void:
	var closest := ""
	var closest_distance := SELECT_DISTANCE
	for hero_name in displayed_heroes:
		if not hero_nodes.has(hero_name):
			continue
		var shrine: Node2D = hero_nodes[hero_name]["root"]
		var distance := target.global_position.distance_to(shrine.global_position)
		if distance <= closest_distance:
			closest = hero_name
			closest_distance = distance
	var last_zone := _p1_last_zone if player_id == 1 else _p2_last_zone
	if not closest.is_empty() and closest != last_zone:
		_select_hero_for_player(closest, player_id)
	if player_id == 1:
		_p1_last_zone = closest
	else:
		_p2_last_zone = closest

func _select_hero_for_player(hero_name: String, player_id: int) -> void:
	var target := player_one if player_id == 1 else player_two
	if player_id == 1:
		Global.hero_p1 = hero_name
		Global.current_hero = hero_name
		Global.selected_hero_id = hero_name
	else:
		Global.hero_p2 = hero_name
	if target != null and target.has_method("update_hero_sprites"):
		target.update_hero_sprites()
	Global.save_game()
	_refresh_shrines()
	_set_status("Player %d chose %s  •  Enter the lower tunnel when both are ready." % [player_id, hero_name])
	var pulse := create_tween()
	pulse.tween_property(target, "scale", Vector2(1.14, 1.14), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(target, "scale", Vector2.ONE, 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_hero_shrines() -> void:
	shrine_root = Node2D.new()
	shrine_root.name = "CompactHeroShrines"
	shrine_root.z_index = 12
	world.add_child(shrine_root)
	for index in range(displayed_heroes.size()):
		var hero_name := displayed_heroes[index]
		var position := LEFT_SHRINE_POSITION
		if displayed_heroes.size() == 1:
			position = LEFT_SHRINE_POSITION
		elif index == 1:
			position = RIGHT_SHRINE_POSITION
		_create_shrine(hero_name, position)
	_refresh_shrines()

func _create_shrine(hero_name: String, shrine_position: Vector2) -> void:
	var root := Node2D.new()
	root.name = hero_name.replace(" ", "") + "Shrine"
	root.position = shrine_position
	shrine_root.add_child(root)

	var accent: Color = HERO_ACCENTS[hero_name]
	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.position = Vector2(0, 18)
	glow.polygon = _ring_polygon(29.0)
	glow.color = Color(accent.r, accent.g, accent.b, 0.18)
	root.add_child(glow)

	var pedestal := Polygon2D.new()
	pedestal.name = "Pedestal"
	pedestal.position = Vector2(0, 18)
	pedestal.polygon = _ring_polygon(24.0)
	pedestal.color = Color(0.055, 0.07, 0.095, 0.98)
	root.add_child(pedestal)

	var edge := Line2D.new()
	edge.name = "Edge"
	edge.position = Vector2(0, 18)
	edge.points = _ring_line(24.0)
	edge.width = 2.0
	edge.default_color = Color(accent.r, accent.g, accent.b, 0.72)
	root.add_child(edge)

	var sprite := Sprite2D.new()
	sprite.name = "Hero"
	sprite.texture = HERO_TEXTURES[hero_name]
	sprite.position = Vector2(0, -23)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var texture_size: Vector2 = sprite.texture.get_size()
	var scale_factor := 58.0 / maxf(texture_size.y, 1.0)
	sprite.scale = Vector2(scale_factor, scale_factor)
	root.add_child(sprite)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.position = Vector2(-82, 43)
	name_label.size = Vector2(164, 28)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 4)
	root.add_child(name_label)

	hero_nodes[hero_name] = {
		"root": root,
		"glow": glow,
		"pedestal": pedestal,
		"edge": edge,
		"name": name_label,
	}

func _refresh_shrines() -> void:
	for hero_name in hero_nodes:
		var data: Dictionary = hero_nodes[hero_name]
		var p1_selected: bool = Global.hero_p1 == hero_name
		var p2_selected: bool = Global.hero_p2 == hero_name
		var accent: Color = HERO_ACCENTS[hero_name]
		var label: Label = data["name"]
		var pedestal: Polygon2D = data["pedestal"]
		var edge: Line2D = data["edge"]
		var glow: Polygon2D = data["glow"]
		var suffix := ""
		if p1_selected and p2_selected:
			suffix = "  •  P1 + P2"
		elif p1_selected:
			suffix = "  •  P1"
		elif p2_selected:
			suffix = "  •  P2"
		label.text = hero_name + suffix
		label.add_theme_color_override("font_color", accent if p1_selected or p2_selected else Color(0.82, 0.91, 1.0, 1.0))
		pedestal.color = Color(0.17, 0.105, 0.028, 0.98) if p1_selected or p2_selected else Color(0.055, 0.07, 0.095, 0.98)
		edge.width = 4.0 if p1_selected or p2_selected else 2.0
		glow.color = Color(accent.r, accent.g, accent.b, 0.55) if p1_selected or p2_selected else Color(accent.r, accent.g, accent.b, 0.18)

func _set_status(message: String) -> void:
	var status := get_parent().get_node_or_null("LocalMultiplayerHubController/SinglePlayerHubHUD/StatusPanel/Margin/Status") as Label
	if status:
		status.text = message

func _ring_polygon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(12):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / 12.0) * radius)
	return points

func _ring_line(radius: float) -> PackedVector2Array:
	var points := _ring_polygon(radius)
	points.append(points[0])
	return points
