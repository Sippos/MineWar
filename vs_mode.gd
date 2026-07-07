extends Control

@onready var level1 = $HBoxContainer/SubViewportContainer1/SubViewport1/Level1
@onready var level2 = $HBoxContainer/SubViewportContainer2/SubViewport2/Level2

func _ready() -> void:
	level1.player_id = 1
	level1.is_vs_mode = true
	level2.player_id = 2
	level2.is_vs_mode = true
	
	# Connect sending enemies
	var hud1 = level1.get_node_or_null("UpgradeMenu")
	if hud1:
		hud1.add_user_signal("send_enemy")
		hud1.connect("send_enemy", Callable(self, "_on_p1_send_enemy"))
		
	var hud2 = level2.get_node_or_null("UpgradeMenu")
	if hud2:
		hud2.add_user_signal("send_enemy")
		hud2.connect("send_enemy", Callable(self, "_on_p2_send_enemy"))

func _on_p1_send_enemy(enemy_type: int) -> void:
	print("p1 sending enemy type ", enemy_type)
	level1.income += enemy_type + 1
	var e = level2.ENEMY_SCENE.instantiate()
	# spawn on level2
	var target_cell = level2.get_farthest_open_cell()
	e.global_position = level2.block_layer.to_global(level2.block_layer.map_to_local(target_cell))
	level2.add_child(e)
	if e.has_method("initialize"):
		e.initialize(1, false, enemy_type)

func _on_p2_send_enemy(enemy_type: int) -> void:
	level2.income += enemy_type + 1
	var e = level1.ENEMY_SCENE.instantiate()
	var target_cell = level1.get_farthest_open_cell()
	e.global_position = level1.block_layer.to_global(level1.block_layer.map_to_local(target_cell))
	level1.add_child(e)
	if e.has_method("initialize"):
		e.initialize(1, false, enemy_type)
