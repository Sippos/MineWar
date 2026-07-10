extends CharacterBody2D

enum EnemyType { RAT, SPIDER, BAT, TROGG, ORC }

var enemy_type: EnemyType = EnemyType.RAT
var speed = 80.0
var damage = 10
var health = 50
var gold_drop = 10
var xp_drop = 10
var is_boss_enemy = false

@onready var world = get_parent()
@onready var tile_map = world.get_node("BlockLayer")
@onready var base = world.get_node("Base")

var path: Array[Vector2] = []
var current_path_index = 0
var target_base_cell = Vector2i(0, -1)

var path_timer = 0.0
var walk_timer = 0.0
var current_anim_row = 0
var attack_cooldown_timer = 0.0

func _ready():
	recalculate_path()

func initialize(wave_number: int, is_boss: bool, e_type: int = EnemyType.RAT) -> void:
	is_boss_enemy = is_boss
	enemy_type = e_type as EnemyType
	
	var base_hp = 20
	var base_dmg = 2
	var base_speed = 70.0
	var base_xp = 5
	var base_gold = 3
	var tex_path = "res://assets/sprites/enemies/rat/rat_walk_pixelart_spritesheet.png"
	
	if is_boss:
		base_hp = 500
		base_dmg = 30
		base_speed = 60.0
		base_xp = 250
		base_gold = 150
		tex_path = "res://character_sprites/mech_walk_pixelart_spritesheet.png"
	else:
		match enemy_type:
			EnemyType.RAT:
				base_hp = 20; base_dmg = 2; base_speed = 70.0; base_xp = 5; base_gold = 3
				tex_path = "res://assets/sprites/enemies/rat/rat_walk_pixelart_spritesheet.png"
			EnemyType.SPIDER:
				base_hp = 35; base_dmg = 4; base_speed = 75.0; base_xp = 10; base_gold = 6
				tex_path = "res://character_sprites/spider_walk_spritesheet.png"
			EnemyType.BAT:
				base_hp = 25; base_dmg = 5; base_speed = 95.0; base_xp = 12; base_gold = 8
				tex_path = "res://character_sprites/bat_fly_spritesheet.png"
			EnemyType.TROGG:
				base_hp = 60; base_dmg = 7; base_speed = 50.0; base_xp = 15; base_gold = 12
				tex_path = "res://character_sprites/trogg_walk_spritesheet.png"
			EnemyType.ORC:
				base_hp = 80; base_dmg = 10; base_speed = 60.0; base_xp = 25; base_gold = 20
				tex_path = "res://character_sprites/orc_walk_pixelart_spritesheet.png"
				
	# Scale by wave
	health = int(base_hp * (1.0 + wave_number * 0.2))
	damage = int(base_dmg + wave_number * 1.5)
	speed = base_speed * randf_range(0.9, 1.1)
	gold_drop = int(base_gold + wave_number * 0.5)
	xp_drop = int(base_xp + wave_number * 1.0)
	
	var sprite = $Sprite2D
	if sprite:
		sprite.texture = load(tex_path)
		if is_boss:
			sprite.scale = Vector2(2.0, 2.0)
			sprite.modulate = Color(1, 1, 1)
			Global.mark_monster_seen("Mech")
		else:
			var monster_name = EnemyType.keys()[enemy_type].capitalize()
			Global.mark_monster_seen(monster_name)

func recalculate_path():
	var start_cell = tile_map.local_to_map(tile_map.to_local(global_position))
	if world.astar.is_in_bounds(start_cell.x, start_cell.y) and world.astar.is_in_bounds(target_base_cell.x, target_base_cell.y):
		var id_path = world.astar.get_id_path(start_cell, target_base_cell)
		path.clear()
		for id in id_path:
			path.append(tile_map.to_global(tile_map.map_to_local(id)))
		current_path_index = 0

func _physics_process(delta: float):
	path_timer += delta
	if path_timer > 1.0:
		recalculate_path()
		path_timer = 0.0
	
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	
	var is_attacking_base = false
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider == base:
			is_attacking_base = true
	
	if base and global_position.distance_to(base.global_position) < 70.0:
		is_attacking_base = true

	if is_attacking_base:
		velocity = Vector2.ZERO
		var sprite = $Sprite2D
		if sprite:
			walk_timer = 0.0
			sprite.frame = current_anim_row * 8
		
		if attack_cooldown_timer <= 0.0:
			if base.has_method("take_damage"):
				base.take_damage(damage)
			if "spikes_level" in base and base.spikes_level > 0:
				take_damage(15 * base.spikes_level)
			attack_cooldown_timer = 1.0
	elif path.size() > 0 and current_path_index < path.size():
		var target_pos = path[current_path_index]
		var dir = (target_pos - global_position).normalized()
		var dist = global_position.distance_to(target_pos)
		
		if dist < 15.0:
			current_path_index += 1
		else:
			velocity = dir * speed
			move_and_slide()
			
			# Animation logic
			var angle = dir.angle()
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
				
			var sprite = $Sprite2D
			if sprite:
				walk_timer += delta * 12.0
				sprite.frame = current_anim_row * 8 + (int(walk_timer) % 8)
			
			for i in get_slide_collision_count():
				var col = get_slide_collision(i)
				var collider = col.get_collider()
				if collider.name == "Player":
					if collider.has_method("take_damage"):
						collider.take_damage(damage)
	else:
		recalculate_path()
		var sprite = $Sprite2D
		if sprite:
			walk_timer = 0.0
			sprite.frame = current_anim_row * 8

func take_damage(amount: int) -> void:
	health -= amount
	
	# Flash white
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var tween = create_tween()
		sprite.modulate = Color(10, 10, 10, 1) # Overbright to appear white
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.2)
	
	if health <= 0:
		die()

func die() -> void:
	var coin_scene = preload("res://scenes/entities/collectibles/drops/coin_drop.tscn")
	var coin = coin_scene.instantiate()
	coin.gold_value = gold_drop
	coin.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
	world.call_deferred("add_child", coin)
	
	var xp_scene = preload("res://scenes/entities/collectibles/drops/xp_drop.tscn")
	var xp = xp_scene.instantiate()
	xp.xp_value = xp_drop
	xp.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
	world.call_deferred("add_child", xp)
		
	if is_boss_enemy:
		Global.unlock_hero("Mech")
	
	queue_free()
