extends Node

func _ready() -> void:
	var path := "res://scripts/systems/preparation/in_world_hero_selector.gd"
	var source := FileAccess.get_file_as_string(path)
	var replacements := {
		"card.scale = Vector2(0.96, 0.96)": "card.scale = Vector2(0.79, 0.79)",
		"card_tween.tween_property(card, \"scale\", Vector2.ONE, 0.2)": "card_tween.tween_property(card, \"scale\", Vector2(0.84, 0.84), 0.2)",
		"card_tween.tween_property(card, \"scale\", Vector2(0.97, 0.97), 0.1)": "card_tween.tween_property(card, \"scale\", Vector2(0.81, 0.81), 0.1)"
	}
	for before in replacements:
		if not source.contains(before):
			push_warning("Missing replacement: %s" % before)
			continue
		source = source.replace(before, replacements[before])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(source)
		file.close()
	get_tree().quit()
