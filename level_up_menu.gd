extends CanvasLayer

signal upgrade_selected(upgrade_type: String)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # keep running while tree paused

func setup(has_stomp: bool) -> void:
	var btn_stomp = $Panel/VBoxContainer/ButtonStomp
	if has_stomp:
		btn_stomp.text = "Upgrade Stomp (Level Up)"
	else:
		btn_stomp.text = "Learn Stomp"
	btn_stomp.call_deferred("grab_focus")

func _on_button_stomp_pressed() -> void:
	upgrade_selected.emit("stomp")
	hide_and_unpause()

func _on_button_health_pressed() -> void:
	upgrade_selected.emit("health")
	hide_and_unpause()

func _on_button_damage_pressed() -> void:
	upgrade_selected.emit("damage")
	hide_and_unpause()

func hide_and_unpause() -> void:
	get_tree().paused = false
	queue_free()
