extends Node

const TEST_SAVE := "user://mech_workshop_unlock_smoke.save"
const TEST_MECH_SAVE := "user://mech_workshop_unlock_sidecar.save"

var failures: Array[String] = []

func _ready() -> void:
	await _run()
	if failures.is_empty():
		print("MECH_WORKSHOP_UNLOCK_SMOKE_OK")
		get_tree().quit(0)
	else:
		for message in failures:
			push_error(message)
		get_tree().quit(1)

func _run() -> void:
	_cleanup_files()
	var old_heroes: Array = Global.unlocked_heroes.duplicate()
	var old_bases: Array = Global.unlocked_bases.duplicate()
	var old_pending: Array = Global.pending_unlock_rewards.duplicate(true)
	var old_selected_base := Global.selected_base_id

	Global.set_save_path_override(TEST_SAVE)
	MechUnlockPersistence.set_save_path_override(TEST_MECH_SAVE)
	Global.unlocked_heroes = ["Dwarf"]
	Global.unlocked_bases = ["default_base"]
	Global.pending_unlock_rewards = []
	Global.selected_base_id = "default_base"
	MechUnlockPersistence.mech_defeated = false

	MechUnlockPersistence.mark_defeated()
	_expect(Global.unlocked_heroes.has("Mech"), "Pilot defeat should unlock the Mech hero")
	_expect(Global.unlocked_bases.has("mech_base"), "Pilot defeat should unlock the Goblin Mech Workshop")
	_expect(FileAccess.file_exists(TEST_MECH_SAVE), "Mech unlock sidecar should persist")
	var reward_found := false
	for reward_value in Global.pending_unlock_rewards:
		if reward_value is Dictionary:
			var reward := reward_value as Dictionary
			if str(reward.get("hero", "")) == "Mech" and str(reward.get("base", "")) == "mech_base":
				reward_found = true
	_expect(reward_found, "Mech ceremony should include the Workshop base reward")

	Global.unlocked_heroes = ["Dwarf"]
	Global.unlocked_bases = ["default_base"]
	MechUnlockPersistence.mech_defeated = true
	MechUnlockPersistence.call("_restore_unlock")
	_expect(Global.unlocked_heroes.has("Mech"), "Sidecar restore should recover the Mech hero")
	_expect(Global.unlocked_bases.has("mech_base"), "Sidecar restore should recover the Workshop")

	Global.unlocked_heroes = old_heroes
	Global.unlocked_bases = old_bases
	Global.pending_unlock_rewards = old_pending
	Global.selected_base_id = old_selected_base
	Global.set_save_path_override("")
	MechUnlockPersistence.set_save_path_override("")
	_cleanup_files()

func _cleanup_files() -> void:
	for path in [TEST_SAVE, TEST_MECH_SAVE]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
