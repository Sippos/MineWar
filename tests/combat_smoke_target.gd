extends CharacterBody2D

var health := 2000
var is_dead := false
var currently_attacking_enemy = null

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		is_dead = true
