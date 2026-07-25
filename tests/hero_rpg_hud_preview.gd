extends Node

## Force-unlocks every purchasable HUD module so you can tune layout / bar polish
## with Player Health + Base Health + Stats + Wave + XP (+ Minimap) all visible.

const LEVEL_SCENE: PackedScene = preload("res://scenes/world/mine/level.tscn")

func _ready() -> void:
	Global.hero_p1 = "Nerubian"
	Global.current_hero = "Nerubian"
	Global.selected_hero_id = "Nerubian"
	var level: Node = LEVEL_SCENE.instantiate()
	add_child(level)

	# Let the level + HUD settle.
	for _index: int in range(10):
		await get_tree().physics_frame

	var player: CharacterBody2D = level.get_node_or_null("Player") as CharacterBody2D
	if player != null:
		player.set("level", 6)
		# Give readable sample health so the bars look filled.
		if player.get("max_health") != null:
			player.set("max_health", 120)
		if player.get("health") != null:
			player.set("health", 78)

	for _index: int in range(4):
		await get_tree().physics_frame

	var hud: Node = level.get_node_or_null("HUD")
	if hud == null:
		push_warning("hero_rpg_hud_preview: HUD not found")
		return

	# --- FORCE UNLOCK ALL INFORMATION MODULES ---
	if hud.has_method("unlock_healthbar"):
		hud.unlock_healthbar()
	if hud.has_method("unlock_base_healthbar"):
		hud.unlock_base_healthbar()
	if hud.has_method("unlock_stats"):
		hud.unlock_stats()
	if hud.has_method("unlock_wave_timer"):
		hud.unlock_wave_timer()
	if hud.has_method("unlock_xp"):
		hud.unlock_xp()
	if hud.has_method("unlock_minimap"):
		hud.unlock_minimap()

	# Mirror ownership flags on the upgrade menu so the tree shows them owned.
	var upgrade_menu: Node = level.get_node_or_null("UpgradeMenu")
	if upgrade_menu:
		upgrade_menu.set("healthbar_unlocked", true)
		upgrade_menu.set("base_health_unlocked", true)
		upgrade_menu.set("stats_unlocked", true)
		upgrade_menu.set("wave_timer_unlocked", true)
		upgrade_menu.set("xp_unlocked", true)
		upgrade_menu.set("minimap_unlocked", true)

	# Populate sample values so bars + labels are readable while you polish.
	if player and hud.has_method("update_player_health"):
		var max_hp: int = int(player.get("max_health")) if player.get("max_health") != null else 100
		var cur_hp: int = int(player.get("health")) if player.get("health") != null else 75
		hud.update_player_health(cur_hp, max_hp)
	if hud.has_method("update_health"):
		hud.update_health(68)  # base health sample
	if player and hud.has_method("update_stats"):
		hud.update_stats(
			int(player.get("strength")),
			int(player.get("agility")),
			int(player.get("intelligence"))
		)
	if hud.has_method("update_xp"):
		hud.update_xp(6, 420, 800)
	if hud.has_method("update_wave_info"):
		hud.update_wave_info(3, 18.0, 30.0, false)

	print("[HUD Preview] All modules force-unlocked — tweak layout in the running scene.")
