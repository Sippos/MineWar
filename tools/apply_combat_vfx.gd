extends Node

var failed := false

func _ready() -> void:
	_patch_enemy()
	_patch_player()
	if failed:
		push_error("COMBAT_VFX_PATCH_FAILED")
		get_tree().quit(1)
		return
	print("COMBAT_VFX_PATCH_APPLIED")
	get_tree().quit()

func _replace_checked(text: String, old_text: String, new_text: String, label: String) -> String:
	if not text.contains(old_text):
		push_error("Missing patch target: " + label)
		failed = true
		return text
	return text.replace(old_text, new_text)

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + path)
		failed = true
		return
	file.store_string(text)
	file.close()

func _patch_enemy() -> void:
	var path := "res://enemy.gd"
	var text := FileAccess.get_file_as_string(path)
	text = _replace_checked(text,
		"\thealth_bar_container.modulate.a = 1.0\n\t_play_hit_reaction()\n\tif health <= 0:",
		"\thealth_bar_container.modulate.a = 1.0\n\t_play_hit_reaction()\n\tvar feedback := CombatFeedback.ensure(world)\n\tfeedback.play_enemy_hit(global_position + Vector2(0, 4), _feedback_hit_direction(), amount, health <= 0)\n\tif health <= 0:",
		"enemy confirmed-hit feedback")
	text = _replace_checked(text,
		"\thit_reaction_tween.tween_property(sprite, \"modulate\", Color.WHITE, 0.18)\n\t_spawn_hit_burst()",
		"\thit_reaction_tween.tween_property(sprite, \"modulate\", Color.WHITE, 0.18)",
		"remove generic particle burst")
	var helper_anchor := "func _spawn_hit_burst() -> void:\n"
	if text.contains(helper_anchor) and not text.contains("func _feedback_hit_direction() -> Vector2:"):
		var helper := "func _feedback_hit_direction() -> Vector2:\n\tvar nearest_direction := Vector2.RIGHT\n\tvar nearest_distance := INF\n\tfor candidate in get_tree().get_nodes_in_group(\"players\"):\n\t\tif not candidate is Node2D or not is_instance_valid(candidate):\n\t\t\tcontinue\n\t\tvar delta := global_position - (candidate as Node2D).global_position\n\t\tif delta.length_squared() < nearest_distance:\n\t\t\tnearest_distance = delta.length_squared()\n\t\t\tnearest_direction = delta.normalized() if delta.length_squared() > 0.001 else Vector2.RIGHT\n\treturn nearest_direction\n\n"
		text = text.replace(helper_anchor, helper + helper_anchor)
	_write(path, text)

func _patch_player() -> void:
	var path := "res://player.gd"
	var text := FileAccess.get_file_as_string(path)
	text = _replace_checked(text,
		"\tinvulnerability_timer = 1.0\n\thealth -= applied_amount\n\tvar hud = get_parent().get_node_or_null(\"HUD\")",
		"\tinvulnerability_timer = 1.0\n\thealth -= applied_amount\n\tvar feedback := CombatFeedback.ensure(get_parent())\n\tfeedback.play_player_hit(global_position + Vector2(0, -20), applied_amount, health <= 0)\n\tvar hud = get_parent().get_node_or_null(\"HUD\")",
		"player damage feedback")
	text = _replace_checked(text,
		"\t\tsprite.modulate = Color(1, 0, 0, 1)\n\t\ttween.tween_property(sprite, \"modulate\", Color(1, 1, 1, 1), 0.2)",
		"\t\tsprite.modulate = Color(2.2, 0.35, 0.25, 1.0)\n\t\ttween.tween_property(sprite, \"modulate\", Color.WHITE, 0.16)",
		"player flash polish")
	_write(path, text)
