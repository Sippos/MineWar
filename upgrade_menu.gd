extends CanvasLayer

signal send_enemy(type: int)

@onready var hud = get_parent().get_node_or_null("HUD")
@onready var player = get_parent().get_node_or_null("Player")
@onready var panel: Control = $Panel

@onready var faction_title: Label = $Panel/Window/Margin/VBox/Body/FactionColumn/FactionTitle
@onready var buy_rail_row: Control = $Panel/Window/Margin/VBox/Body/FactionColumn/BuyRailRow
@onready var buy_rail_button: Button = $Panel/Window/Margin/VBox/Body/FactionColumn/BuyRailRow/BuyRail
@onready var buy_rail_cost: Label = $Panel/Window/Margin/VBox/Body/FactionColumn/BuyRailRow/Cost/CostLabel
@onready var buy_minecart_row: Control = $Panel/Window/Margin/VBox/Body/FactionColumn/BuyMinecartRow
@onready var buy_minecart_button: Button = $Panel/Window/Margin/VBox/Body/FactionColumn/BuyMinecartRow/BuyMinecart
@onready var buy_minecart_cost: Label = $Panel/Window/Margin/VBox/Body/FactionColumn/BuyMinecartRow/Cost/CostLabel
@onready var buy_peon_row: Control = $Panel/Window/Margin/VBox/Body/FactionColumn/BuyPeonRow
@onready var buy_peon_button: Button = $Panel/Window/Margin/VBox/Body/FactionColumn/BuyPeonRow/BuyPeon
@onready var buy_peon_cost: Label = $Panel/Window/Margin/VBox/Body/FactionColumn/BuyPeonRow/Cost/CostLabel
@onready var upgrade_spikes_button: Button = $Panel/Window/Margin/VBox/Body/FactionColumn/UpgradeSpikesRow/UpgradeSpikes
@onready var upgrade_spikes_cost: Label = $Panel/Window/Margin/VBox/Body/FactionColumn/UpgradeSpikesRow/Cost/CostLabel

@onready var unlock_healthbar_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockHealthbarRow/UnlockHealthbar
@onready var unlock_healthbar_cost: Label = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockHealthbarRow/Cost/CostLabel
@onready var unlock_base_health_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockBaseHealthRow/UnlockBaseHealth
@onready var unlock_base_health_cost: Label = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockBaseHealthRow/Cost/CostLabel
@onready var unlock_wave_timer_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockWaveTimerRow/UnlockWaveTimer
@onready var unlock_wave_timer_cost: Label = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockWaveTimerRow/Cost/CostLabel
@onready var unlock_xp_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockXPRow/UnlockXP
@onready var unlock_xp_cost: Label = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockXPRow/Cost/CostLabel
@onready var unlock_minimap_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockMinimapRow/UnlockMinimap
@onready var unlock_minimap_cost: Label = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockMinimapRow/Cost/CostLabel
@onready var upgrade_minimap_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/UpgradeMinimapRow/UpgradeMinimap
@onready var upgrade_minimap_cost: Label = $Panel/Window/Margin/VBox/Body/HUDColumn/UpgradeMinimapRow/Cost/CostLabel
@onready var upgrade_max_health_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/UpgradeMaxHealthRow/UpgradeMaxHealth
@onready var upgrade_max_health_cost: Label = $Panel/Window/Margin/VBox/Body/HUDColumn/UpgradeMaxHealthRow/Cost/CostLabel
@onready var heal_player_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/HealPlayerRow/HealPlayer
@onready var heal_player_cost: Label = $Panel/Window/Margin/VBox/Body/HUDColumn/HealPlayerRow/Cost/CostLabel

@onready var unlock_stats_button: Button = $Panel/Window/Margin/VBox/Body/StatsColumn/UnlockStatsRow/UnlockStats
@onready var unlock_stats_cost: Label = $Panel/Window/Margin/VBox/Body/StatsColumn/UnlockStatsRow/Cost/CostLabel
@onready var upgrade_strength_button: Button = $Panel/Window/Margin/VBox/Body/StatsColumn/UpgradeStrengthRow/UpgradeStrength
@onready var upgrade_strength_cost: Label = $Panel/Window/Margin/VBox/Body/StatsColumn/UpgradeStrengthRow/Cost/CostLabel
@onready var upgrade_agility_button: Button = $Panel/Window/Margin/VBox/Body/StatsColumn/UpgradeAgilityRow/UpgradeAgility
@onready var upgrade_agility_cost: Label = $Panel/Window/Margin/VBox/Body/StatsColumn/UpgradeAgilityRow/Cost/CostLabel
@onready var upgrade_intelligence_button: Button = $Panel/Window/Margin/VBox/Body/StatsColumn/UpgradeIntelligenceRow/UpgradeIntelligence
@onready var upgrade_intelligence_cost: Label = $Panel/Window/Margin/VBox/Body/StatsColumn/UpgradeIntelligenceRow/Cost/CostLabel

@onready var close_button: Button = $Panel/Window/Margin/VBox/Footer/Close

@onready var vs_prompt_panel: Panel = $VSPromptPanel
@onready var vs_upgrades_button: Button = $VSPromptPanel/Margin/VBox/UpgradesButton
@onready var vs_send_button: Button = $VSPromptPanel/Margin/VBox/SendButton
@onready var vs_close_button: Button = $VSPromptPanel/Margin/VBox/CloseButton

@onready var vs_send_panel: Panel = $VSSendPanel
@onready var vs_rat_button: Button = $VSSendPanel/Margin/VBox/RatButton
@onready var vs_spider_button: Button = $VSSendPanel/Margin/VBox/SpiderButton
@onready var vs_bat_button: Button = $VSSendPanel/Margin/VBox/BatButton
@onready var vs_trogg_button: Button = $VSSendPanel/Margin/VBox/TroggButton
@onready var vs_orc_button: Button = $VSSendPanel/Margin/VBox/OrcButton
@onready var vs_back_button: Button = $VSSendPanel/Margin/VBox/BackButton

var healthbar_unlocked := false
var base_health_unlocked := false
var stats_unlocked := false
var wave_timer_unlocked := false
var xp_unlocked := false
var minimap_unlocked := false
var minimap_upgraded := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_signals()
	hide_menu()

func _connect_signals() -> void:
	_connect_button(close_button, _on_close_pressed)
	_connect_button(buy_rail_button, _on_buy_rail_pressed)
	_connect_button(buy_minecart_button, _on_buy_minecart_pressed)
	_connect_button(buy_peon_button, _on_buy_peon_pressed)
	_connect_button(upgrade_spikes_button, _on_upgrade_spikes_pressed)

	_connect_button(unlock_healthbar_button, _on_unlock_healthbar_pressed)
	_connect_button(unlock_base_health_button, _on_unlock_base_health_pressed)
	_connect_button(unlock_wave_timer_button, _on_unlock_wave_timer_pressed)
	_connect_button(unlock_xp_button, _on_unlock_xp_pressed)
	_connect_button(unlock_minimap_button, _on_unlock_minimap_pressed)
	_connect_button(upgrade_minimap_button, _on_upgrade_minimap_pressed)
	_connect_button(upgrade_max_health_button, _on_upgrade_max_health_pressed)
	_connect_button(heal_player_button, _on_heal_player_pressed)

	_connect_button(unlock_stats_button, _on_unlock_stats_pressed)
	_connect_button(upgrade_strength_button, _on_upgrade_strength_pressed)
	_connect_button(upgrade_agility_button, _on_upgrade_agility_pressed)
	_connect_button(upgrade_intelligence_button, _on_upgrade_intelligence_pressed)

	_connect_button(vs_upgrades_button, _on_vs_upgrades_pressed)
	_connect_button(vs_send_button, _on_vs_send_pressed)
	_connect_button(vs_close_button, _on_close_pressed)
	_connect_button(vs_back_button, _on_vs_back_pressed)
	_connect_button(vs_rat_button, _on_send_rat)
	_connect_button(vs_spider_button, _on_send_spider)
	_connect_button(vs_bat_button, _on_send_bat)
	_connect_button(vs_trogg_button, _on_send_trogg)
	_connect_button(vs_orc_button, _on_send_orc)

func _connect_button(button: Button, callback: Callable) -> void:
	if button and not button.pressed.is_connected(callback):
		button.disabled = false
		button.pressed.connect(callback)

func _get_player_id() -> int:
	if get_parent() and get_parent().get("player_id") != null:
		return int(get_parent().get("player_id"))
	return 1

func _is_vs_mode() -> bool:
	return get_parent() and get_parent().get("is_vs_mode") == true

func _get_player_hero_name() -> String:
	if _get_player_id() == 2:
		return Global.hero_p2
	return Global.hero_p1

func get_upgrade_cost(stat_level: int) -> int:
	return max(1, (stat_level * 2) - 1)

func _can_spend_gems(amount: int) -> bool:
	return hud != null and hud.total_gems >= amount

func _can_spend_gold(amount: int) -> bool:
	return hud != null and hud.total_gold >= amount

func _spend_gems(amount: int) -> bool:
	if not _can_spend_gems(amount):
		return false
	hud.add_gems(-amount)
	return true

func _spend_gold(amount: int) -> bool:
	if not _can_spend_gold(amount):
		return false
	hud.add_gold(-amount)
	return true

func _set_button_enabled(button: Button, _enabled: bool) -> void:
	# Keep buttons visually opaque. Purchase methods still block if resources are missing.
	if button:
		button.disabled = false
		button.modulate = Color(1, 1, 1, 1)

func _set_cost(label: Label, amount: int) -> void:
	if label:
		label.text = str(amount)
		label.modulate = Color(1, 1, 1, 1)

func update_button_texts() -> void:
	if not hud or not player:
		return

	var hero_name := _get_player_hero_name()
	faction_title.text = "%s Faction" % hero_name

	var is_dwarf := hero_name == "Dwarf"
	var is_shaman := hero_name == "Shaman"
	buy_rail_row.visible = is_dwarf
	buy_minecart_row.visible = is_dwarf
	buy_peon_row.visible = is_shaman

	buy_rail_button.text = "Buy Rail"
	buy_minecart_button.text = "Buy Minecart"
	buy_peon_button.text = "Buy Peon"
	_set_cost(buy_rail_cost, 10)
	_set_cost(buy_minecart_cost, 50)
	_set_cost(buy_peon_cost, 30)
	_set_button_enabled(buy_rail_button, true)
	_set_button_enabled(buy_minecart_button, true)
	_set_button_enabled(buy_peon_button, true)

	var base = get_parent().get_node_or_null("Base")
	var spikes_level := 0
	if base:
		spikes_level = base.spikes_level
	upgrade_spikes_button.text = "Spikes Lv.%d" % spikes_level
	_set_cost(upgrade_spikes_cost, 20)
	_set_button_enabled(upgrade_spikes_button, true)

	unlock_healthbar_button.text = "Player HP"
	unlock_base_health_button.text = "Base HP"
	unlock_wave_timer_button.text = "Wave Timer"
	unlock_xp_button.text = "XP Bar"
	unlock_minimap_button.text = "Minimap"
	upgrade_minimap_button.text = "See Enemies"
	upgrade_max_health_button.text = "+20 Max HP"
	heal_player_button.text = "Heal +20 HP"
	_set_cost(unlock_healthbar_cost, 10)
	_set_cost(unlock_base_health_cost, 10)
	_set_cost(unlock_wave_timer_cost, 10)
	_set_cost(unlock_xp_cost, 10)
	_set_cost(unlock_minimap_cost, 20)
	_set_cost(upgrade_minimap_cost, 50)
	_set_cost(upgrade_max_health_cost, 15)
	_set_cost(heal_player_cost, 10)

	_set_button_enabled(unlock_healthbar_button, true)
	_set_button_enabled(unlock_base_health_button, true)
	_set_button_enabled(unlock_wave_timer_button, true)
	_set_button_enabled(unlock_xp_button, true)
	_set_button_enabled(unlock_minimap_button, true)
	_set_button_enabled(upgrade_minimap_button, true)
	_set_button_enabled(upgrade_max_health_button, true)
	_set_button_enabled(heal_player_button, true)

	var str_cost := get_upgrade_cost(player.strength)
	var agi_cost := get_upgrade_cost(player.agility)
	var int_cost := get_upgrade_cost(player.intelligence)
	upgrade_strength_button.text = "STR +1"
	upgrade_agility_button.text = "AGI +1"
	upgrade_intelligence_button.text = "INT +1"
	unlock_stats_button.text = "Show Stats"
	_set_cost(upgrade_strength_cost, str_cost)
	_set_cost(upgrade_agility_cost, agi_cost)
	_set_cost(upgrade_intelligence_cost, int_cost)
	_set_cost(unlock_stats_cost, 10)

	_set_button_enabled(upgrade_strength_button, true)
	_set_button_enabled(upgrade_agility_button, true)
	_set_button_enabled(upgrade_intelligence_button, true)
	_set_button_enabled(unlock_stats_button, true)

	vs_rat_button.text = "Rat - 5 Gold (+1 income)"
	vs_spider_button.text = "Spider - 10 Gold (+2 income)"
	vs_bat_button.text = "Bat - 15 Gold (+3 income)"
	vs_trogg_button.text = "Trogg - 20 Gold (+4 income)"
	vs_orc_button.text = "Orc - 25 Gold (+5 income)"
	_set_button_enabled(vs_rat_button, true)
	_set_button_enabled(vs_spider_button, true)
	_set_button_enabled(vs_bat_button, true)
	_set_button_enabled(vs_trogg_button, true)
	_set_button_enabled(vs_orc_button, true)

func show_menu() -> void:
	update_button_texts()
	if player:
		player.can_move = false

	if _is_vs_mode():
		panel.visible = false
		vs_send_panel.visible = false
		vs_prompt_panel.visible = true
		vs_upgrades_button.call_deferred("grab_focus")
	else:
		vs_prompt_panel.visible = false
		vs_send_panel.visible = false
		panel.visible = true
		buy_rail_button.call_deferred("grab_focus")

func hide_menu() -> void:
	panel.visible = false
	vs_prompt_panel.visible = false
	vs_send_panel.visible = false
	if player:
		player.can_move = true

func _on_close_pressed() -> void:
	hide_menu()

func _on_vs_upgrades_pressed() -> void:
	update_button_texts()
	vs_prompt_panel.visible = false
	vs_send_panel.visible = false
	panel.visible = true
	buy_rail_button.call_deferred("grab_focus")

func _on_vs_send_pressed() -> void:
	update_button_texts()
	vs_prompt_panel.visible = false
	panel.visible = false
	vs_send_panel.visible = true
	vs_rat_button.call_deferred("grab_focus")

func _on_vs_back_pressed() -> void:
	update_button_texts()
	vs_send_panel.visible = false
	vs_prompt_panel.visible = true
	vs_upgrades_button.call_deferred("grab_focus")

func _on_unlock_healthbar_pressed() -> void:
	if not healthbar_unlocked and _spend_gold(10):
		healthbar_unlocked = true
		hud.unlock_healthbar()
		update_button_texts()

func _on_unlock_base_health_pressed() -> void:
	if not base_health_unlocked and _spend_gold(10):
		base_health_unlocked = true
		hud.unlock_base_healthbar()
		update_button_texts()

func _on_unlock_stats_pressed() -> void:
	if not stats_unlocked and _spend_gold(10):
		stats_unlocked = true
		hud.unlock_stats()
		update_button_texts()

func _on_unlock_wave_timer_pressed() -> void:
	if not wave_timer_unlocked and _spend_gold(10):
		wave_timer_unlocked = true
		hud.unlock_wave_timer()
		update_button_texts()

func _on_unlock_xp_pressed() -> void:
	if not xp_unlocked and _spend_gold(10):
		xp_unlocked = true
		hud.unlock_xp()
		update_button_texts()

func _on_unlock_minimap_pressed() -> void:
	if not minimap_unlocked and _spend_gold(20):
		minimap_unlocked = true
		hud.unlock_minimap()
		update_button_texts()

func _on_upgrade_minimap_pressed() -> void:
	if minimap_unlocked and not minimap_upgraded and _spend_gold(50):
		minimap_upgraded = true
		hud.upgrade_minimap_enemies()
		update_button_texts()

func _on_upgrade_max_health_pressed() -> void:
	if _spend_gold(15):
		player.max_health += 20
		player.health += 20
		hud.update_player_health(player.health, player.max_health)
		update_button_texts()

func _on_upgrade_strength_pressed() -> void:
	var cost := get_upgrade_cost(player.strength)
	if _spend_gems(cost):
		player.upgrade_strength()
		hud.update_stats(player.strength, player.agility, player.intelligence)
		update_button_texts()

func _on_upgrade_agility_pressed() -> void:
	var cost := get_upgrade_cost(player.agility)
	if _spend_gems(cost):
		player.upgrade_agility()
		hud.update_stats(player.strength, player.agility, player.intelligence)
		update_button_texts()

func _on_upgrade_intelligence_pressed() -> void:
	var cost := get_upgrade_cost(player.intelligence)
	if _spend_gems(cost):
		player.upgrade_intelligence()
		hud.update_stats(player.strength, player.agility, player.intelligence)
		update_button_texts()

func _on_upgrade_spikes_pressed() -> void:
	if _spend_gold(20):
		var base = get_parent().get_node_or_null("Base")
		if base:
			base.spikes_level += 1
		update_button_texts()

func _on_heal_player_pressed() -> void:
	if player.health < player.max_health and _spend_gold(10):
		player.health = min(player.health + 20, player.max_health)
		hud.update_player_health(player.health, player.max_health)
		update_button_texts()

func _send_enemy(enemy_type: int, cost: int) -> void:
	if _spend_gold(cost):
		emit_signal("send_enemy", enemy_type)
		hide_menu()

func _on_send_rat() -> void:
	_send_enemy(0, 5)

func _on_send_spider() -> void:
	_send_enemy(1, 10)

func _on_send_bat() -> void:
	_send_enemy(2, 15)

func _on_send_trogg() -> void:
	_send_enemy(3, 20)

func _on_send_orc() -> void:
	_send_enemy(4, 25)

func _on_buy_rail_pressed() -> void:
	if _spend_gold(10):
		var base = get_parent().get_node_or_null("Base")
		if base and base.has_method("spawn_rail"):
			base.spawn_rail()
		update_button_texts()

func _on_buy_minecart_pressed() -> void:
	if _spend_gold(50):
		var base = get_parent().get_node_or_null("Base")
		if base and base.has_method("spawn_minecart"):
			base.spawn_minecart()
		update_button_texts()

func _on_buy_peon_pressed() -> void:
	if _spend_gold(30):
		var base = get_parent().get_node_or_null("Base")
		if base and base.has_method("spawn_peon"):
			base.spawn_peon()
		update_button_texts()
