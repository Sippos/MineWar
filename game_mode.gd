extends Node

# Central runtime switch for MineWars gameplay loops.
enum Mode {
	SIEGE,
	EXPLORATION,
	BREACH_EXPERIMENT,
	LINE_WARS,
	EXPLORATION_VS,
	HUB,
}

var current_mode: Mode = Mode.SIEGE

func set_mode(mode: Mode) -> void:
	current_mode = mode

func is_siege() -> bool:
	return current_mode == Mode.SIEGE

func is_exploration() -> bool:
	return current_mode == Mode.EXPLORATION

func is_breach_experiment() -> bool:
	return current_mode == Mode.BREACH_EXPERIMENT

func is_line_wars() -> bool:
	return current_mode == Mode.LINE_WARS

func is_hub() -> bool:
	return current_mode == Mode.HUB
