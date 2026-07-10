extends CanvasLayer

signal upgrade_selected(upgrade_type: String)

var options_container: VBoxContainer
var hero_controller: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(_legacy_has_stomp = false) -> void:
	call_deferred("_build_hero_upgrade_menu")

func _build_hero_upgrade_menu() -> void:
	hero_controller = _find_hero_controller()
	var panel := $Panel
	panel.offset_left = -310.0
	panel