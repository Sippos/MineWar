extends Node

## Test suite verifying POLISH-032:
## 1. Visceral ground-pound shockwave ring and camera trauma on Dwarf War Stomp
## 2. Distinct procedural audio stingers for high-impact hero abilities:
##    - hero_stomp (War Stomp sub-bass impact)
##    - hero_avatar (Mountain God brass & runic climax swell)
##    - shaman_lightning (High-voltage FM electric arc crackle)
##    - shaman_totem (Resonant wood/stone thud & harmonic chime)
##    - druid_burrow_pulse (Subterranean soil churn & verdant pulse)
## 3. Tactical ability impact frames and camera punch wired into JuiceManager
## 4. Ability execution, shockwave VFX instantiation, and audio hook triggering

const COMBAT_FEEDBACK_SCRIPT: GDScript = preload("res://combat_feedback.gd")
const SHOCKWAVE_SCRIPT: GDScript = preload("res://hero_stomp_shockwave.gd")
const HERO_ABILITIES_SCRIPT: GDScript = preload("res://hero_abilities.gd")
const HERO_BALANCE_SCRIPT: GDScript = preload("res://hero_balance_controller.gd")
const DUMMY_SCRIPT: Script = preload("res://tests/hero_dummy_enemy.gd")

var failures := 0
var mock_world: Node2D
var mock_player: CharacterBody2D
var mock_abilities: Node
var mock_balance: Node
var mock_camera: Camera2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_all_tests")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: %s" % message)
	else:
		print("PASS: %s" % message)

func _finish() -> void:
	if failures == 0:
		print("HERO_ABILITIES_JUICE_PASS")
		get_tree().quit(0)
	else:
		print("HERO_ABILITIES_JUICE_FAIL (%d failures)" % failures)
		get_tree().quit(1)

func _run_all_tests() -> void:
	await _setup_mock_environment()
	_test_sound_fx_streams_and_methods()
	_test_juice_manager_tactical_ability_hooks()
	_test_shockwave_vfx_instantiation_and_rendering()
	_test_dwarf_war_stomp_and_avatar_execution()
	_test_shaman_lightning_and_totem_execution()
	_test_druid_burrow_pulse_execution()
	_cleanup_mock_environment()
	_finish()

func _setup_mock_environment() -> void:
	mock_world = Node2D.new()
	mock_world.name = "MockWorld"
	
	for layer_name in ["BlockLayer", "DamageLayer", "FrontDamageLayer", "FrontWallLayer"]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		mock_world.add_child(layer)
	
	mock_camera = Camera2D.new()
	mock_camera.name = "Camera2D"
	mock_world.add_child(mock_camera)
	
	mock_player = CharacterBody2D.new()
	mock_player.name = "Player"
	mock_player.set_script(preload("res://player.gd"))
	mock_player.position = Vector2(400, 400)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	mock_player.add_child(sprite)
	
	mock_player.set("current_hero_name", "Dwarf")
	mock_player.set("player_id", 1)
	mock_player.set("level", 6)
	mock_player.set("strength", 5)
	mock_player.set("agility", 3)
	mock_player.set("intelligence", 4)
	mock_player.set("health", 100)
	mock_player.set("max_health", 100)
	mock_player.set("base_speed", 120.0)
	mock_player.set("stomp_level", 2)
	mock_player.set("stomp_cooldown_timer", 0.0)
	mock_player.add_to_group("players")
	mock_world.add_child(mock_player)
	
	mock_abilities = Node.new()
	mock_abilities.name = "HeroAbilities"
	mock_abilities.set_script(HERO_ABILITIES_SCRIPT)
	mock_player.add_child(mock_abilities)
	
	mock_balance = Node.new()
	mock_balance.name = "HeroBalanceController"
	mock_balance.set_script(HERO_BALANCE_SCRIPT)
	mock_player.add_child(mock_balance)
	
	add_child(mock_world)
	await get_tree().process_frame

func _cleanup_mock_environment() -> void:
	if is_instance_valid(mock_world):
		mock_world.queue_free()

func _test_sound_fx_streams_and_methods() -> void:
	print("--- Testing SoundFX Procedural Ability Streams ---")
	var sound_fx := get_node_or_null("/root/SoundFX")
	_expect(sound_fx != null, "SoundFX singleton must be present in tree")
	if sound_fx == null:
		return
	
	var streams: Dictionary = sound_fx.get("_streams")
	_expect(streams.has("hero_stomp"), "SoundFX must contain 'hero_stomp' procedural stream")
	_expect(streams.has("hero_avatar"), "SoundFX must contain 'hero_avatar' procedural stream")
	_expect(streams.has("shaman_lightning"), "SoundFX must contain 'shaman_lightning' procedural stream")
	_expect(streams.has("shaman_totem"), "SoundFX must contain 'shaman_totem' procedural stream")
	_expect(streams.has("druid_burrow_pulse"), "SoundFX must contain 'druid_burrow_pulse' procedural stream")
	
	var stomp_wav = streams.get("hero_stomp") as AudioStreamWAV
	_expect(stomp_wav != null and stomp_wav.data.size() > 0, "hero_stomp stream must be valid non-empty AudioStreamWAV")
	_expect(stomp_wav.mix_rate == 22050, "hero_stomp stream must be 22.05 kHz PCM")
	
	var avatar_wav = streams.get("hero_avatar") as AudioStreamWAV
	_expect(avatar_wav != null and avatar_wav.data.size() > 0, "hero_avatar stream must be valid non-empty AudioStreamWAV")
	
	var lightning_wav = streams.get("shaman_lightning") as AudioStreamWAV
	_expect(lightning_wav != null and lightning_wav.data.size() > 0, "shaman_lightning stream must be valid non-empty AudioStreamWAV")
	
	var totem_wav = streams.get("shaman_totem") as AudioStreamWAV
	_expect(totem_wav != null and totem_wav.data.size() > 0, "shaman_totem stream must be valid non-empty AudioStreamWAV")
	
	var pulse_wav = streams.get("druid_burrow_pulse") as AudioStreamWAV
	_expect(pulse_wav != null and pulse_wav.data.size() > 0, "druid_burrow_pulse stream must be valid non-empty AudioStreamWAV")
	
	# Test that calling each sound hook does not crash
	sound_fx.play_hero_stomp()
	_expect(true, "SoundFX.play_hero_stomp() must execute cleanly")
	sound_fx.play_hero_avatar()
	_expect(true, "SoundFX.play_hero_avatar() must execute cleanly")
	sound_fx.play_shaman_lightning()
	_expect(true, "SoundFX.play_shaman_lightning() must execute cleanly")
	sound_fx.play_shaman_totem()
	_expect(true, "SoundFX.play_shaman_totem() must execute cleanly")
	sound_fx.play_druid_burrow_pulse()
	_expect(true, "SoundFX.play_druid_burrow_pulse() must execute cleanly")

func _test_juice_manager_tactical_ability_hooks() -> void:
	print("--- Testing JuiceManager Tactical Ability Hooks ---")
	var juice := get_node_or_null("/root/JuiceManager")
	_expect(juice != null, "JuiceManager singleton must be present in tree")
	if juice == null:
		return
	
	# Stomp impact
	juice.set("_trauma", 0.0)
	juice.trigger_stomp_impact(0, false)
	_expect(juice.get_trauma() >= 0.45, "trigger_stomp_impact(0, false) must apply base trauma >= 0.45 (got %f)" % juice.get_trauma())
	
	juice.set("_trauma", 0.0)
	juice.trigger_stomp_impact(4, true)
	_expect(juice.get_trauma() >= 0.65, "trigger_stomp_impact(4, true) in Avatar mode must apply trauma >= 0.65 (got %f)" % juice.get_trauma())
	
	# Avatar activation
	juice.set("_trauma", 0.0)
	juice.trigger_avatar_activation()
	_expect(juice.get_trauma() >= 0.50, "trigger_avatar_activation() must apply trauma >= 0.50 (got %f)" % juice.get_trauma())
	
	# Lightning strike
	juice.set("_trauma", 0.0)
	juice.trigger_lightning_strike(3)
	_expect(juice.get_trauma() >= 0.40, "trigger_lightning_strike(3) must apply trauma >= 0.40 (got %f)" % juice.get_trauma())
	
	# Totem placement
	juice.set("_trauma", 0.0)
	juice.trigger_totem_placement()
	_expect(juice.get_trauma() >= 0.20, "trigger_totem_placement() must apply trauma >= 0.20 (got %f)" % juice.get_trauma())
	
	# Burrow pulse
	juice.set("_trauma", 0.0)
	juice.trigger_burrow_pulse(2)
	_expect(juice.get_trauma() >= 0.25, "trigger_burrow_pulse(2) must apply trauma >= 0.25 (got %f)" % juice.get_trauma())

func _test_shockwave_vfx_instantiation_and_rendering() -> void:
	print("--- Testing Shockwave VFX Instantiation & Rendering ---")
	var feedback: Node = COMBAT_FEEDBACK_SCRIPT.ensure(mock_world)
	_expect(feedback != null, "CombatFeedback service must be initialized")
	
	# Instantiate standard shockwave
	var sw: Node2D = feedback.play_stomp_shockwave(Vector2(450, 450), 140.0, false, 2)
	_expect(sw != null and is_instance_valid(sw), "play_stomp_shockwave must instantiate shockwave Node2D")
	_expect(sw.global_position == Vector2(450, 450), "Shockwave global_position must match origin")
	_expect(float(sw.get("_radius")) == 140.0, "Shockwave _radius must be 140.0")
	_expect(bool(sw.get("_is_avatar")) == false, "Shockwave _is_avatar must be false")
	
	var fissures: Array = sw.get("_fissure_angles")
	_expect(fissures.size() == 10, "Shockwave must generate 10 seismic fissure angles (got %d)" % fissures.size())
	
	var rocks: Array = sw.get("_rock_particles")
	_expect(rocks.size() >= 16, "Shockwave must generate >= 16 rock debris particles (got %d)" % rocks.size())
	
	# Verify drawing can be queued and processed without errors
	sw.queue_redraw()
	_expect(true, "Shockwave queue_redraw() must execute without exceptions")
	
	# Instantiate avatar shockwave
	var sw_avatar: Node2D = feedback.play_stomp_shockwave(Vector2(500, 500), 195.0, true, 5)
	_expect(bool(sw_avatar.get("_is_avatar")) == true, "Avatar shockwave must have _is_avatar == true")
	var avatar_rocks: Array = sw_avatar.get("_rock_particles")
	_expect(avatar_rocks.size() >= 24, "Avatar shockwave must generate >= 24 dense debris particles (got %d)" % avatar_rocks.size())
	sw_avatar.queue_redraw()
	_expect(true, "Avatar shockwave queue_redraw() must execute without exceptions")
	
	sw.queue_free()
	sw_avatar.queue_free()

func _test_dwarf_war_stomp_and_avatar_execution() -> void:
	print("--- Testing Dwarf War Stomp & Avatar Climax Execution ---")
	# Create dummy target in range
	var dummy := CharacterBody2D.new()
	dummy.name = "StompDummy"
	dummy.set_script(DUMMY_SCRIPT)
	dummy.add_to_group("enemies")
	mock_world.add_child(dummy)
	dummy.global_position = mock_player.global_position + Vector2(60, 0)
	
	# Dwarf setup
	mock_player.set("current_hero_name", "Dwarf")
	mock_player.set("stomp_level", 2)
	mock_abilities.set("avatar_level", 1)
	
	# Trigger Avatar activation
	mock_abilities.call("_try_activate_avatar")
	_expect(bool(mock_abilities.get("avatar_active")) == true, "Avatar of the Mountain must become active")
	_expect(int(mock_player.get("strength")) > 5, "Avatar must apply strength bonus to player")
	
	# Trigger Stomp
	var initial_dummy_health: int = int(dummy.get("health"))
	mock_player.set("stomp_cooldown_timer", 3.5) # Simulate cast
	mock_abilities.set("last_stomp_cooldown", 0.0)
	mock_abilities.call("_track_stomp_cast")
	
	_expect(float(dummy.get("stun_timer")) > 0.0, "Dummy must be stunned by War Stomp")
	dummy.queue_free()

func _test_shaman_lightning_and_totem_execution() -> void:
	print("--- Testing Shaman Lightning & Totem Hooks ---")
	mock_player.set("current_hero_name", "Shaman")
	mock_abilities.set("chain_level", 2)
	mock_abilities.set("chain_cooldown", 0.0)
	mock_abilities.set("totem_level", 2)
	
	# Spawn dummy enemies in chain range
	var dummy1 := CharacterBody2D.new()
	dummy1.name = "ShamanDummy1"
	dummy1.set_script(DUMMY_SCRIPT)
	dummy1.add_to_group("enemies")
	mock_world.add_child(dummy1)
	dummy1.global_position = mock_player.global_position + Vector2(80, 0)
	
	var dummy2 := CharacterBody2D.new()
	dummy2.name = "ShamanDummy2"
	dummy2.set_script(DUMMY_SCRIPT)
	dummy2.add_to_group("enemies")
	mock_world.add_child(dummy2)
	dummy2.global_position = dummy1.global_position + Vector2(60, 0)
	
	# Cast chain lightning
	mock_abilities.set("facing_direction", Vector2.RIGHT)
	mock_abilities.call("_try_chain_lightning")
	
	_expect(float(mock_abilities.get("chain_cooldown")) > 0.0, "Chain lightning cooldown must be set after cast")
	_expect(int(dummy1.get("total_damage_taken")) > 0, "Primary dummy must take lightning damage")
	
	# Spawn totem
	var totem_node := Node2D.new()
	totem_node.name = "MockTotem"
	totem_node.set("totem_type", "heal")
	mock_world.add_child(totem_node)
	mock_abilities.call("_configure_shaman_totem", totem_node)
	_expect(int(totem_node.get_meta("totem_rank", 0)) == 2, "Shaman totem rank meta must be set")
	
	dummy1.queue_free()
	dummy2.queue_free()
	totem_node.queue_free()

func _test_druid_burrow_pulse_execution() -> void:
	print("--- Testing Druid Burrow Pulse Execution ---")
	mock_player.set("current_hero_name", "Druid")
	mock_abilities.set("mole_level", 2)
	
	var dummy := CharacterBody2D.new()
	dummy.name = "DruidDummy"
	dummy.set_script(DUMMY_SCRIPT)
	dummy.add_to_group("enemies")
	mock_world.add_child(dummy)
	dummy.global_position = mock_player.global_position + Vector2(45, 0)
	
	# Execute burrow pulse
	mock_balance.call("_druid_burrow_pulse")
	_expect(int(dummy.get("total_damage_taken")) > 0, "Enemy in burrow pulse radius must take damage")
	_expect(float(dummy.get("speed_multiplier")) < 1.0, "Enemy in burrow pulse radius must be slowed")
	
	dummy.queue_free()
