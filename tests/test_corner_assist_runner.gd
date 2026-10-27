extends Node2D

## Test suite verifying Dome Keeper Corner Assist / Anti-Snag Raycasts in player.gd:
## 1. Feeler ray instantiation, positioning, and configuration
## 2. Horizontal feeler corner detection (top/bottom snag -> down/up nudge)
## 3. Vertical feeler corner detection (left/right snag -> right/left nudge)
## 4. Solid flat wall handling (both feelers hit -> zero nudge)
## 5. Open corridor handling (neither feeler hits -> zero nudge)
## 6. Mining protection (currently_digging_cell locks out nudging)
## 7. Real 2D physics corner clearance simulation

var failures := 0
var player: CharacterBody2D
const PLAYER_SCENE := preload("res://local_coop_player.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("--- Running Corner Assist Feeler Ray Tests ---")
	
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(500, 500)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_test_feeler_initialization()
	await _test_horizontal_corner_nudges()
	await _test_vertical_corner_nudges()
	await _test_flat_wall_and_open_air()
	_test_digging_and_input_protection()
	await _test_real_physics_corner_clearance()

	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: %s" % message)
	else:
		print("PASS: %s" % message)

func _finish() -> void:
	if failures == 0:
		print("CORNER_ASSIST_PASS")
		get_tree().quit(0)
	else:
		print("CORNER_ASSIST_FAIL (%d failures)" % failures)
		get_tree().quit(1)

func _test_feeler_initialization() -> void:
	var rays: Dictionary = player.call("get_feeler_rays")
	_expect(rays.size() == 8, "Must provide 8 feeler rays (4 cardinal pairs)")
	
	var all_valid := true
	for ray_name in rays:
		var ray: RayCast2D = rays[ray_name]
		if ray == null or not is_instance_valid(ray):
			all_valid = false
			break
		if ray.collision_mask != 1 or not ray.enabled or not ray.exclude_parent:
			all_valid = false
			break
	_expect(all_valid, "All 8 feeler rays must be valid, enabled, and scanning collision layer 1")
	
	# Verify geometric symmetry around player center (0, -24)
	var right_top: RayCast2D = rays["right_top"]
	var right_bot: RayCast2D = rays["right_bottom"]
	_expect(right_top.position.y < -24.0, "Right-top feeler must be above center (-24)")
	_expect(right_bot.position.y > -24.0, "Right-bottom feeler must be below center (-24)")
	_expect(is_equal_approx(right_top.position.x, right_bot.position.x), "Right feelers must share forward X position")

func _test_horizontal_corner_nudges() -> void:
	var rays: Dictionary = player.call("get_feeler_rays")
	var rt: RayCast2D = rays["right_top"]
	var rb: RayCast2D = rays["right_bottom"]
	
	# Create a dummy static body on Layer 1
	var obstacle := StaticBody2D.new()
	obstacle.collision_layer = 1
	var col := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(32, 32)
	col.shape = box
	obstacle.add_child(col)
	add_child(obstacle)
	
	# Position obstacle to collide ONLY with right-top feeler
	obstacle.global_position = rt.global_position + Vector2(10, 0)
	await get_tree().physics_frame
	rt.force_raycast_update()
	rb.force_raycast_update()
	
	_expect(rt.is_colliding() and not rb.is_colliding(), "Obstacle should collide only with right-top feeler")
	var nudge_down: Vector2 = player.call("get_corner_assist_nudge", Vector2.RIGHT, 200.0)
	_expect(nudge_down.y > 0.0 and is_equal_approx(nudge_down.x, 0.0), "Top snag moving right must nudge DOWN (+Y)")
	_expect(is_equal_approx(nudge_down.y, 150.0), "Nudge speed must be 75%% of move speed (150.0 px/s)")
	
	# Reposition obstacle to collide ONLY with right-bottom feeler
	obstacle.global_position = rb.global_position + Vector2(10, 0)
	await get_tree().physics_frame
	rt.force_raycast_update()
	rb.force_raycast_update()
	
	_expect(rb.is_colliding() and not rt.is_colliding(), "Obstacle should collide only with right-bottom feeler")
	var nudge_up: Vector2 = player.call("get_corner_assist_nudge", Vector2.RIGHT, 200.0)
	_expect(nudge_up.y < 0.0 and is_equal_approx(nudge_up.x, 0.0), "Bottom snag moving right must nudge UP (-Y)")
	_expect(is_equal_approx(nudge_up.y, -150.0), "Nudge speed must be -150.0 px/s")

	obstacle.queue_free()
	await get_tree().physics_frame

func _test_vertical_corner_nudges() -> void:
	var rays: Dictionary = player.call("get_feeler_rays")
	var dl: RayCast2D = rays["down_left"]
	var dr: RayCast2D = rays["down_right"]
	
	var obstacle := StaticBody2D.new()
	obstacle.collision_layer = 1
	var col := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(32, 32)
	col.shape = box
	obstacle.add_child(col)
	add_child(obstacle)
	
	# Position obstacle to collide ONLY with down-left feeler
	obstacle.global_position = dl.global_position + Vector2(0, 10)
	await get_tree().physics_frame
	dl.force_raycast_update()
	dr.force_raycast_update()
	
	_expect(dl.is_colliding() and not dr.is_colliding(), "Obstacle should collide only with down-left feeler")
	var nudge_right: Vector2 = player.call("get_corner_assist_nudge", Vector2.DOWN, 200.0)
	_expect(nudge_right.x > 0.0 and is_equal_approx(nudge_right.y, 0.0), "Left snag moving down must nudge RIGHT (+X)")
	_expect(is_equal_approx(nudge_right.x, 150.0), "Nudge speed must be +150.0 px/s")
	
	# Position obstacle to collide ONLY with down-right feeler
	obstacle.global_position = dr.global_position + Vector2(0, 10)
	await get_tree().physics_frame
	dl.force_raycast_update()
	dr.force_raycast_update()
	
	_expect(dr.is_colliding() and not dl.is_colliding(), "Obstacle should collide only with down-right feeler")
	var nudge_left: Vector2 = player.call("get_corner_assist_nudge", Vector2.DOWN, 200.0)
	_expect(nudge_left.x < 0.0 and is_equal_approx(nudge_left.y, 0.0), "Right snag moving down must nudge LEFT (-X)")
	_expect(is_equal_approx(nudge_left.x, -150.0), "Nudge speed must be -150.0 px/s")

	obstacle.queue_free()
	await get_tree().physics_frame

func _test_flat_wall_and_open_air() -> void:
	var rays: Dictionary = player.call("get_feeler_rays")
	var rt: RayCast2D = rays["right_top"]
	var rb: RayCast2D = rays["right_bottom"]
	
	# In open air (no obstacles):
	rt.force_raycast_update()
	rb.force_raycast_update()
	_expect(not rt.is_colliding() and not rb.is_colliding(), "Open air should have no collisions")
	var open_nudge: Vector2 = player.call("get_corner_assist_nudge", Vector2.RIGHT, 200.0)
	_expect(open_nudge == Vector2.ZERO, "Open air must produce Vector2.ZERO nudge")
	
	# Solid flat wall spanning both feelers:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var col := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(32, 80) # Tall wall covering both top and bottom feelers
	col.shape = box
	wall.add_child(col)
	add_child(wall)
	
	wall.global_position = player.global_position + Vector2(25, -24)
	await get_tree().physics_frame
	rt.force_raycast_update()
	rb.force_raycast_update()
	
	_expect(rt.is_colliding() and rb.is_colliding(), "Flat wall must collide with both feelers")
	var wall_nudge: Vector2 = player.call("get_corner_assist_nudge", Vector2.RIGHT, 200.0)
	_expect(wall_nudge == Vector2.ZERO, "Flat wall must produce Vector2.ZERO nudge (no false corner slides)")
	
	wall.queue_free()
	await get_tree().physics_frame

func _test_digging_and_input_protection() -> void:
	# If digging, corner assist should never nudge
	player.set("currently_digging_cell", Vector2i(10, 10))
	var nudge_while_digging: Vector2 = player.call("get_corner_assist_nudge", Vector2.RIGHT, 200.0)
	_expect(nudge_while_digging == Vector2.ZERO, "Mining in progress must disable corner assist nudges")
	player.set("currently_digging_cell", null)
	
	# If dead or immobile:
	player.set("is_dead", true)
	var dead_nudge: Vector2 = player.call("get_corner_assist_nudge", Vector2.RIGHT, 200.0)
	_expect(dead_nudge == Vector2.ZERO, "Dead player must produce ZERO nudge")
	player.set("is_dead", false)
	
	player.set("can_move", false)
	var immobile_nudge: Vector2 = player.call("get_corner_assist_nudge", Vector2.RIGHT, 200.0)
	_expect(immobile_nudge == Vector2.ZERO, "Immobile player must produce ZERO nudge")
	player.set("can_move", true)

func _test_real_physics_corner_clearance() -> void:
	# Build a 64x64 corner block at (600, 600).
	# Bounds: X in [568, 632], Y in [568, 632].
	var corner := StaticBody2D.new()
	corner.collision_layer = 1
	var col := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(64, 64)
	col.shape = box
	corner.add_child(col)
	add_child(corner)
	corner.global_position = Vector2(600, 600)

	# Place player at X=625.
	# Left feeler is at 625 - 17 = 608 (caught on corner block, < 632).
	# Right feeler is at 625 + 17 = 642 (in open air past right edge, > 632).
	# Player bottom edge is at global_position.y - 4. Place resting on top face of block (568).
	player.global_position = Vector2(625, 568 + 4)
	player.velocity = Vector2(0, 200)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var initial_x := player.global_position.x
	# Simulate 15 physics frames of moving down against the snag
	for i in range(15):
		player.call("_apply_corner_assist", Vector2.DOWN, 200.0, 1.0 / 60.0)
		player.move_and_slide()
		await get_tree().physics_frame

	var final_x := player.global_position.x
	# The player should have been nudged towards the open right lane (+X)
	_expect(final_x > initial_x, "Player must be nudged rightward around corner during physics movement (cleared by %.2f px)" % (final_x - initial_x))

	corner.queue_free()
	await get_tree().physics_frame
