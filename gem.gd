extends RigidBody2D

const GEM_VISUAL_OFFSET = Vector2(0, -8)
const FOLLOW_DISTANCE = 40.0
const FOLLOW_SPEED_GAIN = 8.0
const MAX_FOLLOW_SPEED = 260.0
const FOLLOW_RESPONSE = 10.0
const SEPARATION_DISTANCE = 14.0
const MAX_SEPARATION_SPEED = 24.0

var tethered_to = null

func _ready() -> void:
	add_to_group("gems")
	z_index = 1
	_set_visual_offset(GEM_VISUAL_OFFSET)
	var area = get_node_or_null("PickupArea")
	if area:
		if not area.body_exited.is_connected(_on_pickup_area_body_exited):
			area.body_exited.connect(_on_pickup_area_body_exited)

func tether_to(player) -> bool:
	if tethered_to != null and is_instance_valid(tethered_to) and tethered_to != player:
		return false
	tethered_to = player
	if player is PhysicsBody2D:
		add_collision_exception_with(player)
	z_index = 1
	_set_visual_offset(GEM_VISUAL_OFFSET)
	return true

func untether() -> void:
	if tethered_to != null and tethered_to is PhysicsBody2D:
		remove_collision_exception_with(tethered_to)
	tethered_to = null
	z_index = 1
	_set_visual_offset(GEM_VISUAL_OFFSET)

func _set_visual_offset(offset: Vector2) -> void:
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.position = offset

func _physics_process(delta: float) -> void:
	var desired_velocity = Vector2.ZERO

	if tethered_to != null and is_instance_valid(tethered_to):
		var to_target = tethered_to.global_position - global_position
		var dist = to_target.length()

		if dist > FOLLOW_DISTANCE:
			var follow_speed = minf((dist - FOLLOW_DISTANCE) * FOLLOW_SPEED_GAIN, MAX_FOLLOW_SPEED)
			desired_velocity = to_target.normalized() * follow_speed

		# Keep nearby carried gems apart without the strong spring forces that
		# previously made them wobble outside narrow tunnel walls.
		var separation_velocity = Vector2.ZERO
		for gem in get_tree().get_nodes_in_group("gems"):
			if gem == self or not is_instance_valid(gem) or gem.tethered_to != tethered_to:
				continue
			var gem_distance = global_position.distance_to(gem.global_position)
			if gem_distance < SEPARATION_DISTANCE and gem_distance > 0.1:
				var push_direction = gem.global_position.direction_to(global_position)
				var separation_strength = (SEPARATION_DISTANCE - gem_distance) / SEPARATION_DISTANCE
				separation_velocity += push_direction * separation_strength * MAX_SEPARATION_SPEED

		desired_velocity += separation_velocity.limit_length(MAX_SEPARATION_SPEED)

	var response = clampf(delta * FOLLOW_RESPONSE, 0.0, 1.0)
	linear_velocity = linear_velocity.lerp(desired_velocity, response)
	angular_velocity = 0.0

func _on_pickup_area_body_entered(body) -> void:
	if body.has_method("add_nearby_gem"):
		body.add_nearby_gem(self)

func _on_pickup_area_body_exited(body) -> void:
	if body.has_method("remove_nearby_gem"):
		body.remove_nearby_gem(self)
