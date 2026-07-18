extends Node

var failed := false

func _ready() -> void:
	_patch_enemy()
	_patch_player_scene()
	if failed:
		push_error("COMBAT_VFX_ALIGNMENT_FIX_FAILED")
		get_tree().quit(1)
		return
	print("COMBAT_VFX_ALIGNMENT_FIX_APPLIED")
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
	text = _replace_checked(
		text,
		"\tfeedback.play_enemy_hit(global_position + Vector2(0, 4), _feedback_hit_direction(), amount, health <= 0)",
		"\tvar hit_power_damage := amount * (2 if is_boss_enemy else 1)\n\tfeedback.play_enemy_hit(sprite.global_position, _feedback_hit_direction(), hit_power_damage, health <= 0)",
		"enemy impact center and boss scale"
	)
	text = _replace_checked(
		text,
		"func _feedback_hit_direction() -> Vector2:\n\tvar nearest_direction := Vector2.RIGHT\n\tvar nearest_distance := INF\n\tfor candidate in get_tree().get_nodes_in_group(\"players\"):\n\t\tif not candidate is Node2D or not is_instance_valid(candidate):\n\t\t\tcontinue\n\t\tvar delta := global_position - (candidate as Node2D).global_position\n\t\tif delta.length_squared() < nearest_distance:\n\t\t\tnearest_distance = delta.length_squared()\n\t\t\tnearest_direction = delta.normalized() if delta.length_squared() > 0.001 else Vector2.RIGHT\n\treturn nearest_direction",
		"func _feedback_hit_direction() -> Vector2:\n\tvar nearest_direction := Vector2.RIGHT\n\tvar nearest_distance := INF\n\tfor candidate in world.get_children():\n\t\tif not candidate is Node2D or not is_instance_valid(candidate):\n\t\t\tcontinue\n\t\tif not str(candidate.name).begins_with(\"Player\"):\n\t\t\tcontinue\n\t\tvar delta := sprite.global_position - (candidate as Node2D).global_position\n\t\tif delta.length_squared() < nearest_distance:\n\t\t\tnearest_distance = delta.length_squared()\n\t\t\tnearest_direction = delta.normalized() if delta.length_squared() > 0.001 else Vector2.RIGHT\n\treturn nearest_direction",
		"enemy hit direction lookup"
	)
	_write(path, text)

func _patch_player_scene() -> void:
	var path := "res://scenes/world/mine/level.tscn"
	var text := FileAccess.get_file_as_string(path)
	text = _replace_checked(
		text,
		"[node name=\"Player\" type=\"CharacterBody2D\" parent=\".\" unique_id=885445882]",
		"[node name=\"Player\" type=\"CharacterBody2D\" parent=\".\" unique_id=885445882 groups=[\"players\"]]",
		"player group"
	)
	_write(path, text)
