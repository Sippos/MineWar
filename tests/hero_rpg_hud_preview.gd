extends Node

const LEVEL_SCENE: PackedScene = preload("res://scenes/world/mine/level.tscn")

func _ready() -> void:
	Global.hero_p1 = "Nerubian"
	Global.current_hero = "Nerubian"
	Global.selected_hero_id = "Nerubian"
	var level: Node = LEVEL_SCENE.instantiate()
	add_child(level)
	for _index: int in range(8):
		await get_tree().physics_frame
	var player: CharacterBody2D = level.get_node_or_null("Player") as CharacterBody2D
	if player != null:
		player.set("level", 6)
	for _index: int in range(4):
		await get_tree().physics_frame
	var hud: Node = level.get_node_or_null("HUD")
	if hud != null:
		var stats: Control = hud.get_node_or_null("StatsContainer") as Control
		if stats != null:
			stats.visible = true
		if hud.has_method("update_stats") and player != null:
			hud.call("update_stats", int(player.get("strength")), int(player.get("agility")), int(player.get("intelligence")))
