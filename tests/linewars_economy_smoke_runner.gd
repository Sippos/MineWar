extends Node

const ECONOMY := preload("res://scripts/systems/linewars_economy.gd")

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_assert(int(ECONOMY.send("rat_raid").get("gold_cost", 0)) == 50, "Rat Raid uses 50 gold")
	_assert(int(ECONOMY.send("trogg_push").get("gold_cost", 0)) == 120, "Trogg Push uses 120 gold")
	_assert(int(ECONOMY.send("elite_push").get("gold_cost", 0)) == 250, "Elite Push uses 250 gold")
	_assert(ECONOMY.passive_gold_for_elapsed(0.0) == 10, "Starting passive income is predictable")
	_assert(ECONOMY.passive_gold_for_elapsed(180.0) == 12, "Passive income escalates every three minutes")
	_assert(str(ECONOMY.roll_gamble(rng, "gold_bonus").get("id", "")) == "gold_bonus", "Gamble outcomes can be forced for balance tests")
	print("LINEWARS_ECONOMY_SMOKE_PASS")
	get_tree().quit(0)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("LINEWARS_ECONOMY_SMOKE_FAIL: " + message)
		get_tree().quit(1)
