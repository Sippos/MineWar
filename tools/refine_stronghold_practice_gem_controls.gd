extends Node

func _ready() -> void:
	var path := "res://scripts/systems/stronghold_practice_gem_controller.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read practice gem controller")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	file.close()
	source = source.replace(
		"const VEIN_POSITION := Vector2(-418.0, 54.0)\nconst RECEIVER_POSITION := Vector2(-322.0, 54.0)\n",
		"const VEIN_POSITION := Vector2(-390.0, 54.0)\nconst RECEIVER_POSITION := Vector2(-292.0, 54.0)\n"
	)
	source = source.replace(
		"var vein_root: Node2D\nvar vein_block: Polygon2D\n",
		"var vein_root: Node2D\nvar vein_body: StaticBody2D\nvar vein_collision: CollisionShape2D\nvar vein_block: Polygon2D\n"
	)
	source = source.replace(
		"\tvar near_vein := player.global_position.distance_to(get_practice_vein_position()) <= DIG_RADIUS\n\tvar dig_action := \"p%d_dig\" % maxi(1, int(player.get(\"player_id\")))\n\tif near_vein and Input.is_action_pressed(dig_action):\n",
		"\tvar near_vein: bool = player.global_position.distance_to(get_practice_vein_position()) <= DIG_RADIUS\n\tif near_vein and _is_pressing_toward_vein():\n"
	)
	source = source.replace(
		"func _process_active_gem(delta: float) -> void:\n",
		"func _is_pressing_toward_vein() -> bool:\n\tvar player_number := maxi(1, int(player.get(\"player_id\")))\n\tvar input_direction := Vector2(\n\t\tInput.get_axis(\"p%d_left\" % player_number, \"p%d_right\" % player_number),\n\t\tInput.get_axis(\"p%d_up\" % player_number, \"p%d_down\" % player_number)\n\t)\n\tif input_direction.length_squared() < 0.04:\n\t\treturn false\n\tvar toward_vein := player.global_position.direction_to(get_practice_vein_position())\n\treturn input_direction.normalized().dot(toward_vein) >= 0.45\n\nfunc _process_active_gem(delta: float) -> void:\n"
	)
	source = source.replace(
		"\t\tPracticeState.VEIN_READY:\n\t\t\tdig_progress = 0.0\n",
		"\t\tPracticeState.VEIN_READY:\n\t\t\tdig_progress = 0.0\n\t\t\tif vein_collision != null:\n\t\t\t\tvein_collision.set_deferred(\"disabled\", false)\n"
	)
	source = source.replace(
		"\t\tPracticeState.GEM_ACTIVE:\n\t\t\tvein_root.visible = false\n",
		"\t\tPracticeState.GEM_ACTIVE:\n\t\t\tvein_root.visible = false\n\t\t\tif vein_collision != null:\n\t\t\t\tvein_collision.set_deferred(\"disabled\", true)\n"
	)
	source = source.replace(
		"\t\tPracticeState.DELIVERY:\n\t\t\tvein_root.visible = false\n",
		"\t\tPracticeState.DELIVERY:\n\t\t\tvein_root.visible = false\n\t\t\tif vein_collision != null:\n\t\t\t\tvein_collision.set_deferred(\"disabled\", true)\n"
	)
	source = source.replace(
		"\t\t\thint_label.text = (\"HOLD DIG • %.2fs dense-stone test\" % seconds) if near else \"PRACTICE VEIN • Test mining speed\"\n",
		"\t\t\thint_label.text = (\"HOLD TOWARD VEIN • %.2fs dense-stone test\" % seconds) if near else \"PRACTICE VEIN • Test mining speed\"\n"
	)
	source = source.replace(
		"\t\t\t\tvar drop_action: String = \"DROP AT CART • E / B\" if player.global_position.distance_to(RECEIVER_POSITION) <= RECEIVER_RADIUS else \"DENSE GEM • %d%% SLOW • Carry it to the cart\" % penalty\n",
		"\t\t\t\tvar drop_action: String = \"DROP AT CART • Q / B\" if player.global_position.distance_to(RECEIVER_POSITION) <= RECEIVER_RADIUS else \"DENSE GEM • %d%% SLOW • Carry it to the cart\" % penalty\n"
	)
	source = source.replace(
		"\tvein_root.position = VEIN_POSITION\n\tadd_child(vein_root)\n\n\tvar shadow := Polygon2D.new()\n",
		"\tvein_root.position = VEIN_POSITION\n\tadd_child(vein_root)\n\n\tvein_body = StaticBody2D.new()\n\tvein_body.name = \"PracticeVeinCollision\"\n\tvein_body.collision_layer = 1\n\tvein_body.collision_mask = 0\n\tvein_root.add_child(vein_body)\n\tvein_collision = CollisionShape2D.new()\n\tvar vein_shape := RectangleShape2D.new()\n\tvein_shape.size = Vector2(58.0, 58.0)\n\tvein_collision.shape = vein_shape\n\tvein_body.add_child(vein_collision)\n\n\tvar shadow := Polygon2D.new()\n"
	)
	source = source.replace(
		"\tvein_label = _make_label(\"DENSE PRACTICE VEIN\", VEIN_POSITION + Vector2(-82.0, -58.0), Vector2(164.0, 20.0), 10, Color(0.52, 0.94, 1.0, 1.0))\n",
		"\tvein_label = _make_label(\"PRACTICE VEIN\", VEIN_POSITION + Vector2(-54.0, -57.0), Vector2(108.0, 20.0), 9, Color(0.52, 0.94, 1.0, 1.0))\n"
	)
	source = source.replace(
		"\t_make_label(\"PRACTICE CART + PEON\", RECEIVER_POSITION + Vector2(-92.0, -58.0), Vector2(184.0, 20.0), 10, Color(1.0, 0.72, 0.28, 1.0))\n\thint_label = _make_label(\"PRACTICE VEIN • Test mining speed\", Vector2(-505.0, 112.0), Vector2(276.0, 38.0), 11, Color(0.88, 0.94, 1.0, 1.0))\n",
		"\t_make_label(\"CART + PEON\", RECEIVER_POSITION + Vector2(-52.0, -57.0), Vector2(104.0, 20.0), 9, Color(1.0, 0.72, 0.28, 1.0))\n\thint_label = _make_label(\"PRACTICE VEIN • Test mining speed\", Vector2(-445.0, 112.0), Vector2(252.0, 38.0), 11, Color(0.88, 0.94, 1.0, 1.0))\n"
	)
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write practice gem controller")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("STRONGHOLD_PRACTICE_GEM_CONTROLS_REFINED")
	get_tree().quit()
