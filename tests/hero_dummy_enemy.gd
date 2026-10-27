extends CharacterBody2D

@export var max_health := 1200
var health := 1200
var speed := 80.0
var is_boss_enemy := false
var total_damage_taken := 0
var stun_timer := 0.0
var speed_multiplier := 1.0

func _ready() -> void:
	add_to_group("enemies")
	health = max_health

func take_damage(amount: int) -> void:
	var applied := maxi(0, amount)
	total_damage_taken += applied
	health = maxi(0, health - applied)

func apply_stun(duration: float, _push := Vector2.ZERO) -> void:
	stun_timer = maxf(stun_timer, duration)

func apply_slow(duration: float, multiplier: float) -> void:
	speed_multiplier = multiplier

func reset_health() -> void:
	health = max_health
	total_damage_taken = 0
	stun_timer = 0.0
	speed_multiplier = 1.0
