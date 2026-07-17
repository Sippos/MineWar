extends Node

# Central runtime switch for experimental gameplay loops.
enum Mode {
	KEEPER,
	EXPLORATION,
	BREACH_EXPERIMENT,
	LINE_WARS,
	EXPLORATION_VS,
}

var current_mode: Mode = Mode.KEEPER

func set_mode(mode: Mode) -> void:
	current_mode = mode

func is_keeper() -> bool:
	return current_mode == Mode.KEEPER

func is_exploration() -> bool:
	return current_mode == Mode.EXPLORATION

func is_breach_experiment() -> bool:
	return current_mode == Mode.BREACH_EXPERIMENT

func is_line_wars() -> bool:
	return current_mode == Mode.LINE_WARS
