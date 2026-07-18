extends Node

const DEFAULT_SAVE_PATH := "user://mech_unlock.save"
const MECH_UNLOCK_REWARD := {
	"type": "hero_base",
	"hero": "Mech",
	"base": "mech_base",
	"title": "THE WAR MECH IS YOURS",
	"description": "The defeated goblin pilot has surrendered the Mech and opened the Goblin Mech Workshop. Its emergency pilot can rebuild the frame faster there."
}

var mech_defeated := false
var save_path_override := ""

func get_save_path() -> String:
	return save_path_override if not save_path_override.is_empty() else DEFAULT_SAVE_PATH

func set_save_path_override(path: String) -> void:
	save_path_override = path
	mech_defeated = FileAccess.file_exists(get_save_path())

func _ready() -> void:
	mech_defeated = FileAccess.file_exists(get_save_path())
	call_deferred("_restore_unlock")

func mark_defeated() -> void:
	var save_path := get_save_path()
	var first_defeat := not mech_defeated and not FileAccess.file_exists(save_path)
	mech_defeated = true
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_8(1)
		file.close()
	_restore_unlock()
	if first_defeat:
		_queue_unlock_reward()

func _restore_unlock() -> void:
	if not mech_defeated:
		return
	var global_state := get_node_or_null("/root/Global")
	if global_state and global_state.has_method("unlock_hero"):
		global_state.unlock_hero("Mech")
	if global_state and global_state.has_method("unlock_base"):
		global_state.unlock_base("mech_base")

func _queue_unlock_reward() -> void:
	var global_state := get_node_or_null("/root/Global")
	if global_state == null:
		return
	var pending_value: Variant = global_state.get("pending_unlock_rewards")
	if pending_value is Array:
		var pending: Array = pending_value
		var already_queued := false
		for reward_value in pending:
			if reward_value is Dictionary and str((reward_value as Dictionary).get("hero", "")) == "Mech":
				already_queued = true
				break
		if not already_queued:
			pending.append(MECH_UNLOCK_REWARD.duplicate(true))
			global_state.set("pending_unlock_rewards", pending)
	if global_state.has_method("save_game"):
		global_state.save_game()
