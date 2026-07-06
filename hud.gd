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

func _ready():
	if minimap:
		minimap.draw.connect(_on_minimap_draw)

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
	get_tree().paused = true
