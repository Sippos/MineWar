class_name LineWarsEconomy
extends RefCounted

# One balance source for the competitive loop. Gold is predictable war
# currency; gems stay rare and pay for hero identity or the Goblin gamble.
const STARTING_GOLD := 50
const STARTING_GEMS := 1
const PASSIVE_GOLD_INTERVAL := 5.0
const BASE_PASSIVE_GOLD := 10
const INCOME_STEP_SECONDS := 180.0
const INCOME_STEP_GOLD := 2
const GEM_GAMBLE_COST := 1

const SENDS := {
	"rat_raid": {
		"label": "RAT RAID",
		"gold_cost": 50,
		"count": 5,
		"enemy_type": "RAT",
		"description": "Send 5 fast rats now",
	},
	"trogg_push": {
		"label": "TROGG PUSH",
		"gold_cost": 120,
		"count": 2,
		"enemy_type": "TROGG",
		"description": "Send 2 durable troggs now",
	},
	"elite_push": {
		"label": "ELITE PUSH",
		"gold_cost": 250,
		"count": 3,
		"enemy_type": "ORC",
		"description": "Send 3 elite orcs now",
	},
}

const GAMBLE_OUTCOMES := [
	{
		"id": "overcharge",
		"label": "JACKPOT: OVERCHARGE",
		"weight": 28,
		"count": 8,
		"enemy_type": "RAT",
		"description": "The machine spits out a huge Rat Raid!",
	},
	{
		"id": "rare_enemy",
		"label": "JACKPOT: PROTOTYPE ORC",
		"weight": 22,
		"count": 1,
		"enemy_type": "ORC",
		"description": "A rare prototype fighter enters the enemy tunnel!",
	},
	{
		"id": "gold_bonus",
		"label": "PAYDAY",
		"weight": 30,
		"gold_bonus": 100,
		"description": "Loose gears reveal a hidden war chest: +100 Gold.",
	},
	{
		"id": "malfunction",
		"label": "MALFUNCTION",
		"weight": 20,
		"description": "Smoke, sparks, and no attack. The gem is gone.",
	},
]

static func send(send_id: String) -> Dictionary:
	return (SENDS.get(send_id, {}) as Dictionary).duplicate(true)

static func passive_gold_for_elapsed(elapsed_seconds: float) -> int:
	var steps := int(floor(maxf(elapsed_seconds, 0.0) / INCOME_STEP_SECONDS))
	return BASE_PASSIVE_GOLD + steps * INCOME_STEP_GOLD

static func roll_gamble(rng: RandomNumberGenerator, forced_outcome_id: String = "") -> Dictionary:
	if forced_outcome_id != "":
		for outcome_value in GAMBLE_OUTCOMES:
			var outcome: Dictionary = outcome_value
			if str(outcome.get("id", "")) == forced_outcome_id:
				return outcome.duplicate(true)

	var total_weight := 0
	for outcome_value in GAMBLE_OUTCOMES:
		total_weight += int((outcome_value as Dictionary).get("weight", 0))
	var roll := rng.randi_range(1, maxi(total_weight, 1))
	for outcome_value in GAMBLE_OUTCOMES:
		var outcome: Dictionary = outcome_value
		roll -= int(outcome.get("weight", 0))
		if roll <= 0:
			return outcome.duplicate(true)
	return (GAMBLE_OUTCOMES.back() as Dictionary).duplicate(true)
