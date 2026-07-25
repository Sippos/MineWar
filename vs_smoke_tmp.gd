extends SceneTree

func _initialize() -> void:
	var scene := load("res://vs_mode.tscn") as PackedScene
	var vs := scene.instantiate()
	root.add_child(vs)
	current_scene = vs
	for i in range(180):
		await process_frame
	var l1 := vs.get_node("HBoxContainer/SubViewportContainer1/SubViewport1/Level1")
	var l2 := vs.get_node("HBoxContainer/SubViewportContainer2/SubViewport2/Level2")
	print("L1 is_vs_mode=", l1.is_vs_mode, " player_id=", l1.player_id)
	print("L2 is_vs_mode=", l2.is_vs_mode, " player_id=", l2.player_id)
	# In VS layout the surface above the base is diggable rock (1); in the
	# single-player layout it is unmineable bedrock (16).
	print("L1 surface cell(5,-5) source=", l1.block_layer.get_cell_source_id(Vector2i(5, -5)))
	print("L2 surface cell(5,-5) source=", l2.block_layer.get_cell_source_id(Vector2i(5, -5)))

	# Sending a creep must spawn it in the opponent's mine only.
	var before1 := _count_enemies(l1)
	var before2 := _count_enemies(l2)
	vs._on_send_enemy(0, 1)
	await process_frame
	print("after p1 send: L1 enemies ", before1, "->", _count_enemies(l1), " L2 enemies ", before2, "->", _count_enemies(l2))

	# Destroying player 2's base must end the match with player 1 as winner.
	l2.get_node("Base").take_damage(9999)
	await process_frame
	var overlay := vs.get_node_or_null("VSMatchResult")
	print("result overlay=", overlay != null, " paused=", paused)
	if overlay:
		for label in _labels(overlay):
			print("  banner: ", label.text)
	paused = false
	quit()

func _count_enemies(level: Node) -> int:
	var n := 0
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and level.is_ancestor_of(e):
			n += 1
	return n

func _labels(node: Node) -> Array:
	var out := []
	if node is Label:
		out.append(node)
	for c in node.get_children():
		out.append_array(_labels(c))
	return out
