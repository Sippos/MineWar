extends CharacterBody2D

@export var move_speed := 245.0
var movement_enabled := true
var _pulse_time := 0.0
const HUB_BOUNDS := Rect2(-510.0, -245.0, 1020.0, 555.0)

func _ready() -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()
	if not movement_enabled:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 7.0 * delta)
		move_and_slide()
		return
	var input_vector := Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
	velocity = input_vector * move_speed
	move_and_slide()
	position.x = clampf(position.x, HUB_BOUNDS.position.x, HUB_BOUNDS.end.x)
	position.y = clampf(position.y, HUB_BOUNDS.position.y, HUB_BOUNDS.end.y)

func _draw() -> void:
	var pulse := (sin(_pulse_time * 3.2) + 1.0) * 0.5
	var glow_radius := 29.0 + pulse * 5.0
	draw_circle(Vector2.ZERO, glow_radius, Color(0.23, 0.88, 1.0, 0.10 + pulse * 0.05))
	draw_circle(Vector2.ZERO, 20.0, Color(0.18, 0.78, 1.0, 0.22))
	draw_circle(Vector2.ZERO, 13.0, Color(0.55, 0.96, 1.0, 0.95))
	draw_circle(Vector2(-3.5, -4.5), 4.0, Color(1.0, 1.0, 1.0, 0.92))
	for index in range(4):
		var angle := _pulse_time * 0.65 + float(index) * TAU / 4.0
		var start := Vector2.RIGHT.rotated(angle) * (24.0 + pulse * 2.0)
		var finish := Vector2.RIGHT.rotated(angle) * (34.0 + pulse * 3.0)
		draw_line(start, finish, Color(0.45, 0.92, 1.0, 0.45), 2.0)
