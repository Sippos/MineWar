class_name RunSummaryData
extends RefCounted

## Run retrospective DTO capturing expedition performance metrics,
## scoring, and Legacy Ore ledger breakdown for MineWars.

var victory: bool = false
var hero_name: String = "Dwarf"
var hero_level: int = 1
var strength: int = 1
var agility: int = 1
var intelligence: int = 1

var waves_survived: int = 1
var final_wave: int = 4
var elapsed_time_string: String = "00:00"
var base_integrity: int = 100

var total_gems: int = 0
var total_gold: int = 0
var blocks_mined: int = 0
var caches_unlocked: int = 0

var horn_soundings: int = 0
var horn_greed_multiplier: float = 1.0
var score: int = 0

var base_survival_ore: int = 1
var victory_bonus_ore: int = 0
var horn_bonus_ore: int = 0
var legacy_ore_earned: int = 1
var total_legacy_ore: int = 0
var milestone_title: String = ""

func calculate_score() -> int:
	var base_points := (blocks_mined * 10) + (total_gems * 25) + (caches_unlocked * 200) + (waves_survived * 500) + (base_integrity * 15)
	if victory:
		base_points += 2500
	score = int(round(float(base_points) * maxf(horn_greed_multiplier, 1.0)))
	return score

func to_dict() -> Dictionary:
	return {
		"victory": victory,
		"hero_name": hero_name,
		"hero_level": hero_level,
		"strength": strength,
		"agility": agility,
		"intelligence": intelligence,
		"waves_survived": waves_survived,
		"final_wave": final_wave,
		"elapsed_time_string": elapsed_time_string,
		"base_integrity": base_integrity,
		"total_gems": total_gems,
		"total_gold": total_gold,
		"blocks_mined": blocks_mined,
		"caches_unlocked": caches_unlocked,
		"horn_soundings": horn_soundings,
		"horn_greed_multiplier": horn_greed_multiplier,
		"score": score,
		"base_survival_ore": base_survival_ore,
		"victory_bonus_ore": victory_bonus_ore,
		"horn_bonus_ore": horn_bonus_ore,
		"legacy_ore_earned": legacy_ore_earned,
		"total_legacy_ore": total_legacy_ore,
		"milestone_title": milestone_title,
	}

static func from_dict(data: Dictionary) -> RefCounted:
	var script: GDScript = load("res://scripts/systems/gameplay/run_summary_data.gd") as GDScript
	var summary: RefCounted = script.new()
	summary.set("victory", bool(data.get("victory", false)))
	summary.set("hero_name", str(data.get("hero_name", "Dwarf")))
	summary.set("hero_level", int(data.get("hero_level", 1)))
	summary.set("strength", int(data.get("strength", 1)))
	summary.set("agility", int(data.get("agility", 1)))
	summary.set("intelligence", int(data.get("intelligence", 1)))
	summary.set("waves_survived", int(data.get("waves_survived", 1)))
	summary.set("final_wave", int(data.get("final_wave", 4)))
	summary.set("elapsed_time_string", str(data.get("elapsed_time_string", "00:00")))
	summary.set("base_integrity", int(data.get("base_integrity", 100)))
	summary.set("total_gems", int(data.get("total_gems", 0)))
	summary.set("total_gold", int(data.get("total_gold", 0)))
	summary.set("blocks_mined", int(data.get("blocks_mined", 0)))
	summary.set("caches_unlocked", int(data.get("caches_unlocked", 0)))
	summary.set("horn_soundings", int(data.get("horn_soundings", 0)))
	summary.set("horn_greed_multiplier", float(data.get("horn_greed_multiplier", 1.0)))
	summary.set("score", int(data.get("score", 0)))
	summary.set("base_survival_ore", int(data.get("base_survival_ore", 1)))
	summary.set("victory_bonus_ore", int(data.get("victory_bonus_ore", 0)))
	summary.set("horn_bonus_ore", int(data.get("horn_bonus_ore", 0)))
	summary.set("legacy_ore_earned", int(data.get("legacy_ore_earned", 1)))
	summary.set("total_legacy_ore", int(data.get("total_legacy_ore", 0)))
	summary.set("milestone_title", str(data.get("milestone_title", "")))
	return summary
