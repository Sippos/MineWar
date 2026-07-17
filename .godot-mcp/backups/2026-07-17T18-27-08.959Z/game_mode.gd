extends Node

# Central runtime switch for experimental gameplay loops.
enum Mode {
	EXPLORATION,
	BREACH_EXPERIMENT,
	LINE_WARS,
	EXPLORATION_VS,
}

var current_mode: Mode = Mode.EXPLORATION

func set_mode(mode: Mode) -> void:
	current_mode = mode

func is_exploration() -> bool:
	return current_mode == Mode.EXPLORATION

func is_breach_experiment() -> bool:
	return current_mode == Mode.BREACH_EXPERIMENT

func is_line_wars() -> bool:
	return current_mode == Mode.LINE_WARS
