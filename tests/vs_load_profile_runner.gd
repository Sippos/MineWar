extends Node

## Temporary profiling harness: instantiates vs_mode.tscn and reports how long
## the whole VS-mode load takes. Run with:
##   godot --headless --path . tests/vs_load_profile_runner.tscn

func _ready() -> void:
	var t_load := Time.get_ticks_usec()
	var packed: PackedScene = load("res://vs_mode.tscn")
	print("[PROF] PackedScene load %.1f ms" % ((Time.get_ticks_usec() - t_load) / 1000.0))

	var t_inst := Time.get_ticks_usec()
	var vs := packed.instantiate()
	print("[PROF] instantiate %.1f ms" % ((Time.get_ticks_usec() - t_inst) / 1000.0))

	var t_add := Time.get_ticks_usec()
	add_child(vs)
	print("[PROF] add_child (_ready sync part) %.1f ms" % ((Time.get_ticks_usec() - t_add) / 1000.0))

	# Let the awaited generation finish.
	for i in range(10):
		var tf := Time.get_ticks_usec()
		await get_tree().process_frame
		print("[PROF] frame %d: %.1f ms" % [i, (Time.get_ticks_usec() - tf) / 1000.0])
	print("[PROF] WALL CLOCK to settled %.1f ms" % ((Time.get_ticks_usec() - t_load) / 1000.0))
	get_tree().quit()
