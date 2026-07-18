extends Node

func _ready() -> void:
	var selector_path := "res://scripts/systems/preparation/in_world_hero_selector.gd"
	var selector := FileAccess.get_file_as_string(selector_path)
	selector = selector.replace("card.scale = Vector2(0.79, 0.79)", "card.scale = Vector2(0.50, 0.50)")
	selector = selector.replace("card_tween.tween_property(card, \"scale\", Vector2(0.84, 0.84)", "card_tween.tween_property(card, \"scale\", Vector2(0.56, 0.56)")
	selector = selector.replace("card_tween.tween_property(card, \"scale\", Vector2(0.81, 0.81)", "card_tween.tween_property(card, \"scale\", Vector2(0.52, 0.52)")
	var selector_file := FileAccess.open(selector_path, FileAccess.WRITE)
	selector_file.store_string(selector)

	var signs_path := "res://scenes/world/preparation/single_player_mode_signs.tscn"
	var signs := FileAccess.get_file_as_string(signs_path)
	signs = signs.replace("position = Vector2(-110, -340)", "position = Vector2(-110, -290)")
	signs = signs.replace("position = Vector2(-110, 358)", "position = Vector2(-110, 286)")
	signs = signs.replace("position = Vector2(455, -28)", "position = Vector2(390, -28)")
	var signs_file := FileAccess.open(signs_path, FileAccess.WRITE)
	signs_file.store_string(signs)
	get_tree().quit()
