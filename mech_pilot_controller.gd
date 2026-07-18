extends Node

const PILOT_SCENE := preload("res://mech_player_pilot.tscn")
const PILOT_MAX_HEALTH := 12

var player: CharacterBody2D
var pilot: CharacterBody2D
var stored_mech_max_health := 30
var stored_player_id := 1
var pilot_cycle_exhausted := false
var active := false

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	process_priority = 240
	if player == null:
		queue_free()

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	if pilot_cycle_exhausted:
		if not bool(player.get("is_dead")):
			pilot_cycle_exhausted = false
		return
	if active:
		_process_active_pilot(delta)
		return
	if str(player.get("current_hero_name")) == "Mech" and bool(player.get("is_dead")):
		_spawn_pilot()

func _spawn_pilot() -> void:
	var world := player.get_parent() as Node2D
	if world == null:
		return
	stored_mech_max_health = maxi(1, int(player.get("max_health")))
	stored_player_id = maxi(1, int(player.get("player_id")))
	pilot = PILOT_SCENE.instantiate() as CharacterBody2D
	world.add_child(pilot)
	pilot.global_position = player.global_position
	if pilot.has_method("configure"):
		pilot.configure(self, player, stored_player_id)
	active = true
	player.set_physics_process(false)
	player.set("is_dead", false)
	player.set("max_health", PILOT_MAX_HEALTH)
	player.set("health", PILOT_MAX_HEALTH)
	player.set("invulnerability_timer", 0.8)
	player.set_collision_layer_value(1, false)
	player.set_collision_mask_value(1, false)
	var sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.visible = false
	_update_hud_health()
	var hud := world.get_node_or_null("HUD")
	if hud and hud.has_method("show_notice"):
		hud.show_notice("MECH DESTROYED — pilot ejected! Reach the base to rebuild.", 4.5)

func _process_active_pilot(delta: float) -> void:
	if pilot == null or not is_instance_valid(pilot):
		on_pilot_defeated()
		return
	player.global_position = pilot.global_position
	var invulnerability := maxf(0.0, float(player.get("invulnerability_timer")) - delta)
	player.set("invulnerability_timer", invulnerability)
	if bool(player.get("is_dead")) or int(player.get("health")) <= 0:
		if pilot.has_method("force_defeat"):
			pilot.force_defeat()
		else:
			on_pilot_defeated()

func rebuild_mech() -> void:
	if not active:
		return
	var world := player.get_parent()
	active = false
	if pilot and is_instance_valid(pilot):
		pilot.queue_free()
	pilot = null
	player.set("max_health", stored_mech_max_health)
	player.set_physics_process(true)
	if player.has_method("respawn"):
		player.respawn()
	player.set("health", maxi(1, int(ceil(float(stored_mech_max_health) * 0.5))))
	player.set("invulnerability_timer", 1.5)
	_update_hud_health()
	if world and world.has_node("HUD"):
		var hud := world.get_node("HUD")
		if hud.has_method("show_notice"):
			hud.show_notice("FIELD REPAIR COMPLETE — Mech restored at 50% health.", 3.5)

func on_pilot_defeated() -> void:
	if not active:
		return
	active = false
	pilot_cycle_exhausted = true
	if pilot and is_instance_valid(pilot):
		pilot.queue_free()
	pilot = null
	player.set("max_health", stored_mech_max_health)
	player.set("health", 0)
	player.set("is_dead", true)
	player.set("respawn_timer", 1.5)
	player.set("invulnerability_timer", 0.0)
	var sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.visible = false
	player.set_collision_layer_value(1, false)
	player.set_collision_mask_value(1, false)
	player.set_physics_process(true)
	_update_hud_health()

func _update_hud_health() -> void:
	var world := player.get_parent()
	if world == null:
		return
	var hud := world.get_node_or_null("HUD")
	if hud and hud.has_method("update_player_health"):
		hud.update_player_health(int(player.get("health")), int(player.get("max_health")))
