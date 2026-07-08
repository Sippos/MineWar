extends CanvasLayer

signal send_enemy(type: int)

@onready var hud = get_parent().get_node_or_null("HUD")
@onready var player = get_parent().get_node_or_null("Player")
@onready var panel: Control = $Panel
@onready var upgrade_window: Control = $Panel/Window

@onready var swap_hero_button: Button = $Panel/Window/Margin/VBox/Body/FactionColumn/SwapHero
@onready var buy_rail_button: Button = $Panel/Window/Margin/VBox/Body/FactionColumn/BuyRail
@onready var buy_minecart_button: Button = $Panel/Window/Margin/VBox/Body/FactionColumn/BuyMinecart
@onready var buy_peon_button: Button = $Panel/Window/Margin/VBox/Body/FactionColumn/BuyPeon
@onready var upgrade_spikes_button: Button = $Panel/Window/Margin/VBox/Body/FactionColumn/UpgradeSpikes
@onready var faction_title: Label = $Panel/Window/Margin/VBox/Body/FactionColumn/FactionTitle

@onready var unlock_healthbar_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockHealthbar
@onready var unlock_base_health_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockBaseHealth
@onready var unlock_wave_timer_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockWaveTimer
@onready var unlock_xp_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockXP
@onready var unlock_minimap_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/UnlockMinimap
@onready var upgrade_minimap_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/UpgradeMinimap
@onready var upgrade_max_health_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/UpgradeMaxHealth
@onready var heal_player_button: Button = $Panel/Window/Margin/VBox/Body/HUDColumn/HealPlayer

@onready var unlock_stats_button: Button = $Panel/Window/Margin/VBox/Body/StatsColumn/UnlockStats
@onready var upgrade_strength_button: Button = $Panel/Window/Margin/VBox/Body/StatsColumn/UpgradeStrength
@onready var upgrade_agility_button: Button = $Panel/Window/Margin/VBox/Body/StatsColumn/UpgradeAgility
@onready var upgrade_intelligence_button: Button = $Panel/Window/Margin/VBox/Body/StatsColumn/UpgradeIntelligence

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
	_connect_button(swap_hero_button, _on_swap_hero_pressed)
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


func _set_player_hero_name(hero_name: String) -> void:
	if _get_player_id() == 2:
		Global.hero_p2 = hero_name
	else:
		Global.hero_p1 = hero_name
	Global.current_hero = hero_name


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


func _set_button_enabled(button: Button, enabled: bool) -> void:
	if button:
		button.disabled = not enabled


func update_button_texts() -> void:
	if not hud or not player:
		return

	var hero_name := _get_player_hero_name()
	faction_title.text = "%s Faction" % hero_name
	swap_hero_button.text = "Swap Hero\nCurrent: %s" % hero_name
	_set_button_enabled(swap_hero_button, Global.unlocked_heroes.size() > 1 or _is_vs_mode())

	var is_dwarf := hero_name == "Dwarf"
	var is_shaman := hero_name == "Shaman"
	buy_rail_button.visible = is_dwarf
	buy_minecart_button.visible = is_dwarf
	buy_peon_button.visible = is_shaman

	buy_rail_button.text = "Buy Rail\n10 Gold"
	buy_minecart_button.text = "Buy Minecart\n50 Gold"
	buy_peon_button.text = "Buy Peon\n30 Gold"
	_set_button_enabled(buy_rail_button, _can_spend_gold(10))
	_set_button_enabled(buy_minecart_button, _can_spend_gold(50))
	_set_button_enabled(buy_peon_button, _can_spend_gold(30))

	var base = get_parent().get_node_or_null("Base")
	var spikes_level := 0
	if base:
		spikes_level = base.spikes_level
	upgrade_spikes_button.text = "Spikes Lv.%d\n20 Gold" % spikes_level
	_set_button_enabled(upgrade_spikes_button, _can_spend_gold(20))

	unlock_healthbar_button.text = "Player HP\n10 Gold"
	unlock_base_health_button.text = "Base HP\n10 Gold"
	unlock_wave_timer_button.text = "Wave Timer\n10 Gold"
	unlock_xp_button.text = "XP Bar\n10 Gold"
	unlock_minimap_button.text = "Minimap\n20 Gold"
	upgrade_minimap_button.text = "See Enemies\n50 Gold"
	upgrade_max_health_button.text = "+20 Max HP\n15 Gold"
	heal_player_button.text = "Heal +20 HP\n10 Gold"

	_set_button_enabled(unlock_healthbar_button, not healthbar_unlocked and _can_spend_gold(10))
	_set_button_enabled(unlock_base_health_button, not base_health_unlocked and _can_spend_gold(10))
	_set_button_enabled(unlock_wave_timer_button, not wave_timer_unlocked and _can_spend_gold(10))
	_set_button_enabled(unlock_xp_button, not xp_unlocked and _can_spend_gold(10))
	_set_button_enabled(unlock_minimap_button, not minimap_unlocked and _can_spend_gold(20))
	_set_button_enabled(upgrade_minimap_button, minimap_unlocked and not minimap_upgraded and _can_spend_gold(50))
	_set_button_enabled(upgrade_max_health_button, _can_spend_gold(15))
	_set_button_enabled(heal_player_button, player.health < player.max_health and _can_spend_gold(10))

	var str_cost := get_upgrade_cost(player.strength)
	var agi_cost := get_upgrade_cost(player.agility)
	var int_cost := get_upgrade_cost(player.intelligence)
	upgrade_strength_button.text = "STR +1\n%d Gems" % str_cost
	upgrade_agility_button.text = "AGI +1\n%d Gems" % agi_cost
	upgrade_intelligence_button.text = "INT +1\n%d Gems" % int_cost
	unlock_stats_button.text = "Show Stats\n10 Gold"

	_set_button_enabled(upgrade_strength_button, _can_spend_gems(str_cost))
	_set_button_enabled(upgrade_agility_button, _can_spend_gems(agi_cost))
	_set_button_enabled(upgrade_intelligence_button, _can_spend_gems(int_cost))
	_set_button_enabled(unlock_stats_button, not stats_unlocked and _can_spend_gold(10))

	vs_rat_button.text = "Rat - 5 Gold (+1 income)"
	vs_spider_button.text = "Spider - 10 Gold (+2 income)"
	vs_bat_button.text = "Bat - 15 Gold (+3 income)"
	vs_trogg_button.text = "Trogg - 20 Gold (+4 income)"
	vs_orc_button.text = "Orc - 25 Gold (+5 income)"
	_set_button_enabled(vs_rat_button, _can_spend_gold(5))
	_set_button_enabled(vs_spider_button, _can_spend_gold(10))
	_set_button_enabled(vs_bat_button, _can_spend_gold(15))
	_set_button_enabled(vs_trogg_button, _can_spend_gold(20))
	_set_button_enabled(vs_orc_button, _can_spend_gold(25))


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
		swap_hero_button.call_deferred("grab_focus")


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
	swap_hero_button.call_deferred("grab_focus")


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


func _on_swap_hero_pressed() -> void:
	if Global.unlocked_heroes.is_empty():
		return

	var current_hero := _get_player_hero_name()
	var index := Global.unlocked_heroes.find(current_hero)
	if index < 0:
		index = 0
	var next_index := (index + 1) % Global.unlocked_heroes.size()
	_set_player_hero_name(Global.unlocked_heroes[next_index])

	if player and player.has_method("update_hero_sprites"):
		player.update_hero_sprites()
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
