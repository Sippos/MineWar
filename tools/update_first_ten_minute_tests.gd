extends Node

var failures: Array[String] = []

func _ready() -> void:
	var path := "res://tests/minewars_complete_run_runner.gd"
	var source := FileAccess.get_file_as_string(path)
	var old_text := "\t_test_initial_journey_state()\n\t_test_build_identities()\n\n\tvar initial_gems := int(hud.get(\"total_gems\"))"
	var new_text := "\t_test_initial_journey_state()\n\t_test_build_identities()\n\tif bool(controller.get(\"first_run_training_active\")):\n\t\tlevel.set(\"onboarding_active\", false)\n\t\tGlobal.complete_prototype_onboarding()\n\t\tawait _wait_frames(