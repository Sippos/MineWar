extends Node2D

const PLAYER_TWO_SCENE = preload("res://local_coop_player.tscn")
const MAIN_MENU_PATH := "res://scenes/menus/main/menu.tscn"

@onready var level: Node2D = $Level
@onready var shared_camera: Camera2D = $SharedCamera
@onready var p2_status: Label = $CoopHUD/P2Panel/VBox/P2Status
@onready var distance_hint: Label = $CoopHUD/P2Panel/VBox/DistanceHint
@onready var exit_button: Button = $CoopHUD/ExitButton

var player_one: CharacterBody2D
var player_two: CharacterBody2D
var support_timer := 0.0

func _ready() -> void:
	GameMode.set_mode(GameMode.Mode.EXPLORATION)
	exit_button.pressed.connect(_return_to_menu)
	await get_tree().process_frame
	player_one = level.get_node_or_null("Player") as CharacterBody2D
	if player_one == null:
		push_error("Local co-op could not find Player 1 in the exploration level.")
		return
	player_one.set("player_id", 1)
	player_one.add_to_group("coop_players")
	var player_one_camera := player_one.get_node_or_null("Camera2D") as Camera2D
	if player_one_camera != null:
		player_one_camera.enabled = false

	player_two = PLAYER_TWO_SCENE.instantiate() as CharacterBody2D
	player_two.name = "Player2"
	player_two.position = player_one.position + Vector2(64.0, 0.0)
	level.add_child(player_two)
	player_two.set("player_id", 2)
	player_two.add_to_group("coop_players")
	shared_camera.global_position = (player_one.global_position + player_two.global_position) * 0.5
	shared_camera.enabled = true
	_update_coop_hud()

func _process(delta: float) -> void:
	if not is_instance_valid(player_one) or not is_instance_valid(player_two):
		return
	var midpoint := (player_one.global_position + player_two.global_position) * 0.5 + Vector2(0.0, -24.0)
	var camera_weight := 1.0 - exp(-6.0 * delta)
	shared_camera.global_position = shared_camera.global_position.lerp(midpoint, camera_weight)
	var separation := player_one.global_position.distance_to(player_two.global_position)
	var desired_zoom_value := clampf(1.5 - maxf(0.0, separation - 180.0) / 760.0, 0.68, 1.5)
	var desired_zoom := Vector2(desired_zoom_value, desired_zoom_value)
	shared_camera.zoom = shared_camera.zoom.lerp(desired_zoom, 1.0 - exp(-4.0 * delta))

	support_timer += delta
	if support_timer >= 0.15:
		support_timer = 0.0
		_support_player_two()
		_update_coop_hud()

func _support_player_two() -> void:
	var base := level.get_node_or_null("Base") as Node2D
	if base == null or not is_instance_valid(player_two):
		return
	var near_base := player_two.global_position.distance_to(base.global_position) <= 105.0
	if not near_base:
		return
	var is_dead_value = player_two.get("is_dead")
	var health_value = player_two.get("health")
	var max_health_value = player_two.get("max_health")
	if is_dead_value != null and not bool(is_dead_value) and health_value != null and max_health_value != null:
		var health := int(health_value)
		var max_health := int(max_health_value)
		if health < max_health:
			player_two.set("health", mini(max_health, health + 1))
	if player_two.has_method("deposit_gems"):
		var deposited := int(player_two.call("deposit_gems"))
		if deposited > 0:
			if base.has_method("_emit_deposit_feedback"):
				base.call("_emit_deposit_feedback", deposited)
			if base.has_signal("gems_deposited"):
				base.emit_signal("gems_deposited", deposited)

func _update_coop_hud() -> void:
	if not is_instance_valid(player_two):
		p2_status.text = "PLAYER 2 • JOINING..."
		return
	var health := int(player_two.get("health"))
	var max_health := int(player_two.get("max_health"))
	var carried := int(player_two.call("get_carry_load")) if player_two.has_method("get_carry_load") else 0
	p2_status.text = "PLAYER 2 • %s • HP %d/%d • GEMS %d" % [Global.hero_p2, health, max_health, carried]
	var separation := player_one.global_position.distance_to(player_two.global_position) if is_instance_valid(player_one) else 0.0
	if separation > 720.0:
		distance_hint.text = "Regroup — camera is at maximum zoom"
	elif separation > 460.0:
		distance_hint.text = "Players are spreading apart"
	else:
		distance_hint.text = "P1: WASD • P2: Arrow Keys"

func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
