extends Node

## Temporary profiling harness: loads ONE level.tscn and times the first idle
## frames. Pass a bisect switch after `++` to disable one subsystem before the
## first frame, e.g.
##   godot --headless --path . tests/level_load_profile_runner.tscn ++ nocollision

func _ready() -> void:
	var switches := OS.get_cmdline_user_args()
	if "nolevel" in switches:
		print("[PROF] switch: level never instantiated (control run)")
		for i in range(6):
			var t0 := Time.get_ticks_usec()
			await get_tree().process_frame
			print("[PROF] frame %d: %.1f ms" % [i, (Time.get_ticks_usec() - t0) / 1000.0])
		get_tree().quit()
		return
	var t := Time.get_ticks_usec()
	var packed: PackedScene = load("res://scenes/world/mine/level.tscn")
	print("[PROF] level PackedScene load %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	var level := packed.instantiate()
	add_child(level)
	print("[PROF] level add_child %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))

	if "nocollision" in switches:
		for child in level.get_children():
			if child is TileMapLayer:
				child.collision_enabled = false
		print("[PROF] switch: collision disabled")
	if "noocclude" in switches:
		var mgr := level.get_node_or_null("MineLightOccluderManager")
		if mgr:
			mgr.call("clear_all")
		print("[PROF] switch: occluders cleared")
	if "notilevis" in switches:
		for child in level.get_children():
			if child is TileMapLayer:
				child.visible = false
		print("[PROF] switch: tilemap layers hidden")
	for node_name in ["HUD", "Base", "Player", "UpgradeMenu"]:
		if ("no" + node_name.to_lower()) in switches:
			var n := level.get_node_or_null(node_name)
			if n:
				level.remove_child(n)
				n.queue_free()
			print("[PROF] switch: %s removed" % node_name)
	if "nolight" in switches:
		for light in level.find_children("*", "Light2D", true, false):
			light.enabled = false
		print("[PROF] switch: lights disabled")

	for i in range(6):
		var tf := Time.get_ticks_usec()
		await get_tree().process_frame
		print("[PROF] frame %d: %.1f ms" % [i, (Time.get_ticks_usec() - tf) / 1000.0])
	get_tree().quit()
