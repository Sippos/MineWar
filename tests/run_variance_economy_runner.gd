extends Node

# Covers the three economy changes that gems, stats and long-term progression
# now depend on:
#   * single-player stat costs climb, and climb slower for the hero's primary
#     attribute, so a run's gems buy a build instead of buying everything;
#   * every expedition draws its stage objectives and one run modifier, while
#     the first expedition still gets the authored onboarding draw;
#   * Legacy Ore has an uncapped sink, so the meta no longer runs dry after the
#     ~37 ore of capped ranks.

const HUB_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")
const SIEGE_SCRIPT := preload("res://scripts/systems/world_generation/siege_mode_controller.gd")
const SMOKE_SAVE_PATH := "user://run_variance_economy_smoke.save"

var failures := 0

func _ready() -> void:
	# The checks run deferred so the scene tree is fully entered first.
	call_deferred("_run_checks")

func _run_checks() -> void:
	Global.set_save_path_override(SMOKE_SAVE_PATH)
	await _check_stat_costs_on_the_real_menu()
	_check_objective_pools_are_diggable()
	_check_authored_onboarding_draw()
	_check_run_modifiers_are_coherent()
	_check_uncapped_legacy_sink()
	_check_uncapped_rank_survives_a_save_round_trip()
	_check_staged_run_ore_bonus()
	if failures == 0:
		print("RUN_VARIANCE_ECONOMY_PASS")
		get_tree().quit(0)
	else:
		push_error("RUN_VARIANCE_ECONOMY_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

# --- stat costs -------------------------------------------------------------

## The upgrade menu only works as its authored scene, so the cost curve is
## measured on the real menu inside a real stronghold rather than on a bare
## script instance.
func _check_stat_costs_on_the_real_menu() -> void:
	Global.unlocked_heroes = ["Dwarf", "Shaman"]
	Global.first_level_beaten = true
	Global.minewars_runs_completed = 1
	var hub := HUB_SCENE.instantiate()
	add_child(hub)
	for i in range(6):
		await get_tree().process_frame
	var level := hub.get_node_or_null("Level") as Node2D
	var menu := level.get_node_or_null("UpgradeMenu") if level != null else null
	var hero := level.get_node_or_null("Player") if level != null else null
	if menu == null or hero == null:
		_expect(false, "The cost-curve check needs the real UpgradeMenu and Player")
		hub.queue_free()
		return

	hero.set("current_hero_name", "Dwarf")
	_check_costs_climb(menu)
	_check_primary_is_the_cheap_lane(menu, hero)
	_check_vs_economy_untouched(menu, level)
	await _check_deepening_reaches_the_hero(hero)
	hub.queue_free()
	await get_tree().process_frame

func _lane_total(menu: Node, stat_name: String) -> int:
	var total := 0
	for level_value in range(1, 12):
		total += int(menu.call("get_upgrade_cost", level_value, stat_name))
	return total

func _check_costs_climb(menu: Node) -> void:
	# Dwarf is Strength-primary, so agility is a plain non-primary attribute.
	var first := int(menu.call("get_upgrade_cost", 1, "agility"))
	var mid := int(menu.call("get_upgrade_cost", 5, "agility"))
	var deep := int(menu.call("get_upgrade_cost", 11, "agility"))
	_expect(first == 1, "The first attribute point should still cost a single gem (got %d)" % first)
	_expect(mid > first, "Costs must climb with the attribute level (%d then %d)" % [first, mid])
	_expect(deep > mid, "Costs must keep climbing at depth (%d then %d)" % [mid, deep])
	# The old flat economy made every purchase automatic; a full stat lane should
	# now cost a meaningful share of a run's haul.
	var lane_total := _lane_total(menu, "agility")
	_expect(lane_total >= 25, "Maxing one attribute lane should cost real gems (got %d)" % lane_total)

func _check_primary_is_the_cheap_lane(menu: Node, hero: Node) -> void:
	hero.set("current_hero_name", "Dwarf")
	var dwarf_primary := _lane_total(menu, "strength")
	var dwarf_off := _lane_total(menu, "intelligence")
	_expect(dwarf_primary < dwarf_off, "The Dwarf's primary Strength lane should be cheaper than Intelligence (%d vs %d)" % [dwarf_primary, dwarf_off])

	# The discount must follow the hero, not be hardcoded to Strength.
	hero.set("current_hero_name", "Shaman")
	var shaman_primary := _lane_total(menu, "intelligence")
	var shaman_off := _lane_total(menu, "strength")
	_expect(shaman_primary < shaman_off, "The Shaman's primary Intelligence lane should be the cheap one (%d vs %d)" % [shaman_primary, shaman_off])
	hero.set("current_hero_name", "Dwarf")

func _check_vs_economy_untouched(menu: Node, level: Node) -> void:
	# Competitive pricing is a separate, tuned economy and must not move.
	var was_vs: bool = bool(level.get("is_vs_mode"))
	level.set("is_vs_mode", true)
	for level_value in [1, 3, 7]:
		var expected: int = (int(level_value) * 2) - 1
		var actual: int = int(menu.call("get_upgrade_cost", level_value, "strength"))
		_expect(actual == expected, "VS cost at level %d should stay %d (got %d)" % [level_value, expected, actual])
	level.set("is_vs_mode", was_vs)

## Deepening is only worth buying if its ranks actually start the hero deeper in
## their primary attribute, which is the one hook a table check cannot prove.
func _check_deepening_reaches_the_hero(hero: Node) -> void:
	var rpg := hero.get_node_or_null("HeroRPGController")
	if rpg == null:
		_expect(false, "The Deepening check needs the live HeroRPGController")
		return
	hero.set("current_hero_name", "Dwarf")
	Global.permanent_upgrade_levels["deepening"] = 0
	rpg.call("_apply_hero_profile", false)
	var baseline := int(hero.get("strength"))
	var baseline_intelligence := int(hero.get("intelligence"))

	Global.permanent_upgrade_levels["deepening"] = 3
	rpg.call("_apply_hero_profile", false)
	var boosted := int(hero.get("strength"))
	_expect(boosted == baseline + 3, "Three Deepening ranks should add three Strength for a Dwarf (%d then %d)" % [baseline, boosted])
	_expect(int(hero.get("intelligence")) == baseline_intelligence, "Deepening should only deepen the primary attribute")

	# The bonus must not be double-counted when the controller re-syncs.
	rpg.call("_capture_external_progression")
	rpg.call("_apply_hero_profile", false)
	_expect(int(hero.get("strength")) == boosted, "Re-syncing must not stack the Deepening bonus again (got %d, expected %d)" % [int(hero.get("strength")), boosted])
	Global.permanent_upgrade_levels["deepening"] = 0
	await get_tree().process_frame

# --- run variance -----------------------------------------------------------

func _check_objective_pools_are_diggable() -> void:
	var pools: Dictionary = SIEGE_SCRIPT.STAGE_OBJECTIVE_POOLS
	var motherlodes: Dictionary = SIEGE_SCRIPT.STAGE_MOTHERLODE_COUNTS
	_expect(pools.size() == SIEGE_SCRIPT.FINAL_STAGE, "Every stage should own an objective pool")
	for stage_value in pools.keys():
		var stage := int(stage_value)
		var pool: Array = pools[stage_value]
		var seam := int(motherlodes.get(stage, 0))
		_expect(pool.size() >= 2, "Stage %d needs more than one objective to vary" % stage)
		var has_headroom := false
		for entry_value in pool:
			var entry: Dictionary = entry_value
			var target := int(entry.get("target", 0))
			_expect(target >= 1, "Stage %d objective '%s' needs a real target" % [stage, entry.get("title", "?")])
			# Every objective must be finishable from the crystals the seam holds.
			# A modifier's target bonus is clamped to the seam at runtime, so a
			# full-seam objective is safe — it simply does not get harder.
			_expect(target <= seam, "Stage %d objective '%s' (target %d) is not diggable from a %d-crystal seam" % [stage, entry.get("title", "?"), target, seam])
			_expect(not str(entry.get("reward_id", "")).is_empty(), "Stage %d objective '%s' needs a reward" % [stage, entry.get("title", "?")])
			if target < seam:
				has_headroom = true
		# ...but LONG FUSE must not be a guaranteed no-op on any stage.
		_expect(has_headroom, "Stage %d needs at least one objective the target bonus can actually raise" % stage)

func _check_authored_onboarding_draw() -> void:
	# A new player must meet the hand-authored objectives, in order, with no omen.
	var pools: Dictionary = SIEGE_SCRIPT.STAGE_OBJECTIVE_POOLS
	_expect(str((pools[1][0] as Dictionary).get("title", "")) == "RICH VEIN", "The authored first objective should stay first in its pool")
	_expect(str((pools[2][0] as Dictionary).get("title", "")) == "MINER'S SATCHEL", "The authored second objective should stay first in its pool")
	_expect(str((pools[3][0] as Dictionary).get("title", "")) == "ANCIENT FORGE", "The authored third objective should stay first in its pool")
	_expect(str((pools[4][0] as Dictionary).get("title", "")) == "HEART CACHE", "The authored final objective should stay first in its pool")
	var first_modifier: Dictionary = SIEGE_SCRIPT.RUN_MODIFIERS[0]
	_expect(str(first_modifier.get("id", "")) == "steady", "The onboarding draw should be the no-op modifier")

func _check_run_modifiers_are_coherent() -> void:
	var modifiers: Array = SIEGE_SCRIPT.RUN_MODIFIERS
	_expect(modifiers.size() >= 4, "A single alternative is not variance")
	var seen_ids := {}
	for entry_value in modifiers:
		var entry: Dictionary = entry_value
		var id := str(entry.get("id", ""))
		_expect(not id.is_empty() and not seen_ids.has(id), "Modifier ids must be present and unique (saw '%s' twice)" % id)
		seen_ids[id] = true
		_expect(not str(entry.get("title", "")).is_empty(), "Modifier '%s' needs a title to announce" % id)
		_expect(not str(entry.get("description", "")).is_empty(), "Modifier '%s' needs a description" % id)
		if id == "steady":
			continue
		# Every non-steady modifier must actually change something.
		var effect_keys := ["mining_scale", "muster_scale", "enemy_bonus", "gem_bonus", "target_bonus", "ore_bonus"]
		var has_effect := false
		for key in effect_keys:
			if entry.has(key):
				has_effect = true
		_expect(has_effect, "Modifier '%s' announces itself but changes nothing" % id)
		# A modifier that only makes the run harder should pay for itself.
		var mining_scale := float(entry.get("mining_scale", 1.0))
		_expect(mining_scale >= 0.7, "Modifier '%s' cuts the dig window too far (%.2f)" % [id, mining_scale])

# --- legacy ore -------------------------------------------------------------

func _reset_progression() -> void:
	Global.legacy_ore = 0
	Global.pending_run_ore_bonus = 0
	for upgrade_id in Global.PERMANENT_UPGRADE_IDS:
		Global.permanent_upgrade_levels[upgrade_id] = 0

func _check_uncapped_legacy_sink() -> void:
	_reset_progression()
	_expect(Global.PERMANENT_UPGRADE_UNCAPPED.has("deepening"), "Deepening should be the uncapped sink")
	_expect(not Global.is_permanent_upgrade_maxed("deepening"), "An uncapped rank should never report maxed at level 0")

	# Buy well past the total rank count of every capped upgrade combined.
	var previous_cost := 0
	for rank in range(12):
		var cost := Global.get_permanent_upgrade_cost("deepening")
		_expect(cost > previous_cost, "Deepening cost should keep climbing (rank %d cost %d after %d)" % [rank, cost, previous_cost])
		previous_cost = cost
		Global.legacy_ore = cost
		_expect(Global.purchase_permanent_upgrade("deepening"), "Deepening rank %d should be purchasable" % rank)
	_expect(Global.get_permanent_upgrade_level("deepening") == 12, "Twelve purchases should grant twelve ranks")
	_expect(not Global.is_permanent_upgrade_maxed("deepening"), "Deepening must still not be maxed after twelve ranks")
	_expect(Global.get_permanent_primary_attribute_bonus() == 12, "Deepening ranks should reach the run as primary-attribute points")

	# Safe Return is the rank that changes a rule rather than padding a number.
	_reset_progression()
	_expect(Global.get_permanent_muster_scale() == 1.0, "Muster time should be unmodified without Safe Return")
	Global.legacy_ore = Global.get_permanent_upgrade_cost("safe_return")
	_expect(Global.purchase_permanent_upgrade("safe_return"), "Safe Return should be purchasable")
	_expect(Global.get_permanent_muster_scale() > 1.0, "Safe Return should widen the muster window")
	_expect(Global.is_permanent_upgrade_maxed("safe_return"), "Safe Return is a single capped rank")

func _check_uncapped_rank_survives_a_save_round_trip() -> void:
	# The load path clamps ranks to their max level, which is 0 for an uncapped
	# upgrade — without an explicit exemption every Deepening rank is wiped.
	_reset_progression()
	Global.permanent_upgrade_levels["deepening"] = 9
	Global.permanent_upgrade_levels["reinforced_core"] = 99
	Global.save_game()
	Global.permanent_upgrade_levels["deepening"] = 0
	Global.load_game()
	_expect(Global.get_permanent_upgrade_level("deepening") == 9, "Uncapped ranks must survive a save round trip (got %d)" % Global.get_permanent_upgrade_level("deepening"))
	_expect(Global.get_permanent_upgrade_level("reinforced_core") == int(Global.PERMANENT_UPGRADE_MAX_LEVELS["reinforced_core"]), "Capped ranks must still clamp on load")

func _check_staged_run_ore_bonus() -> void:
	_reset_progression()
	Global.stage_run_ore_bonus(2)
	var plain := 0
	var bonused := Global.award_run_legacy_ore(6, false)
	_expect(Global.pending_run_ore_bonus == 0, "A paid-out modifier bonus should not pay twice")
	Global.legacy_ore = 0
	plain = Global.award_run_legacy_ore(6, false)
	_expect(bonused == plain + 2, "A modifier's ore bonus should reach the result screen (%d vs %d)" % [bonused, plain])

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("RUN_VARIANCE_ECONOMY: %s" % message)
