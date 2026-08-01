extends Node2D

# MineWars is a four-chapter roguelike expedition:
# pursue a marked objective, decide when greed becomes dangerous, return to the
# bastion, defend it, spend the build reward, and deliberately descend again.

const ENEMY_SCENE := preload("res://enemy.tscn")
const BOSS_BEHAVIOR := preload("res://scripts/systems/world_generation/minewars_boss_behavior.gd")
const SEALED_CACHE_SCRIPT := preload("res://scripts/gameplay/collectibles/rewards/sealed_cache.gd")
const FIXED_ENTRANCE_CELL := Vector2i(12, 0)  # Right tunnel endpoint
const SECONDARY_ENTRANCE_CELL := Vector2i(12, 0)
const SPAWN_GAP := 0.42
const FINAL_STAGE := 4
const RECOVERY_BASE_DISTANCE := 112.0
const NEXT_EXPEDITION_DEPTH := 3
const NEXT_EXPEDITION_DISTANCE := 180.0
const MINEWARS_BOSS_HEALTH := 540
const MINEWARS_BOSS_DAMAGE := 9
const MINEWARS_BOSS_SPEED := 46.0

const STAGE_NAMES := {
	1: "OUTER SEAM",
	2: "DEEP VEINS",
	3: "ANCIENT STRATA",
	4: "GOBLIN WAR MECH",
}
const STAGE_MINING_WINDOWS := {
	1: 90.0,
	2: 82.0,
	3: 72.0,
	4: 62.0,
}
const STAGE_ENEMY_COUNTS := {
	1: 3,
	2: 5,
	3: 7,
}
const STAGE_ENEMY_ROSTERS := {
	1: [0, 0, 0],
	2: [0, 1, 0, 1, 2],
	3: [1, 2, 3, 1, 3, 2, 4],
}
const STAGE_CLEAR_GEM_REWARDS := {
	1: 1,
	2: 1,
	3: 2,
}
const STAGE_MUSTER_TIMES := {
	1: 16.0,
	2: 13.0,
	3: 10.0,
	4: 8.0,
}
const STAGE_ENEMY_POWER_LEVELS := {
	1: 1,
	2: 2,
	3: 4,
	4: 6,
}
const STAGE_MOTHERLODE_COUNTS := {
	1: 3,
	2: 4,
	3: 6,
	4: 8,
}
# Every expedition used to run the identical four stages with the identical four
# objectives, so run 12 played exactly like run 2. Each stage now draws its
# objective from a pool and the run draws one world-wide modifier, which is what
# turns "I beat it" into "one more run". Index 0 of every pool is the original
# authored objective: the first expedition and the guided trial always draw it,
# so onboarding stays word-for-word what it was.
# Targets must stay within STAGE_MOTHERLODE_COUNTS for their stage.
const STAGE_OBJECTIVE_POOLS := {
	1: [
		{
			"title": "RICH VEIN",
			"description": "Break 2 crystals from the marked seam.",
			"target": 2,
			"reward": "2 secured gems",
			"reward_id": "gems_2",
		},
		{
			"title": "SHALLOW CACHE",
			"description": "Strip all 3 crystals from the marked seam.",
			"target": 3,
			"reward": "prospector's boots",
			"reward_id": "boots",
		},
		{
			"title": "FIRST CUT",
			"description": "Break 2 crystals from the marked seam.",
			"target": 2,
			"reward": "3 secured gems",
			"reward_id": "gems_3",
		},
	],
	2: [
		{
			"title": "MINER'S SATCHEL",
			"description": "Clear 3 crystals to recover the lost carrying harness.",
			"target": 3,
			"reward": "+1 free carry slot",
			"reward_id": "satchel",
		},
		{
			"title": "SHARPENED EDGE",
			"description": "Clear 4 crystals to recover the lost pickaxe.",
			"target": 4,
			"reward": "faster mining",
			"reward_id": "pickaxe",
		},
		{
			"title": "DEEP POCKETS",
			"description": "Clear 3 crystals from the deep vein.",
			"target": 3,
			"reward": "4 secured gems",
			"reward_id": "gems_4",
		},
	],
	3: [
		{
			"title": "ANCIENT FORGE",
			"description": "Crack 4 ancient crystals to reforge the pick.",
			"target": 4,
			"reward": "+1 Pick Power",
			"reward_id": "pick_power",
		},
		{
			"title": "BURIED HOARD",
			"description": "Crack 5 ancient crystals to open the hoard.",
			"target": 5,
			"reward": "5 secured gems",
			"reward_id": "gems_5",
		},
		{
			"title": "SUREFOOTED",
			"description": "Crack 4 ancient crystals to free the buried boots.",
			"target": 4,
			"reward": "prospector's boots",
			"reward_id": "boots",
		},
	],
	4: [
		{
			"title": "HEART CACHE",
			"description": "Strip 5 crystals before the final assault.",
			"target": 5,
			"reward": "3 boss-preparation gems",
			"reward_id": "gems_3",
		},
		{
			"title": "WAR PREPARATION",
			"description": "Strip 6 crystals before the final assault.",
			"target": 6,
			"reward": "5 boss-preparation gems",
			"reward_id": "gems_5",
		},
		{
			"title": "LAST FORGE",
			"description": "Strip 5 crystals to reforge the pick for the boss.",
			"target": 5,
			"reward": "+1 Pick Power",
			"reward_id": "pick_power",
		},
	],
}

# Run-wide modifiers. Each one is two-sided so the draw is a plan change rather
# than a difficulty roll: the harder ones pay Legacy Ore on the way out.
const RUN_MODIFIERS := [
	{
		"id": "steady",
		"title": "STEADY DIG",
		"description": "No omens. The mine is quiet.",
	},
	{
		"id": "rich_seam",
		"title": "RICH SEAM",
		"description": "The seams run rich, but the air is going bad — shorter dig windows, richer hauls.",
		"mining_scale": 0.88,
		"gem_bonus": 1,
	},
	{
		"id": "unstable_ceiling",
		"title": "UNSTABLE CEILING",
		"description": "The rock is groaning. Dig fast and the Bastion pays for the risk.",
		"mining_scale": 0.8,
		"ore_bonus": 2,
	},
	{
		"id": "horde_stirring",
		"title": "THE HORDE STIRS",
		"description": "Something has woken below — every assault comes a body heavier.",
		"enemy_bonus": 1,
		"ore_bonus": 2,
	},
	{
		"id": "long_fuse",
		"title": "LONG FUSE",
		"description": "The breach is slow to open, but the seams give up nothing easily.",
		"muster_scale": 1.35,
		"target_bonus": 1,
	},
]
# The war horn. The dig window used to be the only thing that decided when a
# stage ended, so greed had no mechanical expression: the clock returned the
# player, the player never chose to return. The horn is the choice — end the
# window early and the bastion pays for the time it did not have to hold. It is
# deliberately a separate action from interact, because banking gems must stay
# free: a player who walks home with one gem is not committing to anything.
const HORN_RADIUS := 128.0
const HORN_SECONDS_PER_GEM := 20.0
const HORN_SECONDS_PER_ORE := 30.0

const MOTHERLODE_PATTERN: Array[Vector2i] = [
	Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1),
]

enum Phase { MINING, ATTACK, RECOVERY }

var world: Node2D
var block_layer: TileMapLayer
var player: CharacterBody2D
var base: Node2D
var hud: Node
var upgrade_menu: Node
var phase := Phase.MINING
var mining_timer := 90.0
var stage_number := 1
var wave_spawning := false
var assault_muster_timer := 0.0
var assault_spawn_started := false
var warning_stage := -1
var recovery_player_reached_base := false
var recovery_arrival_announced := false
var recovery_upgrade_opened := false
var objective_progress := 0
var objective_completed := false
var objective_reward_claimed := false
var objective_missed_announced := false
var objective_dug_cells: Dictionary = {}
var boss_phase := 0
var pending_reinforcement_batches := 0
var ui_layer: CanvasLayer
var status_label: Label
var build_label: Label
var objective_label: Label
var hint_label: Label
var entrance_marker: Node2D
var secondary_entrance_marker: Node2D
var first_run_training_active := false
var first_expedition_run := false
var muster_arrival_announced := false
var horn_marker: Node2D
var horn_label: Label
var horn_sounded := false
var reward_caches: Array = []
var reward_caches_open := false
# Per-run variance: one objective drawn per stage plus a single run-wide modifier.
var run_objectives: Dictionary = {}
var run_modifier: Dictionary = {}
var run_seed: int = 0

func _ready() -> void:
	call_deferred("_activate")

func _activate() -> void:
	world = get_parent() as Node2D
	if world == null or not is_instance_valid(world):
		queue_free()
		return
	if world.get("is_vs_mode") == true or not GameMode.is_siege():
		queue_free()
		return

	block_layer = world.get_node_or_null("BlockLayer") as TileMapLayer
	player = world.get_node_or_null("Player") as CharacterBody2D
	base = world.get_node_or_null("Base") as Node2D
	hud = world.get_node_or_null("HUD")
	upgrade_menu = world.get_node_or_null("UpgradeMenu")
	if block_layer == null or player == null or base == null:
		push_error("MineWars Expedition requires BlockLayer, Player, and Base.")
		queue_free()
		return

	world.set_process(false)
	world.set_meta("siege_mode", true)
	world.set_meta("minewars_expedition", true)
	world.set_meta("minewars_final_stage", FINAL_STAGE)
	world.set_meta("wave_spawning", false)
	world.set_meta("minewars_force_return_cue", false)
	world.set_meta("minewars_return_seconds", -1)
	if world.has_method("ensure_minewars_motherlodes"):
		world.ensure_minewars_motherlodes()
	world.current_wave_number = stage_number
	first_expedition_run = Global.minewars_runs_completed == 0
	first_run_training_active = not Global.prototype_onboarding_completed
	world.set_meta("minewars_first_expedition", first_expedition_run)
	world.set_meta("minewars_training_active", first_run_training_active)
	_roll_run_variance()
	world.enemies_per_wave = _enemy_count_for(stage_number)
	mining_timer = _mining_window_for(stage_number)
	_set_phase_meta("mining")
	_ensure_surface_lanes()
	_create_ui()
	_create_horn_marker()
	_create_primary_entrance_marker()
	_initialize_stage_objective()
	_update_ui()
	_spawn_base_signal(Color(0.28, 0.88, 1.0, 0.9), 1, 58.0)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_mine_awaken"):
		sound_fx.play_mine_awaken()
	if hud and hud.has_method("show_notice"):
		if first_run_training_active:
			hud.show_notice("MINER'S TRIAL — the assault clock is paused. Complete the five guided steps first.", 5.2)
		else:
			hud.show_notice("EXPEDITION I — follow the marked %s, then return before the assault." % _objective_title(), 5.0)
	_queue_run_modifier_announcement()

## One draw per expedition: an objective for each stage and a single run-wide
## modifier. The first expedition and the guided trial always take the authored
## opening so onboarding never changes under a new player.
func _roll_run_variance() -> void:
	run_objectives.clear()
	var authored_only := first_expedition_run or first_run_training_active
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	run_seed = rng.seed
	for stage in STAGE_OBJECTIVE_POOLS.keys():
		var pool: Array = STAGE_OBJECTIVE_POOLS[stage]
		var index := 0 if authored_only or pool.is_empty() else rng.randi_range(0, pool.size() - 1)
		run_objectives[stage] = (pool[index] as Dictionary).duplicate(true)
	var modifier_index := 0 if authored_only else rng.randi_range(0, RUN_MODIFIERS.size() - 1)
	run_modifier = (RUN_MODIFIERS[modifier_index] as Dictionary).duplicate(true)
	# The modifier's ore payout is staged now so the result screen still pays it
	# out on a loss, when this controller is long gone.
	Global.stage_run_ore_bonus(_modifier_int("ore_bonus"))
	world.set_meta("minewars_run_modifier", str(run_modifier.get("id", "steady")))
	world.set_meta("minewars_run_seed", run_seed)

func _modifier_int(key: String, fallback: int = 0) -> int:
	return int(run_modifier.get(key, fallback))

func _modifier_float(key: String, fallback: float = 1.0) -> float:
	return float(run_modifier.get(key, fallback))

## The omen follows the expedition banner rather than fighting it for the same
## notice slot.
func _queue_run_modifier_announcement() -> void:
	if run_modifier.is_empty() or str(run_modifier.get("id", "steady")) == "steady":
		return
	if not is_inside_tree():
		return
	await get_tree().create_timer(5.2).timeout
	if not is_inside_tree():
		return
	_announce_run_modifier()

## Announced once the expedition UI exists, so the player reads the omen before
## the first dig window starts.
func _announce_run_modifier() -> void:
	if run_modifier.is_empty() or str(run_modifier.get("id", "steady")) == "steady":
		return
	if hud == null or not hud.has_method("show_notice"):
		return
	hud.show_notice("%s — %s" % [str(run_modifier.get("title", "")), str(run_modifier.get("description", ""))], 5.6)

func _enemy_count_for(stage: int) -> int:
	return maxi(1, int(STAGE_ENEMY_COUNTS.get(stage, 3)) + _modifier_int("enemy_bonus"))

## The muster window is what really limits how deep a player dares go, so both
## the run modifier and the permanent Safe Return rank widen it.
func _muster_time_for(stage: int) -> float:
	var window := float(STAGE_MUSTER_TIMES.get(stage, 8.0))
	return maxf(3.0, window * _modifier_float("muster_scale") * Global.get_permanent_muster_scale())

func _spawn_base_signal(signal_color: Color, pulse_count: int = 2, radius: float = 72.0) -> void:
	if base == null or not is_instance_valid(base):
		return
	var signal_node := Node2D.new()
	signal_node.name = "BastionSignal"
	signal_node.global_position = base.global_position
	signal_node.z_index = 24
	world.add_child(signal_node)
	var glow := Polygon2D.new()
	var glow_points := PackedVector2Array()
	for index in range(33):
		glow_points.append(Vector2.RIGHT.rotated(TAU * float(index) / 32.0) * radius * 0.74)
	glow.polygon = glow_points
	glow.color = Color(signal_color.r, signal_color.g, signal_color.b, 0.1)
	signal_node.add_child(glow)
	for pulse_index in range(maxi(pulse_count, 1)):
		var ring := Line2D.new()
		ring.width = 5.0
		ring.default_color = signal_color
		var points := PackedVector2Array()
		for index in range(33):
			points.append(Vector2.RIGHT.rotated(TAU * float(index) / 32.0) * radius)
		ring.points = points
		ring.scale = Vector2(0.42, 0.42)
		signal_node.add_child(ring)
		var pulse := create_tween()
		pulse.tween_interval(float(pulse_index) * 0.13)
		pulse.set_parallel(true)
		pulse.tween_property(ring, "scale", Vector2(1.08, 1.08), 0.66).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pulse.tween_property(ring, "modulate:a", 0.0, 0.7)
	var fade := create_tween()
	fade.tween_interval(0.65 + float(maxi(pulse_count - 1, 0)) * 0.13)
	fade.tween_property(glow, "modulate:a", 0.0, 0.28)
	fade.tween_callback(signal_node.queue_free)

func _pulse_entrance_marker(signal_color: Color, pulse_count: int = 2) -> void:
	if entrance_marker == null or not is_instance_valid(entrance_marker):
		return
	entrance_marker.modulate = signal_color
	var pulse := create_tween().set_loops(maxi(pulse_count, 1))
	pulse.tween_property(entrance_marker, "scale", Vector2(1.24, 1.24), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(entrance_marker, "scale", Vector2.ONE, 0.24)
	pulse.finished.connect(func():
		if is_instance_valid(entrance_marker):
			entrance_marker.modulate = Color.WHITE
	)

func _sync_return_guidance() -> void:
	var force_return := false
	var seconds := -1
	if phase == Phase.MINING and warning_stage >= 2:
		force_return = true
		seconds = ceili(mining_timer)
	elif phase == Phase.ATTACK:
		force_return = player.global_position.distance_to(base.global_position) > RECOVERY_BASE_DISTANCE * 1.45
		seconds = ceili(assault_muster_timer) if assault_muster_timer > 0.0 else -1
	world.set_meta("minewars_force_return_cue", force_return)
	world.set_meta("minewars_return_seconds", seconds)

func _check_muster_arrival() -> void:
	if muster_arrival_announced or assault_muster_timer <= 0.0:
		return
	if player.global_position.distance_to(base.global_position) > RECOVERY_BASE_DISTANCE * 1.65:
		return
	muster_arrival_announced = true
	world.set_meta("minewars_force_return_cue", false)
	_spawn_base_signal(Color(0.32, 1.0, 0.58, 0.94), 2, 78.0)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_objective_tick"):
		sound_fx.play_objective_tick(2)

func _play_assault_warning_feedback() -> void:
	_spawn_base_signal(Color(1.0, 0.28, 0.12, 0.94), 3, 86.0)
	_pulse_entrance_marker(Color(1.0, 0.42, 0.18, 1.0), 4)
	_spawn_breach_dust(0.7)
	_shake_camera(5.0)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_warning_horn"):
		sound_fx.play_warning_horn()

func _spawn_breach_dust(strength: float = 1.0) -> void:
	if entrance_marker == null or not is_instance_valid(entrance_marker):
		return
	var dust := CPUParticles2D.new()
	dust.name = "BreachDust"
	dust.one_shot = true
	dust.amount = maxi(12, int(32.0 * strength))
	dust.lifetime = 0.65
	dust.explosiveness = 0.92
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 18.0
	dust.gravity = Vector2(0, 105)
	dust.initial_velocity_min = 55.0
	dust.initial_velocity_max = 145.0
	dust.scale_amount_min = 1.6
	dust.scale_amount_max = 5.0
	dust.color = Color(0.78, 0.48, 0.27, 0.88)
	dust.global_position = entrance_marker.global_position
	dust.z_index = 22
	world.add_child(dust)
	dust.emitting = true
	get_tree().create_timer(0.9).timeout.connect(dust.queue_free)

func _shake_camera(amount: float) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var rest := camera.offset
	var shake := create_tween()
	shake.tween_property(camera, "offset", rest + Vector2(amount, -amount * 0.55), 0.045)
	shake.tween_property(camera, "offset", rest + Vector2(-amount * 0.85, amount * 0.45), 0.045)
	shake.tween_property(camera, "offset", rest + Vector2(amount * 0.45, amount * 0.3), 0.045)
	shake.tween_property(camera, "offset", rest, 0.08)

func _play_breach_open_feedback() -> void:
	_spawn_breach_dust(1.35)
	_pulse_entrance_marker(Color(1.0, 0.22, 0.08, 1.0), 5)
	_shake_camera(8.0)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_breach"):
		sound_fx.play_breach()

func _finish_first_run_training() -> void:
	first_run_training_active = false
	world.set_meta("minewars_training_active", false)
	mining_timer = _mining_window_for(stage_number)
	warning_stage = 0
	_initialize_stage_objective()
	_spawn_base_signal(Color(1.0, 0.78, 0.24, 0.92), 2, 68.0)
	if hud and hud.has_method("show_notice"):
		hud.show_notice("EXPEDITION CLOCK STARTED — 90 seconds. Follow the cyan Rich Vein marker, then return to defend.", 5.4)

func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world) or not GameMode.is_siege():
		return
	if world.get("preparation_active") == true:
		return

	match phase:
		Phase.MINING:
			_process_mining(delta)
		Phase.ATTACK:
			_process_attack()
		Phase.RECOVERY:
			_process_recovery()

	_update_wave_hud()
	_update_ui()

func _process_mining(delta: float) -> void:
	if first_run_training_active:
		mining_timer = _mining_window_for(stage_number)
		warning_stage = 0
		world.set_meta("minewars_force_return_cue", false)
		world.set_meta("minewars_return_seconds", -1)
		if Global.prototype_onboarding_completed and world.get("onboarding_active") != true:
			_finish_first_run_training()
		return
	mining_timer = maxf(mining_timer - delta, 0.0)
	_update_stage_objective()
	_update_warning_stage()
	_sync_return_guidance()
	_update_horn_prompt()
	if mining_timer <= 0.0 and not wave_spawning:
		_start_assault()

## The horn stands at the bastion and only answers during the dig window. Its
## label carries the live bounty so the trade is priced before it is taken.
func _create_horn_marker() -> void:
	if base == null or not is_instance_valid(base):
		return
	horn_marker = Node2D.new()
	horn_marker.name = "WarHornPrompt"
	horn_marker.z_index = 9
	horn_marker.visible = false
	world.add_child(horn_marker)
	horn_label = Label.new()
	horn_label.position = Vector2(-150, -108)
	horn_label.size = Vector2(300, 22)
	horn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	horn_label.add_theme_font_size_override("font_size", 13)
	horn_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.26, 1.0))
	horn_label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01, 0.96))
	horn_label.add_theme_constant_override("outline_size", 5)
	horn_marker.add_child(horn_label)

func _update_horn_prompt() -> void:
	if horn_marker == null or not is_instance_valid(horn_marker):
		return
	if base == null or not is_instance_valid(base) or player == null or not is_instance_valid(player):
		horn_marker.visible = false
		return
	horn_marker.global_position = base.global_position
	var in_range := player.global_position.distance_to(base.global_position) <= HORN_RADIUS
	horn_marker.visible = in_range and _horn_available()
	if horn_marker.visible:
		var gems := _horn_gem_bounty()
		var ore := _horn_ore_bounty()
		horn_label.text = "G / SELECT  •  SOUND THE HORN   +%d ◇   +%d ORE" % [gems, ore]

func _horn_available() -> bool:
	return phase == Phase.MINING and not wave_spawning and not horn_sounded and not first_run_training_active

func _horn_gem_bounty() -> int:
	return int(floor(mining_timer / HORN_SECONDS_PER_GEM))

func _horn_ore_bounty() -> int:
	return int(floor(mining_timer / HORN_SECONDS_PER_ORE))

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("p1_horn") or not _horn_available():
		return
	if base == null or player == null or not is_instance_valid(base) or not is_instance_valid(player):
		return
	if player.global_position.distance_to(base.global_position) > HORN_RADIUS:
		return
	_sound_the_horn()

func _sound_the_horn() -> void:
	horn_sounded = true
	var gems := _horn_gem_bounty()
	var ore := _horn_ore_bounty()
	if gems > 0 and hud and hud.has_method("add_gems"):
		hud.add_gems(gems)
	if ore > 0:
		# stage_run_ore_bonus assigns rather than accumulates, so the modifier's
		# own staged bonus has to be carried forward here.
		Global.stage_run_ore_bonus(int(Global.pending_run_ore_bonus) + ore)
	if horn_marker and is_instance_valid(horn_marker):
		horn_marker.visible = false
	mining_timer = 0.0
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_upgrade"):
		sound_fx.play_upgrade()
	_spawn_base_signal(Color(1.0, 0.72, 0.26, 0.95), 3, 96.0)
	_shake_camera(5.0)
	if hud and hud.has_method("show_notice"):
		hud.show_notice("THE HORN SOUNDS — you called them early. +%d gems, +%d Legacy Ore." % [gems, ore], 3.6)
	_start_assault()

func _process_attack() -> void:
	_sync_return_guidance()
	_check_muster_arrival()
	if assault_muster_timer > 0.0:
		assault_muster_timer = maxf(assault_muster_timer - get_process_delta_time(), 0.0)
		if assault_muster_timer <= 0.0 and not assault_spawn_started:
			assault_spawn_started = true
			_spawn_assault()
		return
	if not assault_spawn_started:
		assault_spawn_started = true
		_spawn_assault()
		return
	if not wave_spawning and pending_reinforcement_batches == 0 and _count_world_enemies() == 0:
		_complete_assault()

func _process_recovery() -> void:
	var carry_load := int(player.get_carry_load()) if player.has_method("get_carry_load") else 0
	if not recovery_player_reached_base:
		if player.global_position.distance_to(base.global_position) <= RECOVERY_BASE_DISTANCE:
			recovery_player_reached_base = true
			if not recovery_arrival_announced and hud and hud.has_method("show_notice"):
				recovery_arrival_announced = true
				hud.show_notice("Stronghold secured. Spend the haul, then descend when the build is ready.", 4.0)
		return

	if not recovery_upgrade_opened and carry_load == 0 and _banked_gems() > 0:
		recovery_upgrade_opened = true
		call_deferred("_open_recovery_upgrade_menu")

	var depth := _player_depth()
	var distance_from_base := player.global_position.distance_to(base.global_position)
	if depth >= NEXT_EXPEDITION_DEPTH and distance_from_base >= NEXT_EXPEDITION_DISTANCE:
		_begin_next_expedition()

func _open_recovery_upgrade_menu() -> void:
	await get_tree().create_timer(0.35).timeout
	if phase != Phase.RECOVERY or upgrade_menu == null or not is_instance_valid(upgrade_menu):
		return
	if upgrade_menu.has_method("show_menu"):
		upgrade_menu.show_menu()

func _ensure_surface_lanes() -> void:
	var previous_generation_flag: bool = world.world_generation_in_progress
	world.world_generation_in_progress = true
	# Ensure the right tunnel is open from hub edge to spawn point.
	for x in range(5, FIXED_ENTRANCE_CELL.x + 1):
		for y in range(FIXED_ENTRANCE_CELL.y - 1, FIXED_ENTRANCE_CELL.y + 2):
			var cell := Vector2i(x, y)
			if block_layer.get_cell_source_id(cell) != -1:
				world.on_cell_dug(cell)
	world.world_generation_in_progress = previous_generation_flag
	world.topology_revision += 1

func _start_assault() -> void:
	phase = Phase.ATTACK
	if horn_marker and is_instance_valid(horn_marker):
		horn_marker.visible = false
	wave_spawning = true
	assault_muster_timer = _muster_time_for(stage_number)
	assault_spawn_started = false
	muster_arrival_announced = false
	world.set_meta("wave_spawning", true)
	world.set_meta("minewars_force_return_cue", true)
	world.set_meta("minewars_return_seconds", ceili(assault_muster_timer))
	world.set_meta("active_wave_number", stage_number)
	world.current_wave_number = stage_number
	warning_stage = -1
	_set_phase_meta("attack")
	if not objective_completed and not objective_missed_announced:
		objective_missed_announced = true
		var sound_fx := get_node_or_null("/root/SoundFX")
		if sound_fx and sound_fx.has_method("play_error"):
			sound_fx.play_error()
	_play_assault_warning_feedback()
	if hud and hud.has_method("notify_wave_started"):
		hud.notify_wave_started(stage_number == FINAL_STAGE, stage_number)

func _spawn_assault() -> void:
	_play_breach_open_feedback()
	var is_boss := stage_number == FINAL_STAGE
	var entrance_position := _cell_world_position(FIXED_ENTRANCE_CELL)
	if world.has_method("_spawn_wave_telegraph"):
		world._spawn_wave_telegraph(entrance_position, is_boss)
	await get_tree().create_timer(0.8).timeout
	var roster: Array = [4] if is_boss else STAGE_ENEMY_ROSTERS.get(stage_number, [0, 0, 0])
	for index in range(roster.size()):
		if world == null or not is_instance_valid(world):
			return
		var enemy := _spawn_enemy(int(roster[index]), entrance_position + Vector2(0, float((index % 3) - 1) * 9.0), is_boss)
		if is_boss and enemy != null:
			_attach_boss_behavior(enemy)
		await get_tree().create_timer(SPAWN_GAP).timeout
	wave_spawning = false
	world.set_meta("wave_spawning", false)

func _spawn_enemy(enemy_type: int, spawn_position: Vector2, is_boss: bool = false) -> Node:
	var enemy := ENEMY_SCENE.instantiate()
	world.add_child(enemy)
	enemy.global_position = spawn_position
	if enemy.has_method("initialize"):
		var power_level := int(STAGE_ENEMY_POWER_LEVELS.get(stage_number, stage_number))
		enemy.initialize(power_level, is_boss, enemy_type)
		if is_boss:
			enemy.set("health", MINEWARS_BOSS_HEALTH)
			enemy.set("max_health", MINEWARS_BOSS_HEALTH)
			enemy.set("damage", MINEWARS_BOSS_DAMAGE)
			enemy.set("speed", MINEWARS_BOSS_SPEED)
			enemy.set_meta("minewars_boss", true)
			if enemy.has_method("_set_health_bar_values"):
				enemy.call("_set_health_bar_values", true)
	if enemy.has_method("begin_breach_emergence"):
		enemy.begin_breach_emergence(1.0 if is_boss else 0.6)
	return enemy

func _attach_boss_behavior(enemy: Node) -> void:
	var behavior := BOSS_BEHAVIOR.new()
	behavior.name = "MineWarsBossBehavior"
	enemy.add_child(behavior)
	behavior.configure(enemy, self)

func _on_boss_phase_shift(new_phase: int, boss: Node) -> void:
	if boss == null or not is_instance_valid(boss) or new_phase <= boss_phase:
		return
	boss_phase = new_phase
	if new_phase == 1:
		boss.set("speed", 58.0)
		if hud and hud.has_method("show_notice"):
			hud.show_notice("MECH PHASE II — armor shattered. The pilot releases its spider guard!", 4.2)
		_spawn_boss_reinforcements([1, 1], FIXED_ENTRANCE_CELL)
	else:
		boss.set("speed", 70.0)
		boss.set("damage", 14)
		_create_secondary_entrance_marker()
		if hud and hud.has_method("show_notice"):
			hud.show_notice("MECH OVERDRIVE — a second breach tears open in the east!", 4.5)
		_spawn_boss_reinforcements([2, 2, 3], SECONDARY_ENTRANCE_CELL)

func _spawn_boss_reinforcements(roster: Array, entrance_cell: Vector2i) -> void:
	pending_reinforcement_batches += 1
	var entrance_position := _cell_world_position(entrance_cell)
	if world.has_method("_spawn_wave_telegraph"):
		world._spawn_wave_telegraph(entrance_position, false)
	await get_tree().create_timer(0.85).timeout
	for index in range(roster.size()):
		if world == null or not is_instance_valid(world):
			pending_reinforcement_batches = maxi(0, pending_reinforcement_batches - 1)
			return
		_spawn_enemy(int(roster[index]), entrance_position + Vector2(0, float(index - 1) * 10.0), false)
		await get_tree().create_timer(0.28).timeout
	pending_reinforcement_batches = maxi(0, pending_reinforcement_batches - 1)

func _complete_assault() -> void:
	world.set_meta("minewars_force_return_cue", false)
	world.set_meta("minewars_return_seconds", -1)
	assault_muster_timer = 0.0
	assault_spawn_started = false
	_award_stage_clear_reward(stage_number)
	_spawn_base_signal(Color(0.34, 1.0, 0.58, 0.92), 2, 82.0)
	if stage_number >= FINAL_STAGE:
		_set_phase_meta("complete")
		world.current_wave_number = FINAL_STAGE + 1
		return

	stage_number += 1
	world.current_wave_number = stage_number
	world.enemies_per_wave = _enemy_count_for(stage_number)
	phase = Phase.RECOVERY
	warning_stage = -1
	recovery_player_reached_base = false
	recovery_arrival_announced = false
	recovery_upgrade_opened = false
	_reset_stage_objective_state()
	_set_phase_meta("recovery")

func _award_stage_clear_reward(cleared_stage: int) -> void:
	if hud == null or not hud.has_method("add_gems"):
		return
	var reward := int(STAGE_CLEAR_GEM_REWARDS.get(cleared_stage, 0))
	if reward <= 0:
		return
	hud.add_gems(reward)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_deposit"):
		sound_fx.play_deposit(reward)

func _begin_next_expedition() -> void:
	world.set_meta("minewars_force_return_cue", false)
	world.set_meta("minewars_return_seconds", -1)
	phase = Phase.MINING
	mining_timer = _mining_window_for(stage_number)
	warning_stage = -1
	recovery_player_reached_base = false
	recovery_arrival_announced = false
	recovery_upgrade_opened = false
	horn_sounded = false
	_initialize_stage_objective()
	_set_phase_meta("mining")
	_spawn_base_signal(Color(0.28, 0.88, 1.0, 0.82), 1, 58.0)
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_mine_awaken"):
		sound_fx.play_mine_awaken()

func _reset_stage_objective_state() -> void:
	# Caches the player never opened bury themselves when the next stage begins.
	_collapse_reward_caches()
	objective_progress = 0
	objective_completed = false
	objective_reward_claimed = false
	objective_missed_announced = false
	objective_dug_cells.clear()
	world.set_meta("minewars_objective_complete", false)
	world.set_meta("minewars_objective_progress", 0)
	world.set_meta("minewars_objective_title", _objective_title())

func _initialize_stage_objective() -> void:
	_reset_stage_objective_state()
	_update_stage_objective()

func notify_objective_gem_dug(cell: Vector2i) -> void:
	if phase != Phase.MINING or objective_completed or objective_dug_cells.has(cell):
		return
	if not _is_current_motherlode_cell(cell):
		return
	objective_dug_cells[cell] = true
	objective_progress = mini(objective_progress + 1, int(STAGE_MOTHERLODE_COUNTS.get(stage_number, objective_progress + 1)))
	world.set_meta("minewars_objective_progress", objective_progress)
	world.set_meta("minewars_objective_target", _objective_target())
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_objective_tick"):
		sound_fx.play_objective_tick(objective_progress)
	if objective_progress >= _objective_target():
		_complete_stage_objective()

func _is_current_motherlode_cell(cell: Vector2i) -> bool:
	var motherlodes_value: Variant = world.get("minewars_motherlodes")
	if not motherlodes_value is Dictionary:
		return false
	var motherlodes: Dictionary = motherlodes_value
	if not motherlodes.has(stage_number):
		return false
	var center: Vector2i = motherlodes[stage_number]
	var total := int(STAGE_MOTHERLODE_COUNTS.get(stage_number, 0))
	for index in range(total):
		if cell == center + MOTHERLODE_PATTERN[index % MOTHERLODE_PATTERN.size()]:
			return true
	return false

func _update_stage_objective() -> void:
	if objective_completed:
		return
	var total := int(STAGE_MOTHERLODE_COUNTS.get(stage_number, 0))
	var remaining := _motherlode_remaining(stage_number)
	objective_progress = maxi(objective_progress, clampi(total - remaining, 0, total))
	world.set_meta("minewars_objective_progress", objective_progress)
	world.set_meta("minewars_objective_target", _objective_target())
	if objective_progress >= _objective_target():
		_complete_stage_objective()

func _complete_stage_objective() -> void:
	if objective_completed:
		return
	objective_completed = true
	world.set_meta("minewars_objective_complete", true)
	_open_reward_caches()
	_play_objective_completion_feedback()
	var sound_fx := get_node_or_null("/root/SoundFX")
	if sound_fx and sound_fx.has_method("play_upgrade"):
		sound_fx.play_upgrade()

## The stage reward is no longer handed over: three sealed caches open in the
## seam, each showing what it holds, and taking one collapses the rest. The
## decision is made by walking, inside the dig clock, which keeps the reward in
## the mine instead of moving it onto a menu.
func _open_reward_caches() -> void:
	if objective_reward_claimed or reward_caches_open:
		return
	var choices := _reward_cache_choices()
	var cells := _reward_cache_cells(choices.size())
	if choices.size() < 2 or cells.size() < 2:
		# Nowhere sensible to place them — pay the authored reward directly rather
		# than dropping a stage reward on the floor.
		_award_objective_reward()
		return
	# The authored reward is index 0, so a short placement list never drops it.
	choices.resize(mini(choices.size(), cells.size()))
	reward_caches_open = true
	for index in range(choices.size()):
		var choice: Dictionary = choices[index]
		var cache := Area2D.new()
		cache.name = "SealedCache%d" % index
		cache.set_script(SEALED_CACHE_SCRIPT)
		world.add_child(cache)
		cache.global_position = _cell_world_position(cells[index])
		cache.configure(str(choice.get("reward_id", "")), str(choice.get("title", "CACHE")), choice.get("colour", Color(1.0, 0.78, 0.32, 1.0)))
		cache.claimed.connect(_on_reward_cache_claimed)
		reward_caches.append(cache)
	if hud and hud.has_method("show_notice"):
		hud.show_notice("THE SEAM OPENS — three caches, one choice. Taking one buries the others.", 4.0)

func _on_reward_cache_claimed(reward_id: String) -> void:
	_collapse_reward_caches()
	_award_objective_reward(reward_id)

func _collapse_reward_caches() -> void:
	for cache_value in reward_caches:
		var cache := cache_value as Node
		if cache == null or not is_instance_valid(cache):
			continue
		if cache.has_method("collapse"):
			cache.collapse()
	reward_caches.clear()
	reward_caches_open = false

## The stage's authored reward is always one of the three, so a drawn objective
## still pays what it advertised. The other two are drawn from rewards the hero
## can still use, which keeps a gear cache from offering gear already worn.
func _reward_cache_choices() -> Array:
	var authored := str(_objective_data().get("reward_id", ""))
	var choices: Array = [_reward_cache_entry(authored)]
	var pool := ["satchel", "boots", "pickaxe", "pick_power", "gems_3", "gems_5"]
	var taken := [authored]
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + stage_number * 7717
	pool.shuffle()
	for candidate in pool:
		if choices.size() >= 3:
			break
		if taken.has(candidate) or not _reward_still_useful(candidate):
			continue
		taken.append(candidate)
		choices.append(_reward_cache_entry(candidate))
	return choices

func _reward_still_useful(reward_id: String) -> bool:
	match reward_id:
		"satchel":
			return not _hero_owns_gear("miners_satchel")
		"boots":
			return not _hero_owns_gear("boots")
		"pickaxe":
			return not _hero_owns_gear("pickaxe")
		"pick_power":
			return int(player.get("mining_power_level")) < 3
	return true

func _hero_owns_gear(gear_id: String) -> bool:
	var owned: Variant = player.get("cave_reward_ids")
	return owned is Array and (owned as Array).has(gear_id)

func _reward_cache_entry(reward_id: String) -> Dictionary:
	if reward_id.begins_with("gems_"):
		return {"reward_id": reward_id, "title": "%s GEMS" % reward_id.trim_prefix("gems_"), "colour": Color(0.45, 0.85, 1.0, 1.0)}
	match reward_id:
		"satchel":
			return {"reward_id": reward_id, "title": "MINER'S SATCHEL", "colour": Color(0.62, 0.86, 0.45, 1.0)}
		"boots":
			return {"reward_id": reward_id, "title": "PROSPECTOR'S BOOTS", "colour": Color(0.62, 0.86, 0.45, 1.0)}
		"pickaxe":
			return {"reward_id": reward_id, "title": "SHARPENED PICK", "colour": Color(1.0, 0.72, 0.30, 1.0)}
		"pick_power":
			return {"reward_id": reward_id, "title": "+1 PICK POWER", "colour": Color(1.0, 0.72, 0.30, 1.0)}
	return {"reward_id": reward_id, "title": "SEALED CACHE", "colour": Color(1.0, 0.78, 0.32, 1.0)}

## Caches are spread around the seam the player just cleared, far enough apart
## that reaching a second one costs real time. A cell qualifies if it is already
## open or if it is rock touching open ground: the mine is mostly solid, so
## requiring open cells alone would leave nowhere to put them, and a cache one
## dig away still reads as buried treasure rather than a floor pickup.
func _reward_cache_cells(wanted: int) -> Array[Vector2i]:
	var placed: Array[Vector2i] = []
	var motherlodes_value: Variant = world.get("minewars_motherlodes")
	if not motherlodes_value is Dictionary or not (motherlodes_value as Dictionary).has(stage_number):
		return placed
	var center: Vector2i = (motherlodes_value as Dictionary)[stage_number]
	for radius in [3, 5, 7, 9, 11]:
		var offsets: Array[Vector2i] = []
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				offsets.append(Vector2i(dx, dy))
		offsets.shuffle()
		for offset in offsets:
			if placed.size() >= wanted:
				return placed
			var cell: Vector2i = center + offset
			if not _is_cache_placeable(cell):
				continue
			var too_close := false
			for existing in placed:
				if absi(existing.x - cell.x) + absi(existing.y - cell.y) < 5:
					too_close = true
					break
			if not too_close:
				placed.append(cell)
	return placed

func _is_cache_placeable(cell: Vector2i) -> bool:
	if block_layer.get_cell_source_id(cell) == -1:
		return true
	for neighbour in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if block_layer.get_cell_source_id(cell + neighbour) == -1:
			return true
	return false

func _award_objective_reward(override_reward_id: String = "") -> void:
	if objective_reward_claimed:
		return
	objective_reward_claimed = true
	var reward_id := override_reward_id if override_reward_id != "" else str(_objective_data().get("reward_id", ""))
	# "gems_N" pays N gems; a gear reward that the hero already owns falls back to
	# gems so a drawn objective is never worth nothing.
	if reward_id.begins_with("gems_"):
		_award_objective_gems(int(reward_id.trim_prefix("gems_")))
		return
	match reward_id:
		"satchel":
			_award_objective_gear("miners_satchel", 2)
		"pickaxe":
			_award_objective_gear("pickaxe", 2)
		"boots":
			_award_objective_gear("boots", 2)
		"pick_power":
			var before := int(player.get("mining_power_level"))
			if player.has_method("upgrade_mining_power"):
				player.upgrade_mining_power()
			if int(player.get("mining_power_level")) == before:
				_award_objective_gems(2)

## Objective gem payouts carry the run modifier's bonus, so a RICH SEAM run
## really does haul more out of the same seam.
func _award_objective_gems(amount: int) -> void:
	var total := maxi(0, amount) + _modifier_int("gem_bonus")
	if total > 0 and hud and hud.has_method("add_gems"):
		hud.add_gems(total)

func _award_objective_gear(reward_id: String, gem_fallback: int) -> void:
	var applied := false
	if player.has_method("apply_cave_reward"):
		applied = player.apply_cave_reward(reward_id)
	if not applied:
		_award_objective_gems(gem_fallback)

func _motherlode_remaining(stage: int) -> int:
	var total := int(STAGE_MOTHERLODE_COUNTS.get(stage, 0))
	var motherlodes_value: Variant = world.get("minewars_motherlodes")
	var block_layer := world.get_node_or_null("BlockLayer") as TileMapLayer
	if not motherlodes_value is Dictionary or block_layer == null:
		return total
	var motherlodes: Dictionary = motherlodes_value
	if not motherlodes.has(stage):
		return total
	var center: Vector2i = motherlodes[stage]
	var remaining := 0
	for index in range(total):
		var cell := center + MOTHERLODE_PATTERN[index % MOTHERLODE_PATTERN.size()]
		if block_layer.get_cell_source_id(cell) == 21:
			remaining += 1
	return remaining

func _objective_data() -> Dictionary:
	return run_objectives.get(stage_number, {})

func _objective_title() -> String:
	return str(_objective_data().get("title", "EXPEDITION TARGET"))

func _objective_description() -> String:
	return str(_objective_data().get("description", "Search the marked depth."))

func _objective_reward_text() -> String:
	return str(_objective_data().get("reward", "bonus secured"))

func _objective_target() -> int:
	var target := int(_objective_data().get("target", 1)) + _modifier_int("target_bonus")
	# A modifier must never ask for more crystals than the seam contains.
	return clampi(target, 1, int(STAGE_MOTHERLODE_COUNTS.get(stage_number, target)))

func _set_phase_meta(phase_name: String) -> void:
	world.set_meta("minewars_phase", phase_name)
	world.set_meta("minewars_stage_number", stage_number)
	world.set_meta("minewars_stage_name", _stage_name(stage_number))
	world.set_meta("minewars_final_stage", FINAL_STAGE)
	world.set_meta("minewars_objective_title", _objective_title())
	world.set_meta("minewars_objective_target", _objective_target())

func _update_warning_stage() -> void:
	var maximum := _mining_window_for(stage_number)
	var new_stage := 0
	if mining_timer <= maxf(9.0, maximum * 0.12):
		new_stage = 3
	elif mining_timer <= maximum * 0.30:
		new_stage = 2
	elif mining_timer <= maximum * 0.55:
		new_stage = 1
	if new_stage == warning_stage:
		return
	warning_stage = new_stage
	if warning_stage <= 0:
		return
	var sound_fx := get_node_or_null("/root/SoundFX")
	match warning_stage:
		1:
			if sound_fx and sound_fx.has_method("play_warning_drum"):
				sound_fx.play_warning_drum(1)
			_pulse_entrance_marker(Color(1.0, 0.68, 0.28, 0.82), 1)
		2:
			if sound_fx and sound_fx.has_method("play_warning_drum"):
				sound_fx.play_warning_drum(2)
			_spawn_base_signal(Color(1.0, 0.62, 0.2, 0.88), 1, 68.0)
			_pulse_entrance_marker(Color(1.0, 0.5, 0.18, 0.92), 2)
		3:
			if sound_fx and sound_fx.has_method("play_warning_horn"):
				sound_fx.play_warning_horn()
			_spawn_base_signal(Color(1.0, 0.25, 0.1, 0.94), 3, 82.0)
			_pulse_entrance_marker(Color(1.0, 0.24, 0.08, 1.0), 3)
			_spawn_breach_dust(0.45)
			_shake_camera(3.5)

func _update_wave_hud() -> void:
	if hud == null or not hud.has_method("update_wave_info"):
		return
	var maximum := _mining_window_for(stage_number)
	var is_boss := stage_number == FINAL_STAGE
	match phase:
		Phase.ATTACK:
			if assault_muster_timer > 0.0:
				hud.update_wave_info(stage_number, assault_muster_timer, _muster_time_for(stage_number), is_boss)
			else:
				hud.update_wave_info(stage_number, -1.0, maximum, is_boss)
		Phase.MINING:
			hud.update_wave_info(stage_number, mining_timer, maximum, is_boss)
		Phase.RECOVERY:
			hud.update_wave_info(maxi(stage_number - 1, 1), maximum, maximum, false)

func _create_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 25
	add_child(ui_layer)
	var panel := PanelContainer.new()
	# The expedition controller still owns these labels for state updates and
	# short-lived completion feedback, but the persistent card no longer belongs
	# in the gameplay HUD. It sat directly below the hero portrait and obscured
	# the health module on narrow/mobile screens.
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(16, 96)
	panel.custom_minimum_size = Vector2(304, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.032, 0.045, 0.78)
	style.border_color = Color(0.22, 0.54, 0.68, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	ui_layer.add_child(panel)
	# Objectives still drive world markers and completion feedback, but the large
	# permanent MineWars text card is intentionally removed from the play HUD.
	panel.visible = false
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)
	var title := Label.new()
	title.text = "MINEWARS"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3, 0.9))
	stack.add_child(title)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	stack.add_child(status_label)
	objective_label = Label.new()
	objective_label.add_theme_font_size_override("font_size", 12)
	objective_label.add_theme_color_override("font_color", Color(0.42, 0.94, 1.0, 1.0))
	stack.add_child(objective_label)
	build_label = Label.new()
	build_label.add_theme_font_size_override("font_size", 11)
	stack.add_child(build_label)
	hint_label = Label.new()
	hint_label.visible = false
	stack.add_child(hint_label)

func _update_ui() -> void:
	if status_label == null or not is_instance_valid(status_label):
		return
	var carry_load := int(player.get_carry_load()) if player.has_method("get_carry_load") else 0
	var depth := _player_depth()
	_update_build_label()
	_update_objective_label()

	if first_run_training_active:
		hint_label.visible = true
		status_label.text = "MINER'S TRIAL  •  CLOCK PAUSED\nLearn the core loop without pressure"
		objective_label.text = "TRAINING  •  Complete the five guided HUD steps"
		match int(world.get("onboarding_stage")):
			0: hint_label.text = "Dig straight down through the center shaft."
			1: hint_label.text = "Break the glowing cyan crystal seam."
			2: hint_label.text = "Stand beside the crystal and press SPACE / A."
			3: hint_label.text = "Carry it back into the bastion deposit zone."
			_: hint_label.text = "Open the forge with E / Y and buy one stat upgrade."
		return
	hint_label.visible = false

	if phase == Phase.ATTACK:
		if assault_muster_timer > 0.0:
			status_label.text = "ASSAULT  •  BREACHING
D %d   ◇ %d" % [depth, carry_load]
		else:
			status_label.text = "ASSAULT  •  ENEMIES %d
D %d   ◇ %d" % [_count_world_enemies(), depth, carry_load]
		return

	if phase == Phase.RECOVERY:
		status_label.text = "STRONGHOLD  •  SAFE
◇ %d" % _banked_gems()
		return

	status_label.text = "%s  •  %s
D %d   ◇ %d" % [_stage_name(stage_number), _danger_text(), depth, carry_load]

func _update_objective_label() -> void:
	if objective_label == null:
		return
	if phase == Phase.RECOVERY:
		objective_label.text = "NEXT  •  %s" % _objective_title()
		return
	var state := "✓" if objective_completed else "%d/%d" % [mini(objective_progress, _objective_target()), _objective_target()]
	objective_label.text = "%s   %s   +%s" % [_objective_title(), state, _objective_reward_text()]

func _update_build_label() -> void:
	if build_label == null or player == null:
		return
	var rpg := player.get_node_or_null("HeroRPGController")
	if rpg == null or not rpg.has_method("get_build_identity"):
		build_label.text = "STR %d   AGI %d   INT %d" % [int(player.get("strength")), int(player.get("agility")), int(player.get("intelligence"))]
		return
	var identity: Dictionary = rpg.call("get_build_identity")
	build_label.text = str(identity.get("title", "UNSHAPED"))
	build_label.add_theme_color_override("font_color", identity.get("color", Color.WHITE))

func _play_objective_completion_feedback() -> void:
	if ui_layer == null or not is_instance_valid(ui_layer):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.position = Vector2.ZERO
	flash.size = viewport_size
	flash.color = Color(0.25, 0.9, 1.0, 0.0)
	ui_layer.add_child(flash)
	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "color:a", 0.16, 0.07)
	flash_tween.tween_property(flash, "color:a", 0.0, 0.24)
	flash_tween.finished.connect(flash.queue_free)

	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(360, 54)
	badge.position = Vector2((viewport_size.x - 360.0) * 0.5, viewport_size.y * 0.22)
	badge.pivot_offset = Vector2(180, 27)
	badge.scale = Vector2(0.78, 0.78)
	badge.modulate = Color(1, 1, 1, 0)
	ui_layer.add_child(badge)
	var label := Label.new()
	label.text = "%s   ✓   %s" % [_objective_title(), _objective_reward_text()]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.45, 0.96, 1.0))
	badge.add_child(label)
	var badge_tween := create_tween().set_parallel(true)
	badge_tween.tween_property(badge, "modulate", Color.WHITE, 0.12)
	badge_tween.tween_property(badge, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	badge_tween.chain().tween_interval(0.9)
	badge_tween.chain().tween_property(badge, "modulate:a", 0.0, 0.2)
	badge_tween.finished.connect(badge.queue_free)
	_shake_camera(3.0)

func _danger_text() -> String:
	match warning_stage:
		0: return "CALM"
		1: return "DISTANT MOVEMENT"
		2: return "APPROACHING"
		_: return "IMMINENT"

func _stage_name(value: int) -> String:
	return str(STAGE_NAMES.get(value, "UNKNOWN DEPTH"))

func _mining_window_for(value: int) -> float:
	return maxf(20.0, float(STAGE_MINING_WINDOWS.get(value, 60.0)) * _modifier_float("mining_scale"))

func _player_depth() -> int:
	return maxi(block_layer.local_to_map(block_layer.to_local(player.global_position)).y, 0)

func _banked_gems() -> int:
	if hud == null:
		return 0
	var value: Variant = hud.get("total_gems")
	return int(value) if value != null else 0

func _create_primary_entrance_marker() -> void:
	entrance_marker = _create_entrance_marker(FIXED_ENTRANCE_CELL, "", Color(1.0, 0.28, 0.12, 0.9))

func _create_secondary_entrance_marker() -> void:
	if secondary_entrance_marker != null and is_instance_valid(secondary_entrance_marker):
		return
	secondary_entrance_marker = _create_entrance_marker(SECONDARY_ENTRANCE_CELL, "OVERDRIVE BREACH", Color(0.55, 0.3, 1.0, 0.95))
	var pulse := create_tween().set_loops(4)
	pulse.tween_property(secondary_entrance_marker, "scale", Vector2(1.25, 1.25), 0.18)
	pulse.tween_property(secondary_entrance_marker, "scale", Vector2.ONE, 0.22)

func _create_entrance_marker(cell: Vector2i, caption: String, color: Color) -> Node2D:
	var marker := Node2D.new()
	marker.global_position = _cell_world_position(cell)
	marker.z_index = 7
	world.add_child(marker)
	var glow := Polygon2D.new()
	var glow_points := PackedVector2Array()
	for index in range(25):
		glow_points.append(Vector2.RIGHT.rotated(TAU * float(index) / 24.0) * 30.0)
	glow.polygon = glow_points
	glow.color = Color(color.r, color.g, color.b, 0.08)
	marker.add_child(glow)
	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = color
	var points := PackedVector2Array()
	for index in range(25):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / 24.0) * 28.0)
	ring.points = points
	marker.add_child(ring)
	if not caption.is_empty():
		var label := Label.new()
		label.text = caption
		label.position = Vector2(-70, -50)
		label.size = Vector2(140, 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", color.lightened(0.28))
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.96))
		label.add_theme_constant_override("outline_size", 3)
		marker.add_child(label)
	return marker

func _count_world_enemies() -> int:
	var count := 0
	for enemy_value in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_value as Node
		if enemy != null and is_instance_valid(enemy) and world.is_ancestor_of(enemy):
			count += 1
	return count

func _cell_world_position(cell: Vector2i) -> Vector2:
	return block_layer.to_global(block_layer.map_to_local(cell))
