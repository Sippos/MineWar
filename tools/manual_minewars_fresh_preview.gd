extends Node

const TEMP_SAVE := "user://minewars_manual_feel_test.save"
const TEMP_MECH_SAVE := "user://minewars_manual_feel_mech.save"

func _ready() -> void:
	Global.set_save_path_override(TEMP_SAVE)
	MechUnlockPersistence.set_save_path_override(TEMP_MECH_SAVE)
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	if FileAccess.file_exists(TEMP_MECH_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MECH_SAVE))
	Global.unlocked_heroes = Global.DEFAULT