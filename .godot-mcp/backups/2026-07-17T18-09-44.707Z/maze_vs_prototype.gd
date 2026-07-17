extends Control

const MENU_SCENE := "res://scenes/menus/main/menu.tscn"

@onready var lane_one: Control = $BoardRow/LaneOne
@onready var lane_two: Control = $BoardRow/LaneTwo
@onready var wave_label: Label = $WaveLabel
@onready var instruction_label: Label = $InstructionLabel
@onready var start_wave_button: Button = $StartWaveButton
@onready var return_button: Button = $ReturnButton
@onready var restart_button: Button = $RestartButton
@onready var result_label: Label = $ResultLabel

var current_wave := 1
var wave_in_progress := false
var game_over := false
var finished_lanes: Dictionary = {}
var _game_over_resolution_queued := false

func _ready() -> void:
	lane_one.setup("PLAYER 1 • %s" % Global.hero_p1, 1, Global.hero_p1)
	lane_two.setup("PLAYER 2 • %s" % Global.hero_p2, 2, Global.hero_p2)

	lane_one.ready_changed.connect(_on_lane_ready_changed)
	lane_two.ready_changed.connect(_on_lane_ready_changed)
	lane_one.wave_finished.connect(_on_lane_wave_finished)
	lane_two.wave_finished.connect(_on_lane_wave_finished)
	lane_one.core_destroyed.connect(_on_lane_core_destroyed)
	lane_two.core_destroyed.connect(_on_lane_core_destroyed)
	lane_one.attack_changed.connect(_on_attack_changed)
	lane_two.attack_changed.connect(_on_attack_changed)

	start_wave_button.pressed.connect(_on_start_wave_pressed)
	return_button.pressed.connect(_on_return_pressed)
	restart_button.pressed.connect(_on_restart_pressed)

	_begin_build_phase()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_return_pressed()

func _begin_build_phase() -> void:
	if game_over:
		return
	wave_in_progress = false
	finished_lanes.clear()
	lane_one.enter_build_phase(current_wave)
	lane_two.enter_build_phase(current_wave)
	wave_label.text = "WAVE %d • BUILD PHASE" % current_wave
	instruction_label.text = _wave_preview_text()
	start_wave_button.text = "START WAVE %d" % current_wave
	_refresh_start_button()

func _on_lane_ready_changed(_ready: bool) -> void:
	_refresh_start_button()

func _on_attack_changed(_amount: int) -> void:
	instruction_label.text = _wave_preview_text()
	_refresh_start_button()

func _refresh_start_button() -> void:
	if game_over:
		start_wave_button.disabled = true
		return
	start_wave_button.disabled = wave_in_progress or not lane_one.is_lane_ready() or not lane_two.is_lane_ready()
	if wave_in_progress:
		start_wave_button.text = "WAVE RUNNING"
	elif lane_one.is_lane_ready() and lane_two.is_lane_ready():
		start_wave_button.text = "START WAVE %d" % current_wave
	else:
		start_wave_button.text = "BOTH PLAYERS MUST READY"

func _on_start_wave_pressed() -> void:
	if game_over or wave_in_progress:
		return
	if not lane_one.is_lane_ready() or not lane_two.is_lane_ready():
		return

	wave_in_progress = true
	finished_lanes.clear()
	var player_one_send: Array[String] = lane_one.consume_queued_attack()
	var player_two_send: Array[String] = lane_two.consume_queued_attack()
	var base_enemy_count := _base_enemy_count()
	var enemy_health := _enemy_health()
	var enemy_speed := _enemy_speed()

	lane_one.begin_wave(current_wave, base_enemy_count, enemy_health, enemy_speed, player_two_send)
	lane_two.begin_wave(current_wave, base_enemy_count, enemy_health, enemy_speed, player_one_send)
	wave_label.text = "WAVE %d • P1 RECEIVES %d • P2 RECEIVES %d" % [
		current_wave,
		base_enemy_count + player_two_send.size(),
		base_enemy_count + player_one_send.size()
	]
	instruction_label.text = "Hero abilities are emergency tools; the highlighted route remains your main defence. Brutes deal 2 core damage."
	_refresh_start_button()

func _on_lane_wave_finished(lane: Control) -> void:
	if game_over:
		return
	finished_lanes[lane.get_instance_id()] = true
	if finished_lanes.size() < 2:
		wave_label.text = "WAVE %d • ONE MINE CLEARED • WAITING FOR THE OTHER" % current_wave
		return
	current_wave += 1
	call_deferred("_begin_build_phase")

func _on_lane_core_destroyed(_lane: Control) -> void:
	if _game_over_resolution_queued:
		return
	_game_over_resolution_queued = true
	call_deferred("_resolve_game_over")

func _resolve_game_over() -> void:
	_game_over_resolution_queued = false
	if game_over:
		return
	game_over = true
	wave_in_progress = false
	var hp_one: int = lane_one.get_core_hp()
	var hp_two: int = lane_two.get_core_hp()
	var result: String
	if hp_one <= 0 and hp_two <= 0:
		result = "DRAW • BOTH CORES FELL"
	elif hp_one <= 0:
		result = "PLAYER 2 WINS • %s" % Global.hero_p2
	else:
		result = "PLAYER 1 WINS • %s" % Global.hero_p1
	result_label.text = result
	result_label.visible = true
	wave_label.text = "DUEL COMPLETE AT WAVE %d" % current_wave
	instruction_label.text = "Compare route ratings, send choices, and ability timing before restarting the duel."
	start_wave_button.disabled = true
	restart_button.visible = true

func _base_enemy_count() -> int:
	return 3 + current_wave

func _enemy_health() -> float:
	return 14.0 + float(current_wave) * 2.0

func _enemy_speed() -> float:
	return 2.65 + float(current_wave - 1) * 0.08

func _wave_preview_text() -> String:
	return "Next: %d Raiders • HP %.0f • Speed %.2f  |  P1 pressure %d • P2 pressure %d  |  Runner fast / Brute heavy" % [
		_base_enemy_count(),
		_enemy_health(),
		_enemy_speed(),
		lane_one.get_queued_send_points(),
		lane_two.get_queued_send_points(),
	]

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_return_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
