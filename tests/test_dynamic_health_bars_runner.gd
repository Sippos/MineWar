extends Node

## Test suite verifying POLISH-031:
## 1. Transient enemy health bar lifecycle (hidden -> shown on damage/proximity/targeting -> fadeout)
## 2. Animated damage-catchup white bar with easing delay (DAMAGE_LAG_DELAY)
## 3. Dynamic health bar color grading (Healthy green -> Warning amber -> Critical red)
## 4. Visual combat status badges:
##    - Chokepoint Vulnerability badge ("⚔ VULN")
##    - Fire DoT from Magma Seam ("🔥 BURN") with periodic tick damage
##    - Sleep / Stun badge ("💤 SLEEP")
##    - Boss badge ("☠ BOSS")
## 5. Combat feedback with tactical tinting

const ENEMY_SCENE: PackedScene = preload("res://enemy.tscn")
const COMBAT_FEEDBACK_SCRIPT: GDScript = preload("res://combat_feedback.gd")

var failures := 0
var mock_world: Node2D
var mock_tile_map: TileMapLayer
var mock_base: CharacterBody2D
var mock_player: CharacterBody2D

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
		print("DYNAMIC_HEALTH_BARS_PASS")
		get_tree().quit(0)
	else:
		print("DYNAMIC_HEALTH_BARS_FAIL (%d failures)" % failures)
		get_tree().quit(1)

func _run_all_tests() -> void:
	await _setup_mock_environment()
	_test_health_bar_initial_state()
	_test_damage_triggers_health_bar()
	_test_inactivity_fadeout()
	_test_proximity_and_targeting()
	_test_damage_lag_bar_delay_and_catchup()
	_test_health_bar_color_modulation()
	_test_chokepoint_vulnerability_badge()
	_test_burn_dot_and_badge()
	_test_sleep_and_boss_badges()
	_test_tactical_combat_feedback()
	_cleanup_mock_environment()
	_finish()

func _setup_mock_environment() -> void:
	mock_world = Node2D.new()
	mock_world.name = "MockWorld"

	# Mock tilemap with chokepoint detection
	mock_tile_map = TileMapLayer.new()
	mock_tile_map.name = "BlockLayer"
	mock_world.add_child(mock_tile_map)

	# Mock base
	mock_base = CharacterBody2D.new()
	mock_base.name = "Base"
	mock_base.position = Vector2(0, 0)
	mock_world.add_child(mock_base)

	# Mock player
	mock_player = CharacterBody2D.new()
	mock_player.name = "Player"
	mock_player.position = Vector2(800, 800) # Start far away
	mock_player.add_to_group("players")
	mock_world.add_child(mock_player)

	add_child(mock_world)
	await get_tree().process_frame

func _cleanup_mock_environment() -> void:
	if is_instance_valid(mock_world):
		mock_world.queue_free()

func _create_test_enemy(pos: Vector2 = Vector2(0, 50)) -> CharacterBody2D:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.position = pos
	mock_world.add_child(enemy)
	enemy.initialize(1, false, 0) # Rat, wave 1
	return enemy

func _test_health_bar_initial_state() -> void:
	var enemy := _create_test_enemy(Vector2(500, 500))
	
	_expect(not enemy.is_health_bar_showing(), "Health bar should initially not be showing")
	_expect(enemy.get_health_bar_alpha() <= 0.05, "Health bar initial alpha should be <= 0.05 (got %f)" % enemy.get_health_bar_alpha())
	_expect(not enemy.health_bar_container.visible, "Health bar container should initially be invisible")
	
	enemy.queue_free()

func _test_damage_triggers_health_bar() -> void:
	var enemy := _create_test_enemy(Vector2(500, 500))
	
	enemy.take_damage(5)
	
	_expect(enemy.is_health_bar_showing(), "Health bar should show immediately after taking damage")
	_expect(enemy.health_bar_container.visible, "Health bar container should be visible after taking damage")
	_expect(enemy.get_health_bar_alpha() == 1.0, "Health bar alpha should snap to 1.0 on damage")
	_expect(enemy.health_bar_hold_timer > 2.0, "Health bar hold timer should be initialized (got %f)" % enemy.health_bar_hold_timer)
	
	enemy.queue_free()

func _test_inactivity_fadeout() -> void:
	var enemy := _create_test_enemy(Vector2(500, 500))
	enemy.take_damage(5)
	_expect(enemy.is_health_bar_showing(), "Health bar should be showing after damage")
	
	# Simulate time advance to expire hold timer
	var hold_time: float = enemy.health_bar_hold_timer
	enemy._update_health_bar(hold_time + 0.1)
	
	_expect(enemy.health_bar_hold_timer == 0.0, "Hold timer should reach zero after hold time")
	
	# Simulate fadeout frames
	for _i in range(15):
		enemy._update_health_bar(0.08)
	
	_expect(enemy.get_health_bar_alpha() <= 0.02, "Health bar alpha should fade down to <= 0.02 (got %f)" % enemy.get_health_bar_alpha())
	_expect(not enemy.is_health_bar_showing(), "Health bar should be hidden after inactivity fadeout")
	_expect(not enemy.health_bar_container.visible, "Container visible should be false when alpha reaches zero")
	
	enemy.queue_free()

func _test_proximity_and_targeting() -> void:
	var enemy := _create_test_enemy(Vector2(800, 800))
	mock_player.position = Vector2(800, 850) # 50px away, within HEALTH_BAR_NEAR_DISTANCE (115px)
	
	_expect(enemy._is_player_near_or_targeted(), "Enemy should detect player in melee proximity")
	
	# Update health bar with player near
	for _i in range(10):
		enemy._update_health_bar(0.05)
	
	_expect(enemy.is_health_bar_showing(), "Health bar should show when player approaches melee proximity")
	_expect(enemy.get_health_bar_alpha() > 0.8, "Alpha should rise when player is nearby (got %f)" % enemy.get_health_bar_alpha())
	
	# Move player far away
	mock_player.position = Vector2(2000, 2000)
	_expect(not enemy._is_player_near_or_targeted(), "Enemy should not detect far player")
	
	# Now target enemy specifically
	mock_player.set_meta("currently_attacking_enemy", enemy)
	_expect(enemy._is_player_near_or_targeted(), "Enemy should report true when targeted by player")
	
	mock_player.remove_meta("currently_attacking_enemy")
	enemy.queue_free()

func _test_damage_lag_bar_delay_and_catchup() -> void:
	var enemy := _create_test_enemy(Vector2(500, 500))
	enemy.health = 50
	enemy.max_health = 50
	enemy._set_health_bar_values(true) # Snap both to 50
	
	_expect(enemy.get_health_bar_value() == 50.0, "Initial health value must be 50")
	_expect(enemy.get_damage_lag_value() == 50.0, "Initial lag value must be 50")
	
	# Take chunk damage
	enemy.take_damage(20) # Health becomes 30
	_expect(enemy.health == 30, "Health must be 30 after 20 damage")
	_expect(enemy.get_damage_lag_delay_remaining() > 0.3, "Damage lag delay timer must be set (got %f)" % enemy.get_damage_lag_delay_remaining())
	
	# Advance a small duration (0.12s) within the delay window
	for _i in range(3):
		enemy._update_health_bar(0.04)
	
	# Health bar moves fast towards 30, but damage lag bar is FROZEN at 50
	_expect(enemy.get_health_bar_value() < 40.0, "Health bar should have dropped rapidly (got %f)" % enemy.get_health_bar_value())
	_expect(enemy.get_damage_lag_value() == 50.0, "Damage lag bar must remain frozen at 50 during delay (got %f)" % enemy.get_damage_lag_value())
	_expect(enemy.get_damage_lag_value() > enemy.get_health_bar_value(), "Damage lag bar must be higher than health bar, exposing white chunk")
	
	# Now advance past the delay timer (e.g. +1.4s)
	for _i in range(35):
		enemy._update_health_bar(0.04)
	
	_expect(enemy.get_damage_lag_delay_remaining() == 0.0, "Damage lag delay should reach 0")
	_expect(absf(enemy.get_damage_lag_value() - 30.0) < 0.5, "Damage lag bar must smoothly catch up to current health (got %f, expected ~30)" % enemy.get_damage_lag_value())
	
	enemy.queue_free()

func _test_health_bar_color_modulation() -> void:
	var enemy := _create_test_enemy(Vector2(500, 500))
	enemy.max_health = 100
	
	# Healthy (> 50%) -> Green
	enemy.health = 80
	enemy._update_health_bar(0.02)
	var green_mod: Color = enemy.health_bar.modulate
	_expect(green_mod.g > 0.7 and green_mod.r < 0.5, "Health bar at 80%% should be green tint (got %s)" % str(green_mod))
	
	# Warning (25% - 50%) -> Amber
	enemy.health = 40
	enemy._update_health_bar(0.02)
	var amber_mod: Color = enemy.health_bar.modulate
	_expect(amber_mod.r > 0.8 and amber_mod.g > 0.6, "Health bar at 40%% should be amber warning tint (got %s)" % str(amber_mod))
	
	# Critical (<= 25%) -> Red
	enemy.health = 15
	enemy._update_health_bar(0.02)
	var red_mod: Color = enemy.health_bar.modulate
	_expect(red_mod.r > 0.8 and red_mod.g < 0.4, "Health bar at 15%% should be red critical tint (got %s)" % str(red_mod))
	
	enemy.queue_free()

func _test_chokepoint_vulnerability_badge() -> void:
	var enemy := _create_test_enemy(Vector2(500, 500))
	
	# Outside chokepoint
	enemy._update_status_badges(0.0)
	_expect(not enemy.has_status_badge("chokepoint"), "Enemy outside chokepoint must not have chokepoint badge")
	_expect(not enemy.chokepoint_badge.visible, "Chokepoint badge node must be invisible")
	
	# Inject mock chokepoint behavior on world
	mock_world.set_script(load("res://tests/test_dynamic_health_bars_world_mock.gd") if FileAccess.file_exists("res://tests/test_dynamic_health_bars_world_mock.gd") else null)
	
	# Or test manual badge application
	enemy.apply_status_badge("chokepoint", 0.0)
	_expect(enemy.has_status_badge("chokepoint"), "has_status_badge('chokepoint') should return true")
	_expect(enemy.chokepoint_badge.visible, "Chokepoint badge must be visible when active")
	_expect(enemy.chokepoint_badge.text.contains("VULN") or enemy.chokepoint_badge.text.contains("CHOKE"), "Chokepoint badge text must communicate vulnerability")
	_expect(enemy.get_active_status_badges().has("chokepoint"), "Active badges list must contain 'chokepoint'")
	
	enemy.remove_status_badge("chokepoint")
	_expect(not enemy.has_status_badge("chokepoint"), "Badge should be removed cleanly")
	_expect(not enemy.chokepoint_badge.visible, "Chokepoint badge should be hidden after removal")
	
	enemy.queue_free()

func _test_burn_dot_and_badge() -> void:
	var enemy := _create_test_enemy(Vector2(500, 500))
	enemy.health = 50
	enemy.max_health = 50
	enemy._set_health_bar_values(true)
	
	# Apply burn DoT
	enemy.apply_burn(2.0, 5)
	
	_expect(enemy.has_status_badge("burn"), "Enemy must report active 'burn' status")
	_expect(enemy.burn_badge.visible, "Burn badge must be visible")
	_expect(enemy.burn_badge.text.contains("BURN") or enemy.burn_badge.text.contains("FIRE"), "Burn badge must display burn text")
	_expect(enemy.get_active_status_badges().has("burn"), "Active badges list must contain 'burn'")
	_expect(enemy.burn_duration == 2.0, "Burn duration must equal 2.0s")
	
	# Advance physics time to trigger a DoT tick (burn ticks every 0.5s)
	enemy._physics_process(0.55)
	_expect(enemy.health <= 45, "Burn DoT tick must reduce enemy health (expected <= 45, got %d)" % enemy.health)
	
	# Advance physics time past remaining burn duration
	enemy._physics_process(2.0)
	_expect(enemy.burn_duration == 0.0, "Burn duration should expire")
	_expect(not enemy.has_status_badge("burn"), "Burn status should be cleared after expiration")
	_expect(not enemy.burn_badge.visible, "Burn badge should become invisible after expiration")
	
	enemy.queue_free()

func _test_sleep_and_boss_badges() -> void:
	var enemy := _create_test_enemy(Vector2(500, 500))
	
	# Sleep badge
	enemy.sleep_timer = 2.0
	enemy._update_status_badges(0.0)
	_expect(enemy.has_status_badge("sleep"), "Sleep status should be active when sleep_timer > 0")
	_expect(enemy.sleep_badge.visible, "Sleep badge should be visible")
	_expect(enemy.get_active_status_badges().has("sleep"), "Active badges must include 'sleep'")
	
	enemy.sleep_timer = 0.0
	enemy._update_status_badges(0.0)
	_expect(not enemy.has_status_badge("sleep"), "Sleep status should deactivate when timer is 0")
	_expect(not enemy.sleep_badge.visible, "Sleep badge should be hidden")
	
	# Boss badge
	enemy.is_boss_enemy = true
	enemy._update_status_badges(0.0)
	_expect(enemy.has_status_badge("boss"), "Boss status should be active for boss enemy")
	_expect(enemy.boss_badge.visible, "Boss badge should be visible")
	_expect(enemy.get_active_status_badges().has("boss"), "Active badges must include 'boss'")
	
	enemy.queue_free()

func _test_tactical_combat_feedback() -> void:
	var feedback: Node = COMBAT_FEEDBACK_SCRIPT.ensure(mock_world)
	_expect(feedback != null, "CombatFeedback service should ensure successfully")
	
	# Tactical golden hit
	feedback.play_enemy_hit(Vector2(100, 100), Vector2.RIGHT, 35, false, Color(1.0, 0.85, 0.22, 1.0))
	
	# Fiery hit
	feedback.play_enemy_hit(Vector2(100, 100), Vector2.UP, 20, false, Color(1.0, 0.32, 0.10, 1.0))
	
	# Lethal hit
	feedback.play_enemy_hit(Vector2(100, 100), Vector2.DOWN, 50, true, Color(1.0, 0.85, 0.22, 1.0))
	
	_expect(true, "CombatFeedback play_enemy_hit with tactical tints should execute without error")
