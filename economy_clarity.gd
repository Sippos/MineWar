extends Node

const PANEL_NAME := "InvestmentPanel"
const MENU_BUTTON_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/Button.png")
const REFRESH_INTERVAL := 0.15

var active_world: Node = null
var active_menu: Node = null
var investment_panel: Control = null
var resource_label: Label = null
var hint_label: Label = null
var buttons := {}
var refresh_timer := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	var world := _find_single_player_world()
	if world != active_world:
		_bind_world(world)
	
	if active_world == null or not is_instance_valid(active_world):
		return
	
	var menu := active_world.get_node_or_null("UpgradeMenu")
	if menu != active_menu:
		active_menu = menu
		investment_panel = null
		buttons.clear()
		if active_menu:
			_unlock_core_information()
			call_deferred("_attach_investment_panel")
	
	if active_menu == null or investment_panel == null:
		return
	
	refresh_timer -= delta
	if refresh_timer <= 0.0:
		refresh_timer = REFRESH_INTERVAL
		_refresh_panel()

func _bind_world(world: Node) -> void:
	active_world = world
	active_menu = null
	investment_panel = null
	resource_label = null
	hint_label = null
	buttons.clear()
	refresh_timer = 0.0

func _find_single_player_world() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return _find_world_recursive(scene)

func _find_world_recursive(node: Node) -> Node:
	if _is_single_player_world(node):
		return node
	for child in node.get_children():
		var found := _find_world_recursive(child)
		if found:
			return found
	return null

func _is_single_player_world(node: Node) -> bool:
	if not node.has_node("HUD") or not node.has_node("Player") or not node.has_node("UpgradeMenu"):
		return false
	var is_vs = node.get("is_vs_mode")
	return is_vs != null and not bool(is_vs)

func _unlock_core_information() -> void:
	if active_world == null or active_menu == null:
		return
	var hud := active_world.get_node_or_null("HUD")
	if hud == null:
		return
	
	active_menu.set("healthbar_unlocked", true)
	active_menu.set("base_health_unlocked", true)
	active_menu.set("stats_unlocked", true)
	active_menu.set("wave_timer_unlocked", true)
	active_menu.set("xp_unlocked", true)
	
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

func _attach_investment_panel() -> void:
	if active_menu == null or not is_instance_valid(active_menu):
		return
	var root := active_menu.get_node_or_null("Panel")
	if root == null:
		return
	
	var existing := root.get_node_or_null(PANEL_NAME)
	if existing:
		investment_panel = existing
		return
	
	for child in root.get_children():
		if child.name not in ["MenuPanel", "Title", "Close"]:
			child.visible = false
	
	var title := root.get_node_or_null("Title")
	if title:
		title.text = "Choose Your Investment"
		title.offset_left = 350.0
		title.offset_right = 810.0
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var close := root.get_node_or_null("Close")
	if close:
		close.text = "Return to Mine"
		close.offset_left = 760.0
		close.offset_right = 940.0
	
	investment_panel = Control.new()
	investment_panel.name = PANEL_NAME
	investment_panel.position = Vector2(238, 76)
	investment_panel.size = Vector2(690, 410)
	root.add_child(investment_panel)
	
	resource_label = Label.new()
	resource_label.name = "Resources"
	resource_label.position = Vector2(0, 0)
	resource_label.size = Vector2(690, 30)
	resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resource_label.add_theme_font_size_override("font_size", 21)
	resource_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55, 1.0))
	investment_panel.add_child(resource_label)
	
	hint_label = Label.new()
	hint_label.name = "Hint"
	hint_label.position = Vector2(0, 28)
	hint_label.size = Vector2(690, 26)
	hint_label.text = "Gems shape your hero. Gold buys survival, scouting, and infrastructure."
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.82, 0.76, 0.66, 1.0))
	investment_panel.add_child(hint_label)
	
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.position = Vector2(0, 62)
	columns.size = Vector2(690, 338)
	columns.add_theme_constant_override("separation", 15)
	investment_panel.add_child(columns)
	
	var hero_column := _create_column(columns, "HERO POWER")
	_add_action_button(hero_column, "strength", "Strength +1", "Basic damage, +6 health, regeneration, carrying, and primary-attribute damage")
	_add_action_button(hero_column, "agility", "Agility +1", "+3.5% attack speed, movement, armor, and a smaller mining bonus")
	_add_action_button(hero_column, "intelligence", "Intelligence +1", "Spell and summon power, shorter cooldowns, and longer effects")
	
	var survival_column := _create_column(columns, "SURVIVAL")
	_add_action_button(survival_column, "max_health", "Fortify Hero", "+20 maximum health")
	_add_action_button(survival_column, "heal", "Field Treatment", "Restore 20 health")
	_add_action_button(survival_column, "scouting", "Mine Scouting", "Unlock map, then enemy tracking")
	
	var faction_column := _create_column(columns, "FACTION ECONOMY")
	_add_action_button(faction_column, "peon", "Recruit Peon", "Automates reachable gem delivery")
	_add_action_button(faction_column, "rail", "Build Rail", "Extends Dwarf mine infrastructure")
	_add_action_button(faction_column, "minecart", "Deploy Minecart", "High-cost Dwarf logistics")
	
	_refresh_panel()

func _create_column(parent: HBoxContainer, title_text: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(220, 330)
	column.add_theme_constant_override("separation", 9)
	parent.add_child(column)
	
	var title := Label.new()
	title.text = title_text
	title.custom_minimum_size = Vector2(220, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.5, 1.0))
	column.add_child(title)
	return column

func _add_action_button(parent: VBoxContainer, action: String, title_text: String, description: String) -> void:
	var button := Button.new()
	button.name = action.capitalize().replace(" ", "")
	button.custom_minimum_size = Vector2(220, 82)
	button.text = "%s\n%s" % [title_text, description]
	button.tooltip_text = description
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _make_button_style())
	button.add_theme_stylebox_override("hover", _make_button_style())
	button.add_theme_stylebox_override("pressed", _make_button_style())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(Callable(self, "_activate_action").bind(action))
	parent.add_child(button)
	buttons[action] = button

func _make_button_style() -> StyleBox:
	if MENU_BUTTON_TEXTURE:
		var style := StyleBoxTexture.new()
		style.texture = MENU_BUTTON_TEXTURE
		return style
	var fallback := StyleBoxFlat.new()
	fallback.bg_color = Color(0.18, 0.1, 0.04, 0.94)
	fallback.border_color = Color(0.72, 0.48, 0.18, 1.0)
	fallback.set_border_width_all(2)
	fallback.set_corner_radius_all(6)
	return fallback

func _refresh_panel() -> void:
	if active_world == null or active_menu == null or investment_panel == null:
		return
	var hud := active_world.get_node_or_null("HUD")
	var player := active_world.get_node_or_null("Player")
	if hud == null or player == null:
		return
	
	var gold := int(hud.get("total_gold"))
	var gems := int(hud.get("total_gems"))
	resource_label.text = "GOLD  %d     •     GEMS  %d" % [gold, gems]
	
	_update_stat_button("strength", int(player.get("strength")), gems, "Strength")
	_update_stat_button("agility", int(player.get("agility")), gems, "Agility")
	_update_intelligence_button(player, gems)
	_update_gold_button("max_health", 15, gold, "Fortify Hero", "+20 maximum health")
	_update_heal_button(player, gold)
	_update_scouting_button(hud, gold)
	_update_faction_buttons(player, gold)

func _stat_cost(level: int) -> int:
	return (level * 2) - 1

func _stat_description(action: String) -> String:
	match action:
		"strength":
			return "Damage/stomp +1 free carry every 3 STR"
		"agility":
			return "Faster movement, attacks, and digging"
		"intelligence":
			return "Stronger/faster abilities and brood recovery"
	return ""

func _update_stat_button(action: String, level: int, gems: int, display_name: String) -> void:
	var button: Button = buttons.get(action)
	if button == null:
		return
	var cost := _stat_cost(level)
	button.visible = true
	button.disabled = gems < cost
	button.text = "%s +1   •   %d Gems\n%s — level %d" % [display_name, cost, _stat_description(action), level]
	button.tooltip_text = _stat_description(action)

func _update_intelligence_button(player: Node, gems: int) -> void:
	var button: Button = buttons.get("intelligence")
	if button == null:
		return
	var hero := str(player.get("current_hero_name"))
	button.visible = hero == "Nerubian"
	if not button.visible:
		return
	var level := int(player.get("intelligence"))
	var cost := _stat_cost(level)
	button.disabled = gems < cost
	button.text = "Intelligence +1   •   %d Gems\n%s — level %d" % [cost, _stat_description("intelligence"), level]
	button.tooltip_text = _stat_description("intelligence")

func _update_gold_button(action: String, cost: int, gold: int, title_text: String, description: String) -> void:
	var button: Button = buttons.get(action)
	if button == null:
		return
	button.visible = true
	button.disabled = gold < cost
	button.text = "%s   •   %d Gold\n%s" % [title_text, cost, description]

func _update_heal_button(player: Node, gold: int) -> void:
	var button: Button = buttons.get("heal")
	if button == null:
		return
	var current := int(player.get("health"))
	var maximum := int(player.get("max_health"))
	button.visible = true
	button.disabled = gold < 10 or current >= maximum
	if current >= maximum:
		button.text = "Field Treatment\nAlready at full health"
	else:
		button.text = "Field Treatment   •   10 Gold\nRestore 20 health (%d / %d)" % [current, maximum]

func _update_scouting_button(hud: Node, gold: int) -> void:
	var button: Button = buttons.get("scouting")
	if button == null:
		return
	var minimap_unlocked := bool(active_menu.get("minimap_unlocked"))
	var minimap_upgraded := bool(active_menu.get("minimap_upgraded"))
	button.visible = true
	if minimap_upgraded:
		button.disabled = true
		button.text = "Mine Scouting\nEnemy tracking active"
	elif minimap_unlocked:
		button.disabled = gold < 50
		button.text = "Track Enemies   •   50 Gold\nReveal enemies on the minimap"
	else:
		button.disabled = gold < 20
		button.text = "Unlock Minimap   •   20 Gold\nSee explored tunnels and positions"

func _update_faction_buttons(player: Node, gold: int) -> void:
	var hero := str(player.get("current_hero_name"))
	var peon: Button = buttons.get("peon")
	var rail: Button = buttons.get("rail")
	var minecart: Button = buttons.get("minecart")
	
	peon.visible = hero == "Shaman"
	rail.visible = hero == "Dwarf"
	minecart.visible = hero == "Dwarf"
	
	if peon.visible:
		peon.disabled = gold < 30
		peon.text = "Recruit Peon   •   30 Gold\nAutomates reachable gem delivery"
	if rail.visible:
		rail.disabled = gold < 10
		rail.text = "Build Rail   •   10 Gold\nPlace new mine infrastructure"
	if minecart.visible:
		minecart.disabled = gold < 50
		minecart.text = "Deploy Minecart   •   50 Gold\nAutomate rail-based hauling"
	
	var no_faction_choices := hero != "Dwarf" and hero != "Shaman"
	if no_faction_choices:
		peon.visible = true
		peon.disabled = true
		peon.text = "Brood Economy\nNerubian spiders are ability-driven"

func _activate_action(action: String) -> void:
	if active_menu == null or not is_instance_valid(active_menu):
		return
	match action:
		"strength":
			active_menu.call("_on_upgrade_strength_pressed")
		"agility":
			active_menu.call("_on_upgrade_agility_pressed")
		"intelligence":
			active_menu.call("_on_upgrade_intelligence_pressed")
		"max_health":
			active_menu.call("_on_upgrade_max_health_pressed")
		"heal":
			active_menu.call("_on_heal_player_pressed")
		"scouting":
			if bool(active_menu.get("minimap_unlocked")):
				active_menu.call("_on_upgrade_minimap_pressed")
			else:
				active_menu.call("_on_unlock_minimap_pressed")
		"peon":
			active_menu.call("_on_buy_peon_pressed")
		"rail":
			active_menu.call("_on_buy_rail_pressed")
		"minecart":
			active_menu.call("_on_buy_minecart_pressed")
	refresh_timer = 0.0
