extends Control

const MENU_SCENE := "res://scenes/menus/main/menu.tscn"
const PREPARATION_DURATION := 20.0
const ROUND_DURATION := 40.0
const INCOME_INTERVAL := 6.0

@onready var lane_one: Control = $BoardRow/LaneOne
@onready var lane_two: Control = $BoardRow/LaneTwo
@onready var phase_label: Label = $PhaseLabel
@onready var instruction_label: Label = $InstructionLabel
@onready var phase_button: Button = $PhaseButton
@onready var return_button: Button = $ReturnButton
@onready var restart_button: Button = $RestartButton
@onready var result_label: Label = $ResultLabel

var current_round := 1
var preparation_remaining := PREPARATION_DURATION
var round_remaining := ROUND_DURATION
var income_remaining := INCOME_INTERVAL
var combat_started := false
var game_over := false
var _game_over_resolution_queued := false

func _ready() -> void:
	lane_one.setup("PLAYER 1", 1, Global.hero_p1)
	lane_two.setup("PLAYER 2", 2, Global.hero_p2)
	lane_one.enemy_purchased.connect(_on_player_one_purchased)
	lane_two.enemy_purchased.connect(_on_player_two_purchased)
	lane_one.core_destroyed.connect(_on_lane_core_destroyed)
	lane_two.core_destroyed.connect(_on_lane_core_destroyed)
	lane_one.economy_changed.connect(_refresh_phase_ui)
	lane_two.economy_changed.connect(_refresh_phase_ui)
	phase_button.pressed.connect(_on_phase_button_pressed)
	return_button.pressed.connect(_on_return_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	_begin_preparation()

func _process(delta: float) -> void:
	if game_over:
		return
	if not combat_started:
		preparation_remaining = maxf(0.0, preparation_remaining - delta)
		if preparation_remaining <= 0.0:
			_start_combat()
		else:
			_refresh_phase_ui()
		return

	round_remaining -= delta
	income_remaining -= delta
	while income_remaining <= 0.0:
		income_remaining += INCOME_INTERVAL
		lane_one.grant_income()
		lane_two.grant_income()
	while round_remaining <= 0.0:
		round_remaining += ROUND_DURATION
		current_round += 1
		lane_one.start_round(current_round)
		lane_two.start_round(current_round)
	_refresh_phase_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_return_pressed()

func _begin_preparation() -> void:
	current_round = 1
	preparation_remaining = PREPARATION_DURATION
	round_remaining = ROUND_DURATION
	income_remaining = INCOME_INTERVAL
	combat_started = false
	game_over = false
	lane_one.enter_preparation()
	lane_two.enter_preparation()
	instruction_label.text = "Build for 20 seconds. When combat starts, every Rat or Orc appears in the opponent's mine immediately."
	phase_button.disabled = false
	phase_button.text = "START COMBAT EARLY"
	result_label.visible = false
	restart_button.visible = false
	_refresh_phase_ui()

func _start_combat() -> void:
	if combat_started or game_over:
		return
	combat_started = true
	current_round = 1
	round_remaining = ROUND_DURATION
	income_remaining = INCOME_INTERVAL
	lane_one.start_combat()
	lane_two.start_combat()
	lane_one.start_round(current_round)
	lane_two.start_round(current_round)
	instruction_label.text = "LIVE: dig while enemies move. Rat is fast; Orc unlocks in Round 2 and is slow, tough, and damaging."
	phase_button.disabled = true
	_refresh_phase_ui()

func _on_phase_button_pressed() -> void:
	if not combat_started:
		_start_combat()

func _on_player_one_purchased(enemy_type: String) -> void:
	lane_two.receive_enemy(enemy_type, current_round)
	_refresh_phase_ui()

func _on_player_two_purchased(enemy_type: String) -> void:
	lane_one.receive_enemy(enemy_type, current_round)
	_refresh_phase_ui()

func _refresh_phase_ui() -> void:
	if not is_node_ready():
		return
	if game_over:
		return
	if not combat_started:
		phase_label.text = "OPENING BUILD • COMBAT IN %ds" % ceili(preparation_remaining)
		phase_button.text = "START COMBAT EARLY"
		return
	phase_label.text = "ROUND %d • NEXT ROUND %ds • INCOME %ds" % [
		current_round,
		ceili(round_remaining),
		ceili(income_remaining),
	]
	phase_button.text = "LIVE • P1 INCOMING %d • P2 INCOMING %d" % [lane_one.get_enemy_count(), lane_two.get_enemy_count()]

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
	phase_label.text = "DUEL COMPLETE • ROUND %d" % current_round
	instruction_label.text = "Immediate sends, live rerouting, and income growth decided this duel."
	phase_button.disabled = true
	phase_button.text = "MATCH COMPLETE"
	restart_button.visible = true

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_return_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
