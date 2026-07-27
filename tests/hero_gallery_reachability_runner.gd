extends Node

# The compact stronghold shows two pedestals: the active hero and one
# alternative. The alternative used to be picked by scanning the roster
# backwards, which always resolved to the newest unlock — so once the roster
# grew, every earlier hero, the starting Dwarf included, became unreachable.
# Stepping onto the alternative has to walk the whole roster.

const SELECTOR_SCRIPT := preload("res://scripts/systems/preparation/in_world_hero_selector.gd")
const SMOKE_SAVE_PATH := "user://hero_gallery_smoke.save"
const ROSTER := ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King", "Mech"]

var failures := 0

func _ready() -> void:
	Global.set_save_path_override(SMOKE_SAVE_PATH)
	_check_headless_never_touches_the_campaign_save()
	_check_every_hero_is_reachable()
	_check_a_fresh_unlock_is_offered_first()
	if failures == 0:
		print("HERO_GALLERY_PASS")
		get_tree().quit(0)
	else:
		push_error("HERO_GALLERY_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

## An autoload loads and can rewrite the save in _ready, before any test scene
## can opt out, so headless runs must never resolve to the campaign save at all.
func _check_headless_never_touches_the_campaign_save() -> void:
	_expect(OS.has_feature("headless"), "This suite is meant to run headless")
	var previous := Global.save_path_override
	Global.set_save_path_override("")
	_expect(Global.get_save_path() != Global.DEFAULT_SAVE_PATH, "A headless run must not resolve to the campaign save")
	_expect(Global.get_save_path() == Global.HEADLESS_SAVE_PATH, "A headless run should use the sandbox save")
	Global.set_save_path_override(previous)
	_expect(Global.get_save_path() == previous, "An explicit override should still win")

func _make_selector() -> Node:
	var world := Node2D.new()
	add_child(world)
	var selector := Node2D.new()
	selector.set_script(SELECTOR_SCRIPT)
	# Only _compact_hero_choices is under test; it reads Global and world meta,
	# so the selector never needs its full stronghold to answer.
	selector.set("world", world)
	return selector

func _choices_for(active: String) -> Array:
	Global.selected_hero_id = active
	var selector := _make_selector()
	var choices: Array = selector.call("_compact_hero_choices")
	selector.get_parent().queue_free()
	return choices

func _check_every_hero_is_reachable() -> void:
	Global.unlocked_heroes = ROSTER.duplicate()

	# Walking the alternative pedestal must eventually reach every hero.
	var reached := {}
	var active := "Dwarf"
	for step in range(ROSTER.size() * 2):
		reached[active] = true
		var choices := _choices_for(active)
		_expect(choices.size() == 2, "A full roster should offer an active hero and an alternative (active=%s, got %s)" % [active, str(choices)])
		if choices.size() < 2:
			return
		_expect(str(choices[0]) == active, "The active hero should hold the first pedestal (active=%s)" % active)
		active = str(choices[1])
	for hero_name in ROSTER:
		_expect(reached.has(hero_name), "%s should be reachable by stepping through the gallery" % hero_name)

	# The starting hero specifically: from the last unlock the wrap must return.
	var from_mech := _choices_for("Mech")
	_expect(from_mech.size() == 2 and str(from_mech[1]) == "Dwarf", "The roster should wrap from the newest unlock back to the Dwarf (got %s)" % str(from_mech))

	# A single-hero stronghold still shows no gallery at all.
	Global.unlocked_heroes = ["Dwarf"]
	_expect(_choices_for("Dwarf").is_empty(), "A one-hero stronghold should show no pedestals")

func _check_a_fresh_unlock_is_offered_first() -> void:
	Global.unlocked_heroes = ROSTER.duplicate()
	Global.selected_hero_id = "Dwarf"
	var world := Node2D.new()
	world.set_meta("newly_unlocked_heroes", ["Undead King"])
	add_child(world)
	var selector := Node2D.new()
	selector.set_script(SELECTOR_SCRIPT)
	selector.set("world", world)
	var choices: Array = selector.call("_compact_hero_choices")
	_expect(choices.size() == 2 and str(choices[1]) == "Undead King", "A hero unlocked by the last run should be the alternative on offer (got %s)" % str(choices))
	world.queue_free()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("HERO_GALLERY: %s" % message)
