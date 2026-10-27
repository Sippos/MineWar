extends RigidBody2D

const GEM_VISUAL_OFFSET = Vector2(0, -5)
const FOLLOW_DISTANCE = 26.0
const SLOT_BACK_SPACING = 4.0
const SLOT_SIDE_OFFSET = 5.0
const FOLLOW_RESPONSE = 11.0
const MAX_FOLLOW_SPEED = 420.0
const SNAP_DISTANCE = 160.0
const WORLD_Z_INDEX = 0

const SPRING_STIFFNESS := 32.0
const SPRING_DAMPING := 7.5

var tethered_to = null
var carry_line: Line2D = null
var _spring_velocity := Vector2.ZERO
var _follow_direction := Vector2.DOWN
var _last_tether_position := Vector2.ZERO
var _pop_tween_x: Tween
var _pop_tween_y: Tween

func _ready() -> void:
	add_to_group("gems")
	_apply_world_sorting()
	_set_visual_offset(GEM_VISUAL_OFFSET)
	_setup_pickup_prompt()
	
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

func _setup_pickup_prompt() -> void:
	var pickup_prompt := Label.new()
	pickup_prompt.name = "PickupPrompt"
	pickup_prompt.text = "SPACE / A"
	pickup_prompt.visible = bool(get_meta("tutorial_emphasis", false)) and not _is_touch_runtime()
	pickup_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup_prompt.position = Vector2(-52, -58)
	pickup_prompt.size = Vector2(104, 28)
	pickup_prompt.z_index = 28
	pickup_prompt.add_theme_font_size_override("font_size", 13)
	pickup_prompt.add_theme_color_override("font_color", Color(0.4, 1.0, 1.0, 1.0))
	pickup_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
	pickup_prompt.add_theme_constant_override("outline_size", 4)
	add_child(pickup_prompt)
	var prompt_tween := create_tween().set_loops()
	prompt_tween.tween_property(pickup_prompt, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	prompt_tween.tween_property(pickup_prompt, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)

func should_deposit_as_gem() -> bool:
	return not bool(get_meta("stronghold_practice_gem", false))

func get_carry_weight() -> int:
	return maxi(1, int(get_meta("practice_carry_weight", 1)))

func set_tutorial_emphasis(enabled: bool) -> void:
	set_meta("tutorial_emphasis", enabled)
	_set_pickup_prompt_visible(enabled)

func _set_pickup_prompt_visible(should_show: bool) -> void:
	var pickup_prompt := get_node_or_null("PickupPrompt") as Label
	if pickup_prompt:
		# The touch HUD already provides a contextual PICK control. Keyboard glyphs
		# repeated over every nearby gem obscure the mine on phones and tablets.
		pickup_prompt.visible = should_show and tethered_to == null and not _is_touch_runtime()

func _is_touch_runtime() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android") or bool(get_tree().root.get_meta("web_low_memory_mode", false))

func tether_to(player) -> bool:
	if tethered_to != null and is_instance_valid(tethered_to) and tethered_to != player:
		return false
	
	if _pop_tween_x and _pop_tween_x.is_valid():
		_pop_tween_x.kill()
		_pop_tween_x = null
	if _pop_tween_y and _pop_tween_y.is_valid():
		_pop_tween_y.kill()
		_pop_tween_y = null
	var sprite := get_node_or_null("Sprite2D") as Node2D
	if sprite:
		sprite.scale = Vector2.ONE
	
	tethered_to = player
	_last_tether_position = player.global_position
	if player is CharacterBody2D and player.velocity.length_squared() > 16.0:
		_follow_direction = player.velocity.normalized()
	
	_create_carry_line()
	
	# Carried gems remain normal Y-sorted world objects. Their actual trailing
	# position decides whether they render in front of or behind the hero instead
	# of a fixed Z index forcing every gem over the character sprite.
	freeze = true
	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_spring_velocity = Vector2.ZERO
	_apply_world_sorting()
	_set_visual_offset(GEM_VISUAL_OFFSET)
	_set_pickup_prompt_visible(false)
	var world = get_parent()
	if world and world.has_method("spawn_gem_pickup_feedback"):
		world.spawn_gem_pickup_feedback(global_position)
	if world and world.has_method("notify_tutorial_gem_picked"):
		world.notify_tutorial_gem_picked(self)
	return true

func untether() -> void:
	_cleanup_carry_line()
	_spring_velocity = Vector2.ZERO
	tethered_to = null
	freeze = true
	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_apply_world_sorting()
	_set_visual_offset(GEM_VISUAL_OFFSET)
	_set_pickup_prompt_visible(bool(get_meta("tutorial_emphasis", false)))

func _exit_tree() -> void:
	_cleanup_carry_line()

func _create_carry_line() -> void:
	_cleanup_carry_line()
	carry_line = Line2D.new()
	carry_line.name = "GemCarryLine"
	carry_line.add_to_group("polish_feedback")
	carry_line.width = 1.75
	# Dome Keeper signature warm golden energy tether
	carry_line.default_color = Color(1.0, 0.83, 0.64, 0.8)
	carry_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	carry_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	carry_line.z_index = 1
	carry_line.add_point(global_position)
	var target_pos: Vector2 = (tethered_to as Node2D).global_position if (tethered_to != null and is_instance_valid(tethered_to) and tethered_to is Node2D) else global_position
	carry_line.add_point(target_pos)
	var parent_node := get_parent()
	if parent_node:
		parent_node.add_child(carry_line)

func _cleanup_carry_line() -> void:
	if carry_line != null and is_instance_valid(carry_line):
		carry_line.queue_free()
	carry_line = null

func _apply_world_sorting() -> void:
	z_index = WORLD_Z_INDEX
	z_as_relative = true

func _set_visual_offset(offset: Vector2) -> void:
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.position = offset

## Pops the gem out of a cracked wall face with a slight arc and squash/stretch bounce.
func pop_from_mine(origin: Vector2, impulse_direction: Vector2 = Vector2.ZERO) -> void:
	if tethered_to != null:
		return
	global_position = origin
	var pop_dir := impulse_direction
	if pop_dir.length_squared() < 0.01:
		pop_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)).normalized()
	
	var travel_distance := randf_range(16.0, 26.0)
	var target_pos := origin + pop_dir * travel_distance + Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0))
	var peak_height := randf_range(14.0, 22.0)
	var mid_y := minf(origin.y, target_pos.y) - peak_height
	
	var sprite := get_node_or_null("Sprite2D") as Node2D
	if sprite:
		sprite.scale = Vector2(0.85, 1.2)
	
	if _pop_tween_x and _pop_tween_x.is_valid():
		_pop_tween_x.kill()
	if _pop_tween_y and _pop_tween_y.is_valid():
		_pop_tween_y.kill()
		
	_pop_tween_x = create_tween()
	_pop_tween_x.tween_property(self, "global_position:x", target_pos.x, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	_pop_tween_y = create_tween()
	_pop_tween_y.tween_property(self, "global_position:y", mid_y, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pop_tween_y.tween_property(self, "global_position:y", target_pos.y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pop_tween_y.finished.connect(func():
		if not is_instance_valid(self) or tethered_to != null:
			return
		if sprite and is_instance_valid(sprite):
			sprite.scale = Vector2(1.25, 0.75)
			var land_tw := create_tween()
			land_tw.tween_property(sprite, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

func _physics_process(delta: float) -> void:
	if tethered_to == null:
		return
	if not is_instance_valid(tethered_to):
		untether()
		return
	
	var sim_delta: float = minf(delta, 0.033)
	
	var player_position: Vector2 = tethered_to.global_position
	var anchor_position := player_position
	if tethered_to is CharacterBody2D:
		anchor_position += Vector2(0, -12)
		
	if carry_line and is_instance_valid(carry_line):
		carry_line.set_point_position(0, global_position)
		carry_line.set_point_position(1, anchor_position)
	
	var player_motion := player_position - _last_tether_position
	if tethered_to is CharacterBody2D and tethered_to.velocity.length_squared() > 16.0:
		player_motion = tethered_to.velocity
	if player_motion.length_squared() > 1.0:
		_follow_direction = player_motion.normalized()
	_last_tether_position = player_position
	
	var slot := _get_carry_slot()
	var back_distance := FOLLOW_DISTANCE + float(min(slot, 3)) * SLOT_BACK_SPACING
	var side_offset := 0.0
	if slot > 0:
		side_offset = SLOT_SIDE_OFFSET if slot % 2 == 1 else -SLOT_SIDE_OFFSET
	var perpendicular := Vector2(-_follow_direction.y, _follow_direction.x)
	var target_position := player_position - _follow_direction * back_distance + perpendicular * side_offset
	var to_target := target_position - global_position
	var distance := to_target.length()
	
	# Dome Keeper spring-tether physics: elastic impulse towards target with damping
	if distance > SNAP_DISTANCE:
		global_position = target_position
		_spring_velocity = Vector2.ZERO
	elif distance > 0.01:
		var accel := to_target * SPRING_STIFFNESS - _spring_velocity * SPRING_DAMPING
		_spring_velocity += accel * sim_delta
		if _spring_velocity.length() > MAX_FOLLOW_SPEED:
			_spring_velocity = _spring_velocity.normalized() * MAX_FOLLOW_SPEED
		global_position += _spring_velocity * sim_delta
	else:
		_spring_velocity = Vector2.ZERO
	
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
		_set_pickup_prompt_visible(true)

func _on_pickup_area_body_exited(body) -> void:
	if body.has_method("remove_nearby_gem"):
		body.remove_nearby_gem(self)
	_set_pickup_prompt_visible(bool(get_meta("tutorial_emphasis", false)))
