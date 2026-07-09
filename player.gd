extends CharacterBody2D

var player_id: int = 1 :
	set(val):
		player_id = val
		update_hero_sprites()


var agility = 1
var strength = 1
var intelligence = 1

var base_speed = 200.0
var base_dig_time = 0.4
var base_jetpack_thrust = 1500.0
const JUMP_VELOCITY = -400.0

const GEM_SCENE = preload("res://gem.tscn")

var tex_walk: Texture2D
var tex_attack: Texture2D

var health = 30
var max_health = 30
var is_dead = false
var death_count = 0
var respawn_timer = 0.0
var invulnerability_timer = 0.0

var level = 1
var xp = 0
var max_xp = 100
var stomp_level = 0
var stomp_cooldown_timer = 0.0

var dig_timer = 0.0
var currently_digging_cell = null
var walk_timer = 0.0
var current_anim_row = 0

var current_hero_name = "Dwarf"
var current_sprite_scale = Vector2(0.85, 0.85)
var current_sprite_position = Vector2(0, -24)

const HERO_VISUALS = {
	"Dwarf": {
		"walk_scale": Vector2(0.85, 0.85),
		"attack_scale": Vector2(1.25, 1.25),
		"sprite_position": Vector2(0, -24)
	},
	"Shaman": {
		"walk_scale": Vector2(0.58, 0.58),
		"attack_scale": Vector2(0.58, 0.58),
		"sprite_position": Vector2(0, -16)
	}
}

var attack_timer = 0.0
var currently_attacking_enemy = null

var carried_gems = []
var nearby_gems = []

@onready var tile_map: TileMapLayer = $"../BlockLayer"
@onready var damage_layer: TileMapLayer = $"../DamageLayer"
@onready var front_damage_layer: TileMapLayer = $"../FrontDamageLayer"
@onready var front_layer: TileMapLayer = $"../FrontWallLayer"
var ray_right: RayCast2D
var ray_left: RayCast2D
var ray_down: RayCast2D
var ray_up: RayCast2D

func _ready() -> void:
	collision_mask |= 4 # Collide with enemies (Layer 3)
	ray_right = RayCast2D.new(); ray_right.position = Vector2(0, -24); ray_right.target_position = Vector2(34, 0); ray_right.collision_mask = 5; add_child(ray_right)
	ray_left = RayCast2D.new(); ray_left.position = Vector2(0, -24); ray_left.target_position = Vector2(-34, 0); ray_left.collision_mask = 5; add_child(ray_left)
	ray_down = RayCast2D.new(); ray_down.position = Vector2(0, -24); ray_down.target_position = Vector2(0, 34); ray_down.collision_mask = 5; add_child(ray_down)
	ray_up = RayCast2D.new(); ray_up.position = Vector2(0, -24); ray_up.target_position = Vector2(0, -34); ray_up.collision_mask = 5; add_child(ray_up)
	
	update_hero_sprites()

func update_hero_sprites() -> void:
	var h_name = Global.hero_p1
	if player_id == 2:
		h_name = Global.hero_p2
		
	if Global.hero_data.has(h_name):
		current_hero_name = h_name
		var data = Global.hero_data[h_name]
		tex_walk = load(data["walk"])
		tex_attack = load(data["attack"])
		if has_node("Sprite2D"):
			$Sprite2D.texture = tex_walk
			_apply_sprite_visuals(false)

func _get_hero_visuals() -> Dictionary:
	return HERO_VISUALS.get(current_hero_name, HERO_VISUALS["Dwarf"])

func _apply_sprite_visuals(is_attack: bool) -> void:
	var visuals = _get_hero_visuals()
	current_sprite_scale = visuals["attack_scale"] if is_attack else visuals["walk_scale"]
	current_sprite_position = visuals["sprite_position"]
	if has_node("Sprite2D"):
		$Sprite2D.scale = current_sprite_scale
		$Sprite2D.position = current_sprite_position


func get_weight_penalty() -> float:
	var p = float(carried_gems.size()) * 0.15
	if p > 0.75:
		return 0.75
	return p

func add_nearby_gem(gem) -> void:
	if not nearby_gems.has(gem):
		nearby_gems.append(gem)

func remove_nearby_gem(gem) -> void:
	nearby_gems.erase(gem)

func deposit_gems() -> int:
	var deposited = 0
	var remaining_items = []
	for gem in carried_gems:
		if is_instance_valid(gem):
			if gem.has_method("should_deposit_as_gem") and not gem.should_deposit_as_gem():
				remaining_items.append(gem)
			else:
				gem.queue_free()
				deposited += 1
	carried_gems = remaining_items
	return deposited

func upgrade_strength() -> void:
	strength += 1

func upgrade_agility() -> void:
	agility += 1

func upgrade_intelligence() -> void:
	intelligence += 1

func take_damage(amount: int) -> void:
	if is_dead or invulnerability_timer > 0.0: return
	
	invulnerability_timer = 1.0 # 1 second of invulnerability
	health -= amount
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("update_player_health"):
		hud.update_player_health(health, max_health)
	
	# Flash red
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var tween = create_tween()
		sprite.modulate = Color(1, 0, 0, 1)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.2)
	
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	death_count += 1
	health = 0
	
	for gem in carried_gems:
		if is_instance_valid(gem) and gem.has_method("untether"):
			gem.untether()
	carried_gems.clear()
	
	$Sprite2D.visible = false
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	respawn_timer = min(20.0, 3.0 + (death_count - 1) * 3.0)

func respawn() -> void:
	is_dead = false
	health = max_health
	global_position = get_parent().get_node("Base").global_position
	
	$Sprite2D.visible = true
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("update_player_health"):
		hud.update_player_health(health, max_health)

var can_move = true

func _physics_process(delta: float) -> void:

	if Input.is_action_just_pressed("p%d_grab" % player_id):
		for gem in nearby_gems:
			if is_instance_valid(gem) and not carried_gems.has(gem):
				if gem.has_method("tether_to"):
					gem.tether_to(self)
				carried_gems.append(gem)
	elif Input.is_action_just_pressed("p%d_drop" % player_id):
		if carried_gems.size() > 0:
			var gem = carried_gems.pop_back()
			if is_instance_valid(gem) and gem.has_method("untether"):
				gem.untether()
	if invulnerability_timer > 0.0:
		invulnerability_timer -= delta
		
	if stomp_cooldown_timer > 0.0:
		stomp_cooldown_timer -= delta
		
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("update_stomp_cooldown"):
		var max_cooldown = max(1.0, 5.0 - stomp_level * 0.5)
		hud.update_stomp_cooldown(stomp_level, stomp_cooldown_timer, max_cooldown)
		
	if Input.is_action_just_pressed("p%d_stomp" % player_id) and stomp_level > 0 and stomp_cooldown_timer <= 0.0:
		perform_stomp()

	if is_dead:
		respawn_timer -= delta
		hud = get_parent().get_node_or_null("HUD")
		if hud and hud.has_method("update_respawn_timer"):
			hud.update_respawn_timer(respawn_timer)
		
		if respawn_timer <= 0:
			respawn()
		return

	var penalty = get_weight_penalty()
	var current_speed = (base_speed + (agility - 1) * 20.0) * (1.0 - penalty)

	var direction = Vector2.ZERO
	if can_move:
		direction.x = Input.get_axis("p%d_left" % player_id, "p%d_right" % player_id)
		direction.y = Input.get_axis("p%d_up" % player_id, "p%d_down" % player_id)
	
	if direction.length() > 0:
		direction = direction.normalized()
		velocity = direction * current_speed
		
		# Animation logic
		var angle = direction.angle()
		var PI_8 = PI / 8.0
		if angle > -PI_8 and angle <= PI_8:
			current_anim_row = 6 # Right
		elif angle > PI_8 and angle <= 3*PI_8:
			current_anim_row = 7 # Down-Right
		elif angle > 3*PI_8 and angle <= 5*PI_8:
			current_anim_row = 0 # Down
		elif angle > 5*PI_8 and angle <= 7*PI_8:
			current_anim_row = 1 # Down-Left
		elif angle > 7*PI_8 or angle <= -7*PI_8:
			current_anim_row = 2 # Left
		elif angle > -7*PI_8 and angle <= -5*PI_8:
			current_anim_row = 3 # Up-Left
		elif angle > -5*PI_8 and angle <= -3*PI_8:
			current_anim_row = 4 # Up
		elif angle > -3*PI_8 and angle <= -PI_8:
			current_anim_row = 5 # Up-Right
			
		$Sprite2D.flip_h = false
		walk_timer += delta * 12.0
		$Sprite2D.frame = current_anim_row * 8 + (int(walk_timer) % 8)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, current_speed)
		
		# Idle frame
		walk_timer = 0.0
		$Sprite2D.frame = current_anim_row * 8

	var enemy_hit = null
	if direction.length() > 0:
		var enemies = get_tree().get_nodes_in_group("enemies")
		var p_center = global_position + Vector2(0, -24)
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			var e_center = enemy.global_position + Vector2(0, 8)
			if p_center.distance_to(e_center) < 70.0:
				var dir_to_enemy = p_center.direction_to(e_center)
				if direction.normalized().dot(dir_to_enemy) > 0.3:
					enemy_hit = enemy
					break

	if enemy_hit:
		var p_center = global_position + Vector2(0, -24)
		var e_center = enemy_hit.global_position + Vector2(0, 8)
		if p_center.distance_to(e_center) < 42.0:
			velocity = Vector2.ZERO # Stop moving into the enemy to prevent jitter

	move_and_slide()
	
	if enemy_hit:
		_stop_digging()
		if currently_attacking_enemy != enemy_hit:
			currently_attacking_enemy = enemy_hit
			attack_timer = 0.0
		
		attack_timer += delta
		var attack_interval = base_dig_time * pow(0.9, agility - 1)
		if attack_timer >= attack_interval:
			var damage = 10 * strength
			if enemy_hit.has_method("take_damage"):
				enemy_hit.take_damage(damage)
			attack_timer = 0.0
	else:
		currently_attacking_enemy = null
		attack_timer = 0.0
		handle_digging(delta)

	if currently_attacking_enemy != null or currently_digging_cell != null:
		if $Sprite2D.texture != tex_attack:
			$Sprite2D.texture = tex_attack
			_apply_sprite_visuals(true)
	else:
		if $Sprite2D.texture != tex_walk:
			$Sprite2D.texture = tex_walk
			_apply_sprite_visuals(false)

func handle_digging(delta: float) -> void:
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("p%d_right" % player_id): input_dir.x += 1
	elif Input.is_action_pressed("p%d_left" % player_id): input_dir.x -= 1
	elif Input.is_action_pressed("p%d_down" % player_id): input_dir.y += 1
	elif Input.is_action_pressed("p%d_up" % player_id): input_dir.y -= 1
	
	var active_ray: RayCast2D = null
	
	# Only dig if we are pressing against a wall (velocity is low due to collision)
	if velocity.length() < 20.0:
		if input_dir.x > 0:
			active_ray = ray_right
		elif input_dir.x < 0:
			active_ray = ray_left
		elif input_dir.y > 0:
			active_ray = ray_down
		elif input_dir.y < 0:
			active_ray = ray_up
			
	if active_ray and active_ray.is_colliding():
		var collider = active_ray.get_collider()
		
		if collider == tile_map:
			var point = active_ray.get_collision_point()
			# Move point slightly into the tile to get correct cell
			point += active_ray.target_position.normalized() * 5.0
			var cell = tile_map.local_to_map(tile_map.to_local(point))
			
			if tile_map.get_cell_source_id(cell) != -1:
				# Prevent digging the top 2 layers to force a single entrance funnel, and prevent digging above the surface
				if (cell.y <= 1 and cell.x != 0) or cell.y < 0:
					_stop_digging()
					return
					
				if currently_digging_cell == cell:
					dig_timer += delta
					
					var calculated_dig_time = base_dig_time * pow(0.9, agility - 1)
					var current_target_dig_time = calculated_dig_time
					var block_id = tile_map.get_cell_source_id(cell)
					if block_id == 2: current_target_dig_time = calculated_dig_time * 2.0
					elif block_id == 3: current_target_dig_time = calculated_dig_time * 4.0
					
					var damage_progress = dig_timer / current_target_dig_time
					var source_id = 7 if damage_progress < 0.66 else 8
					damage_layer.set_cell(cell, source_id, Vector2i(0, 0))
					
					var below_cell = Vector2i(cell.x, cell.y + 1)
					if front_layer.get_cell_source_id(below_cell) != -1:
						var front_source_id = 13 if damage_progress < 0.66 else 14
						front_damage_layer.set_cell(below_cell, front_source_id, Vector2i(0, 0))
					
					if dig_timer >= current_target_dig_time:
						tile_map.erase_cell(cell)
						damage_layer.erase_cell(cell)
						front_damage_layer.erase_cell(below_cell)
						var cell_had_gem = get_parent().has_gem(cell)
						get_parent().on_cell_dug(cell)
						
						if cell_had_gem:
							var gem = GEM_SCENE.instantiate()
							var spawn_pos = tile_map.to_global(tile_map.map_to_local(cell))
							gem.global_position = spawn_pos
							get_parent().call_deferred("add_child", gem)
							
						currently_digging_cell = null
						dig_timer = 0.0
				else:
					_stop_digging()
					currently_digging_cell = cell
					dig_timer = 0.0
			else:
				_stop_digging()
	else:
		_stop_digging()

func _stop_digging() -> void:
	if currently_digging_cell != null:
		damage_layer.erase_cell(currently_digging_cell)
		var below_cell = Vector2i(currently_digging_cell.x, currently_digging_cell.y + 1)
		front_damage_layer.erase_cell(below_cell)
		currently_digging_cell = null
		dig_timer = 0.0

func add_xp(amount: int) -> void:
	xp += amount
	if xp >= max_xp:
		level_up()
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("update_xp"):
		hud.update_xp(level, xp, max_xp)

func level_up() -> void:
	xp -= max_xp
	level += 1
	max_xp = int(max_xp * 1.5)
	
	health = max_health
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("update_player_health"):
		hud.update_player_health(health, max_health)
	
	if hud and hud.has_method("update_xp"):
		hud.update_xp(level, xp, max_xp)
	
	get_tree().paused = true
	var menu_scene = preload("res://level_up_menu.tscn")
	var menu = menu_scene.instantiate()
	get_parent().add_child(menu)
	menu.setup(stomp_level > 0)
	menu.upgrade_selected.connect(_on_upgrade_selected)

func _on_upgrade_selected(upgrade_type: String) -> void:
	if upgrade_type == "stomp":
		stomp_level += 1
	elif upgrade_type == "health":
		max_health += 10
		health += 10
	elif upgrade_type == "damage":
		strength += 1
	
	var hud = get_parent().get_node_or_null("HUD")
	if hud:
		if hud.has_method("update_player_health"):
			hud.update_player_health(health, max_health)
		if hud.has_method("update_stats"):
			hud.update_stats(strength, agility, intelligence)

func perform_stomp() -> void:
	stomp_cooldown_timer = max(1.0, 5.0 - stomp_level * 0.5)
	var radius = 100.0 + stomp_level * 20.0
	var stomp_damage = 20 * stomp_level * strength
	
	var sprite = $Sprite2D
	if sprite:
		var tween = create_tween()
		sprite.scale = current_sprite_scale * 1.2
		sprite.modulate = Color(1, 1, 0)
		tween.tween_property(sprite, "scale", current_sprite_scale, 0.2)
		tween.parallel().tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)
		
	# Stomp particle effect
	var burst = CPUParticles2D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 50
	burst.lifetime = 0.6
	burst.explosiveness = 0.95
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 20.0
	burst.spread = 180.0
	burst.gravity = Vector2(0, 0)
	burst.initial_velocity_min = 150.0
	burst.initial_velocity_max = 280.0
	burst.damping_min = 300.0
	burst.damping_max = 400.0
	burst.scale_amount_min = 3.0
	burst.scale_amount_max = 7.0
	burst.color = Color(0.6, 0.5, 0.4, 0.9) # Dust/Dirt color
	burst.global_position = global_position
	burst.z_index = 0
	get_parent().call_deferred("add_child", burst)
	burst.call_deferred("set_emitting", true)
	
	var t = get_tree().create_timer(1.0)
	t.timeout.connect(burst.queue_free)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(stomp_damage)
