extends Node

const HERO_PROFILES: Dictionary = {
	"Dwarf": {
		"primary": "strength",
		"base_stats": {"strength": 4, "agility": 2, "intelligence": 1},
		"growth": {"strength": 0.80, "agility": 0.35, "intelligence": 0.20},
		"base_health": 40,
		"base_attack_damage": 5.0,
		"base_attack_interval": 0.78,
		"base_armor": 1.20,
		"base_regen": 0.18
	},
	"Mech": {
		"primary": "strength",
		"base_stats": {"strength": 5, "agility": 1, "intelligence": 1},
		"growth": {"strength": 0.90, "agility": 0.20, "intelligence": 0.15},
		"base_health": 52,
		"base_attack_damage": 7.0,
		"base_attack_interval": 0.86,
		"base_armor": 2.00,
		"base_regen": 0.16
	},
	"Shaman": {
		"primary": "intelligence",
		"base_stats": {"strength": 1, "agility": 2, "intelligence": 4},
		"growth": {"strength": 0.20, "agility": 0.35, "intelligence": 0.85},
		"base_health": 32,
		"base_attack_damage": 4.0,
		"base_attack_interval": 0.88,
		"base_armor": 0.20,
		"base_regen": 0.08
	},
	"Nerubian": {
		"primary": "agility",
		"base_stats": {"strength": 2, "agility": 4, "intelligence": 1},
		"growth": {"strength": 0.40, "agility": 0.85, "intelligence": 0.20},
		"base_health": 36,
		"base_attack_damage": 4.0,
		"base_attack_interval": 0.60,
		"base_armor": 0.60,
		"base_regen": 0.12
	},
	"Druid": {
		"primary": "intelligence",
		"base_stats": {"strength": 2, "agility": 2, "intelligence": 4},
		"growth": {"strength": 0.45, "agility": 0.45, "intelligence": 0.75},
		"base_health": 34,
		"base_attack_damage": 4.0,
		"base_attack_interval": 0.78,
		"base_armor": 0.50,
		"base_regen": 0.16
	},
	"Undead King": {
		"primary": "intelligence",
		"base_stats": {"strength": 2, "agility": 1, "intelligence": 4},
		"growth": {"strength": 0.55, "agility": 0.20, "intelligence": 0.80},
		"base_health": 38,
		"base_attack_damage": 4.0,
		"base_attack_interval": 0.90,
		"base_armor": 0.80,
		"base_regen": 0.14
	}
}

const STAT_NAMES: Array[String] = ["strength", "agility", "intelligence"]

var player: CharacterBody2D
var world: Node
var applied_hero: String = ""
var tracked_level: int = 1
var permanent_stat_bonuses: Dictionary = {
	"strength": 0,
	"agility": 0,
	"intelligence": 0
}
var extra_max_health_bonus: int = 0
var regen_progress: float = 0.0
var hud_refresh_timer: float = 0.0
var summary_panel: PanelContainer
var summary_label: Label

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	if player == null:
		queue_free()
		return
	world = player.get_parent()
	process_priority = 260
	call_deferred("_late_setup")

func _late_setup() -> void:
	if not is_instance_valid(player):
		return
	_apply_hero_profile(true)
	_ensure_hud()
	_update_hud(true)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var hero: String = _hero_name()
	if hero != applied_hero:
		_apply_hero_profile(true)
	else:
		_capture_external_progression()
		var current_level: int = maxi(1, int(player.get("level")))
		if current_level != tracked_level:
			tracked_level = current_level
			_write_stats_and_health(false, true)
	_process_regeneration(delta)
	hud_refresh_timer -= delta
	if hud_refresh_timer <= 0.0:
		hud_refresh_timer = 0.25
		_ensure_hud()
		_update_hud(false)

func _hero_name() -> String:
	return str(player.get("current_hero_name"))

func _profile() -> Dictionary:
	var hero: String = _hero_name()
	if HERO_PROFILES.has(hero):
		return HERO_PROFILES[hero]
	return HERO_PROFILES["Dwarf"]

func _base_stats() -> Dictionary:
	var profile: Dictionary = _profile()
	return profile["base_stats"]

func _growth_stats() -> Dictionary:
	var profile: Dictionary = _profile()
	return profile["growth"]

func _apply_hero_profile(preserve_health_ratio: bool) -> void:
	var previous_max: int = maxi(1, int(player.get("max_health")))
	var previous_health: int = maxi(0, int(player.get("health")))
	var health_ratio: float = clampf(float(previous_health) / float(previous_max), 0.0, 1.0)
	applied_hero = _hero_name()
	tracked_level = maxi(1, int(player.get("level")))
	_write_stats_only()
	var target_max: int = _expected_max_health() + _temporary_health_bonus()
	player.set("max_health", target_max)
	if preserve_health_ratio:
		player.set("health", clampi(int(round(float(target_max) * health_ratio)), 1, target_max))
	else:
		player.set("health", clampi(previous_health, 0, target_max))
	_refresh_hud_health()

func _desired_permanent_stat(stat_name: String) -> int:
	var base: Dictionary = _base_stats()
	var growth: Dictionary = _growth_stats()
	var level_steps: int = maxi(0, int(player.get("level")) - 1)
	var growth_amount: int = int(floor(float(level_steps) * float(growth[stat_name])))
	return int(base[stat_name]) + growth_amount + int(permanent_stat_bonuses[stat_name])

func _temporary_stat_bonus(stat_name: String) -> int:
	var abilities: Node = player.get_node_or_null("HeroAbilities")
	if abilities == null:
		return 0
	if stat_name == "strength" and bool(abilities.get("avatar_active")):
		return int(abilities.get("avatar_strength_bonus"))
	if stat_name == "intelligence" and bool(abilities.get("ascendance_active")):
		return int(abilities.get("ascendance_int_bonus"))
	return 0

func _temporary_health_bonus() -> int:
	var abilities: Node = player.get_node_or_null("HeroAbilities")
	if abilities != null and bool(abilities.get("avatar_active")):
		return int(abilities.get("avatar_health_bonus"))
	return 0

func _capture_external_progression() -> void:
	var stats_changed: bool = false
	for stat_name: String in STAT_NAMES:
		var actual_without_temporary: int = int(player.get(stat_name)) - _temporary_stat_bonus(stat_name)
		var desired: int = _desired_permanent_stat(stat_name)
		if actual_without_temporary > desired:
			permanent_stat_bonuses[stat_name] = int(permanent_stat_bonuses[stat_name]) + actual_without_temporary - desired
			stats_changed = true
	if stats_changed:
		_write_stats_only()
	var expected_health: int = _expected_max_health() + _temporary_health_bonus()
	var actual_health: int = int(player.get("max_health"))
	if actual_health > expected_health:
		extra_max_health_bonus += actual_health - expected_health
	if stats_changed:
		_write_stats_and_health(false, true)

func _write_stats_only() -> void:
	for stat_name: String in STAT_NAMES:
		player.set(stat_name, _desired_permanent_stat(stat_name) + _temporary_stat_bonus(stat_name))

func _write_stats_and_health(preserve_ratio: bool, heal_gained_health: bool) -> void:
	var old_max: int = maxi(1, int(player.get("max_health")))
	var old_health: int = maxi(0, int(player.get("health")))
	var ratio: float = clampf(float(old_health) / float(old_max), 0.0, 1.0)
	_write_stats_only()
	var target_max: int = _expected_max_health() + _temporary_health_bonus()
	player.set("max_health", target_max)
	if preserve_ratio:
		player.set("health", clampi(int(round(float(target_max) * ratio)), 1, target_max))
	elif heal_gained_health and target_max > old_max:
		player.set("health", mini(target_max, old_health + target_max - old_max))
	else:
		player.set("health", clampi(old_health, 0, target_max))
	_refresh_hud_health()
	_update_hud(true)

func _expected_max_health() -> int:
	var profile: Dictionary = _profile()
	var base: Dictionary = _base_stats()
	var permanent_strength: int = _desired_permanent_stat("strength")
	var strength_above_base: int = maxi(0, permanent_strength - int(base["strength"]))
	return int(profile["base_health"]) + strength_above_base * 6 + extra_max_health_bonus

func register_stat_bonus(stat_name: String, amount: int) -> void:
	if not permanent_stat_bonuses.has(stat_name) or amount == 0:
		return
	permanent_stat_bonuses[stat_name] = maxi(0, int(permanent_stat_bonuses[stat_name]) + amount)
	_write_stats_and_health(false, true)

func register_health_bonus(amount: int) -> void:
	if amount == 0:
		return
	extra_max_health_bonus = maxi(0, extra_max_health_bonus + amount)
	_write_stats_and_health(false, true)

func get_primary_attribute() -> String:
	var profile: Dictionary = _profile()
	return str(profile["primary"])

func get_primary_attribute_value() -> int:
	return int(player.get(get_primary_attribute()))

func get_basic_attack_damage() -> int:
	var profile: Dictionary = _profile()
	var strength_value: int = int(player.get("strength"))
	var primary_value: int = get_primary_attribute_value()
	var damage: float = float(profile["base_attack_damage"]) + float(strength_value) * 1.25 + float(primary_value)
	return maxi(1, int(round(damage)))

func get_attack_interval() -> float:
	var profile: Dictionary = _profile()
	var base: Dictionary = _base_stats()
	var agility_value: int = int(player.get("agility"))
	var extra_agility := maxi(0, agility_value - int(base["agility"]))
	var attack_speed_multiplier: float = 1.0 + float(extra_agility) * 0.055
	return maxf(0.26, float(profile["base_attack_interval"]) / attack_speed_multiplier)

func get_attacks_per_second() -> float:
	return 1.0 / maxf(0.01, get_attack_interval())

func get_move_speed() -> float:
	var base: Dictionary = _base_stats()
	var agility_value: int = int(player.get("agility"))
	var extra_agility := maxi(0, agility_value - int(base["agility"]))
	return float(player.get("base_speed")) + float(extra_agility) * 5.5

func get_dig_time_multiplier() -> float:
	var base: Dictionary = _base_stats()
	var agility_value: int = int(player.get("agility"))
	var strength_value: int = int(player.get("strength"))
	var extra_agility := maxi(0, agility_value - int(base["agility"]))
	var extra_strength := maxi(0, strength_value - int(base["strength"]))
	var mining_speed: float = float(extra_agility) * 0.050 + float(extra_strength) * 0.012
	return maxf(0.48, 1.0 / (1.0 + mining_speed))

func get_mining_force_multiplier(block_id: int) -> float:
	if block_id != 2 and block_id != 3:
		return 1.0
	var base: Dictionary = _base_stats()
	var strength_value: int = int(player.get("strength"))
	var extra_strength := maxi(0, strength_value - int(base["strength"]))
	var reduction_per_point := 0.075 if block_id == 2 else 0.095
	return maxf(0.42, 1.0 - float(extra_strength) * reduction_per_point)

func get_build_identity() -> Dictionary:
	var base: Dictionary = _base_stats()
	var strength_extra := maxi(0, int(player.get("strength")) - int(base["strength"]))
	var agility_extra := maxi(0, int(player.get("agility")) - int(base["agility"]))
	var intelligence_extra := maxi(0, int(player.get("intelligence")) - int(base["intelligence"]))
	var highest := maxi(strength_extra, maxi(agility_extra, intelligence_extra))
	if highest < 2:
		return {"title": "UNSHAPED", "description": "The next few gems will define this run.", "color": Color(0.78, 0.82, 0.88)}
	var leaders := 0
	leaders += 1 if strength_extra == highest else 0
	leaders += 1 if agility_extra == highest else 0
	leaders += 1 if intelligence_extra == highest else 0
	if leaders > 1:
		return {"title": "HYBRID DELVER", "description": "Balanced mining, combat, and utility.", "color": Color(0.78, 0.72, 1.0)}
	if strength_extra == highest:
		var title := "LOADBEARER" if highest < 5 else ("EARTHBREAKER" if highest < 8 else "MOUNTAIN KING")
		return {"title": title, "description": "Heavy loads, brutal melee, and hard-rock force.", "color": Color(1.0, 0.48, 0.24)}
	if agility_extra == highest:
		var title := "SCOUT MINER" if highest < 5 else ("VEIN RUNNER" if highest < 8 else "CAVE BLUR")
		return {"title": title, "description": "Fast digging, rapid attacks, and safer returns.", "color": Color(0.35, 1.0, 0.58)}
	var title := "PROSPECTOR" if highest < 5 else ("RUNECASTER" if highest < 8 else "ARCANE ENGINE")
	return {"title": title, "description": "Stronger utility, shorter cooldowns, and empowered summons.", "color": Color(0.35, 0.72, 1.0)}

func get_armor() -> float:
	var profile: Dictionary = _profile()
	var agility_value: int = int(player.get("agility"))
	var armor: float = float(profile["base_armor"]) + float(agility_value) * 0.18
	var abilities: Node = player.get_node_or_null("HeroAbilities")
	if abilities != null and bool(abilities.get("avatar_active")):
		armor += 2.5
	return armor

func get_damage_reduction() -> float:
	var armor: float = maxf(0.0, get_armor())
	return minf(0.65, armor / (10.0 + armor))

func modify_incoming_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var reduced: float = float(amount) * (1.0 - get_damage_reduction())
	return maxi(1, int(round(reduced)))

func get_health_regeneration() -> float:
	var profile: Dictionary = _profile()
	var base: Dictionary = _base_stats()
	var strength_value: int = int(player.get("strength"))
	var strength_above_base: int = maxi(0, strength_value - int(base["strength"]))
	return float(profile["base_regen"]) + float(strength_above_base) * 0.08

func get_spell_power_multiplier() -> float:
	var base: Dictionary = _base_stats()
	var intelligence_value: int = int(player.get("intelligence"))
	var extra_intelligence := maxi(0, intelligence_value - int(base["intelligence"]))
	return 1.0 + float(extra_intelligence) * 0.065

func get_summon_power_multiplier() -> float:
	var base: Dictionary = _base_stats()
	var intelligence_value: int = int(player.get("intelligence"))
	var extra_intelligence := maxi(0, intelligence_value - int(base["intelligence"]))
	return 1.0 + float(extra_intelligence) * 0.055

func get_cooldown_multiplier() -> float:
	var base: Dictionary = _base_stats()
	var intelligence_value: int = int(player.get("intelligence"))
	var extra_intelligence := maxi(0, intelligence_value - int(base["intelligence"]))
	var reduction: float = minf(0.42, float(extra_intelligence) * 0.028)
	return 1.0 - reduction

func get_duration_multiplier() -> float:
	var base: Dictionary = _base_stats()
	var intelligence_value: int = int(player.get("intelligence"))
	var extra_intelligence := maxi(0, intelligence_value - int(base["intelligence"]))
	return 1.0 + float(extra_intelligence) * 0.030

func scale_spell_damage(base_damage: int) -> int:
	return maxi(1, int(round(float(base_damage) * get_spell_power_multiplier())))

func scale_summon_damage(base_damage: int) -> int:
	return maxi(1, int(round(float(base_damage) * get_summon_power_multiplier())))

func scale_physical_ability_damage(base_damage: int) -> int:
	var base: Dictionary = _base_stats()
	var strength_value: int = int(player.get("strength"))
	var extra_strength: int = maxi(0, strength_value - int(base["strength"]))
	var multiplier: float = 1.0 + float(extra_strength) * 0.045
	if get_primary_attribute() == "strength":
		multiplier += float(extra_strength) * 0.020
	return maxi(1, int(round(float(base_damage) * multiplier)))

func adjust_cooldown(base_cooldown: float) -> float:
	return maxf(0.25, base_cooldown * get_cooldown_multiplier())

func adjust_duration(base_duration: float) -> float:
	return maxf(0.1, base_duration * get_duration_multiplier())

func _process_regeneration(delta: float) -> void:
	if bool(player.get("is_dead")):
		regen_progress = 0.0
		return
	var health_value: int = int(player.get("health"))
	var max_health_value: int = int(player.get("max_health"))
	if health_value >= max_health_value:
		regen_progress = 0.0
		return
	regen_progress += get_health_regeneration() * delta
	var whole_healing: int = int(floor(regen_progress))
	if whole_healing <= 0:
		return
	regen_progress -= float(whole_healing)
	player.set("health", mini(max_health_value, health_value + whole_healing))
	_refresh_hud_health()

func _ensure_hud() -> void:
	if world == null:
		return
	var hud: Node = world.get_node_or_null("HUD")
	if hud == null:
		return
	var stats_container: Control = hud.get_node_or_null("StatsContainer") as Control
	if stats_container == null:
		return
	_update_stat_tooltips(stats_container)
	if summary_panel != null and is_instance_valid(summary_panel):
		return
	summary_panel = PanelContainer.new()
	summary_panel.name = "HeroRPGSummaryP%d" % int(player.get("player_id"))
	summary_panel.offset_left = 20.0
	summary_panel.offset_top = 108.0
	summary_panel.offset_right = 500.0
	summary_panel.offset_bottom = 138.0
	summary_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_panel.z_index = 12
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.03, 0.04, 0.88)
	style.border_color = Color(0.48, 0.4, 0.26, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	summary_panel.add_theme_stylebox_override("panel", style)
	hud.add_child(summary_panel)
	summary_label = Label.new()
	summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary_label.add_theme_font_size_override("font_size", 13)
	summary_label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.65))
	summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_panel.add_child(summary_label)

func _update_stat_tooltips(stats_container: Control) -> void:
	var primary: String = get_primary_attribute()
	var strength_suffix: String = "  PRIMARY" if primary == "strength" else ""
	var agility_suffix: String = "  PRIMARY" if primary == "agility" else ""
	var intelligence_suffix: String = "  PRIMARY" if primary == "intelligence" else ""
	var strength_tooltip: String = "Strength%s\n+1.25 basic damage, +6 maximum health, +0.08 health regeneration per point above the hero base.\nThe primary attribute also adds +1 basic damage per point." % strength_suffix
	var agility_tooltip: String = "Agility%s\n+3.5%% attack speed, +3 movement speed, +0.18 armor, and about +2.5%% mining speed per point." % agility_suffix
	var intelligence_tooltip: String = "Intelligence%s\n+3.5%% spell power, +3%% summon power, +1.25%% cooldown recovery, and +1.5%% effect duration per point." % intelligence_suffix
	var tooltip_map: Dictionary = {
		"StrIcon": strength_tooltip,
		"StrLabel": strength_tooltip,
		"AgiIcon": agility_tooltip,
		"AgiLabel": agility_tooltip,
		"IntIcon": intelligence_tooltip,
		"IntLabel": intelligence_tooltip
	}
	for node_name: String in tooltip_map:
		var control: Control = stats_container.get_node_or_null(node_name) as Control
		if control != null:
			control.tooltip_text = str(tooltip_map[node_name])

func _update_hud(force: bool) -> void:
	if summary_panel == null or not is_instance_valid(summary_panel):
		return
	var hud: Node = world.get_node_or_null("HUD") if world != null else null
	var stats_container: Control = hud.get_node_or_null("StatsContainer") as Control if hud != null else null
	summary_panel.visible = stats_container != null and stats_container.visible
	if summary_label == null:
		return
	var primary_text: String = get_primary_attribute().to_upper()
	var spell_percent: int = int(round(get_spell_power_multiplier() * 100.0))
	var summon_percent: int = int(round(get_summon_power_multiplier() * 100.0))
	var new_text: String = "PRIMARY %s   DMG %d   APS %.2f   ARM %.1f   SPELL %d%%   SUMMON %d%%" % [primary_text, get_basic_attack_damage(), get_attacks_per_second(), get_armor(), spell_percent, summon_percent]
	if force or summary_label.text != new_text:
		summary_label.text = new_text

func _refresh_hud_health() -> void:
	if world == null:
		return
	var hud: Node = world.get_node_or_null("HUD")
	if hud != null and hud.has_method("update_player_health"):
		hud.call("update_player_health", int(player.get("health")), int(player.get("max_health")))
	if hud != null and hud.has_method("update_stats"):
		hud.call("update_stats", int(player.get("strength")), int(player.get("agility")), int(player.get("intelligence")))
