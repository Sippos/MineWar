extends Area2D

var linked_portal: Node2D
var cooldown_timer: float = 0.0
var portal_lifetime: float = -1.0
var is_entrance: bool = false

func _ready() -> void:
	add_to_group("portals")
	body_entered.connect(_on_body_entered)
	
	# Visual particles for the portal
	var burst := CPUParticles2D.new()
	burst.emitting = true
	burst.direction = Vector2(0, -1)
	burst.gravity = Vector2(0, -30)
	burst.initial_velocity_min = 20
	burst.initial_velocity_max = 50
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.color = Color(0.2, 0.8, 0.4, 0.7) # Druid green
	burst.amount = 30
	burst.position = Vector2.ZERO
	add_child(burst)

func _physics_process(delta: float) -> void:
	cooldown_timer -= delta
	if portal_lifetime > 0.0:
		portal_lifetime -= delta
		if portal_lifetime <= 0.0:
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if cooldown_timer > 0.0:
		return
	if not is_instance_valid(linked_portal):
		return
	if body.name == "Player":
		body.global_position = linked_portal.global_position
		linked_portal.cooldown_timer = 2.0
		self.cooldown_timer = 2.0
		_spawn_teleport_effect(body.global_position)
		_spawn_teleport_effect(linked_portal.global_position)

func _spawn_teleport_effect(pos: Vector2) -> void:
	var burst := CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.direction = Vector2(0, -1)
	burst.spread = 180
	burst.initial_velocity_min = 50
	burst.initial_velocity_max = 100
	burst.scale_amount_min = 3.0
	burst.scale_amount_max = 6.0
	burst.color = Color(0.2, 1.0, 0.5)
	burst.amount = 40
	burst.position = pos
	get_parent().add_child(burst)
