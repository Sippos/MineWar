extends Node2D

const TOTEM_TEXTURES = {
	"dig": preload("res://Shaman_Totem_DigBuff.png"),
	"heal": preload("res://Shaman_Totem_Healing.png"),
	"radar": preload("res://Shaman_Totem_Radar.png"),
	"gem": preload("res://Shaman_Totem_GemBuff.png")
}

const TOTEM_LABELS = {
	"dig": "Dig Totem",
	"heal": "Healing Totem",
	"radar": "Radar Totem",
	"gem": "Gem Totem"
}

@export var totem_type: String = "dig"
@export var aura_radius: float = 180.0
@export var lifetime: float = 25.0

var max_lifetime := 25.0
var heal_timer := 0.0
var radar_timer := 0.0
var noticed_enemies := {}
var follow_target: Node2D = null
var follow_offset := Vector2(0, -48)
var float_timer := 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("shaman_totems")
	max_lifetime = lifetime
	if TOTEM_TEXTURES.has(totem_type):
		sprite.texture = TOTEM_TEXTURES[totem_type] as Texture2D
	_fit_sprite()
	_spawn_aura()

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	
	if totem_type == "dig":
		_process_dig_follow(delta)
	
	match totem_type:
		"heal":
			_process_healing(delta)
		"radar":
			_process_radar(delta)

func affects_player(player: Node2D) -> bool:
	return is_instance_valid(player) and global_position.distance_to(player.global_position) <= aura_radius

func get_display_name() -> String:
	return TOTEM_LABELS.get(totem_type, "Totem")

func get_lifetime_ratio() -> float:
	if max_lifetime <= 0.0:
		return 0.0
	return clamp(lifetime / max_lifetime, 0.0, 1.0)

func _process_dig_follow(delta: float) -> void:
	float_timer += delta
	if is_instance_valid(follow_target):
		var target_pos = follow_target.global_position + follow_offset
		global_position = global_position.lerp(target_pos, min(1.0, delta * 8.0))
	sprite.position.y = -14.0 + sin(float_timer * 5.0) * 5.0

func _process_healing(delta: float) -> void:
	heal_timer += delta
	if heal_timer < 1.0:
		return
	heal_timer = 0.0
	
	var player = _get_player()
	if not player or not affects_player(player) or player.is_dead:
		return
	if player.health >= player.max_health:
		return
	
	player.health = min(player.health + 4, player.max_health)
	var hud = _get_hud()
	if hud and hud.has_method("update_player_health"):
		hud.update_player_health(player.health, player.max_health)

func _process_radar(delta: float) -> void:
	radar_timer += delta
	if radar_timer < 0.35:
		return
	radar_timer = 0.0
	
	var player = _get_player()
	if not player or not affects_player(player):
		return
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) > aura_radius:
			continue
		
		var enemy_id = enemy.get_instance_id()
		var cooldown = noticed_enemies.get(enemy_id, 0.0)
		if cooldown <= 0.0:
			_notify("Enemy near your radar totem!")
			_pulse(Color(0.2, 0.75, 1.0, 1.0))
			noticed_enemies[enemy_id] = 3.0
	
	for enemy_id in noticed_enemies.keys():
		noticed_enemies[enemy_id] -= delta
		if noticed_enemies[enemy_id] <= 0.0:
			noticed_enemies.erase(enemy_id)

func _fit_sprite() -> void:
	if sprite.texture == null:
		return
	var max_side = max(sprite.texture.get_width(), sprite.texture.get_height())
	if max_side > 0:
		sprite.scale = Vector2.ONE * (48.0 / float(max_side))

func _spawn_aura() -> void:
	var aura = CPUParticles2D.new()
	aura.name = "Aura"
	aura.amount = 20
	aura.lifetime = 1.4
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 18.0
	aura.gravity = Vector2.ZERO
	aura.initial_velocity_min = 8.0
	aura.initial_velocity_max = 26.0
	aura.damping_min = 8.0
	aura.damping_max = 18.0
	aura.scale_amount_min = 1.5
	aura.scale_amount_max = 4.0
	aura.color = _get_aura_color()
	aura.z_index = -1
	add_child(aura)

func _get_aura_color() -> Color:
	match totem_type:
		"dig":
			return Color(0.35, 0.65, 1.0, 0.55)
		"heal":
			return Color(0.25, 1.0, 0.45, 0.5)
		"radar":
			return Color(0.2, 0.9, 1.0, 0.5)
		"gem":
			return Color(0.95, 0.35, 1.0, 0.5)
	return Color(0.7, 0.8, 1.0, 0.5)

func _pulse(color: Color) -> void:
	if not sprite:
		return
	var tween = create_tween()
	sprite.modulate = color
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

func _notify(text: String) -> void:
	var hud = _get_hud()
	if hud and hud.has_method("show_notice"):
		hud.show_notice(text)

func _get_player():
	var world = get_parent()
	if not world:
		return null
	return world.get_node_or_null("Player")

func _get_hud():
	var world = get_parent()
	if not world:
		return null
	return world.get_node_or_null("HUD")
