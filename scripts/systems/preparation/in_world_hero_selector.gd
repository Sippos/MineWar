extends Node

const HERO_ORDER: Array[String] = ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King", "Mech"]
const HERO_TEXTURES := {
	"Dwarf": preload("res://character_sprites/hero_idle/dwarf_idle_front.png"),
	"Shaman": preload("res://character_sprites/hero_idle/shaman_idle_front.png"),
	"Nerubian": preload("res://character_sprites/hero_idle/nerubian_idle_front.png"),
	"Druid": preload("res://character_sprites/hero_idle/druid_idle_front.png"),
	"Undead King": preload("res://character_sprites/hero_idle/undead_king_idle_front.png"),
	"Mech": preload("res://character_sprites/hero_idle/mech_idle_front.png"),
}
const HERO_POSITIONS := {
	"Dwarf": Vector2(-265, -120),
	"Shaman": Vector2(0, -175),
	"Nerubian": Vector2(265, -120),
	"Druid": Vector2(-225, 145),
	"Undead King": Vector2(225, 145),
	"Mech": Vector2(350, 65),
}
const HERO_CARD_SIDE := {
	"Dwarf": 1.0,
	"Shaman": 1.0,
	"Nerubian": -1.0,
	"Druid": 1.0,
	"Undead King": -1.0,
	"Mech": -1.0,
}
const HERO_CARD_DATA := {
	"Dwarf": {
		"role": "FRONTLINE MINER",
		"description": "A durable brawler who controls crowds and breaks open dangerous ground.",
		"accent": Color(1.0, 0.61, 0.18, 1.0),
		"abilities": [
			{"icon": preload("res://ability_icons/generated/Dwarf_GroundStomp.png"), "title": "Ground Stomp", "description": "Area damage and stun"},
			{"icon": preload("res://ability_icons/generated/Dwarf_ThrowingHammer.png"), "title": "Throwing Hammer", "description": "Ranged stun that breaks blocks"},
			{"icon": preload("res://ability_icons/generated/Dwarf_DwarvenBash.png"), "title": "Dwarven Bash", "description": "Every third strike is empowered"},
			{"icon": preload("res://ability_icons/generated/Dwarf_Avatar.png"), "title": "Avatar", "description": "Level 6 combat transformation"},
		],
	},
	"Shaman": {
		"role": "TOTEM SUPPORT",
		"description": "A flexible spellcaster who shapes the mine with utility totems and chain magic.",
		"accent": Color(0.34, 0.88, 1.0, 1.0),
		"abilities": [
			{"icon": preload("res://ability_icons/generated/Shaman_TotemWheel.png"), "title": "Totem Wheel", "description": "Dig, heal, radar, or gem support"},
			{"icon": preload("res://ability_icons/generated/Shaman_ChainLighting.png"), "title": "Chain Lightning", "description": "Lightning jumps between enemies"},
			{"icon": preload("res://ability_icons/generated/Shaman_AncestralWisdom.png"), "title": "Ancestral Wisdom", "description": "Improves totems and Intelligence"},
			{"icon": preload("res://ability_icons/generated/Shaman_AncestralAscendence.png"), "title": "Ascendance", "description": "Level 6 all-totem form"},
		],
	},
	"Nerubian": {
		"role": "BROOD COMMANDER",
		"description": "A summoner who controls tunnels with webs and a growing spider brood.",
		"accent": Color(0.72, 0.38, 1.0, 1.0),
		"abilities": [
			{"icon": preload("res://ability_icons/generated/Nerubian_SpwanBreed.png"), "title": "Spawn Brood", "description": "Summon mining spider minions"},
			{"icon": preload("res://ability_icons/generated/Nerubian_WebBurst.png"), "title": "Web Burst", "description": "Damage, root, and slow enemies"},
			{"icon": preload("res://ability_icons/generated/Nerubian_ChitinousCarapace.png"), "title": "Chitinous Carapace", "description": "Health and regeneration"},
			{"icon": preload("res://ability_icons/generated/Nerubian_BroodmothersCall.png"), "title": "Broodmother's Call", "description": "Level 6 full-brood assault"},
		],
	},
	"Druid": {
		"role": "TUNNEL SPECIALIST",
		"description": "A mobile explorer who changes form and creates shortcuts through the earth.",
		"accent": Color(0.42, 1.0, 0.48, 1.0),
		"abilities": [
			{"icon": preload("res://ability_icons/generated/Druid_MoleForm.png"), "title": "Mole Form", "description": "Alternate high-speed digging form"},
			{"icon": preload("res://ability_icons/generated/Druid_BurrowTunnel.png"), "title": "Burrow Tunnel", "description": "Place linked tunnel entrances"},
			{"icon": preload("res://ability_icons/generated/Druid_DeepRoot.png"), "title": "Deep Roots", "description": "Health and natural recovery"},
			{"icon": preload("res://ability_icons/generated/Druid_WorldrootPassage.png"), "title": "Worldroot Passage", "description": "Return instantly through the roots"},
		],
	},
	"Undead King": {
		"role": "UNDEAD OVERLORD",
		"description": "A deliberate commander who turns fallen enemies into an advancing army.",
		"accent": Color(0.52, 0.72, 1.0, 1.0),
		"abilities": [
			{"icon": preload("res://ability_icons/generated/UndeadKing_RaiseDead.png"), "title": "Raise Dead", "description": "Summon an undead minion"},
			{"icon": preload("res://ability_icons/generated/UndeadKing_GraveMight.png"), "title": "Grave Might", "description": "Strengthen the undead host"},
			{"icon": preload("res://ability_icons/generated/UndeadKing_SoulHarvest.png"), "title": "Soul Harvest", "description": "Gain power from fallen souls"},
			{"icon": preload("res://ability_icons/generated/UndeadKing_DeathMarch.png"), "title": "Death March", "description": "Level 6 army transformation"},
		],
	},
	"Mech": {
		"role": "CAPTURED SIEGE WALKER",
		"description": "The defeated war machine returns as a heavy miner whose pilot can eject and rebuild the frame at the bastion.",
		"accent": Color(1.0, 0.46, 0.16, 1.0),
		"abilities": [
			{"icon": preload("res://character_sprites/hero_idle/mech_idle_front.png"), "title": "Armored Chassis", "description": "High health and frontline durability"},
			{"icon": preload("res://character_sprites/hero_idle/mech_idle_front.png"), "title": "Mining Servos", "description": "Heavy frame with fast base digging"},
			{"icon": preload("res://character_sprites/hero_idle/mech_idle_front.png"), "title": "Emergency Ejection", "description": "Pilot escapes when the frame is destroyed"},
			{"icon": preload("res://character_sprites/hero_idle/mech_idle_front.png"), "title": "Field Rebuild", "description": "Reach the bastion to restore the Mech"},
		],
	},
}

const CARD_REVEAL_DISTANCE := 132.0
const INTERACT_DISTANCE := 46.0
const CARD_SIZE := Vector2(380, 450)
const CARD_TOP_SAFE := 86.0
const CARD_BOTTOM_SAFE := 78.0

@export var world_path: NodePath = NodePath("../Level")

var world: Node2D
var player: CharacterBody2D
var shrine_root: Node2D
var hero_nodes: Dictionary = {}
var nearby_hero := ""
var nearby_distance := 99999.0
var nearby_can_interact := false
var last_auto_zone := ""

var card_layer: CanvasLayer
var card: PanelContainer
var card_portrait: TextureRect
var card_title: Label
var card_role: Label
var card_description: Label
var card_state: Label
var card_ability_list: VBoxContainer
var card_action_panel: PanelContainer
var card_action: Label
var card_visible_for := ""
var card_tween: Tween

func _ready() -> void:
	world = get_node_or_null(world_path) as Node2D
	if world == null:
		push_error("In-world hero selector could not find the preparation world")
		return
	player = world.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		push_error("In-world hero selector could not find Player")
		return
	_build_hero_shrines()
	_build_proximity_card()
	_refresh_shrines()
	call_deferred("_animate_newly_unlocked_shrines")
	get_tree().root.size_changed.connect(_update_card_position)

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	
	if not GameMode.is_hub():
		if shrine_root and shrine_root.visible:
			shrine_root.visible = false
			_hide_card()
		return
	elif shrine_root and not shrine_root.visible:
		shrine_root.visible = true

	var closest := ""
	var closest_distance := CARD_REVEAL_DISTANCE
	for hero_name in HERO_ORDER:
		if not hero_nodes.has(hero_name):
			continue
		var shrine: Node2D = hero_nodes[hero_name]["root"]
		var distance: float = player.global_position.distance_to(shrine.global_position)
		if distance <= closest_distance:
			closest = hero_name
			closest_distance = distance
	var can_interact: bool = not closest.is_empty() and closest_distance <= INTERACT_DISTANCE
	if closest != nearby_hero or can_interact != nearby_can_interact:
		nearby_hero = closest
		nearby_distance = closest_distance
		nearby_can_interact = can_interact
		_refresh_shrines()
		_set_card_hero(nearby_hero)
	else:
		nearby_distance = closest_distance
	if not nearby_hero.is_empty():
		_update_card_position()
	if can_interact and closest != last_auto_zone:
		last_auto_zone = closest
		if _hero_unlocked(closest):
			_select_hero(closest)
		else:
			_show_locked_feedback(closest)
	elif not can_interact:
		last_auto_zone = ""

func _unhandled_input(event: InputEvent) -> void:
	if nearby_hero.is_empty() or not nearby_can_interact or not event.is_action_pressed("p1_interact"):
		return
	get_viewport().set_input_as_handled()
	if not _hero_unlocked(nearby_hero):
		_show_locked_feedback(nearby_hero)
		return
	_select_hero(nearby_hero)

func _compact_hero_choices() -> Array[String]:
	var choices: Array[String] = []
	# A fresh stronghold needs no shrine for the hero already equipped. The first
	# real unlock introduces a compact current-vs-alternative choice.
	if Global.unlocked_heroes.size() <= 1:
		return choices
	_add_compact_choice(choices, str(Global.selected_hero_id))
	var newly_unlocked: Array = world.get_meta("newly_unlocked_heroes", []) if world != null else []
	for index in range(newly_unlocked.size() - 1, -1, -1):
		_add_compact_choice(choices, str(newly_unlocked[index]))
	for index in range(Global.unlocked_heroes.size() - 1, -1, -1):
		_add_compact_choice(choices, str(Global.unlocked_heroes[index]))
		if choices.size() >= 2:
			break
	return choices

func _add_compact_choice(choices: Array[String], hero_name: String) -> void:
	if choices.size() >= 2 or hero_name.is_empty() or choices.has(hero_name):
		return
	if not _hero_unlocked(hero_name):
		return
	choices.append(hero_name)

func _build_hero_shrines() -> void:
	# A fresh save already has its starting Dwarf. Keep the first room focused on
	# the actual character and bastion; the physical hero gallery appears only
	# after the first completed MineWars expedition.
	if not Global.first_level_beaten:
		return
	shrine_root = Node2D.new()
	shrine_root.name = "PhysicalHeroShrines"
	shrine_root.z_index = 12
	world.add_child(shrine_root)
	var visible_choices := _compact_hero_choices()
	var compact_positions := [Vector2(-205, -62), Vector2(205, -62)]
	for choice_index in range(visible_choices.size()):
		var hero_name: String = visible_choices[choice_index]
		var root := Node2D.new()
		root.name = hero_name.replace(" ", "") + "Shrine"
		root.position = compact_positions[choice_index]
		shrine_root.add_child(root)

		var glow := Polygon2D.new()
		glow.name = "Glow"
		glow.position = Vector2(0, 20)
		glow.polygon = PackedVector2Array([
			Vector2(-28, 0), Vector2(-24, -14), Vector2(-14, -24), Vector2(0, -28),
			Vector2(14, -24), Vector2(24, -14), Vector2(28, 0), Vector2(24, 14),
			Vector2(14, 24), Vector2(0, 28), Vector2(-14, 24), Vector2(-24, 14),
		])
		root.add_child(glow)

		var pedestal := Polygon2D.new()
		pedestal.name = "Pedestal"
		pedestal.position = Vector2(0, 20)
		pedestal.polygon = PackedVector2Array([
			Vector2(-25, 0), Vector2(-21, -12), Vector2(-12, -21), Vector2(0, -25),
			Vector2(12, -21), Vector2(21, -12), Vector2(25, 0), Vector2(21, 12),
			Vector2(12, 21), Vector2(0, 25), Vector2(-12, 21), Vector2(-21, 12),
		])
		root.add_child(pedestal)

		var pedestal_edge := Line2D.new()
		pedestal_edge.name = "PedestalEdge"
		pedestal_edge.position = Vector2(0, 20)
		pedestal_edge.points = PackedVector2Array([
			Vector2(-25, 0), Vector2(-21, -12), Vector2(-12, -21), Vector2(0, -25),
			Vector2(12, -21), Vector2(21, -12), Vector2(25, 0), Vector2(21, 12),
			Vector2(12, 21), Vector2(0, 25), Vector2(-12, 21), Vector2(-21, 12), Vector2(-25, 0),
		])
		pedestal_edge.width = 2.0
		root.add_child(pedestal_edge)

		var sprite := Sprite2D.new()
		sprite.name = "Hero"
		sprite.texture = HERO_TEXTURES[hero_name]
		sprite.position = Vector2(0, -22)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var texture_size: Vector2 = sprite.texture.get_size()
		var scale_factor := 62.0 / maxf(texture_size.y, 1.0)
		sprite.scale = Vector2(scale_factor, scale_factor)
		root.add_child(sprite)

		var name_label := Label.new()
		name_label.name = "Name"
		name_label.position = Vector2(-72, 48)
		name_label.size = Vector2(144, 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 9)
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.add_theme_constant_override("outline_size", 4)
		root.add_child(name_label)

		hero_nodes[hero_name] = {
			"root": root,
			"sprite": sprite,
			"pedestal": pedestal,
			"edge": pedestal_edge,
			"glow": glow,
			"name": name_label,
		}

func _build_proximity_card() -> void:
	card_layer = CanvasLayer.new()
	card_layer.name = "HeroOverflowCardLayer"
	card_layer.layer = 28
	add_child(card_layer)

	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_layer.add_child(overlay)

	card = PanelContainer.new()
	card.name = "HeroOverflowCard"
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	overlay.add_child(card)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 5)
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.custom_minimum_size = Vector2(0, 84)
	header.add_theme_constant_override("separation", 10)
	body.add_child(header)

	var portrait_frame := PanelContainer.new()
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.custom_minimum_size = Vector2(84, 84)
	portrait_frame.add_theme_stylebox_override("panel", _flat_style(Color(0.02, 0.025, 0.035, 0.98), Color(0.35, 0.48, 0.62, 0.9), 2, 8))
	header.add_child(portrait_frame)

	card_portrait = TextureRect.new()
	card_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_frame.add_child(card_portrait)

	var heading_box := VBoxContainer.new()
	heading_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_box.add_theme_constant_override("separation", 0)
	header.add_child(heading_box)

	card_title = Label.new()
	card_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_title.add_theme_font_size_override("font_size", 26)
	card_title.add_theme_color_override("font_outline_color", Color.BLACK)
	card_title.add_theme_constant_override("outline_size", 3)
	heading_box.add_child(card_title)

	card_role = Label.new()
	card_role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_role.add_theme_font_size_override("font_size", 15)
	heading_box.add_child(card_role)

	card_state = Label.new()
	card_state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_state.add_theme_font_size_override("font_size", 15)
	heading_box.add_child(card_state)

	card_description = Label.new()
	card_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_description.custom_minimum_size = Vector2(0, 34)
	card_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_description.add_theme_font_size_override("font_size", 15)
	card_description.add_theme_color_override("font_color", Color(0.78, 0.83, 0.89, 1.0))
	body.add_child(card_description)

	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(separator)

	var abilities_heading := Label.new()
	abilities_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	abilities_heading.text = "ABILITIES"
	abilities_heading.add_theme_font_size_override("font_size", 14)
	abilities_heading.add_theme_color_override("font_color", Color(0.68, 0.77, 0.86, 1.0))
	body.add_child(abilities_heading)

	card_ability_list = VBoxContainer.new()
	card_ability_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_ability_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_ability_list.add_theme_constant_override("separation", 3)
	body.add_child(card_ability_list)

	card_action_panel = PanelContainer.new()
	card_action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_action_panel.custom_minimum_size = Vector2(0, 34)
	body.add_child(card_action_panel)

	card_action = Label.new()
	card_action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_action.add_theme_font_size_override("font_size", 15)
	card_action.add_theme_color_override("font_outline_color", Color.BLACK)
	card_action.add_theme_constant_override("outline_size", 3)
	card_action_panel.add_child(card_action)

func _refresh_shrines() -> void:
	for hero_name in HERO_ORDER:
		if not hero_nodes.has(hero_name):
			continue
		var data: Dictionary = hero_nodes[hero_name]
		var unlocked: bool = _hero_unlocked(hero_name)
		var selected: bool = Global.selected_hero_id == hero_name
		var nearby: bool = nearby_hero == hero_name
		var sprite: Sprite2D = data["sprite"]
		var pedestal: Polygon2D = data["pedestal"]
		var edge: Line2D = data["edge"]
		var glow: Polygon2D = data["glow"]
		var name_label: Label = data["name"]
		var accent: Color = HERO_CARD_DATA[hero_name]["accent"]
		sprite.modulate = Color.WHITE if unlocked else Color(0.09, 0.1, 0.13, 0.84)
		pedestal.color = Color(0.17, 0.105, 0.028, 0.98) if selected else Color(0.055, 0.07, 0.095, 0.98)
		edge.default_color = accent if selected or nearby else Color(0.23, 0.32, 0.42, 0.8)
		edge.width = 4.0 if selected else (3.0 if nearby else 2.0)
		glow.color = Color(accent.r, accent.g, accent.b, 0.52) if selected else (Color(accent.r, accent.g, accent.b, 0.38) if nearby else Color(0.18, 0.48, 0.66, 0.16))
		name_label.text = "%s  •  ACTIVE" % hero_name if selected else (hero_name if unlocked else "%s  •  DORMANT" % hero_name)
		name_label.add_theme_color_override("font_color", accent if selected else (Color(0.82, 0.91, 1.0, 1.0) if unlocked else Color(0.38, 0.42, 0.48, 1.0)))

func _set_card_hero(hero_name: String) -> void:
	if hero_name.is_empty():
		_hide_card()
		return
	card_visible_for = hero_name
	_refresh_card(hero_name)
	_update_card_position()
	if card_tween and card_tween.is_running():
		card_tween.kill()
	card.visible = true
	card.pivot_offset = CARD_SIZE * 0.5
	card.modulate = Color(1, 1, 1, 0)
	card.scale = Vector2(0.85, 0.85)
	card_tween = create_tween().set_parallel(true)
	card_tween.tween_property(card, "modulate", Color.WHITE, 0.14)
	card_tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_card() -> void:
	card_visible_for = ""
	if card == null or not card.visible:
		return
	if card_tween and card_tween.is_running():
		card_tween.kill()
	card_tween = create_tween().set_parallel(true)
	card_tween.tween_property(card, "modulate:a", 0.0, 0.1)
	card_tween.tween_property(card, "scale", Vector2(0.9, 0.9), 0.1)
	card_tween.chain().tween_callback(func():
		if card_visible_for.is_empty() and is_instance_valid(card):
			card.visible = false
	)

func _refresh_card(hero_name: String) -> void:
	if hero_name.is_empty() or not HERO_CARD_DATA.has(hero_name):
		return
	var hero_data: Dictionary = HERO_CARD_DATA[hero_name]
	var accent: Color = hero_data["accent"]
	var unlocked: bool = _hero_unlocked(hero_name)
	var selected: bool = Global.selected_hero_id == hero_name
	card.add_theme_stylebox_override("panel", _card_style(accent, unlocked, selected))
	card_portrait.texture = HERO_TEXTURES[hero_name]
	card_portrait.modulate = Color.WHITE if unlocked else Color(0.16, 0.17, 0.2, 0.9)
	card_title.text = hero_name.to_upper()
	card_title.add_theme_color_override("font_color", accent if unlocked else Color(0.48, 0.52, 0.58, 1.0))
	card_role.text = str(hero_data.get("role", "HERO"))
	card_role.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.92) if unlocked else Color(0.42, 0.46, 0.52, 1.0))
	card_description.text = str(hero_data.get("description", ""))
	card_description.modulate = Color.WHITE if unlocked else Color(0.55, 0.57, 0.62, 1.0)
	if selected:
		card_state.text = "CURRENT HERO"
		card_state.add_theme_color_override("font_color", Color(1.0, 0.84, 0.38, 1.0))
	elif unlocked:
		card_state.text = "AWAKENED"
		card_state.add_theme_color_override("font_color", Color(0.56, 1.0, 0.66, 1.0))
	else:
		card_state.text = "DORMANT  •  LOCKED"
		card_state.add_theme_color_override("font_color", Color(0.62, 0.46, 0.46, 1.0))

	for child in card_ability_list.get_children():
		card_ability_list.remove_child(child)
		child.queue_free()
	var abilities: Array = hero_data.get("abilities", [])
	for ability_value in abilities:
		var ability: Dictionary = ability_value
		card_ability_list.add_child(_make_ability_row(ability, unlocked, accent))

	if not unlocked:
		card_action.text = "DORMANT  •  COMPLETE MORE MINEWARS VICTORIES"
		card_action.add_theme_color_override("font_color", Color(1.0, 0.5, 0.42, 1.0))
		card_action_panel.add_theme_stylebox_override("panel", _flat_style(Color(0.16, 0.035, 0.028, 0.96), Color(0.82, 0.24, 0.18, 0.94), 2, 7))
	elif selected:
		card_action.text = "SELECTED  •  THIS HERO WILL ENTER THE ROUTE"
		card_action.add_theme_color_override("font_color", Color(1.0, 0.85, 0.42, 1.0))
		card_action_panel.add_theme_stylebox_override("panel", _flat_style(Color(0.14, 0.085, 0.02, 0.96), Color(1.0, 0.62, 0.15, 0.94), 2, 7))
	elif nearby_can_interact:
		card_action.text = "STEP ON THE RUNE TO CHOOSE"
		card_action.add_theme_color_override("font_color", Color(0.72, 0.96, 1.0, 1.0))
		card_action_panel.add_theme_stylebox_override("panel", _flat_style(Color(0.02, 0.105, 0.15, 0.96), Color(0.24, 0.76, 1.0, 0.94), 2, 7))
	else:
		card_action.text = "APPROACH THE HERO RUNE"
		card_action.add_theme_color_override("font_color", Color(0.7, 0.78, 0.86, 1.0))
		card_action_panel.add_theme_stylebox_override("panel", _flat_style(Color(0.035, 0.055, 0.075, 0.96), Color(0.28, 0.4, 0.52, 0.9), 2, 7))

func _make_ability_row(ability: Dictionary, unlocked: bool, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, 42)
	row.add_theme_constant_override("separation", 8)

	var icon_frame := PanelContainer.new()
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.custom_minimum_size = Vector2(40, 40)
	icon_frame.add_theme_stylebox_override("panel", _flat_style(Color(0.02, 0.025, 0.035, 0.95), Color(accent.r, accent.g, accent.b, 0.72) if unlocked else Color(0.22, 0.24, 0.28, 0.8), 1, 6))
	row.add_child(icon_frame)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = ability.get("icon") as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = Color.WHITE if unlocked else Color(0.18, 0.19, 0.22, 0.92)
	icon_frame.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = str(ability.get("title", "Ability"))
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58, 1.0) if unlocked else Color(0.46, 0.48, 0.52, 1.0))
	text_box.add_child(title)

	var description := Label.new()
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.text = str(ability.get("description", ""))
	description.clip_text = true
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.add_theme_font_size_override("font_size", 12)
	description.visible = false
	description.add_theme_color_override("font_color", Color(0.68, 0.74, 0.8, 1.0) if unlocked else Color(0.38, 0.4, 0.44, 1.0))
	text_box.add_child(description)
	return row

func _update_card_position() -> void:
	if card != null:
		card.size = CARD_SIZE
	if card == null or card_visible_for.is_empty() or not hero_nodes.has(card_visible_for):
		return
	var shrine: Node2D = hero_nodes[card_visible_for]["root"]
	var screen_position: Vector2 = shrine.get_global_transform_with_canvas().origin
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var preferred_side: float = float(HERO_CARD_SIDE.get(card_visible_for, 1.0))
	var target_x := screen_position.x + 74.0 if preferred_side > 0.0 else screen_position.x - CARD_SIZE.x - 74.0
	if preferred_side > 0.0 and target_x + CARD_SIZE.x > viewport_size.x - 12.0:
		target_x = screen_position.x - CARD_SIZE.x - 74.0
	elif preferred_side < 0.0 and target_x < 12.0:
		target_x = screen_position.x + 74.0
	var target_y := screen_position.y - CARD_SIZE.y * 0.45
	var top_safe := CARD_TOP_SAFE
	var first_run_guide := get_parent().get_node_or_null("SinglePlayerWorldController/FirstRunStrongholdGuide")
	if first_run_guide != null and is_instance_valid(first_run_guide):
		top_safe = 174.0
	target_x = clampf(target_x, 12.0, maxf(12.0, viewport_size.x - CARD_SIZE.x - 12.0))
	target_y = clampf(target_y, top_safe, maxf(top_safe, viewport_size.y - CARD_SIZE.y - CARD_BOTTOM_SAFE))
	card.position = Vector2(target_x, target_y)

func _select_hero(hero_name: String) -> void:
	Global.set_run_loadout(hero_name, Global.selected_base_id)
	if player.has_method("update_hero_sprites"):
		player.update_hero_sprites()
	_refresh_shrines()
	_refresh_card(hero_name)
	_set_hub_status("%s selected. Choose a fortress at the central base, or dig into an unlocked route." % hero_name)
	var tween := create_tween()
	tween.tween_property(player, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _show_locked_feedback(hero_name: String) -> void:
	_set_hub_status("%s is dormant. Each MineWars victory awakens one new hero and fortress." % hero_name)
	card_action.text = "%s IS DORMANT  •  EARN ANOTHER VICTORY" % hero_name.to_upper()
	if card_tween and card_tween.is_running():
		card_tween.kill()
	card_action_panel.modulate = Color.WHITE
	card_tween = create_tween()
	card_tween.tween_property(card_action_panel, "modulate", Color(1.0, 0.42, 0.32, 1.0), 0.08)
	card_tween.tween_property(card_action_panel, "modulate", Color.WHITE, 0.24)
	card_tween.tween_property(card_action_panel, "modulate", Color(1.0, 0.42, 0.32, 1.0), 0.08)
	card_tween.tween_property(card_action_panel, "modulate", Color.WHITE, 0.24)

func _set_hub_status(message: String) -> void:
	var status := get_parent().get_node_or_null("SinglePlayerWorldController/SinglePlayerHubHUD/StatusPanel/Margin/Status") as Label
	if status:
		status.text = message

func _hero_unlocked(hero_name: String) -> bool:
	return Global.is_hero_unlocked(hero_name)

func _animate_newly_unlocked_shrines() -> void:
	if world == null:
		return
	var newly_unlocked: Array = world.get_meta("newly_unlocked_heroes", [])
	for hero_value in newly_unlocked:
		var hero_name := str(hero_value)
		if not hero_nodes.has(hero_name):
			continue
		var root: Node2D = hero_nodes[hero_name]["root"]
		root.modulate = Color(1, 1, 1, 0)
		root.scale = Vector2(0.18, 0.18)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(root, "modulate", Color.WHITE, 0.5)
		tween.tween_property(root, "scale", Vector2.ONE, 0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tween.finished
	world.remove_meta("newly_unlocked_heroes")

func _card_style(accent: Color, unlocked: bool, selected: bool) -> StyleBoxFlat:
	var border := accent if unlocked else Color(0.26, 0.29, 0.34, 0.95)
	var background := Color(0.018, 0.024, 0.034, 0.985)
	if selected:
		background = Color(0.065, 0.045, 0.014, 0.99)
	return _flat_style(background, border, 3 if selected else 2, 12)

func _flat_style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = 9
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
