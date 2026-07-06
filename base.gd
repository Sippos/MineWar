extends Area2D

signal gems_deposited(amount)
signal upgrade_requested
signal base_damaged(new_health)
signal game_over

var health = 100
var player_in_zone = false
var spikes_level = 0
var heal_timer = 0.0

@onready var prompt = $PromptLabel

func _ready() -> void:
	collision_mask |= 4 # Add layer 3 (enemies)
	prompt.visible = false

func _process(delta: float) -> void:
	if player_in_zone:
		var player = get_parent().get_node_or_null("Player")
		if player:
			# Heal player
			heal_timer += delta
			if heal_timer >= 1.0:
				heal_timer = 0.0
				if not player.is_dead and player.health < player.max_health:
					player.health = min(player.health + 5, player.max_health)
					var hud = get_parent().get_node_or_null("HUD")
					if hud and hud.has_method("update_player_health"):
						hud.update_player_health(player.health, player.max_health)
			
			# Auto deposit gems continuously
			if player.has_method("deposit_gems"):
				var deposited = player.deposit_gems()
				if deposited > 0:
					gems_deposited.emit(deposited)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_zone = true
		prompt.visible = true
	elif body.is_in_group("gems"):
		# If a gem is thrown or pushed into the base directly!
		body.queue_free()
		gems_deposited.emit(1)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_zone = false
		prompt.visible = false

func _input(event: InputEvent) -> void:
	if player_in_zone and event.is_action_pressed("p%d_interact" % get_parent().get("player_id", 1)):
		upgrade_requested.emit()

func take_damage(amount: int) -> void:
	health -= amount
	base_damaged.emit(health)
	if health <= 0:
		game_over.emit()

