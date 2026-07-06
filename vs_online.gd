extends Node

var world_seed: int = 0
@onready var level = $Level

func _ready():
	# Configure the level to use the synced seed!
	# We have to hook this up after it loads, so let's let the level generate normally,
	# but we can re-generate if we want to sync the noise exactly.
	# Actually, since noise is FastNoiseLite, we can set its seed.
	# For now, let's just use randi() inside the level if we haven't modified generate_initial_world to take a seed.
	# We will just pass the network events.
	
	level.player_id = 1 # Always use WASD locally for yourself
	level.is_vs_mode = true
	
	# Hook up send_enemy
	var upg_menu = level.get_node_or_null("UpgradeMenu")
	if upg_menu:
		if not upg_menu.has_user_signal("send_enemy"):
			upg_menu.add_user_signal("send_enemy")
		upg_menu.connect("send_enemy", Callable(self, "_on_local_send_enemy"))
		
	# Hook up game over
	var base = level.get_node_or_null("Base")
	if base:
		base.game_over.connect(_on_base_destroyed)

func _on_local_send_enemy(enemy_type: int):
	level.income += 1
	# Send to opponent
	rpc("receive_enemy", enemy_type)

@rpc("any_peer", "call_remote", "reliable")
func receive_enemy(enemy_type: int):
	var e = level.ENEMY_SCENE.instantiate()
	var target_cell = level.get_farthest_open_cell()
	e.global_position = level.block_layer.to_global(level.block_layer.map_to_local(target_cell))
	level.add_child(e)
	if e.has_method("initialize"):
		e.initialize(1, false, enemy_type)

func _on_base_destroyed():
	rpc("opponent_base_destroyed")
	# Show game over locally is handled by HUD already

@rpc("any_peer", "call_remote", "reliable")
func opponent_base_destroyed():
	# You win!
	var hud = level.get_node_or_null("HUD")
	if hud and hud.has_node("GameOverLabel"):
		hud.get_node("GameOverLabel").text = "YOU WIN! Opponent Base Destroyed!"
		hud.get_node("GameOverLabel").modulate = Color(0, 1, 0)
		hud.on_game_over()
