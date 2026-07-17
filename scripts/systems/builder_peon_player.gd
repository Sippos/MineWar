extends CharacterBody2D

@export var move_speed := 190.0
@export var movement_bounds := Rect2(-560.0, -520.0, 1120.0, 660.0)
@export var surface_dig_time := 0.42

@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D

var controlled := true
var awaiting_neutral_input := false
var animation_timer := 0.0
var animation_row := 0

var world_digging_enabled := false
var dig_world: Node2D
var dig_block_layer: TileMapLayer
var dig_damage_layer: TileMapLayer
var dig_front_damage_layer: TileMapLayer
var dig_front_layer: TileMapLayer
var dig_min_cell := Vector2i.ZERO
var dig_max_cell := Vector2i.ZERO
var current_dig_cell := Vector2i(99999, 99999)
var dig_timer := 0.0
var dig_feedback_timer := 0.0

func _ready() -> void:
	add_to_group("builder_peon")
	set_controlled(controlled)

func set_controlled(value: bool) -> void:
	controlled = value
	velocity = Vector2.ZERO
	awaiting_neutral_input = value
	if not value:
		_clear_dig_progress()
	if camera:
		camera.enabled = value
		if value:
			camera.reset_smoothing()

func configure_world_digging(world_node: Node2D, min_cell: Vector2i, max_cell: Vector2i) -> void:
	dig_world = world_node
	dig_block_layer = world_node.get_node_or_null("BlockLayer") as TileMapLayer
	dig_damage_layer = world_node.get_node_or_null("DamageLayer") as TileMapLayer
	dig_front_damage_layer = world_node.get_node_or_null("FrontDamageLayer") as TileMapLayer
	dig_front_layer = world_node.get_node_or_null("FrontWallLayer") as TileMapLayer
	dig_min_cell = min_cell
	dig_max_cell = max_cell
	world_digging_enabled = dig_block_layer != null
	# The old prototype peon ignored terrain because it walked on a drawn board.
	# The continuous-world peon must collide with and mine the real TileMap.
	collision_mask = 1

func _physics_process(delta: float) -> void:
	dig_feedback_timer = maxf(dig_feedback_timer - delta, 0.0)
	if not controlled:
		velocity = Vector2.ZERO
		_update_animation(delta)
		return

	var input_vector := Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
	if input_vector.length_squared() < 0.01:
		input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if awaiting_neutral_input:
		if input_vector.length_squared() >= 0.01:
			velocity = Vector2.ZERO
			_update_animation(delta)
			return
		awaiting_neutral_input = false

	var direction := input_vector.normalized()
	if world_digging_enabled and _process_surface_dig(direction, delta):
		velocity = Vector2.ZERO
		_update_direction_from_vector(direction)
		_update_animation(delta)
		return

	_clear_dig_progress()
	velocity = direction * move_speed
	move_and_slide()
	global_position.x = clampf(global_position.x, movement_bounds.position.x, movement_bounds.end.x)
	global_position.y = clampf(global_position.y, movement_bounds.position.y, movement_bounds.end.y)
	_update_direction_from_vector(direction)
	_update_animation(delta)

func _process_surface_dig(direction: Vector2, delta: float) -> bool:
	if direction.length_squared() < 0.01 or dig_block_layer == null:
		return false
	var cardinal := Vector2.ZERO
	if absf(direction.x) > absf(direction.y):
		cardinal.x = signf(direction.x)
	else:
		cardinal.y = signf(direction.y)
	var probe_position := global_position + cardinal * 38.0
	var cell := dig_block_layer.local_to_map(dig_block_layer.to_local(probe_position))
	if cell.x < dig_min_cell.x or cell.x > dig_max_cell.x or cell.y < dig_min_cell.y or cell.y > dig_max_cell.y:
		return false
	if dig_block_layer.get_cell_source_id(cell) == -1:
		return false

	if current_dig_cell != cell:
		_clear_dig_progress()
		current_dig_cell = cell
	dig_timer += delta

	var progress := clampf(dig_timer / surface_dig_time, 0.0, 1.0)
	if dig_damage_layer:
		dig_damage_layer.set_cell(cell, 7 if progress < 0.66 else 8, Vector2i.ZERO)
	if dig_front_layer and dig_front_damage_layer:
		var below_cell := cell + Vector2i.DOWN
		if dig_front_layer.get_cell_source_id(below_cell) != -1:
			dig_front_damage_layer.set_cell(below_cell, 13 if progress < 0.66 else 14, Vector2i.ZERO)

	if dig_feedback_timer <= 0.0 and dig_world and dig_world.has_method("spawn_mining_feedback"):
		dig_world.call("spawn_mining_feedback", dig_block_layer.to_global(dig_block_layer.map_to_local(cell)))
		dig_feedback_timer = 0.16

	if dig_timer >= surface_dig_time:
		if dig_world.has_method("has_gem"):
			dig_world.call("has_gem", cell)
		if dig_world.has_method("on_cell_dug"):
			dig_world.call("on_cell_dug", cell)
		if dig_front_damage_layer:
			dig_front_damage_layer.erase_cell(cell + Vector2i.DOWN)
		if dig_world.has_method("spawn_mining_feedback"):
			dig_world.call("spawn_mining_feedback", dig_block_layer.to_global(dig_block_layer.map_to_local(cell)), true, false)
		var sound_fx := get_node_or_null("/root/SoundFX")
		if sound_fx:
			sound_fx.play_block_break(false)
		_clear_dig_progress()
	return true

func _clear_dig_progress() -> void:
	if current_dig_cell.x != 99999:
		if dig_damage_layer:
			dig_damage_layer.erase_cell(current_dig_cell)
		if dig_front_damage_layer:
			dig_front_damage_layer.erase_cell(current_dig_cell + Vector2i.DOWN)
	current_dig_cell = Vector2i(99999, 99999)
	dig_timer = 0.0

func _update_direction_from_vector(direction: Vector2) -> void:
	if direction.length_squared() < 0.01:
		return
	var angle := direction.angle()
	var pi_8 := PI / 8.0
	if angle > -pi_8 and angle <= pi_8:
		animation_row = 6
	elif angle > pi_8 and angle <= 3.0 * pi_8:
		animation_row = 7
	elif angle > 3.0 * pi_8 and angle <= 5.0 * pi_8:
		animation_row = 0
	elif angle > 5.0 * pi_8 and angle <= 7.0 * pi_8:
		animation_row = 1
	elif angle > 7.0 * pi_8 or angle <= -7.0 * pi_8:
		animation_row = 2
	elif angle > -7.0 * pi_8 and angle <= -5.0 * pi_8:
		animation_row = 3
	elif angle > -5.0 * pi_8 and angle <= -3.0 * pi_8:
		animation_row = 4
	else:
		animation_row = 5

func _update_animation(delta: float) -> void:
	if sprite == null:
		return
	if velocity.length_squared() > 0.01 or current_dig_cell.x != 99999:
		animation_timer += delta * 12.0
		sprite.frame = animation_row * 8 + (int(animation_timer) % 8)
	else:
		animation_timer = 0.0
		sprite.frame = animation_row * 8
