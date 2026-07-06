extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/VBoxContainer/BackButton.call_deferred("grab_focus")

func _on_back_pressed() -> void:
	queue_free()
