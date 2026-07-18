extends CanvasLayer

signal send_enemy(type: int)
@onready var hud = get_parent().get_node_or_null("HUD")
@onready var player = get_parent().get_node_or_null("Player")
@onready var panel = $Panel

const MENU_ART_CENTER := Vector2(580.0, 323.0)
const MENU_ART_SIZE := Vector2(992.0, 624.0)
const VS_MENU_MARGIN := 16.0
const SINGLE_MENU_MARGIN := 18.0
const SINGLE_MENU_MIN_SCALE := 0.34
const SINGLE_MENU_MAX_SCALE := 0.56
const SINGLE_MENU_MAX_SCREEN_WIDTH_RATIO := 0.70
const UPGRADE_TREE_DESKTOP_MAX_WIDTH := 860.0
const UPGRADE_TREE_MAX_HEIGHT := 594.0
const UPGRADE_TREE_WORLD_STRIP := 260.0
const UPGRADE_TREE_CANVAS_SIZE := Vector2(860.0, 680.0)
const UPGRADE_TREE_NODE_SIZE := Vector2(116.0, 72.0)
const UPGRADE_TREE_ROOT_SIZE := Vector2(72.0, 72.0)
const UPGRADE_TREE_DEPTH_STEP := 146.0
const UPGRADE_TREE_ROW_START_X := 168.0
const UPGRADE_TREE_ROW_GAP := 24.0
const MENU_PANEL_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/MenuPanel.png")
const ENEMY_BUTTON_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/Button.png")
const GOLD_ICON_TEXTURE: Texture2D = preload("res://GoldCoin.png")
const GEM_ICON_TEXTURE: Texture2D = preload("res://assets/sprites/ui/common/stats/StatRessources.png")
const UPGRADE_ICON_PATHS := {
	"UnlockHealthbar": "res://assets/sprites/ui/upgrades/hud_health.svg",
	"UnlockBaseHealth": "res://assets/sprites/ui/upgrades/base_health.svg",
	"UnlockStats": "res://assets/sprites/ui/common/stats/Strenght.png",
	"UnlockXP": "res://assets/sprites/ui/upgrades/xp_bar.svg",
	"UnlockWaveTimer": "res://assets/sprites/ui/upgrades/wave_timer.svg",
	"UnlockMinimap": "res://assets/sprites/ui/upgrades/minimap.svg",
	"UpgradeMinimap": "res://assets/sprites/ui/upgrades/enemy_sight.svg",
	"UpgradeMaxHealth": "res://assets/sprites/ui/upgrades/max_health.svg",
	"HealPlayer": "res://assets/sprites/ui/upgrades/heal.svg",
	"UpgradeSpikes": "res://assets/sprites/ui/upgrades/base_fortification.svg"
}

var healthbar_unlocked = false
var base_health_unlocked = false
var stats_unlocked = false
var wave_timer_unlocked = false
var xp_unlocked = false
var minimap_unlocked = false
var minimap_upgraded = false

var upgrade_tree_shell: PanelContainer
var upgrade_tree_scroll: ScrollContainer
var upgrade_tree_canvas: Control
var upgrade_tree_detail: Label
var upgrade_tree_resources: Label
var upgrade_tree_close: Button
var upgrade_tree_stat_bar: HBoxContainer
var upgrade_tree_buttons := {}
var upgrade_tree_descriptions := {}
var upgrade_tree_currency := {}
var upgrade_tree_costs := {}
var upgrade_tree_owned := {}
var upgrade_camera: Camera2D
var upgrade_camera_original_offset := Vector2.ZERO
var upgrade_camera_tween: Tween
var upgrade_camera_shifted := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Tutorial HUD visibility is temporary assistance. These ownership flags
	# remain false in a fresh run so later attempts can purchase the information
	# modules as part of progression.
	if not $Panel/Close.pressed.is_connected(_on_close_pressed):
		$Panel/Close.pressed.connect(_on_close_pressed)
	_apply_upgrade_icons()
	_build_upgrade_tree_ui()
	get_tree().root.size_changed.connect(_relayout_open_upgrade_menu)
	hide_menu()


func _apply_upgrade_icons() -> void:
	for node_name: String in UPGRADE_ICON_PATHS:
		var button := $Panel.get_node_or_null(node_name) as Button
		var icon_path: String = UPGRADE_ICON_PATHS[node_name]
		if button == null or not ResourceLoader.exists(icon_path):
			continue
		button.icon = load(icon_path) as Texture2D
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 52)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_spacing", 8)


func get_upgrade_cost(stat_level: int) -> int:
	# MineWars rewards frequent, readable build choices. Competitive modes keep
	# the escalating economy so this single-player tuning does not affect LineWars.
	return (stat_level * 2) - 1 if _is_vs_mode() else 1

func update_button_texts():
	var str_cost = get_upgrade_cost(player.strength)
	$Panel/UpgradeStrength.text = ""
	$Panel/StrengthCost.text = str(str_cost)
	
	var agi_cost = get_upgrade_cost(player.agility)
	$Panel/UpgradeAgility.text = ""
	$Panel/AgilityCost.text = str(agi_cost)
	
	var int_cost = get_upgrade_cost(player.intelligence)
	$Panel/UpgradeIntelligence.text = ""
	$Panel/IntelligenceCost.text = str(int_cost)
	
	var vs_mode = _is_vs_mode()
	$Panel/UnlockWaveTimer.visible = not vs_mode
	$Panel/UnlockWaveTimer.disabled = vs_mode or wave_timer_unlocked
	$Panel/WaveTimerGoldIcon.visible = not vs_mode
	$Panel/WaveTimerCost.visible = not vs_mode
	
	$Panel/UpgradeSpikes.visible = false
	$Panel/UpgradeSpikes.disabled = true
	
	var hero_name = _get_menu_hero()
	var is_dwarf = (hero_name == "Dwarf")
	var is_shaman = (hero_name == "Shaman")
	
	$Panel/SwapHero.visible = false
	$Panel/FactionTitle.visible = is_dwarf or is_shaman
	$Panel/BuyRail.visible = is_dwarf
	$Panel/BuyMinecart.visible = is_dwarf
	$Panel/BuyPeon.visible = is_shaman
	_refresh_upgrade_tree_cards()

var vs_prompt_panel: Panel
var vs_send_panel: Panel

func _is_vs_mode() -> bool:
	var level = get_parent()
	return level != null and bool(level.get("is_vs_mode"))

func _get_menu_hero() -> String:
	if player:
		var hero_name = player.get("current_hero_name")
		if typeof(hero_name) == TYPE_STRING and hero_name != "":
			return hero_name
	var p_id = get_parent().get("player_id")
	if p_id == 2:
		return Global.hero_p2
	return Global.hero_p1

func _get_menu_art_top_left() -> Vector2:
	return MENU_ART_CENTER - MENU_ART_SIZE * 0.5

func _layout_vs_upgrade_panel() -> void:
	_layout_upgrade_tree_shell(true)

func _layout_single_player_upgrade_panel() -> void:
	_layout_upgrade_tree_shell(false)

func _layout_upgrade_tree_shell(is_vs: bool) -> void:
	if upgrade_tree_shell == null:
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var margin: float = VS_MENU_MARGIN if is_vs else SINGLE_MENU_MARGIN
	var width: float
	if view_size.x >= 900.0 and not is_vs:
		width = min(UPGRADE_TREE_DESKTOP_MAX_WIDTH, view_size.x * SINGLE_MENU_MAX_SCREEN_WIDTH_RATIO)
		width = min(width, view_size.x - UPGRADE_TREE_WORLD_STRIP)
	else:
		width = view_size.x - margin * 2.0
	var height: float = min(UPGRADE_TREE_MAX_HEIGHT, view_size.y - margin * 2.0)
	width = max(width, 320.0)
	height = max(height, 300.0)
	upgrade_tree_shell.position = Vector2(margin, (view_size.y - height) * 0.5)
	upgrade_tree_shell.size = Vector2(width, height)
	panel.position = Vector2.ZERO
	panel.scale = Vector2.ONE

func _relayout_open_upgrade_menu() -> void:
	if not panel.visible:
		return
	if _is_vs_mode():
		_layout_vs_upgrade_panel()
	else:
		_layout_single_player_upgrade_panel()
		if upgrade_camera_shifted:
			_apply_upgrade_camera_target(false)

func _shift_camera_for_upgrade_tree() -> void:
	if _is_vs_mode() or player == null or upgrade_tree_shell == null:
		return
	upgrade_camera = player.get_node_or_null("Camera2D") as Camera2D
	if upgrade_camera == null:
		return
	if not upgrade_camera_shifted:
		upgrade_camera_original_offset = upgrade_camera.offset
		upgrade_camera_shifted = true
	_apply_upgrade_camera_target(true)

func _apply_upgrade_camera_target(animated: bool) -> void:
	if upgrade_camera == null or player == null or upgrade_tree_shell == null:
		return
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var shell_right: float = upgrade_tree_shell.position.x + upgrade_tree_shell.size.x
	var visible_strip_width: float = maxf(viewport_width - shell_right, 120.0)
	var desired_player_x: float = shell_right + visible_strip_width * 0.48
	var player_screen_x: float = player.get_global_transform_with_canvas().origin.x
	var original_player_screen_x: float = player_screen_x + (upgrade_camera.offset.x - upgrade_camera_original_offset.x)
	var offset_delta: float = desired_player_x - original_player_screen_x
	var target_offset: Vector2 = upgrade_camera_original_offset - Vector2(offset_delta, 0.0)
	var max_shift: float = minf(viewport_width * 0.34, 330.0)
	target_offset.x = clampf(target_offset.x, upgrade_camera_original_offset.x - max_shift, upgrade_camera_original_offset.x + max_shift)
	target_offset.y = upgrade_camera_original_offset.y
	if upgrade_camera_tween and upgrade_camera_tween.is_running():
		upgrade_camera_tween.kill()
	if animated:
		upgrade_camera_tween = create_tween()
		upgrade_camera_tween.set_trans(Tween.TRANS_CUBIC)
		upgrade_camera_tween.set_ease(Tween.EASE_OUT)
		upgrade_camera_tween.tween_property(upgrade_camera, "offset", target_offset, 0.28)
		upgrade_camera_tween.tween_callback(func():
			if upgrade_camera_shifted:
				_apply_upgrade_camera_target(false)
		)
	else:
		upgrade_camera.offset = target_offset

func _restore_camera_after_upgrade_tree() -> void:
	if not upgrade_camera_shifted or upgrade_camera == null:
		return
	if upgrade_camera_tween and upgrade_camera_tween.is_running():
		upgrade_camera_tween.kill()
	upgrade_camera_tween = create_tween()
	upgrade_camera_tween.set_trans(Tween.TRANS_CUBIC)
	upgrade_camera_tween.set_ease(Tween.EASE_OUT)
	upgrade_camera_tween.tween_property(upgrade_camera, "offset", upgrade_camera_original_offset, 0.24)
	upgrade_camera_tween.tween_callback(func():
		upgrade_camera_shifted = false
		upgrade_camera = null
	)

func _build_upgrade_tree_ui() -> void:
	_hide_legacy_upgrade_nodes()
	upgrade_tree_shell = PanelContainer.new()
	upgrade_tree_shell.name = "UpgradeTreeShell"
	upgrade_tree_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	upgrade_tree_shell.add_theme_stylebox_override("panel", _tree_panel_style(Color(0.018, 0.024, 0.032, 0.96), Color(0.82, 0.62, 0.24, 0.98), 2, 12))
	panel.add_child(upgrade_tree_shell)

	var shell_box := VBoxContainer.new()
	shell_box.name = "ShellBox"
	shell_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell_box.offset_left = 18.0
	shell_box.offset_top = 14.0
	shell_box.offset_right = -18.0
	shell_box.offset_bottom = -14.0
	shell_box.add_theme_constant_override("separation", 8)
	upgrade_tree_shell.add_child(shell_box)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 52)
	header.add_theme_constant_override("separation", 12)
	shell_box.add_child(header)

	var title := Label.new()
	title.text = "BASE UPGRADE TREE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48, 1.0))
	header.add_child(title)

	upgrade_tree_resources = Label.new()
	upgrade_tree_resources.name = "Resources"
	upgrade_tree_resources.custom_minimum_size = Vector2(170, 0)
	upgrade_tree_resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	upgrade_tree_resources.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	upgrade_tree_resources.add_theme_font_size_override("font_size", 17)
	header.add_child(upgrade_tree_resources)

	upgrade_tree_close = Button.new()
	upgrade_tree_close.name = "TreeClose"
	upgrade_tree_close.text = "Close"
	upgrade_tree_close.custom_minimum_size = Vector2(92, 44)
	upgrade_tree_close.pressed.connect(_on_close_pressed)
	header.add_child(upgrade_tree_close)

	upgrade_tree_scroll = ScrollContainer.new()
	upgrade_tree_scroll.name = "TreeScroll"
	upgrade_tree_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upgrade_tree_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	upgrade_tree_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	upgrade_tree_scroll.custom_minimum_size = Vector2(0, 270)
	shell_box.add_child(upgrade_tree_scroll)

	upgrade_tree_canvas = Control.new()
	upgrade_tree_canvas.name = "TreeCanvas"
	upgrade_tree_canvas.custom_minimum_size = UPGRADE_TREE_CANVAS_SIZE
	upgrade_tree_scroll.add_child(upgrade_tree_canvas)

	_build_upgrade_tree_canvas()

	upgrade_tree_stat_bar = HBoxContainer.new()
	upgrade_tree_stat_bar.name = "QuickStats"
	upgrade_tree_stat_bar.custom_minimum_size = Vector2(0, 78)
	upgrade_tree_stat_bar.add_theme_constant_override("separation", 12)
	shell_box.add_child(upgrade_tree_stat_bar)
	_build_upgrade_tree_stat_bar()

	upgrade_tree_detail = Label.new()
	upgrade_tree_detail.name = "Detail"
	upgrade_tree_detail.custom_minimum_size = Vector2(0, 48)
	upgrade_tree_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_tree_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	upgrade_tree_detail.add_theme_font_size_override("font_size", 14)
	upgrade_tree_detail.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92, 1.0))
	shell_box.add_child(upgrade_tree_detail)

	_refresh_upgrade_tree_cards()

func _hide_legacy_upgrade_nodes() -> void:
	for child in panel.get_children():
		if child != upgrade_tree_shell:
			child.visible = false

func _tree_panel_style(background: Color, border: Color, border_width: int = 2, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.58)
	style.shadow_size = 5
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

func _build_upgrade_tree_canvas() -> void:
	var graph := _upgrade_graph_definition()
	var branch_y := 18.0
	for branch in graph:
		_layout_upgrade_graph_branch(branch, branch_y)
		branch_y += float(branch.get("height", 170.0))
	upgrade_tree_canvas.custom_minimum_size = Vector2(860.0, maxf(branch_y + 28.0, 640.0))

func _upgrade_graph_definition() -> Array:
	return [
		{
			"title": "HUD MODULES",
			"root_icon": "res://assets/sprites/ui/common/stats/StatRessources.png",
			"height": 640.0,
			"children": [
				{"id": "UnlockHealthbar", "title": "Hero HP", "description": "Unlock the hero health display and its health upgrades.", "cost": 10, "currency": "gold", "icon": UPGRADE_ICON_PATHS["UnlockHealthbar"], "action": Callable(self, "_on_unlock_healthbar_pressed"), "children": [
					{"id": "HealPlayer", "title": "Repair", "description": "Restore 20 hero health.", "cost": 10, "currency": "gold", "icon": UPGRADE_ICON_PATHS["HealPlayer"], "action": Callable(self, "_on_heal_player_pressed")},
					{"id": "UpgradeMaxHealth", "title": "+20 HP", "description": "Increase hero maximum health.", "cost": 15, "currency": "gold", "icon": UPGRADE_ICON_PATHS["UpgradeMaxHealth"], "action": Callable(self, "_on_upgrade_max_health_pressed")}
				]},
				{"id": "UnlockBaseHealth", "title": "Base HP", "description": "Unlock the base health display and its health upgrades.", "cost": 10, "currency": "gold", "icon": UPGRADE_ICON_PATHS["UnlockBaseHealth"], "action": Callable(self, "_on_unlock_base_health_pressed"), "children": [
					{"id": "RepairBase", "title": "Repair", "description": "Restore 25 base health.", "cost": 10, "currency": "gold", "icon": UPGRADE_ICON_PATHS["HealPlayer"], "action": Callable(self, "_on_repair_base_pressed")},
					{"id": "UpgradeBaseHealth", "title": "+25 HP", "description": "Increase base maximum health.", "cost": 20, "currency": "gold", "icon": UPGRADE_ICON_PATHS["UnlockBaseHealth"], "action": Callable(self, "_on_upgrade_base_health_pressed"), "children": [
						{"id": "BaseFortification", "title": "Fortify", "description": "Future armour and spike branch.", "cost": 0, "currency": "gold", "icon": "res://assets/sprites/ui/upgrades/base_fortification.svg", "future": true}
					]}
				]},
				{"id": "UnlockXP", "title": "XP", "description": "Show level progress at the bottom centre.", "cost": 10, "currency": "gold", "icon": UPGRADE_ICON_PATHS["UnlockXP"], "action": Callable(self, "_on_unlock_xp_pressed")},
				{"id": "UnlockWaveTimer", "title": "Waves", "description": "Show the next-wave countdown.", "cost": 10, "currency": "gold", "icon": UPGRADE_ICON_PATHS["UnlockWaveTimer"], "action": Callable(self, "_on_unlock_wave_timer_pressed")},
				{"id": "UnlockStats", "title": "Stats", "description": "Show STR, AGI and INT in the HUD.", "cost": 10, "currency": "gold", "icon": UPGRADE_ICON_PATHS["UnlockStats"], "action": Callable(self, "_on_unlock_stats_pressed")}
			]
		},
		{
			"title": "EXPLORATION",
			"root_icon": UPGRADE_ICON_PATHS["UnlockMinimap"],
			"height": 138.0,
			"children": [
				{"id": "UnlockMinimap", "title": "Minimap", "description": "Reveal the explored mine layout.", "cost": 20, "currency": "gold", "icon": UPGRADE_ICON_PATHS["UnlockMinimap"], "action": Callable(self, "_on_unlock_minimap_pressed"), "children": [
					{"id": "UpgradeMinimap", "title": "Enemies", "description": "Add enemy positions to the minimap.", "cost": 50, "currency": "gold", "icon": UPGRADE_ICON_PATHS["UpgradeMinimap"], "action": Callable(self, "_on_upgrade_minimap_pressed")}
				]}
			]
		},
		{
			"title": "FACTION",
			"root_icon": "res://rail_item_placeholder.png",
			"height": 138.0,
			"children": [
				{"id": "BuyRail", "title": "Rail", "description": "Place another rail segment.", "cost": 10, "currency": "gold", "icon": "res://rail_item_placeholder.png", "action": Callable(self, "_on_buy_rail_pressed"), "children": [
					{"id": "BuyMinecart", "title": "Minecart", "description": "Create a minecart for the rail network.", "cost": 50, "currency": "gold", "icon": "res://character_sprites/minecart_spritesheet_25d.png", "action": Callable(self, "_on_buy_minecart_pressed")}
				]},
				{"id": "BuyPeon", "title": "Peon", "description": "Recruit a Shaman worker.", "cost": 30, "currency": "gold", "icon": "res://character_sprites/shaman_walk_spritesheet_25d.png", "action": Callable(self, "_on_buy_peon_pressed")}
			]
		}
	]

func _layout_upgrade_graph_branch(branch: Dictionary, branch_y: float) -> void:
	var branch_height := float(branch.get("height", 160.0))
	var root_pos := Vector2(48.0, branch_y + branch_height * 0.5 - UPGRADE_TREE_ROOT_SIZE.y * 0.5)
	_create_parallel_tree_root(str(branch.get("title", "UPGRADES")), str(branch.get("title", "UPGRADES")), root_pos, str(branch.get("root_icon", "")))
	var children: Array = branch.get("children", [])
	var leaf_counts: Array[int] = []
	var total_leaves := 0
	for child in children:
		var count := _graph_leaf_count(child)
		leaf_counts.append(count)
		total_leaves += count
	var slot_height := maxf(float(branch.get("height", 160.0)) - 28.0, 96.0) / maxf(float(total_leaves), 1.0)
	var cursor := branch_y + 14.0
	for index in range(children.size()):
		var subtree_height := slot_height * float(leaf_counts[index])
		_layout_upgrade_graph_node(children[index], 0, cursor + subtree_height * 0.5, root_pos + Vector2(UPGRADE_TREE_ROOT_SIZE.x, UPGRADE_TREE_ROOT_SIZE.y * 0.5), slot_height)
		cursor += subtree_height

func _graph_leaf_count(definition: Dictionary) -> int:
	var children: Array = definition.get("children", [])
	if children.is_empty():
		return 1
	var count := 0
	for child in children:
		count += _graph_leaf_count(child)
	return maxi(count, 1)

func _layout_upgrade_graph_node(definition: Dictionary, depth: int, center_y: float, parent_anchor: Vector2, slot_height: float) -> void:
	var node_pos := Vector2(156.0 + depth * UPGRADE_TREE_DEPTH_STEP, center_y - UPGRADE_TREE_NODE_SIZE.y * 0.5)
	var id := str(definition.get("id", ""))
	var action: Callable = definition.get("action", Callable())
	_create_tree_connector(parent_anchor, Vector2(node_pos.x, center_y))
	_create_upgrade_tree_node(id, str(definition.get("title", id)), str(definition.get("description", "")), int(definition.get("cost", 0)), str(definition.get("currency", "gold")), str(definition.get("icon", "")), node_pos, action)
	var button := upgrade_tree_buttons.get(id) as Button
	if button and bool(definition.get("future", false)):
		button.set_meta("future_upgrade", true)
		button.disabled = true
	var children: Array = definition.get("children", [])
	if children.is_empty():
		return
	var total_leaves := 0
	var leaf_counts: Array[int] = []
	for child in children:
		var count := _graph_leaf_count(child)
		leaf_counts.append(count)
		total_leaves += count
	var cursor := center_y - slot_height * float(total_leaves) * 0.5
	var next_anchor := Vector2(node_pos.x + UPGRADE_TREE_NODE_SIZE.x, center_y)
	for index in range(children.size()):
		var subtree_height := slot_height * float(leaf_counts[index])
		_layout_upgrade_graph_node(children[index], depth + 1, cursor + subtree_height * 0.5, next_anchor, slot_height)
		cursor += subtree_height

func _load_upgrade_icon_texture(icon_path: String) -> Texture2D:
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	var texture := load(icon_path) as Texture2D
	if texture == null:
		return null
	if "spritesheet" in icon_path:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		var frame_size := Vector2(texture.get_width() / 8.0, texture.get_height() / 8.0)
		atlas.region = Rect2(Vector2.ZERO, frame_size)
		return atlas
	return texture

func _create_parallel_tree_root(branch_title: String, root_title: String, pos: Vector2, icon_path: String) -> void:
	_create_tree_branch_label(branch_title, Vector2(pos.x - 8.0, pos.y - 24.0), 124)
	var root := PanelContainer.new()
	root.name = "%sRoot" % branch_title.replace(" ", "")
	root.position = pos
	root.size = UPGRADE_TREE_ROOT_SIZE
	root.add_theme_stylebox_override("panel", _tree_panel_style(Color(0.13, 0.075, 0.025, 0.98), Color(0.92, 0.66, 0.22, 1.0), 2, 9))
	upgrade_tree_canvas.add_child(root)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(content)
	var icon := TextureRect.new()
	icon.position = Vector2(9, 9)
	icon.size = Vector2(54, 54)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _load_upgrade_icon_texture(icon_path)
	content.add_child(icon)

func _create_parallel_tree_node(id: String, title_text: String, description: String, cost: int, currency: String, icon_path: String, pos: Vector2, action: Callable, connector_from: Vector2) -> void:
	_create_tree_connector(connector_from, Vector2(pos.x, pos.y + UPGRADE_TREE_NODE_SIZE.y * 0.5))
	_create_upgrade_tree_node(id, title_text, description, cost, currency, icon_path, pos, action)

func _create_future_tree_node(id: String, title_text: String, description: String, icon_path: String, pos: Vector2, connector_from: Vector2) -> void:
	_create_parallel_tree_node(id, title_text, description, 0, "gold", icon_path, pos, Callable(), connector_from)
	var button := upgrade_tree_buttons[id] as Button
	button.disabled = true
	button.set_meta("future_upgrade", true)

func _build_upgrade_tree_stat_bar() -> void:
	var heading := Label.new()
	heading.text = "QUICK STATS"
	heading.custom_minimum_size = Vector2(110, 0)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35, 1.0))
	upgrade_tree_stat_bar.add_child(heading)
	_create_upgrade_tree_node("UpgradeStrength", "STR +1", "Always 1 gem in MineWars. More damage, hard-rock force, and free carrying thresholds.", 1, "gems", "res://assets/sprites/ui/common/stats/Strenght.png", Vector2.ZERO, Callable(self, "_on_upgrade_strength_pressed"), upgrade_tree_stat_bar)
	_create_upgrade_tree_node("UpgradeAgility", "AGI +1", "Always 1 gem in MineWars. Faster attacks, movement, and mining cadence.", 1, "gems", "res://assets/sprites/ui/common/stats/Agility.png", Vector2.ZERO, Callable(self, "_on_upgrade_agility_pressed"), upgrade_tree_stat_bar)
	_create_upgrade_tree_node("UpgradeIntelligence", "INT +1", "Always 1 gem in MineWars. Stronger abilities, summons, and magical mining utility.", 1, "gems", "res://assets/sprites/ui/common/stats/Int.png", Vector2.ZERO, Callable(self, "_on_upgrade_intelligence_pressed"), upgrade_tree_stat_bar)
	_create_upgrade_tree_node("UpgradePickPower", "Pick Power", "Each rank sharply reduces dense-stone and ancient-wall resistance.", 2, "gems", "res://assets/sprites/world/terrain/bricks/Hard_Brick.png", Vector2.ZERO, Callable(self, "_on_upgrade_pick_power_pressed"), upgrade_tree_stat_bar)

func _create_horizontal_upgrade_row(row_title: String, row_y: float, entries: Array) -> void:
	_create_tree_branch_label(row_title, Vector2(12, row_y + 26.0), 132)
	var previous_center := Vector2.ZERO
	for index in range(entries.size()):
		var entry: Array = entries[index]
		var node_position := Vector2(UPGRADE_TREE_ROW_START_X + index * (UPGRADE_TREE_NODE_SIZE.x + UPGRADE_TREE_ROW_GAP), row_y)
		_create_upgrade_tree_node(str(entry[0]), str(entry[1]), str(entry[2]), int(entry[3]), str(entry[4]), str(entry[5]), node_position, entry[6])
		var center := node_position + UPGRADE_TREE_NODE_SIZE * 0.5
		if index == 0:
			_create_tree_connector(Vector2(144, center.y), Vector2(node_position.x, center.y))
		else:
			_create_tree_connector(Vector2(previous_center.x + UPGRADE_TREE_NODE_SIZE.x * 0.5, previous_center.y), Vector2(node_position.x, center.y))
		previous_center = center

func _create_tree_branch_label(text_value: String, pos: Vector2, width: float) -> void:
	var label_node := Label.new()
	label_node.text = text_value
	label_node.position = pos
	label_node.size = Vector2(width, 24)
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_node.add_theme_font_size_override("font_size", 12)
	label_node.add_theme_color_override("font_color", Color(0.72, 0.66, 0.52, 1.0))
	upgrade_tree_canvas.add_child(label_node)

func _create_tree_connector(from_point: Vector2, to_point: Vector2) -> void:
	var connector := Line2D.new()
	connector.name = "Connector"
	connector.width = 3.0
	connector.default_color = Color(0.55, 0.42, 0.20, 0.72)
	var bend_y := (from_point.y + to_point.y) * 0.5
	connector.points = PackedVector2Array([from_point, Vector2(from_point.x, bend_y), Vector2(to_point.x, bend_y), to_point])
	upgrade_tree_canvas.add_child(connector)

func _create_upgrade_tree_node(id: String, title_text: String, description: String, cost: int, currency: String, icon_path: String, pos: Vector2, action: Callable, target_parent: Control = null) -> void:
	var button := Button.new()
	button.name = "Tree_%s" % id
	if target_parent == null:
		button.position = pos
		button.size = UPGRADE_TREE_NODE_SIZE
	else:
		button.custom_minimum_size = UPGRADE_TREE_NODE_SIZE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = description
	button.text = ""
	button.flat = true
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	button.pressed.connect(Callable(self, "_on_upgrade_tree_node_pressed").bind(id, action))
	button.mouse_entered.connect(Callable(self, "_show_upgrade_tree_detail").bind(id))
	button.mouse_entered.connect(Callable(self, "_set_upgrade_tree_card_highlight").bind(id, true))
	button.mouse_exited.connect(Callable(self, "_set_upgrade_tree_card_highlight").bind(id, false))
	button.focus_entered.connect(Callable(self, "_show_upgrade_tree_detail").bind(id))
	button.focus_entered.connect(Callable(self, "_set_upgrade_tree_card_highlight").bind(id, true))
	button.focus_exited.connect(Callable(self, "_set_upgrade_tree_card_highlight").bind(id, false))
	var resolved_parent: Control = upgrade_tree_canvas if target_parent == null else target_parent
	resolved_parent.add_child(button)

	var card_background := PanelContainer.new()
	card_background.name = "CardBackground"
	card_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_background.add_theme_stylebox_override("panel", _tree_panel_style(Color(0.045, 0.055, 0.07, 0.99), Color(0.34, 0.38, 0.45, 0.9), 2, 8))
	button.add_child(card_background)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(8, 7)
	icon.size = Vector2(46, 46)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _load_upgrade_icon_texture(icon_path)
	button.add_child(icon)

	var title_label := Label.new()
	title_label.name = "Title"
	title_label.text = title_text
	title_label.position = Vector2(56, 8)
	title_label.size = Vector2(54, 34)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title_label)

	var currency_icon := TextureRect.new()
	currency_icon.name = "CurrencyIcon"
	currency_icon.position = Vector2(57, 46)
	currency_icon.size = Vector2(17, 17)
	currency_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	currency_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	currency_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	currency_icon.texture = GEM_ICON_TEXTURE if currency == "gems" else GOLD_ICON_TEXTURE
	button.add_child(currency_icon)

	var cost_label := Label.new()
	cost_label.name = "Cost"
	cost_label.position = Vector2(76, 44)
	cost_label.size = Vector2(32, 21)
	cost_label.add_theme_font_size_override("font_size", 13)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cost_label)

	var state_label := Label.new()
	state_label.name = "State"
	state_label.position = Vector2(88, 4)
	state_label.size = Vector2(22, 18)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_label.add_theme_font_size_override("font_size", 11)
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(state_label)

	upgrade_tree_buttons[id] = button
	upgrade_tree_descriptions[id] = description
	upgrade_tree_currency[id] = currency
	upgrade_tree_costs[id] = cost

func _on_upgrade_tree_node_pressed(id: String, action: Callable) -> void:
	var tree_button := upgrade_tree_buttons.get(id) as Control
	_pulse_upgrade_button(tree_button)
	var gems_before := int(hud.total_gems) if hud else 0
	var gold_before := int(hud.total_gold) if hud else 0
	if action.is_valid():
		action.call()
	var purchase_succeeded := hud != null and (int(hud.total_gems) < gems_before or int(hud.total_gold) < gold_before)
	var menu_sound_fx := get_node_or_null("/root/SoundFX")
	if menu_sound_fx:
		if purchase_succeeded:
			if id.begins_with("Buy"):
				menu_sound_fx.play_purchase()
			else:
				menu_sound_fx.play_upgrade()
		elif action.is_valid():
			menu_sound_fx.play_error()
	_refresh_upgrade_tree_cards()
	_show_upgrade_tree_detail(id)

func _show_upgrade_tree_detail(id: String) -> void:
	if upgrade_tree_detail == null:
		return
	var description: String = str(upgrade_tree_descriptions.get(id, ""))
	var button := upgrade_tree_buttons.get(id) as Button
	var title_text := id
	if button and button.get_node_or_null("Title"):
		title_text = str(button.get_node("Title").text)
	upgrade_tree_detail.text = "%s — %s" % [title_text, description]

func _refresh_upgrade_tree_cards() -> void:
	if upgrade_tree_shell == null:
		return
	if upgrade_tree_resources:
		upgrade_tree_resources.text = "Gems %d   Gold %d" % [hud.total_gems if hud else 0, hud.total_gold if hud else 0]
	var hero_name := _get_menu_hero()
	for id_value in upgrade_tree_buttons.keys():
		var id := str(id_value)
		var button := upgrade_tree_buttons[id] as Button
		var cost := int(upgrade_tree_costs.get(id, 0))
		if id == "UpgradeStrength" and player:
			cost = get_upgrade_cost(player.strength)
		elif id == "UpgradeAgility" and player:
			cost = get_upgrade_cost(player.agility)
		elif id == "UpgradeIntelligence" and player:
			cost = get_upgrade_cost(player.intelligence)
		elif id == "UpgradePickPower" and player:
			cost = get_pick_power_cost()
		var title_label := button.get_node_or_null("Title") as Label
		if title_label and player:
			match id:
				"UpgradeStrength":
					title_label.text = "STR %d → %d" % [int(player.strength), int(player.strength) + 1]
				"UpgradeAgility":
					title_label.text = "AGI %d → %d" % [int(player.agility), int(player.agility) + 1]
				"UpgradeIntelligence":
					title_label.text = "INT %d → %d" % [int(player.intelligence), int(player.intelligence) + 1]
				"UpgradePickPower":
					var pick_level := int(player.get("mining_power_level"))
					title_label.text = "Pick MAX" if pick_level >= 3 else "Pick Lv %d" % pick_level
		var currency := str(upgrade_tree_currency.get(id, "gold"))
		var available_amount: int = 0
		if hud:
			available_amount = int(hud.total_gems) if currency == "gems" else int(hud.total_gold)
		var future_locked: bool = button.has_meta("future_upgrade")
		var owned := _is_upgrade_tree_node_owned(id)
		var dependency_locked := false
		if id == "UpgradeMinimap":
			dependency_locked = not minimap_unlocked
		elif id == "HealPlayer" or id == "UpgradeMaxHealth":
			dependency_locked = not healthbar_unlocked
		elif id == "RepairBase" or id == "UpgradeBaseHealth":
			dependency_locked = not base_health_unlocked
		var mode_hidden := id == "UnlockWaveTimer" and _is_vs_mode()
		var faction_hidden := (id == "BuyRail" or id == "BuyMinecart") and hero_name != "Dwarf"
		faction_hidden = faction_hidden or (id == "BuyPeon" and hero_name != "Shaman")
		button.visible = not mode_hidden and not faction_hidden
		button.disabled = owned or dependency_locked or future_locked
		var cost_label := button.get_node_or_null("Cost") as Label
		var state_label := button.get_node_or_null("State") as Label
		if cost_label:
			cost_label.text = "—" if future_locked or owned else str(cost)
			cost_label.add_theme_color_override("font_color", Color(0.68, 0.7, 0.76, 1.0) if future_locked or owned else (Color(1.0, 0.42, 0.32, 1.0) if available_amount < cost else Color(1.0, 0.86, 0.48, 1.0)))
		var currency_icon := button.get_node_or_null("CurrencyIcon") as TextureRect
		if currency_icon:
			currency_icon.visible = not future_locked and not owned
		if state_label:
			if future_locked:
				state_label.text = "…"
				state_label.add_theme_color_override("font_color", Color(0.68, 0.7, 0.76, 1.0))
			elif owned:
				state_label.text = "✓"
				state_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55, 1.0))
			elif dependency_locked:
				state_label.text = "🔒"
				state_label.add_theme_color_override("font_color", Color(0.68, 0.7, 0.76, 1.0))
			elif available_amount < cost:
				state_label.text = "!"
				state_label.add_theme_color_override("font_color", Color(1.0, 0.46, 0.34, 1.0))
			else:
				state_label.text = ""
		var card_background := button.get_node_or_null("CardBackground") as PanelContainer
		if card_background:
			if owned:
				card_background.add_theme_stylebox_override("panel", _tree_panel_style(Color(0.025, 0.12, 0.055, 0.99), Color(0.35, 0.95, 0.48, 0.95), 2, 8))
			elif dependency_locked:
				card_background.add_theme_stylebox_override("panel", _tree_panel_style(Color(0.04, 0.045, 0.055, 0.99), Color(0.30, 0.32, 0.38, 0.9), 2, 8))
			elif available_amount < cost:
				card_background.add_theme_stylebox_override("panel", _tree_panel_style(Color(0.10, 0.035, 0.03, 0.99), Color(0.56, 0.22, 0.18, 0.95), 2, 8))
			else:
				card_background.add_theme_stylebox_override("panel", _tree_panel_style(Color(0.045, 0.055, 0.07, 0.99), Color(0.34, 0.38, 0.45, 0.9), 2, 8))
	_hide_legacy_upgrade_nodes()

func _set_upgrade_tree_card_highlight(id: String, highlighted: bool) -> void:
	var button := upgrade_tree_buttons.get(id) as Button
	if button == null:
		return
	var card_background := button.get_node_or_null("CardBackground") as PanelContainer
	if card_background == null:
		return
	if highlighted and not button.disabled:
		card_background.add_theme_stylebox_override("panel", _tree_panel_style(Color(0.11, 0.08, 0.03, 1.0), Color(1.0, 0.76, 0.26, 1.0), 3, 8))
	else:
		_refresh_upgrade_tree_cards()

func _is_upgrade_tree_node_owned(id: String) -> bool:
	match id:
		"UnlockHealthbar": return healthbar_unlocked
		"UnlockBaseHealth": return base_health_unlocked
		"UnlockStats": return stats_unlocked
		"UnlockWaveTimer": return wave_timer_unlocked
		"UnlockXP": return xp_unlocked
		"UnlockMinimap": return minimap_unlocked
		"UpgradeMinimap": return minimap_upgraded
		"UpgradePickPower": return player != null and int(player.get("mining_power_level")) >= 3
	return false

func _focus_first_upgrade_tree_node() -> void:
	var preferred_ids: Array[String] = []
	if hud and player:
		var available_gems: int = int(hud.total_gems)
		if available_gems >= get_upgrade_cost(int(player.strength)):
			preferred_ids.append("UpgradeStrength")
		if available_gems >= get_upgrade_cost(int(player.agility)):
			preferred_ids.append("UpgradeAgility")
		if available_gems >= get_upgrade_cost(int(player.intelligence)):
			preferred_ids.append("UpgradeIntelligence")
		if int(player.get("mining_power_level")) < 3 and available_gems >= get_pick_power_cost():
			preferred_ids.append("UpgradePickPower")
	preferred_ids.append_array([
		"RepairBase", "HealPlayer", "UpgradeBaseHealth", "UpgradeMaxHealth",
		"UnlockMinimap", "BuyRail", "BuyMinecart", "BuyPeon"
	])
	for id in preferred_ids:
		var button := upgrade_tree_buttons.get(id) as Button
		if button and button.visible and not button.disabled:
			button.call_deferred("grab_focus")
			_show_upgrade_tree_detail(id)
			return
	if upgrade_tree_close:
		upgrade_tree_close.call_deferred("grab_focus")

func _make_texture_style(texture: Texture2D) -> StyleBoxTexture:
	var stylebox = StyleBoxTexture.new()
	if texture:
		stylebox.texture = texture
	return stylebox

func _apply_enemy_button_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_texture_style(ENEMY_BUTTON_TEXTURE))
	btn.add_theme_stylebox_override("hover", _make_texture_style(ENEMY_BUTTON_TEXTURE))
	btn.add_theme_stylebox_override("pressed", _make_texture_style(ENEMY_BUTTON_TEXTURE))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func get_pick_power_cost() -> int:
	if player == null:
		return 999999
	return 2 + int(player.get("mining_power_level")) * 3

func _get_stat_upgrade_color(stat_name: String) -> Color:
	match stat_name:
		"Strength":
			return Color(1.0, 0.28, 0.16, 1.0)
		"Agility":
			return Color(0.25, 1.0, 0.35, 1.0)
		"Intelligence":
			return Color(0.25, 0.65, 1.0, 1.0)
		"Pick Power":
			return Color(1.0, 0.66, 0.22, 1.0)
	return Color(1.0, 0.9, 0.25, 1.0)

func _play_stat_upgrade_effect(stat_name: String, source_button: Control = null) -> void:
	var color = _get_stat_upgrade_color(stat_name)
	_pulse_upgrade_button(source_button)
	_pulse_player_sprite(color)
	_spawn_stat_upgrade_particles(color)
	_spawn_stat_upgrade_ring(color)
	_spawn_stat_upgrade_popup(stat_name, color)

func _pulse_upgrade_button(source_button: Control) -> void:
	if source_button == null or not is_instance_valid(source_button):
		return
	var original_scale = source_button.scale
	source_button.pivot_offset = source_button.size * 0.5
	source_button.scale = original_scale * 1.14
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(source_button, "scale", original_scale, 0.22)

func _pulse_player_sprite(color: Color) -> void:
	if player == null or not is_instance_valid(player):
		return
	var sprite = player.get_node_or_null("Sprite2D")
	if sprite == null:
		return
	var original_scale = sprite.scale
	var original_modulate = sprite.modulate
	sprite.scale = original_scale * 1.28
	sprite.modulate = color
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", original_scale, 0.28)
	tween.tween_property(sprite, "modulate", original_modulate, 0.28)

func _spawn_stat_upgrade_particles(color: Color) -> void:
	if player == null or not is_instance_valid(player) or get_parent() == null:
		return
	var burst = CPUParticles2D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 46
	burst.lifetime = 0.58
	burst.explosiveness = 0.95
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 14.0
	burst.spread = 180.0
	burst.gravity = Vector2(0, -40)
	burst.initial_velocity_min = 90.0
	burst.initial_velocity_max = 210.0
	burst.damping_min = 90.0
	burst.damping_max = 150.0
	burst.scale_amount_min = 2.2
	burst.scale_amount_max = 5.5
	burst.color = color
	burst.global_position = player.global_position + Vector2(0, -28)
	burst.z_index = 30
	get_parent().add_child(burst)
	burst.emitting = true
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(burst.queue_free)

func _spawn_stat_upgrade_ring(color: Color) -> void:
	if player == null or not is_instance_valid(player) or get_parent() == null:
		return
	var ring = Line2D.new()
	ring.closed = true
	ring.width = 4.0
	ring.default_color = Color(color.r, color.g, color.b, 0.85)
	ring.z_index = 29
	var points = PackedVector2Array()
	for i in range(32):
		var angle = TAU * float(i) / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * 18.0)
	ring.points = points
	ring.global_position = player.global_position + Vector2(0, -28)
	ring.scale = Vector2(0.35, 0.35)
	get_parent().add_child(ring)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.48)
	tween.tween_property(ring, "modulate:a", 0.0, 0.48)
	tween.chain().tween_callback(ring.queue_free)

func _spawn_stat_upgrade_popup(stat_name: String, color: Color) -> void:
	if player == null or not is_instance_valid(player) or get_parent() == null:
		return
	var popup = Label.new()
	popup.text = "+1 %s" % stat_name
	popup.add_theme_font_size_override("font_size", 18)
	popup.add_theme_color_override("font_color", color)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.custom_minimum_size = Vector2(120, 28)
	popup.z_index = 100
	popup.modulate = Color(1, 1, 1, 1)
	get_parent().add_child(popup)
	popup.global_position = player.global_position + Vector2(-60, -86)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "global_position", popup.global_position + Vector2(0, -38), 0.62)
	tween.tween_property(popup, "modulate:a", 0.0, 0.62)
	tween.chain().tween_callback(popup.queue_free)

func _create_enemy_button(enemy_name: String, cost: int, income: int, tex_path: String) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 54)
	btn.tooltip_text = "%s: %d gold, +%d gold income" % [enemy_name, cost, income]
	_apply_enemy_button_style(btn)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 12)
	
	var tex_rect = TextureRect.new()
	var tex = load(tex_path)
	var atlas = AtlasTexture.new()
	if tex:
		atlas.atlas = tex
		var fw = tex.get_width() / 8
		var fh = tex.get_height() / 8
		if fw > 0 and fh > 0:
			atlas.region = Rect2(0, 0, fw, fh)
		tex_rect.texture = atlas
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.custom_minimum_size = Vector2(42, 42)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(tex_rect)
	
	var cost_icon = TextureRect.new()
	cost_icon.texture = GOLD_ICON_TEXTURE
	cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cost_icon.custom_minimum_size = Vector2(22, 22)
	cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(cost_icon)
	
	var lbl_cost = Label.new()
	lbl_cost.text = str(cost)
	lbl_cost.custom_minimum_size = Vector2(28, 0)
	lbl_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl_cost)
	
	var inc_icon = TextureRect.new()
	inc_icon.texture = GOLD_ICON_TEXTURE
	inc_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inc_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inc_icon.custom_minimum_size = Vector2(22, 22)
	inc_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(inc_icon)
	
	var lbl_inc = Label.new()
	lbl_inc.text = "+" + str(income)
	lbl_inc.custom_minimum_size = Vector2(30, 0)
	lbl_inc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_inc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl_inc)
	
	btn.add_child(hbox)
	return btn

func _create_vs_panels():
	if vs_prompt_panel != null and is_instance_valid(vs_prompt_panel):
		return
		
	var menu_stylebox = _make_texture_style(MENU_PANEL_TEXTURE)
		
	vs_prompt_panel = Panel.new()
	vs_prompt_panel.name = "VSPromptPanel"
	vs_prompt_panel.add_theme_stylebox_override("panel", menu_stylebox)
	vs_prompt_panel.anchor_left = 0.5
	vs_prompt_panel.anchor_top = 0.5
	vs_prompt_panel.anchor_right = 0.5
	vs_prompt_panel.anchor_bottom = 0.5
	vs_prompt_panel.offset_left = -150
	vs_prompt_panel.offset_top = -100
	vs_prompt_panel.offset_right = 150
	vs_prompt_panel.offset_bottom = 100
	
	var vbox1 = VBoxContainer.new()
	vbox1.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox1.offset_left = 20
	vbox1.offset_top = 20
	vbox1.offset_right = -20
	vbox1.offset_bottom = -20
	
	var lbl1 = Label.new()
	lbl1.text = "Base Options"
	lbl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox1.add_child(lbl1)
	
	var btn_upgrades = Button.new()
	btn_upgrades.text = "Upgrades"
	btn_upgrades.pressed.connect(Callable(self, "_on_vs_upgrades_pressed"))
	vbox1.add_child(btn_upgrades)
	
	var btn_send = Button.new()
	btn_send.text = "Send Enemies"
	btn_send.pressed.connect(Callable(self, "_on_vs_send_pressed"))
	vbox1.add_child(btn_send)
	
	var btn_close1 = Button.new()
	btn_close1.text = "Close"
	btn_close1.pressed.connect(Callable(self, "_on_close_pressed"))
	vbox1.add_child(btn_close1)
	
	vs_prompt_panel.add_child(vbox1)
	add_child(vs_prompt_panel)
	
	vs_send_panel = Panel.new()
	vs_send_panel.name = "VSSendPanel"
	vs_send_panel.add_theme_stylebox_override("panel", menu_stylebox)
	vs_send_panel.anchor_left = 0.5
	vs_send_panel.anchor_top = 0.5
	vs_send_panel.anchor_right = 0.5
	vs_send_panel.anchor_bottom = 0.5
	vs_send_panel.offset_left = -190
	vs_send_panel.offset_top = -240
	vs_send_panel.offset_right = 190
	vs_send_panel.offset_bottom = 240
	
	var vbox2 = VBoxContainer.new()
	vbox2.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox2.offset_left = 54
	vbox2.offset_top = 50
	vbox2.offset_right = -54
	vbox2.offset_bottom = -50
	vbox2.add_theme_constant_override("separation", 8)
	
	var lbl2 = Label.new()
	lbl2.text = "Send Enemies"
	lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox2.add_child(lbl2)
	
	var btn_rat = _create_enemy_button("Rat", 5, 1, "res://assets/sprites/enemies/rat/rat_walk_pixelart_spritesheet.png")
	btn_rat.pressed.connect(Callable(self, "_on_send_rat"))
	vbox2.add_child(btn_rat)
	
	var btn_spider = _create_enemy_button("Spider", 10, 2, "res://character_sprites/spider_walk_spritesheet.png")
	btn_spider.pressed.connect(Callable(self, "_on_send_spider"))
	vbox2.add_child(btn_spider)
	
	var btn_bat = _create_enemy_button("Bat", 15, 3, "res://character_sprites/bat_fly_spritesheet.png")
	btn_bat.pressed.connect(Callable(self, "_on_send_bat"))
	vbox2.add_child(btn_bat)
	
	var btn_trogg = _create_enemy_button("Trogg", 20, 4, "res://character_sprites/trogg_walk_spritesheet.png")
	btn_trogg.pressed.connect(Callable(self, "_on_send_trogg"))
	vbox2.add_child(btn_trogg)
	
	var btn_orc = _create_enemy_button("Orc", 25, 5, "res://character_sprites/orc_walk_pixelart_spritesheet.png")
	btn_orc.pressed.connect(Callable(self, "_on_send_orc"))
	vbox2.add_child(btn_orc)
	
	var btn_back = Button.new()
	btn_back.text = "Back"
	btn_back.pressed.connect(Callable(self, "_on_vs_back_pressed"))
	vbox2.add_child(btn_back)
	
	vs_send_panel.add_child(vbox2)
	add_child(vs_send_panel)

func _on_vs_upgrades_pressed():
	vs_prompt_panel.visible = false
	_layout_vs_upgrade_panel()
	panel.visible = true
	_focus_first_upgrade_tree_node()

func _on_vs_send_pressed():
	vs_prompt_panel.visible = false
	vs_send_panel.visible = true

func _on_vs_back_pressed():
	vs_send_panel.visible = false
	vs_prompt_panel.visible = true

func show_menu():
	update_button_texts()
	if player: player.can_move = false
	if _is_vs_mode():
		_create_vs_panels()
		vs_prompt_panel.visible = true
		vs_send_panel.visible = false
		panel.visible = false
		vs_prompt_panel.get_child(0).get_child(1).call_deferred("grab_focus")
	else:
		_layout_single_player_upgrade_panel()
		panel.visible = true
		_focus_first_upgrade_tree_node()
		call_deferred("_shift_camera_for_upgrade_tree")
		# Single-player upgrade choices are a planning moment. Pausing prevents
		# enemies from damaging the base while a new player reads the tree.
		set_meta("paused_single_player_gameplay", not get_tree().paused)
		get_tree().paused = true

func hide_menu():
	panel.visible = false
	_restore_camera_after_upgrade_tree()
	if player: player.can_move = true
	if vs_prompt_panel: vs_prompt_panel.visible = false
	if vs_send_panel: vs_send_panel.visible = false
	if bool(get_meta("paused_single_player_gameplay", false)):
		set_meta("paused_single_player_gameplay", false)
		get_tree().paused = false

func _on_close_pressed():
	hide_menu()

func _on_unlock_healthbar_pressed():
	if not healthbar_unlocked and hud.total_gold >= 10:
		hud.add_gold(-10)
		healthbar_unlocked = true
		hud.unlock_healthbar()
		$Panel/UnlockHealthbar.disabled = true

func _on_unlock_base_health_pressed():
	if not base_health_unlocked and hud.total_gold >= 10:
		hud.add_gold(-10)
		base_health_unlocked = true
		hud.unlock_base_healthbar()
		$Panel/UnlockBaseHealth.disabled = true

func _on_unlock_stats_pressed():
	if not stats_unlocked and hud.total_gold >= 10:
		hud.add_gold(-10)
		stats_unlocked = true
		hud.unlock_stats()
		$Panel/UnlockStats.disabled = true

func _on_unlock_wave_timer_pressed():
	if _is_vs_mode():
		return
	if not wave_timer_unlocked and hud.total_gold >= 10:
		hud.add_gold(-10)
		wave_timer_unlocked = true
		hud.unlock_wave_timer()
		$Panel/UnlockWaveTimer.disabled = true

func _on_unlock_xp_pressed():
	if not xp_unlocked and hud.total_gold >= 10:
		hud.add_gold(-10)
		xp_unlocked = true
		hud.unlock_xp()
		$Panel/UnlockXP.disabled = true

func _on_unlock_minimap_pressed():
	if not minimap_unlocked and hud.total_gold >= 20:
		hud.add_gold(-20)
		minimap_unlocked = true
		hud.unlock_minimap()
		$Panel/UnlockMinimap.disabled = true

func _on_upgrade_minimap_pressed():
	if minimap_unlocked and not minimap_upgraded and hud.total_gold >= 50:
		hud.add_gold(-50)
		minimap_upgraded = true
		hud.upgrade_minimap_enemies()
		$Panel/UpgradeMinimap.disabled = true

func _on_upgrade_max_health_pressed():
	if hud.total_gold >= 15:
		hud.add_gold(-15)
		player.max_health += 20
		player.health += 20
		hud.update_player_health(player.health, player.max_health)

func _on_repair_base_pressed() -> void:
	var base := get_parent().get_node_or_null("Base")
	if base and hud.total_gold >= 10 and int(base.health) < int(base.max_health):
		hud.add_gold(-10)
		base.repair(25)

func _on_upgrade_base_health_pressed() -> void:
	var base := get_parent().get_node_or_null("Base")
	if base and hud.total_gold >= 20:
		hud.add_gold(-20)
		base.upgrade_max_health(25)

func _notify_tutorial_upgrade_purchased() -> void:
	var world := get_parent()
	if world and world.has_method("notify_tutorial_upgrade_purchased"):
		world.notify_tutorial_upgrade_purchased()

func _on_upgrade_strength_pressed():
	var cost = get_upgrade_cost(player.strength)
	if hud.total_gems >= cost:
		hud.add_gems(-cost)
		player.upgrade_strength()
		hud.update_stats(player.strength, player.agility, player.intelligence)
		_play_stat_upgrade_effect("Strength", $Panel/UpgradeStrength)
		update_button_texts()
		_notify_tutorial_upgrade_purchased()

func _on_upgrade_agility_pressed():
	var cost = get_upgrade_cost(player.agility)
	if hud.total_gems >= cost:
		hud.add_gems(-cost)
		player.upgrade_agility()
		hud.update_stats(player.strength, player.agility, player.intelligence)
		_play_stat_upgrade_effect("Agility", $Panel/UpgradeAgility)
		update_button_texts()
		_notify_tutorial_upgrade_purchased()

func _on_upgrade_intelligence_pressed():
	var cost = get_upgrade_cost(player.intelligence)
	if hud.total_gems >= cost:
		hud.add_gems(-cost)
		player.upgrade_intelligence()
		hud.update_stats(player.strength, player.agility, player.intelligence)
		_play_stat_upgrade_effect("Intelligence", $Panel/UpgradeIntelligence)
		update_button_texts()
		_notify_tutorial_upgrade_purchased()

func _on_upgrade_pick_power_pressed() -> void:
	if player == null or int(player.get("mining_power_level")) >= 3:
		return
	var cost := get_pick_power_cost()
	if hud.total_gems < cost:
		return
	hud.add_gems(-cost)
	player.upgrade_mining_power()
	_play_stat_upgrade_effect("Pick Power", upgrade_tree_buttons.get("UpgradePickPower") as Control)
	_notify_tutorial_upgrade_purchased()

func _on_upgrade_spikes_pressed():
	if hud.total_gold >= 20:
		hud.add_gold(-20)
		var base = get_parent().get_node_or_null("Base")
		if base:
			base.spikes_level += 1
			update_button_texts()

func _on_swap_hero_pressed():
	if $Panel/SwapHero.visible and Global.unlocked_heroes.size() > 1:
		Global.current_hero = Global.get_next_hero()
		player.update_hero_sprites()
		update_button_texts()

func _on_heal_player_pressed():
	if hud.total_gold >= 10 and player.health < player.max_health:
		hud.add_gold(-10)
		player.health = min(player.health + 20, player.max_health)
		hud.update_player_health(player.health, player.max_health)

func _on_send_rat():
	if hud.total_gold >= 5:
		hud.add_gold(-5)
		emit_signal("send_enemy", 0) # 0 = Rat

func _on_send_spider():
	if hud.total_gold >= 10:
		hud.add_gold(-10)
		emit_signal("send_enemy", 1) # 1 = Spider

func _on_send_bat():
	if hud.total_gold >= 15:
		hud.add_gold(-15)
		emit_signal("send_enemy", 2) # 2 = Bat

func _on_send_trogg():
	if hud.total_gold >= 20:
		hud.add_gold(-20)
		emit_signal("send_enemy", 3) # 3 = Trogg

func _on_send_orc():
	if hud.total_gold >= 25:
		hud.add_gold(-25)
		emit_signal("send_enemy", 4) # 4 = Orc

func _on_buy_rail_pressed():
	if hud.total_gold >= 10:
		hud.add_gold(-10)
		var base = get_parent().get_node_or_null("Base")
		if base and base.has_method("spawn_rail"):
			base.spawn_rail()

func _on_buy_minecart_pressed():
	if hud.total_gold >= 50:
		hud.add_gold(-50)
		var base = get_parent().get_node_or_null("Base")
		if base and base.has_method("spawn_minecart"):
			base.spawn_minecart()

func _on_buy_peon_pressed():
	if hud.total_gold >= 30:
		hud.add_gold(-30)
		var base = get_parent().get_node_or_null("Base")
		if base and base.has_method("spawn_peon"):
			base.spawn_peon()
