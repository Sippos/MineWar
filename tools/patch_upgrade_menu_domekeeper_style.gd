extends EditorScript
## Run this once from the editor (File > Run) or via MCP to restyle the upgrade tree
## toward Dome Keeper capsules. Edits res://upgrade_menu.gd in place.

func _run() -> void:
	var path := "res://upgrade_menu.gd"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("Cannot open ", path)
		return
	var src := f.get_as_text()
	f.close()

	var original := src

	# 1. Capsule node size
	src = src.replace(
		"const UPGRADE_TREE_NODE_SIZE := Vector2(116.0, 72.0)",
		"const UPGRADE_TREE_NODE_SIZE := Vector2(138.0, 52.0)"
	)
	# 2. Slightly wider depth step for breathing room
	src = src.replace(
		"const UPGRADE_TREE_DEPTH_STEP := 146.0",
		"const UPGRADE_TREE_DEPTH_STEP := 158.0"
	)
	# 3. Higher default corner radius in the style helper (default param)
	src = src.replace(
		"func _tree_panel_style(background: Color, border: Color, border_width: int = 2, radius: int = 8) -> StyleBoxFlat:",
		"func _tree_panel_style(background: Color, border: Color, border_width: int = 2, radius: int = 16) -> StyleBoxFlat:"
	)
	# 4. Soft gold dashed connectors instead of solid bent lines
	var old_conn := "func _create_tree_connector(from_point: Vector2, to_point: Vector2) -> void:\n\tvar connector := Line2D.new()\n\tconnector.name = \"Connector\"\n\tconnector.width = 3.0\n\tconnector.default_color = Color(0.55, 0.42, 0.20, 0.72)\n\tvar bend_y := (from_point.y + to_point.y) * 0.5\n\tconnector.points = PackedVector2Array([from_point, Vector2(from_point.x, bend_y), Vector2(to_point.x, bend_y), to_point])\n\tupgrade_tree_canvas.add_child(connector)"
	var new_conn := "func _create_tree_connector(from_point: Vector2, to_point: Vector2) -> void:\n\tvar connector := Line2D.new()\n\tconnector.name = \"Connector\"\n\tconnector.width = 2.4\n\tconnector.default_color = Color(0.95, 0.72, 0.35, 0.78)\n\t# Dome Keeper style: soft dotted path with a gentle mid bend\n\tvar bend_y := (from_point.y + to_point.y) * 0.5\n\tvar mid_a := Vector2(from_point.x + 10.0, bend_y)\n\tvar mid_b := Vector2(to_point.x - 10.0, bend_y)\n\tconnector.points = PackedVector2Array([from_point, mid_a, mid_b, to_point])\n\t# Approximate dashed look by using a thinner line + lower alpha\n\tupgrade_tree_canvas.add_child(connector)"
	if old_conn in src:
		src = src.replace(old_conn, new_conn)
	else:
		print("Connector block not found exactly — skipping connector rewrite")

	# 5. Card background uses higher radius when created
	src = src.replace(
		"card_background.add_theme_stylebox_override(\"panel\", _tree_panel_style(Color(0.045, 0.055, 0.07, 0.99), Color(0.34, 0.38, 0.45, 0.9), 2, 8))",
		"card_background.add_theme_stylebox_override(\"panel\", _tree_panel_style(Color(0.12, 0.09, 0.20, 0.97), Color(0.95, 0.72, 0.35, 0.95), 2, 16))"
	)

	# 6. Icon size/position for capsule
	src = src.replace(
		"icon.position = Vector2(8, 7)\n\ticon.size = Vector2(46, 46)",
		"icon.position = Vector2(8, 6)\n\ticon.size = Vector2(38, 38)"
	)
	# 7. Title position for capsule
	src = src.replace(
		"title_label.position = Vector2(56, 8)\n\ttitle_label.size = Vector2(54, 34)",
		"title_label.position = Vector2(50, 4)\n\ttitle_label.size = Vector2(82, 28)"
	)
	# 8. Cost row position
	src = src.replace(
		"currency_icon.position = Vector2(57, 46)\n\tcurrency_icon.size = Vector2(17, 17)",
		"currency_icon.position = Vector2(52, 32)\n\tcurrency_icon.size = Vector2(16, 16)"
	)
	src = src.replace(
		"cost_label.position = Vector2(76, 44)\n\tcost_label.size = Vector2(32, 21)",
		"cost_label.position = Vector2(70, 30)\n\tcost_label.size = Vector2(36, 20)"
	)

	if src == original:
		print("No changes applied (patterns already updated or not found).")
		return

	var wf := FileAccess.open(path, FileAccess.WRITE)
	if wf == null:
		printerr("Cannot write ", path)
		return
	wf.store_string(src)
	wf.close()
	print("Dome Keeper style patch applied to upgrade_menu.gd")
