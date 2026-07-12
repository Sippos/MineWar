extends Area2D

signal gems_deposited(amount)
signal upgrade_requested
signal base_damaged(new_health)
signal game_over

const BASE_TEXTURES = {
	"Dwarf": preload("res://DwarfBase.png"),
	"Shaman": preload("res://ShamanBase.png")
}

var health = 100
var player_in_zone = false
var spikes_level = 0
var heal_timer = 0.0

@onready var prompt = $PromptLabel

func _ready() -> void:
	collision_mask |= 4 # Add layer 3 (enemies)
	prompt.visible = false
	call_deferred("refresh_base_sprite")

func refresh_base_sprite() -> void:
	_apply_base_sprite(_get_hero_name())

func _get_hero_name() -> String:
	var p_id = _get_player_id()
	if p_id == 2:
		return Global.hero_p2
	return Global.hero_p1

func _get_player_id() -> int:
	var parent = get_parent()
	if parent == null:
		return 1
	var p_id = parent.get("player_id")
	if p_id == null:
		return 1
	return int(p_id)

func _apply_base_sprite(hero_name: String) -> void:
	var tex = BASE_TEXTURES.get(hero_name, BASE_TEXTURES["Dwarf"])
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.modulate = Color(1, 1, 1, 1)
		$Sprite2D.scale = Vector2(128.0 / tex.get_width(), 128.0 / tex.get_height())

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
	var p_id = get_parent().get("player_id")
	if p_id == null:
		p_id = 1
	if player_in_zone and event.is_action_pressed("p%d_interact" % p_id):
		upgrade_requested.emit()

func take_damage(amount: int) -> void:
	health -= amount
	base_damaged.emit(health)
	if health <= 0:
		game_over.emit()


func spawn_rail():
	var item = preload("res://rail_item.tscn").instantiate()
	item.global_position = global_position
	get_parent().call_deferred("add_child", item)

func spawn_peon():
	var peon = preload("res://scenes/entities/peon/peon.tscn").instantiate()
	peon.global_position = global_position
	get_parent().call_deferred("add_child", peon)

func spawn_minecart():
	var existing = get_parent().get_node_or_null("Minecart")
	if existing:
		existing.queue_free()
	var cart = preload("res://scenes/entities/transport/minecart/minecart.tscn").instantiate()
	cart.name = "Minecart"
	cart.global_position = global_position
	get_parent().call_deferred("add_child", cart)
