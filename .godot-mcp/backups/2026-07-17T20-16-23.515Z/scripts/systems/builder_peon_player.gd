extends CharacterBody2D

@export var move_speed := 190.0
@export var movement_bounds := Rect2(-560.0, -520.0, 1120.0, 660.0)

@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D

var controlled := true
var animation_timer := 0.0
var animation_row := 0

func _ready() -> void:
	add_to_group("builder_peon")
	set_controlled(controlled)

func set_controlled(value: bool) -> void:
	controlled = value
	velocity = Vector2.ZERO
	if camera:
		camera.enabled = value

func _physics_process(delta: float) -> void:
	if not controlled:
		velocity = Vector2.ZERO
		_update_animation(delta)
		return

	var input_vector := Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
	if input_vector.length_squared() < 0.01:
		input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_vector.normalized() * move_speed
	move_and_slide()
	global_position.x = clampf(global_position.x, movement_bounds.position.x, movement_bounds.end.x)
	global_position.y = clampf(global_position.y, movement_bounds.position.y, movement_bounds.end.y)
	_update_animation(delta)

func _update_animation(delta: float) -> void:
	if sprite == null:
		return
	if velocity.length_squared() > 0.01:
		var angle := velocity.angle()
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
		animation_timer += delta * 12.0
		sprite.frame = animation_row * 8 + (int(animation_timer) % 8)
	else:
		animation_timer = 0.0
		sprite.frame = animation_row * 8
