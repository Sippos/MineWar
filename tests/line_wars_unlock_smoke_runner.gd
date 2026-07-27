extends Node

# The upper LineWars shaft is long-term single-player progression: it stays
# sealed until the player has finished Global.LINE_WARS_UNLOCK_RUNS expeditions,
# then it is carved, signed, and walkable the next time they return to the hub.

const SINGLE_PLAYER_SCENE := preload("res://scenes/world/preparation/preparation_hub.tscn")
const LINE_WARS_SCRIPT := preload("res://scripts/systems/continuous_line_wars_controller.gd")
const SMOKE_SAVE_PATH := "user://line_wars_unlock_smoke_save.json"
const UNMINEABLE_SOURCE_ID := 16

var failures := 0

func _ready() -> void:
	Global.set_save_path_override(SMOKE_SAVE_PATH)
	await _run_smoke_test()
	if failures == 0:
		print("LINE_WARS_UNLOCK_SMOKE_PASS")
		get_tree().quit(0)
	else:
		push_error("LINE_WARS_UNLOCK_SMOKE_FAIL: %d checks failed" % failures)
		get_tree().quit(1)

func _run_smoke_test() -> void:
	_check_unlock_reward_fires_on_the_threshold_run()
	await _check_shaft_is_sealed_before_the_threshold()
	await _check_shaft_opens_and_starts_line_wars()

func _check_unlock_reward_fires_on_the_threshold_run() -> void:
	_expect(Global.LINE_WARS_UNLOCK_RUNS >= 1, "The shaft must cost at least one expedition")

	Global.minewars_runs_completed = Global.LINE_WARS_UNLOCK_RUNS - 1
	Global.pending_unlock_rewards.clear()
	_expect(not Global.is_line_wars_unlocked(), "One run short of the threshold must leave LineWars locked")

	Global.record_minewars_result(false)
	_expect(Global.is_line_wars_unlocked(), "Finishing the threshold run should unlock LineWars")
	_expect(_has_tunnel_reward(Global.pending_unlock_rewards), "The threshold run should queue the shaft-opening ceremony")

	Global.pending_unlock_rewards.clear()
	Global.record_minewars_result(false)
	_expect(not _has_tunnel_reward(Global.pending_unlock_rewards), "Later runs should not re-announce the shaft")

func _check_shaft_is_sealed_before_the_threshold() -> void:
	Global.minewars_runs_completed = Global.LINE_WARS_UNLOCK_RUNS - 1
	Global.pending_unlock_rewards.clear()
	var hub := SINGLE_PLAYER_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(6)

	var world := hub.get_node("Level") as Node2D
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var controller := hub.get_node("SinglePlayerWorldController")
	var entrance: Vector2i = world.get_top_tunnel_entrance()

	_expect(not world.is_top_tunnel_unlocked(), "The upper shaft must stay locked before the threshold run")
	_expect(block_layer.get_cell_source_id(entrance) != -1, "The locked shaft must stay walled off")
	var signs := world.get_node_or_null("SinglePlayerModeSigns")
	var sign_label := signs.get_node_or_null("LineWars") as Label if signs != null else null
	_expect(sign_label != null and not sign_label.visible, "The LineWars sign must stay hidden while the shaft is sealed")

	# Even standing on the sealed cell must not start the mode.
	var hero := world.get_node("Player") as CharacterBody2D
	hero.global_position = block_layer.to_global(block_layer.map_to_local(entrance))
	await _wait_frames(6)
	_expect(world.get_node_or_null("ContinuousLineWarsController") == null, "A locked shaft must never start LineWars")
	_expect(is_instance_valid(controller), "The hub controller should stay in charge while the shaft is locked")

	hub.queue_free()
	await _wait_frames(2)

func _check_shaft_opens_and_starts_line_wars() -> void:
	Global.minewars_runs_completed = Global.LINE_WARS_UNLOCK_RUNS
	Global.pending_unlock_rewards.clear()
	var hub := SINGLE_PLAYER_SCENE.instantiate()
	add_child(hub)
	await _wait_frames(6)

	var world := hub.get_node("Level") as Node2D
	var block_layer := world.get_node("BlockLayer") as TileMapLayer
	var entrance: Vector2i = world.get_top_tunnel_entrance()

	_expect(world.is_top_tunnel_unlocked(), "Reaching the threshold should open the upper shaft")
	_expect(block_layer.get_cell_source_id(entrance) == -1, "The unlocked shaft should be carved through the hub wall")
	_expect(block_layer.get_cell_source_id(entrance + Vector2i(0, -1)) == -1, "The shaft should continue above the doorway")

	var signs := world.get_node_or_null("SinglePlayerModeSigns")
	var sign_label := signs.get_node_or_null("LineWars") as Label if signs != null else null
	var sign_glow := signs.get_node_or_null("TopDoorGlow") as Node2D if signs != null else null
	_expect(sign_label != null and sign_label.visible, "The opened shaft should be signed")
	_expect(sign_glow != null and sign_glow.visible, "The opened shaft should glow")
	var doorway := block_layer.to_global(block_layer.map_to_local(entrance))
	_expect(sign_glow != null and sign_glow.global_position.is_equal_approx(doorway), "The glow should sit on the actual doorway")

	var hero := world.get_node("Player") as CharacterBody2D
	hero.global_position = doorway
	await _wait_frames(8)
	var controller := world.get_node_or_null("ContinuousLineWarsController")
	_expect(controller != null, "Walking into the open shaft should start LineWars")
	if controller != null:
		await _check_the_shaft_opens_into_a_playable_maze(world, block_layer, controller)

	hub.queue_free()
	await _wait_frames(2)

## Starting the mode is not the same as the mode being playable. The hub world
## used to stop at y = -8 while the controller handed the peon a field spanning
## y = -33..-7, so 93% of that field was void: nothing to dig, and every enemy
## spawned on the shaft mouth because no tunnel endpoint could exist.
func _check_the_shaft_opens_into_a_playable_maze(world: Node2D, block_layer: TileMapLayer, controller: Node) -> void:
	var field_min: Vector2i = LINE_WARS_SCRIPT.SURFACE_MIN_CELL
	var field_max: Vector2i = LINE_WARS_SCRIPT.SURFACE_MAX_CELL
	var solid := 0
	var undiggable := 0
	for x in range(field_min.x, field_max.x + 1):
		for y in range(field_min.y, field_max.y + 1):
			var source_id := block_layer.get_cell_source_id(Vector2i(x, y))
			if source_id == -1:
				continue
			solid += 1
			if source_id == UNMINEABLE_SOURCE_ID:
				undiggable += 1
	var field_cells := (field_max.x - field_min.x + 1) * (field_max.y - field_min.y + 1)
	_expect(solid >= int(float(field_cells) * 0.9), "The peon's surface field must be rock to dig, not void (%d/%d solid)" % [solid, field_cells])
	_expect(undiggable == 0, "The surface field must contain no bedrock the peon cannot mine (%d cells)" % undiggable)

	var peon := world.get_node_or_null("BuilderPeon") as CharacterBody2D
	_expect(peon != null, "LineWars should spawn its builder peon")
	if peon != null:
		var peon_cell := block_layer.local_to_map(block_layer.to_local(peon.global_position))
		var inside_field: bool = (peon_cell.x >= field_min.x and peon_cell.x <= field_max.x
			and peon_cell.y >= field_min.y and peon_cell.y <= field_max.y)
		_expect(inside_field, "The peon must spawn inside its own digging field, not above the world (%s)" % str(peon_cell))
		_expect(block_layer.get_cell_source_id(peon_cell + Vector2i(0, -1)) != -1, "The peon must have rock above it to open the maze into")

	# The enemy portal has to follow the maze the player digs. Before any digging
	# the endpoint is the shaft mouth itself; after an opening tunnel it must move.
	var spawn_before: Vector2i = controller.call("_find_farthest_tunnel_cell")
	for y in range(-8, -14, -1):
		world.call("on_cell_dug", Vector2i(0, y))
	for x in range(1, 6):
		world.call("on_cell_dug", Vector2i(x, -13))
	await _wait_frames(4)
	var spawn_after: Vector2i = controller.call("_find_farthest_tunnel_cell")
	_expect(spawn_after != spawn_before, "The enemy portal must follow the dug maze instead of pinning to the shaft mouth")
	_expect(block_layer.get_cell_source_id(spawn_after) == -1, "The enemy portal must sit in an open tunnel cell")
	var base_cell := Vector2i(0, -1)
	_expect(Vector2(spawn_after - base_cell).length() > 8.0, "A dug maze must put real distance between the portal and the base")

func _has_tunnel_reward(rewards: Array) -> bool:
	for reward_value in rewards:
		var reward: Dictionary = reward_value
		if str(reward.get("tunnel", "")) == "line_wars":
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("LINE_WARS_UNLOCK_SMOKE: %s" % message)

func _wait_frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame
