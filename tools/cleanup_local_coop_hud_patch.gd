extends SceneTree

func _init() -> void:
	var path := "res://local_coop_mode.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read local_coop_mode.gd")
		quit(1)
		return
	var source := file.get_as_text()
	file.close()
	var old_text := '''	var hidden_nodes := [
		"PlayerLabel", "PlayerHealthBar", "HeroPortrait", "StatsBackdrop", "StatsContainer",
		"BaseHealthBar", "BaseLabel", "BaseStatus", "HeroRPGSummaryP1", "HeroRPGSummaryP2"
	]'''
	var new_text := '''	var hidden