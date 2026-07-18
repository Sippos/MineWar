extends CharacterBody2D

var current_hero_name := "Dwarf"
var health := 40
var max_health := 40
var is_dead := false
var level := 1
var strength := 1
var agility := 1
var intelligence := 1
var armor := 0.0
var health_regen := 0.0
var attack_damage := 4.0
var attack_interval := 1.0
var player_id := 1
var can_move := true
var invulnerability_timer := 0.0

func get_carry_load() -> int:
	return 0

func deposit_gems() -> int:
	return 0
