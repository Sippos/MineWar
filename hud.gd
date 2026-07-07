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

func _ready():
	if minimap:
		minimap.draw.connect(_on_minimap_draw)
		
	var emulate_touch = ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false)
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or emulate_touch:
		var mobile_controls_scene = load("res://mobile_controls.tscn")
		if mobile_controls_scene:
			var mobile_controls = mobile_controls_scene.instantiate()
			add_child(mobile_controls)
			
	_setup_stomp_ui()

func _setup_stomp_ui() -> void:
	stomp_container = Control.new()
	stomp_container.name = "StompContainer"
	stomp_container.visible = false
	stomp_container.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	stomp_container.offset_left = -80
	stomp_container.offset_top = -80
	stomp_container.offset_right = -30
	stomp_container.offset_bottom = -30
	
	var stomp_icon = ColorRect.new()
	stomp_icon.set_anchors_preset(PRESET_FULL_RECT)
	stomp_icon.color = Color(0.2, 0.2, 0.2, 0.8)
	
	var stomp_label = Label.new()
	stomp_label.text = "STOMP"
	stomp_label.add_theme_font_size_override("font_size", 12)
	stomp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stomp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stomp_label.set_anchors_preset(PRESET_FULL_RECT)
	stomp_icon.add_child(stomp_label)
	
	stomp_progress = TextureProgressBar.new()
	stomp_progress.name = "StompProgress"
	stomp_progress.set_anchors_preset(PRESET_FULL_RECT)
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

func _process(delta):
	if minimap and minimap.visible:
		minimap.queue_redraw()

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
	player_health_bar.visible = true
	var pl = get_node_or_null("PlayerLabel")
	if pl: pl.visible = true

func unlock_base_healthbar() -> void:
	if base_health_bar: base_health_bar.visible = true
	var bl = get_node_or_null("BaseLabel")
	if bl: bl.visible = true

func unlock_stats() -> void:
	var sc = get_node_or_null("StatsContainer")
	if sc: sc.visible = true

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
