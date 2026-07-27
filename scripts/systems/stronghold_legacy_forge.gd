extends Node2D

# The physical Legacy Forge. The first completed expedition announces it
# ("LEGACY FORGE AWAKENED"), so from that run on the stronghold actually holds a
# forge that spends Legacy Ore on the permanent upgrades the run reads back out
# of Global.
#
# The forge used to be one floor pad per upgrade. That cost the stronghold its
# entire floor, collided with the base at the compact hub tier, and could not
# grow past five ranks — Deepening is uncapped, so the list has to. It is now a
# single hearth you stand at, and the ranks live in a menu.
#
# It is stronghold furniture only: the world controller frees it when a run
# starts, because the expedition reuses the same room.

const MENU_SCENE := preload("res://scenes/ui/overlays/legacy_forge/legacy_forge_menu.tscn")

const UPGRADE_ORDER: Array[String] = ["reinforced_core", "starter_cache", "miners_harness", "safe_return", "deepening"]
const UPGRADE_DATA := {
	"reinforced_core": {
		"title": "REINFORCED CORE",
		"effect": "+15 starting base HP per rank",
		"color": Color(1.0, 0.45, 0.18, 1.0),
	},
	"starter_cache": {
		"title": "STARTER CACHE",
		"effect": "+1 starting gem per rank",
		"color": Color(0.2, 0.95, 1.0, 1.0),
	},
	"miners_harness": {
		"title": "MINER'S HARNESS",
		"effect": "+1 free gem carry per rank",
		"color": Color(0.45, 1.0, 0.42, 1.0),
	},
	"safe_return": {
		"title": "SAFE RETURN",
		"effect": "+30% muster time — dig deeper and still get home",
		"color": Color(1.0, 0.86, 0.32, 1.0),
	},
	"deepening": {
		"title": "DEEPENING",
		"effect": "+1 starting point in your hero's primary attribute per rank",
		"color": Color(0.72, 0.52, 1.0, 1.0),
	},
}

# The hearth stands against the left wall, on the only band of floor that clears
# the base, the spawn point and both door columns at every hub tier.
const WALL_MARGIN := 76.0
const FLOOR_MARGIN := 58.0
const INTERACT_RADIUS := 74.0

var world: Node2D
var player: CharacterBody2D
var prompt_label: Label
var glow: Polygon2D
var menu: CanvasLayer
var player_in_range := false

func _ready() -> void:
	world = get_parent() as Node2D
	if world == null:
		queue_free()
		return
	player = world.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		queue_free()
		return
	name = "StrongholdLegacyForge"
	z_index = 11
	global_position = _anchor_position()
	_build_hearth()
	_refresh_prompt()

func _exit_tree() -> void:
	# The menu is parented to this node's tree branch, but the player lock is not:
	# a forge freed while its menu is open would strand the hero unable to move.
	_release_player()

func _anchor_position() -> Vector2:
	var interior: Rect2 = world.get_hub_interior_rect()
	return Vector2(interior.position.x + WALL_MARGIN, interior.end.y - FLOOR_MARGIN)

func _build_hearth() -> void:
	glow = Polygon2D.new()
	glow.name = "Glow"
	var glow_points := PackedVector2Array()
	for index in range(33):
		glow_points.append(Vector2.RIGHT.rotated(TAU * float(index) / 32.0) * 46.0)
	glow.polygon = glow_points
	glow.position = Vector2(0, -12)
	glow.color = Color(1.0, 0.52, 0.14, 0.14)
	add_child(glow)

	var hearth := Polygon2D.new()
	hearth.name = "Stone"
	hearth.polygon = PackedVector2Array([
		Vector2(-30, 34), Vector2(-22, -6), Vector2(-13, -22),
		Vector2(13, -22), Vector2(22, -6), Vector2(30, 34),
	])
	hearth.color = Color(0.11, 0.09, 0.09, 1.0)
	add_child(hearth)

	var hearth_edge := Line2D.new()
	hearth_edge.name = "HearthEdge"
	hearth_edge.width = 2.5
	hearth_edge.default_color = Color(0.52, 0.36, 0.24, 0.9)
	hearth_edge.points = hearth.polygon + PackedVector2Array([hearth.polygon[0]])
	add_child(hearth_edge)

	var coals := Polygon2D.new()
	coals.name = "Coals"
	var coal_points := PackedVector2Array()
	for index in range(17):
		coal_points.append(Vector2.RIGHT.rotated(TAU * float(index) / 16.0) * 11.0)
	coals.polygon = coal_points
	coals.position = Vector2(0, -14)
	coals.color = Color(1.0, 0.78, 0.32, 0.95)
	add_child(coals)

	var embers := CPUParticles2D.new()
	embers.name = "Embers"
	embers.amount = 14
	embers.lifetime = 2.1
	embers.position = Vector2(0, -18)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(12, 4)
	embers.gravity = Vector2(0, -22)
	embers.initial_velocity_min = 6.0
	embers.initial_velocity_max = 20.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.4
	embers.color = Color(1.0, 0.62, 0.2, 0.55)
	embers.emitting = true
	add_child(embers)

	var breathe := create_tween().bind_node(glow).set_loops()
	breathe.tween_property(glow, "modulate:a", 0.5, 1.1).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(glow, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)

	prompt_label = Label.new()
	prompt_label.name = "Prompt"
	prompt_label.position = Vector2(-110, -84)
	prompt_label.size = Vector2(220, 20)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 13)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.46, 1.0))
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 5)
	add_child(prompt_label)

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var in_range := player.global_position.distance_to(global_position) <= INTERACT_RADIUS
	if in_range == player_in_range:
		return
	player_in_range = in_range
	_refresh_prompt()
	# Walking away is a legitimate way to leave the forge.
	if not in_range and is_menu_open():
		close_menu()

func _refresh_prompt() -> void:
	if prompt_label == null:
		return
	if is_menu_open():
		prompt_label.text = ""
	elif player_in_range:
		prompt_label.text = "E / Y  •  LEGACY FORGE  •  %d ORE" % Global.legacy_ore
	else:
		prompt_label.text = "LEGACY FORGE"

func _unhandled_input(event: InputEvent) -> void:
	if is_menu_open() or not player_in_range:
		return
	if not InputMap.has_action("p1_interact") or not event.is_action_pressed("p1_interact"):
		return
	get_viewport().set_input_as_handled()
	open_menu()

func is_menu_open() -> bool:
	return menu != null and is_instance_valid(menu)

func open_menu() -> CanvasLayer:
	if is_menu_open():
		return menu
	menu = MENU_SCENE.instantiate() as CanvasLayer
	add_child(menu)
	menu.call("setup", UPGRADE_ORDER, UPGRADE_DATA)
	menu.connect("closed", _on_menu_closed)
	if player != null and is_instance_valid(player):
		player.set("can_move", false)
	_refresh_prompt()
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_mine_awaken"):
		sound_fx.play_mine_awaken()
	return menu

func close_menu() -> void:
	if not is_menu_open():
		return
	menu.call("close")

func _on_menu_closed() -> void:
	menu = null
	_release_player()
	_refresh_prompt()

func _release_player() -> void:
	if player != null and is_instance_valid(player):
		player.set("can_move", true)
