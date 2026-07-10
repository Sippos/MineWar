extends RigidBody2D

const GEM_VISUAL_OFFSET = Vector2(0, -8)
const FOLLOW_DISTANCE = 32.0
const SLOT_BACK_SPACING = 5.0
const SLOT_SIDE_OFFSET = 6.0
const FOLLOW_RESPONSE = 6.0
const MAX_FOLLOW_SPEED = 320.0
const SNAP_DISTANCE = 220.0
const LOOSE_Z_INDEX = 0
const CARRIED_Z_INDEX = 1
const LOOSE_Y_SORT_ORIGIN = -12
const CARRIED_Y_SORT_ORIGIN = 0

var tethered_to = null
var _follow_direction := Vector2.DOWN
var _last_tether_position := Vector2.ZERO

func _ready() -> void:
	add_to_group("gems")
	_apply_loose_sorting()
	_set_visual_offset(GEM_VISUAL_OFFSET)
	
	# Gems are collectible markers, not movable world physics objects. Keeping
	# the body frozen and on no collision layers prevents players from pushing
	# loose gems around while the child Area2D still handles pickup detection.
	collision_layer = 0
	collision_mask = 0
	freeze = true
	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	
	var area = get_node_or_null("PickupArea")
	if area:
		if not area.body_exited.is_connected(_on_pickup_area_body_exited):
			area.body_exited.connect(_on_pickup_area_body_exited)

func tether_to(player) -> bool:
	if tethered_to != null and is_instance_valid(tethered_to) and tethered_to != player:
		return false
	
	tethered_to = player
	_last_tether_position = player.global_position
	if player is CharacterBody2D and player.velocity.length_squared() > 16.0:
		_follow_direction = player.velocity.normalized()
	
	# Carried gems are moved explicitly as lightweight followers instead of by
	# forces. A gentler response gives them a soft trailing motion while still
	# allowing them to follow the player through narrow tunnel turns.
	freeze = true
	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	z_index = CARRIED_Z_INDEX
	y_sort_origin = CARRIED_Y_SORT_ORIGIN
	_set_visual_offset(GEM_VISUAL_OFFSET)
	return true

func untether() -> void:
	tethered_to = null
	freeze = true
	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_apply_loose_sorting()
	_set_visual_offset(GEM_VISUAL_OFFSET)

func _apply_loose_sorting() -> void:
	# Loose gems share the normal world Z layer with the player and tunnel
	# surfaces. The slightly raised Y-sort origin makes the player win overlap
	# ties, while the gem still renders over the exposed floor/front tiles.
	z_index = LOOSE_Z_INDEX
	y_sort_origin = LOOSE_Y_SORT_ORIGIN

func _set_visual_offset(offset: Vector2) -> void:
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.position = offset

func _physics_process(delta: float) -> void:
	if tethered_to == null:
		return
	if not is_instance_valid(tethered_to):
		untether()
		return
	
	var player_position: Vector2 = tethered_to.global_position
	var player_motion := player_position - _last_tether_position
	if tethered_to is CharacterBody2D and tethered_to.velocity.length_squared() > 16.0:
		player_motion = tethered_to.velocity
	if player_motion.length_squared() > 1.0:
		_follow_direction = player_motion.normalized()
	_last_tether_position = player_position
	
	var slot := _get_carry_slot()
	var back_distance := FOLLOW_DISTANCE + float(min(slot, 2)) * SLOT_BACK_SPACING
	var side_offset := 0.0
	if slot > 0:
		side_offset = SLOT_SIDE_OFFSET if slot % 2 == 1 else -SLOT_SIDE_OFFSET
	var perpendicular := Vector2(-_follow_direction.y, _follow_direction.x)
	var target_position := player_position - _follow_direction * back_distance + perpendicular * side_offset
	var to_target := target_position - global_position
	var distance := to_target.length()
	
	# Only recover instantly after a very large separation. Normal following is
	# deliberately slower so the gems drift behind the player instead of snapping.
	if distance > SNAP_DISTANCE:
		global_position = target_position
	elif distance > 0.01:
		var response := 1.0 - exp(-FOLLOW_RESPONSE * delta)
		var movement := to_target * response
		var max_step := MAX_FOLLOW_SPEED * delta
		if movement.length() > max_step:
			movement = movement.normalized() * max_step
		global_position += movement
	
	rotation = 0.0

func _get_carry_slot() -> int:
	if tethered_to != null and "carried_gems" in tethered_to:
		var slot: int = tethered_to.carried_gems.find(self)
		if slot >= 0:
			return slot
	return 0

func _on_pickup_area_body_entered(body) -> void:
	if body.has_method("add_nearby_gem"):
		body.add_nearby_gem(self)

func _on_pickup_area_body_exited(body) -> void:
	if body.has_method("remove_nearby_gem"):
		body.remove_nearby_gem(self)
