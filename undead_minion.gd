extends CharacterBody2D

@export var max_lifetime := 36.0
@export var speed := 112.0
@export var attack_damage := 12
@export var attack_range := 46.0
@export var attack_interval := 0.75
@export var aggro_range := 520.0

var owner_player: Node2D
var lifetime := 36.0
var target_enemy: Node2D
var path: Array[Vector2] = []
var path_index := 0
var retarget_timer := 0.0
var path_timer := 0.0
var attack_timer := 0.0
var anim_timer := 0.0
var current_anim_row := 0

@onready var world := get_parent()
@onready var block_layer: TileMapLayer = world.get_node_or_null("BlockLayer")

func _ready() -> void:
	add_to_group("undead_minions")
	add_to_group("friendly_minions")
	lifetime = max_lifetime

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_player):
		queue_free()
		return

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	attack_timer = max(0.0, attack_timer - delta)
	retarget_timer -= delta
	path_timer -= delta

	if retarget_timer <= 0.0 or not is_instance_valid(target_enemy):
		retarget_timer = 0.3
		target_enemy = _find_nearest_enemy()
		path_timer = 0.0

	if is_instance_valid(target_enemy):
		_process_enemy_target(delta)
	else:
		_follow_owner(delta)

	_update_animation(delta)
	_update_lifetime_visual()

func _process_enemy_target(delta: float) -> void:
	var distance := global_position.distance_to(target_enemy.global_position)
	if distance <= attack_range:
		velocity = Vector2.ZERO
		if attack_timer <= 0.0:
			if target_enemy.has_method("take_damage"):
				target_enemy.take_damage(attack_damage)
			attack_timer = attack_interval
			_spawn_hit_flash()
		return

	if path_timer <= 0.0:
		path_timer = 0.35
		_recalculate_path_to(target_enemy.global_position)
	_move_along_path(delta)

func _follow_owner(delta: float) -> void:
	var distance := global_position.distance_to(owner_player.global_position)
	if distance <= 82.0:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 5.0 * delta)
		return
	if path_timer <= 0.0:
		path_timer = 0.55
		_recalculate_path_to(owner_player.global_position)
	_move_along_path(delta)

func _find_nearest_enemy() -> Node2D:
	var best: Node2D
	var best_distance := aggro_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best

func _recalculate_path_to(target_global: Vector2) -> void:
	path.clear()
	path_index = 0
	if block_layer == null or world == null:
		return
	var astar = world.get("astar")
	if astar == null:
		return
	var start_cell := block_layer.local_to_map(block_layer.to_local(global_position))
	var end_cell := block_layer.local_to_map(block_layer.to_local(target_global))
	if not astar.is_in_bounds(start_cell.x, start_cell.y):
		return
	if not astar.is_in_bounds(end_cell.x, end_cell.y):
		return
	if astar.is_point_solid(start_cell):
		start_cell = _nearest_walkable_cell(start_cell, astar, 3)
	if astar.is_point_solid(end_cell):
		end_cell = _nearest_walkable_cell(end_cell, astar, 3)
	if start_cell == Vector2i(-99999, -99999) or end_cell == Vector2i(-99999, -99999):
		return
	var id_path = astar.get_id_path(start_cell, end_cell)
	for cell in id_path:
		path.append(block_layer.to_global(block_layer.map_to_local(cell)) + Vector2(0, 12))
	path_index = 1 if path.size() > 1 else 0

func _nearest_walkable_cell(origin: Vector2i, astar, max_radius: int) -> Vector2i:
	if astar.is_in_bounds(origin.x, origin.y) and not astar.is_point_solid(origin):
		return origin
	for radius in range(1, max_radius + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				if x != origin.x - radius and x != origin.x + radius and y != origin.y - radius and y != origin.y + radius:
					continue
				var cell := Vector2i(x, y)
				if astar.is_in_bounds(cell.x, cell.y) and not astar.is_point_solid(cell):
					return cell
	return Vector2i(-99999, -99999)

func _move_along_path(_delta: float) -> void:
	if path_index >= path.size():
		velocity = Vector2.ZERO
		return
	var target_position := path[path_index]
	if global_position.distance_to(target_position) < 6.0:
		path_index += 1
		if path_index >= path.size():
			velocity = Vector2.ZERO
			return
		target_position = path[path_index]
	velocity = global_position.direction_to(target_position) * speed
	move_and_slide()

func _update_animation(delta: float) -> void:
	if not has_node("Sprite2D"):
		return
	if velocity.length() <= 1.0:
		anim_timer = 0.0
		$Sprite2D.frame = current_anim_row * 8
		return
	var angle := velocity.angle()
	var pi_eighth := PI / 8.0
	if angle > -pi_eighth and angle <= pi_eighth:
		current_anim_row = 6
	elif angle > pi_eighth and angle <= 3.0 * pi_eighth:
		current_anim_row = 7
	elif angle > 3.0 * pi_eighth and angle <= 5.0 * pi_eighth:
		current_anim_row = 0
	elif angle > 5.0 * pi_eighth and angle <= 7.0 * pi_eighth:
		current_anim_row = 1
	elif angle > 7.0 * pi_eighth or angle <= -7.0 * pi_eighth:
		current_anim_row = 2
	elif angle > -7.0 * pi_eighth and angle <= -5.0 * pi_eighth:
		current_anim_row = 3
	elif angle > -5.0 * pi_eighth and angle <= -3.0 * pi_eighth:
		current_anim_row = 4
	else:
		current_anim_row = 5
	anim_timer += delta * 11.0
	$Sprite2D.frame = current_anim_row * 8 + (int(anim_timer) % 8)

func _update_lifetime_visual() -> void:
	if has_node("Sprite2D"):
		var ratio: float = clampf(lifetime / maxf(max_lifetime, 0.01), 0.0, 1.0)
		$Sprite2D.modulate.a = clampf(0.3 + ratio * 0.7, 0.3, 1.0)

func _spawn_hit_flash() -> void:
	if not has_node("Sprite2D"):
		return
	var sprite: Sprite2D = $Sprite2D
	sprite.modulate = Color(1.35, 1.15, 1.55, sprite.modulate.a)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, sprite.modulate.a), 0.12)
