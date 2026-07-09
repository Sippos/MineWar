extends CanvasLayer

@onready var label = $Label
@onready var str_label = $StatsContainer/StrLabel
@onready var agi_label = $StatsContainer/AgiLabel
@onready var int_label = $StatsContainer/IntLabel
@onready var gold_label = $GoldLabel
@onready var base_health_bar = $BaseHealthBar
@onready var player_health_bar = $PlayerHealthBar
@onready var minimap = $Minimap
@onready var respawn_label = $RespawnLabel
@onready var wave_label = $WaveLabel
@onready var xp_label = $XPLabel
@onready var xp_bar = $XPBar

var total_gems = 0
var total_gold = 0
var minimap_shows_enemies = false

var stomp_container: Control
var stomp_progress: TextureProgressBar
var notice_label: Label
var notice_tween: Tween
var totem_wheel: Control
var totem_wheel_icons := {}
var totem_status_container: Control
var totem_status_slots := {}
var nerubian_status_container: HBoxContainer
var nerubian_spawn_slot: Control
var nerubian_spider_slots := []

const TOTEM_TYPES = ["dig", "heal", "radar", "gem"]
const TOTEM_LABELS = {
	"dig": "Dig",
	"heal": "Heal",
	"radar": "Radar",
	"gem": "Gem"
}
const TOTEM_TEXTURES = {
	"dig": "res://Shaman_Totem_DigBuff.png",
	"heal": "res://Shaman_Totem_Healing.png",
	"radar": "res://Shaman_Totem_Radar.png",
	"gem": "res://Shaman_Totem_GemBuff.png"
}
const NERUBIAN_SPIDER_TEXTURE = "res://character_sprites/spider_walk_spritesheet.png"
const NERUBIAN_MAX_SPIDER_SLOTS = 5
const NERUBIAN_SPAWN_MAX_COOLDOWN = 3.5
const HUD_STACK_LEFT := 20.0
const HUD_STACK_TOP := 62.0
const HUD_STACK_GAP := 8.0
const HUD_STACK_LABEL_LEFT := 30.0
const HUD_STATS_HEIGHT := 36.0
const HUD_HEALTH_BAR_OFFSET_Y := 18.0
const HUD_HEALTH_MODULE_HEIGHT := 66.0

func _ready():
	if minimap:
		minimap.draw.connect(_on_minimap_draw)
		
	var is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if OS.has_feature("web"):
		is_mobile = is_mobile or JavaScriptBridge.eval("/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)")
		
	if is_mobile:
		var mobile_controls_scene = load("res://mobile_controls.tscn")
		if mobile_controls_scene:
			var mobile_controls = mobile_controls_scene.instantiate()
			add_child(mobile_controls)
			
	_setup_stomp_ui()
	_setup_notice_ui()
	_setup_totem_wheel_ui()
	_setup_totem_status_ui()
	_setup_nerubian_status_ui()
	_relayout_unlocked_hud()

func _setup_stomp_ui() -> void:
	stomp_container = Control.new()
	stomp_container.name = "StompContainer"
	stomp_container.visible = false
	stomp_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stomp_container.offset_left = -80
	stomp_container.offset_top = -80
	stomp_container.offset_right = -30
	stomp_container.offset_bottom = -30
	
	var stomp_icon = ColorRect.new()
	stomp_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	stomp_icon.color = Color(0.2, 0.2, 0.2, 0.8)
	
	var stomp_label = Label.new()
	stomp_label.text = "STOMP"
	stomp_label.add_theme_font_size_override("font_size", 12)
	stomp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stomp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stomp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	stomp_icon.add_child(stomp_label)
	
	stomp_progress = TextureProgressBar.new()
	stomp_progress.name = "StompProgress"
	stomp_progress.set_anchors_preset(Control.PRESET_FULL_RECT)
	stomp_progress.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	var bg_tex = GradientTexture2D.new()
	bg_tex.width = 50
	bg_tex.height = 50
	bg_tex.fill_from = Vector2(0,0)
	bg_tex.fill_to = Vector2(0,0)
	var grad = Gradient.new()
	grad.colors = PackedColorArray([Color(0,0,0,0.65), Color(0,0,0,0.65)])
	bg_tex.gradient = grad
	stomp_progress.texture_progress = bg_tex
	stomp_progress.step = 0.01
	
	stomp_icon.add_child(stomp_progress)
	stomp_container.add_child(stomp_icon)
	add_child(stomp_container)

func _setup_notice_ui() -> void:
	notice_label = Label.new()
	notice_label.name = "NoticeLabel"
	notice_label.visible = false
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 22)
	notice_label.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	notice_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	notice_label.offset_left = 220
	notice_label.offset_top = 72
	notice_label.offset_right = -220
	notice_label.offset_bottom = 112
	add_child(notice_label)

func _process(delta):
	if minimap and minimap.visible:
		minimap.queue_redraw()
	_update_nerubian_status_from_world()

func _relayout_unlocked_hud() -> void:
	var y := HUD_STACK_TOP
	var stats_container = get_node_or_null("StatsContainer")
	if stats_container and stats_container.visible:
		stats_container.position = Vector2(HUD_STACK_LEFT, y)
		y += HUD_STATS_HEIGHT + HUD_STACK_GAP
	y = _layout_health_hud_module("BaseLabel", base_health_bar, y)
	y = _layout_health_hud_module("PlayerLabel", player_health_bar, y)

func _layout_health_hud_module(label_name: String, bar: Control, y: float) -> float:
	var title_label = get_node_or_null(label_name)
	var is_visible = (bar != null and bar.visible) or (title_label != null and title_label.visible)
	if not is_visible:
		return y
	if title_label:
		title_label.position = Vector2(HUD_STACK_LABEL_LEFT, y)
	if bar:
		bar.position = Vector2(HUD_STACK_LEFT, y + HUD_HEALTH_BAR_OFFSET_Y)
	return y + HUD_HEALTH_MODULE_HEIGHT + HUD_STACK_GAP

func _setup_totem_wheel_ui() -> void:
	totem_wheel = Control.new()
	totem_wheel.name = "TotemWheel"
	totem_wheel.visible = false
	totem_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	totem_wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(totem_wheel)
	
	var dim = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	totem_wheel.add_child(dim)
	
	var offsets = {
		"dig": Vector2(0, -92),
		"heal": Vector2(92, 0),
		"radar": Vector2(0, 92),
		"gem": Vector2(-92, 0)
	}
	
	for type in TOTEM_TYPES:
		var slot = PanelContainer.new()
		slot.name = "%sSlot" % type.capitalize()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.custom_minimum_size = Vector2(74, 84)
		slot.set_anchors_preset(Control.PRESET_CENTER)
		slot.offset_left = offsets[type].x - 37
		slot.offset_top = offsets[type].y - 42
		slot.offset_right = offsets[type].x + 37
		slot.offset_bottom = offsets[type].y + 42
		
		var box = VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_child(box)
		
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(TOTEM_TEXTURES[type])
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		
		var text = Label.new()
		text.text = TOTEM_LABELS[type]
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", 12)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(text)
		
		totem_wheel.add_child(slot)
		totem_wheel_icons[type] = slot

func _setup_totem_status_ui() -> void:
	totem_status_container = HBoxContainer.new()
	totem_status_container.name = "TotemStatus"
	totem_status_container.visible = false
	totem_status_container.alignment = BoxContainer.ALIGNMENT_END
	totem_status_container.add_theme_constant_override("separation", 6)
	totem_status_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	totem_status_container.offset_left = -282
	totem_status_container.offset_top = -136
	totem_status_container.offset_right = -28
	totem_status_container.offset_bottom = -82
	add_child(totem_status_container)
	
	for type in TOTEM_TYPES:
		var slot = _create_icon_status_slot(TOTEM_TEXTURES[type], Vector2(56, 54))
		slot.visible = false
		totem_status_container.add_child(slot)
		totem_status_slots[type] = slot

func _setup_nerubian_status_ui() -> void:
	nerubian_status_container = HBoxContainer.new()
	nerubian_status_container.name = "NerubianStatus"
	nerubian_status_container.visible = false
	nerubian_status_container.alignment = BoxContainer.ALIGNMENT_END
	nerubian_status_container.add_theme_constant_override("separation", 6)
	nerubian_status_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	nerubian_status_container.offset_left = -392
	nerubian_status_container.offset_top = 18
	nerubian_status_container.offset_right = -24
	nerubian_status_container.offset_bottom = 78
	add_child(nerubian_status_container)
	
	nerubian_spawn_slot = _create_icon_status_slot(NERUBIAN_SPIDER_TEXTURE, Vector2(64, 58), "BROOD")
	nerubian_status_container.add_child(nerubian_spawn_slot)
	
	for i in range(NERUBIAN_MAX_SPIDER_SLOTS):
		var slot = _create_icon_status_slot(NERUBIAN_SPIDER_TEXTURE, Vector2(48, 50))
		slot.visible = false
		nerubian_status_container.add_child(slot)
		nerubian_spider_slots.append(slot)

func _create_icon_status_slot(texture_path: String, size: Vector2, title: String = "") -> Control:
	var slot = Control.new()
	slot.custom_minimum_size = size
	
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(bg)
	
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.texture = load(texture_path)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6
	icon.offset_top = 4
	icon.offset_right = -6
	icon.offset_bottom = -12
	slot.add_child(icon)
	
	var fill = ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(0.25, 0.75, 1.0, 0.35)
	fill.anchor_left = 0
	fill.anchor_right = 1
	fill.anchor_top = 1
	fill.anchor_bottom = 1
	fill.offset_left = 0
	fill.offset_right = 0
	fill.offset_top = -4
	fill.offset_bottom = 0
	slot.add_child(fill)
	
	var label = Label.new()
	label.name = "Timer"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", 10)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(label)
	
	if title != "":
		var title_label = Label.new()
		title_label.name = "Title"
		title_label.text = title
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		title_label.add_theme_font_size_override("font_size", 9)
		title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(title_label)
	
	return slot

func add_gems(amount: int) -> void:
	total_gems += amount
	label.text = "%d" % total_gems

func add_gold(amount: int) -> void:
	total_gold += amount
	if gold_label:
		gold_label.text = "%d" % total_gold

func update_health(new_health: int) -> void:
	if base_health_bar:
		base_health_bar.value = new_health

func update_stats(str_val: int, agi_val: int, int_val: int) -> void:
	if str_label: str_label.text = str(str_val)
	if agi_label: agi_label.text = str(agi_val)
	if int_label: int_label.text = str(int_val)

func unlock_healthbar() -> void:
	if player_health_bar:
		player_health_bar.visible = true
	var pl = get_node_or_null("PlayerLabel")
	if pl: pl.visible = true
	_relayout_unlocked_hud()

func unlock_base_healthbar() -> void:
	if base_health_bar: base_health_bar.visible = true
	var bl = get_node_or_null("BaseLabel")
	if bl: bl.visible = true
	_relayout_unlocked_hud()

func unlock_stats() -> void:
	var sc = get_node_or_null("StatsContainer")
	if sc: sc.visible = true
	_relayout_unlocked_hud()

func unlock_wave_timer() -> void:
	if wave_label: wave_label.visible = true
	var wb = get_node_or_null("WaveBar")
	if wb: wb.visible = true

func unlock_xp() -> void:
	if xp_bar: xp_bar.visible = true
	if xp_label: xp_label.visible = true

func update_player_health(current: int, max_hp: int) -> void:
	player_health_bar.max_value = max_hp
	player_health_bar.value = current

func update_xp(level: int, current_xp: int, max_xp: int) -> void:
	if xp_label:
		xp_label.text = "Lvl %d: %d / %d XP" % [level, current_xp, max_xp]
	if xp_bar:
		xp_bar.max_value = max_xp
		xp_bar.value = current_xp

func update_stomp_cooldown(stomp_level: int, current_cooldown: float, max_cooldown: float) -> void:
	if stomp_level > 0:
		if stomp_container and not stomp_container.visible:
			stomp_container.visible = true
		if stomp_progress:
			stomp_progress.max_value = max_cooldown
			stomp_progress.value = current_cooldown

func show_notice(text: String, duration: float = 1.8) -> void:
	if not notice_label:
		return
	if notice_tween and notice_tween.is_running():
		notice_tween.kill()
	notice_label.text = text
	notice_label.visible = true
	notice_label.modulate = Color(1, 1, 1, 1)
	notice_tween = create_tween()
	notice_tween.tween_interval(duration)
	notice_tween.tween_property(notice_label, "modulate", Color(1, 1, 1, 0), 0.35)
	notice_tween.tween_callback(func(): notice_label.visible = false)

func show_totem_wheel(selected_type: String) -> void:
	if not totem_wheel:
		return
	totem_wheel.visible = true
	update_totem_wheel_selection(selected_type)

func update_totem_wheel_selection(selected_type: String) -> void:
	for type in totem_wheel_icons.keys():
		var slot = totem_wheel_icons[type]
		if type == selected_type:
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
			slot.scale = Vector2(1.16, 1.16)
		else:
			slot.modulate = Color(0.55, 0.65, 0.75, 0.9)
			slot.scale = Vector2.ONE

func hide_totem_wheel() -> void:
	if totem_wheel:
		totem_wheel.visible = false

func update_totem_status(statuses: Dictionary) -> void:
	var any_visible = false
	for type in TOTEM_TYPES:
		var slot = totem_status_slots.get(type)
		if not slot:
			continue
		var data = statuses.get(type, {})
		var active = float(data.get("active", 0.0))
		var cooldown = float(data.get("cooldown", 0.0))
		var ratio = float(data.get("ratio", 0.0))
		var visible = active > 0.0 or cooldown > 0.0
		slot.visible = visible
		if not visible:
			continue
		any_visible = true
		if active > 0.0:
			_update_status_slot(slot, active, ratio, false, Color(0.2, 0.8, 1.0, 0.45))
		else:
			_update_status_slot(slot, cooldown, 0.0, true, Color(0.1, 0.1, 0.1, 0.55))
	
	totem_status_container.visible = any_visible

func _update_nerubian_status_from_world() -> void:
	if not nerubian_status_container:
		return
	var world = get_parent()
	var player = world.get_node_or_null("Player") if world else null
	if not player or str(player.get("current_hero_name")) != "Nerubian":
		nerubian_status_container.visible = false
		return
	
	nerubian_status_container.visible = true
	var cooldown = max(float(player.get("nerubian_spawn_cooldown_timer")), 0.0)
	var cooldown_ratio = clamp(cooldown / NERUBIAN_SPAWN_MAX_COOLDOWN, 0.0, 1.0)
	if cooldown > 0.0:
		_update_status_slot(nerubian_spawn_slot, cooldown, cooldown_ratio, true, Color(0.1, 0.1, 0.1, 0.55))
	else:
		_update_status_slot(nerubian_spawn_slot, 0.0, 1.0, false, Color(0.2, 0.9, 0.35, 0.42), "READY")
	
	var spider_data = []
	for spider in get_tree().get_nodes_in_group("nerubian_spiders"):
		if is_instance_valid(spider) and spider.get("owner_player") == player:
			var active = float(spider.get("lifetime"))
			var max_life = active
			if spider.has_method("get_max_lifetime"):
				max_life = spider.get_max_lifetime()
			var ratio = active / max(max_life, 0.01)
			spider_data.append({"lifetime": active, "ratio": clamp(ratio, 0.0, 1.0)})
	
	spider_data.sort_custom(func(a, b): return float(a["lifetime"]) < float(b["lifetime"]))
	for i in range(nerubian_spider_slots.size()):
		var slot = nerubian_spider_slots[i]
		if i < spider_data.size():
			slot.visible = true
			_update_status_slot(slot, float(spider_data[i]["lifetime"]), float(spider_data[i]["ratio"]), false, Color(0.75, 0.35, 1.0, 0.38))
		else:
			slot.visible = false

func _update_status_slot(slot: Control, time_value: float, ratio: float, is_cooldown: bool, fill_color: Color, override_text: String = "") -> void:
	if not slot:
		return
	var fill = slot.get_node_or_null("Fill")
	var label = slot.get_node_or_null("Timer")
	var icon = slot.get_node_or_null("Icon")
	slot.modulate = Color(0.58, 0.58, 0.58, 0.95) if is_cooldown else Color(1, 1, 1, 1)
	if label:
		if override_text != "":
			label.text = override_text
		elif time_value > 0.0:
			label.text = "%d" % ceil(time_value)
		else:
			label.text = ""
	if fill:
		fill.color = fill_color
		fill.anchor_top = clamp(1.0 - ratio, 0.0, 1.0)
	if icon:
		icon.modulate = Color.WHITE

func unlock_minimap() -> void:
	minimap.visible = true

func upgrade_minimap_enemies() -> void:
	minimap_shows_enemies = true

func update_respawn_timer(time_left: float) -> void:
	if time_left > 0:
		respawn_label.visible = true
		respawn_label.text = "Respawning in %.1f..." % time_left
	else:
		respawn_label.visible = false

func update_wave_info(wave: int, time_left: float, max_time: float, is_boss: bool) -> void:
	if is_boss:
		wave_label.add_theme_color_override("font_color", Color(1, 0, 0)) # Red text for Boss
		if time_left < 0:
			wave_label.text = "BOSS WAVE %d - COMBAT!" % wave
		else:
			wave_label.text = "BOSS WAVE %d!" % wave
	else:
		wave_label.add_theme_color_override("font_color", Color(1, 1, 1))
		if time_left < 0:
			wave_label.text = "Wave %d - Combat Phase" % wave
		else:
			wave_label.text = "Wave %d" % wave
	
	var wave_bar = get_node_or_null("WaveBar")
	if wave_bar:
		wave_bar.max_value = max_time
		if time_left < 0:
			wave_bar.value = max_time
		else:
			wave_bar.value = time_left

func _on_minimap_draw() -> void:
	var world = get_parent()
	var tile_map = world.get_node_or_null("BlockLayer")
	if not tile_map: return
	
	minimap.draw_rect(Rect2(0, 0, 200, 200), Color(0.1, 0.1, 0.1, 0.8))
	
	for x in range(-20, 20):
		for y in range(-2, 30):
			var cell = Vector2i(x, y)
			var px = (x + 20) * 5
			var py = (y + 2) * 5
			
			if tile_map.get_cell_source_id(cell) == -1:
				minimap.draw_rect(Rect2(px, py, 5, 5), Color(0.5, 0.4, 0.3))
			else:
				minimap.draw_rect(Rect2(px, py, 5, 5), Color(0.2, 0.15, 0.1))
				
	var base_node = world.get_node_or_null("Base")
	if base_node:
		var base_cell = tile_map.local_to_map(tile_map.to_local(base_node.global_position))
		minimap.draw_rect(Rect2((base_cell.x + 20) * 5 - 2, (base_cell.y + 2) * 5 - 2, 9, 9), Color(0, 0.5, 1))

	var player = world.get_node_or_null("Player")
	if player and player.visible:
		var player_cell = tile_map.local_to_map(tile_map.to_local(player.global_position))
		minimap.draw_rect(Rect2((player_cell.x + 20) * 5, (player_cell.y + 2) * 5, 5, 5), Color(0, 1, 0))

	if minimap_shows_enemies:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy):
				var enemy_cell = tile_map.local_to_map(tile_map.to_local(enemy.global_position))
				minimap.draw_rect(Rect2((enemy_cell.x + 20) * 5, (enemy_cell.y + 2) * 5, 5, 5), Color(1, 0, 0))

func on_game_over() -> void:
	respawn_label.text = "GAME OVER! Base Destroyed!"
	respawn_label.visible = true
	
	if not has_node("GameOverMenuButton"):
		var btn = Button.new()
		btn.name = "GameOverMenuButton"
		btn.text = "Back to Main Menu"
		btn.process_mode = Node.PROCESS_MODE_ALWAYS
		btn.add_theme_font_size_override("font_size", 32)
		btn.custom_minimum_size = Vector2(300, 60)
		
		var viewport_size = get_viewport().get_visible_rect().size
		btn.position = Vector2((viewport_size.x - 300) / 2, viewport_size.y / 2 + 50)
		
		btn.pressed.connect(func():
			get_tree().paused = false
			if multiplayer.multiplayer_peer:
				multiplayer.multiplayer_peer.close()
				multiplayer.multiplayer_peer = null
			get_tree().change_scene_to_file("res://menu.tscn")
		)
		add_child(btn)
	
	get_tree().paused = true
