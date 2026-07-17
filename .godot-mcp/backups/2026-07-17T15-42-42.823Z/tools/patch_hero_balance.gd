extends Node

func _ready() -> void:
	var path := "res://hero_balance_controller.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open hero balance controller")
		get_tree().quit(1)
		return
	var text := file.get_as_text()
	file.close()
	text = text.replace("var health_gain := max(0, target_health - old_max_health)", "var health_gain: int = maxi(0, target_health - old_max_health)")
	text = text.replace("var completed := enemy == last_attack_enemy and last_attack_timer > 0.02 and attack_timer <= 0.001", "var completed: bool = enemy == last_attack_enemy and last_attack_timer > 0.02 and attack_timer <= 0.001")
	text = text.replace("var maximum := max(8.0, 14.0 - level * 1.5)", "var maximum: float = maxf(8.0, 14.0 - float(level) * 1.5)")
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write hero balance controller")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("HERO_BALANCE_PATCH_APPLIED")
	get_tree().quit()
