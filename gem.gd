extends RigidBody2D

var tethered_to = null

func _ready() -> void:
	add_to_group("gems")
	var area = get_node_or_null("PickupArea")
	if area:
		if not area.body_exited.is_connected(_on_pickup_area_body_exited):
			area.body_exited.connect(_on_pickup_area_body_exited)

func tether_to(player) -> void:
	tethered_to = player
	if player is PhysicsBody2D:
		add_collision_exception_with(player)
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.position = Vector2(0, -24)

func untether() -> void:
	if tethered_to != null and tethered_to is PhysicsBody2D:
		remove_collision_exception_with(tethered_to)
	tethered_to = null
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.position = Vector2(0, 0)

func _physics_process(delta: float) -> void:
	if tethered_to != null and is_instance_valid(tethered_to):
		var target_pos = tethered_to.global_position
		var dir = (target_pos - global_position).normalized()
		var dist = global_position.distance_to(target_pos)
		
		# Pull towards player, but repel if too close
		if dist > 55.0:
			var force_magnitude = minf(dist * 30.0, 5000.0)
			apply_central_force(dir * force_magnitude)
		elif dist < 40.0:
			var force_magnitude = (40.0 - dist) * 100.0
			apply_central_force(-dir * force_magnitude)
			
		# Repel other gems to prevent overlapping each other
		var gems = get_tree().get_nodes_in_group("gems")
		for g in gems:
			if g != self and is_instance_valid(g) and g.tethered_to == tethered_to:
				var g_dist = global_position.distance_to(g.global_position)
				if g_dist < 20.0 and g_dist > 0.1:
					var push_dir = g.global_position.direction_to(global_position)
					apply_central_force(push_dir * (20.0 - g_dist) * 50.0)

func _on_pickup_area_body_entered(body) -> void:
	if body.name == "Player" and body.has_method("add_nearby_gem"):
		body.add_nearby_gem(self)

func _on_pickup_area_body_exited(body) -> void:
	if body.name == "Player" and body.has_method("remove_nearby_gem"):
		body.remove_nearby_gem(self)
